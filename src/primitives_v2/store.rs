//! The store of the primitives engine: one folder, one write-ahead log, the pinned policy files. NATIVE CHECK, not
//! proved. Record (little-endian; PROTOCOL.md section 3):
//!   [0..4) "PV2R"  [4..12) seq (0 = genesis, then +1)  [12..20) engine time now_ms  [20..28) raw wall_ms
//!   [28..60) SHA-256 of the whole previous record (zero in the genesis record)  [60..64) payload length L
//!   [64..68) CRC-32 of bytes 0..64 (the header check)  [68..68+L) payload, printable ASCII
//!   [68+L..72+L) CRC-32 of bytes 0..68+L
//! The SHA-256 chain and the CRCs find torn, spliced, reordered and damaged files. They authenticate nothing: whoever
//! can write the store folder can write a new valid chain (PROTOCOL.md section 9, trust boundary).
use crate::engine::{self, Modules, PolicySet};
use crate::pin::Sha256;
use crate::prim::{refusal, Kind, Now, Record, Refusal};
use std::collections::{BTreeMap, HashSet};
use std::fs::{self, DirBuilder, File, OpenOptions, TryLockError};
use std::io::{self, BufReader, Read, Write};
use std::os::unix::fs::{DirBuilderExt, MetadataExt, OpenOptionsExt};
use std::path::Path;
use std::sync::OnceLock;
use std::time::{Duration, Instant};

pub const HDR: usize = 68;
pub const MAX_PAYLOAD: usize = 1 << 17;
const MAGIC: &[u8; 4] = b"PV2R";
pub const WAL: &str = "primitives.wal";
const MAX_POLICY_FILE: u64 = 1 << 20;
const MAX_POLICIES: usize = 64;
const LOCK_WAIT: Duration = Duration::from_secs(60);
/// The build kind written in the genesis record. A store of one build kind is refused by the other.
pub const BUILD: &str = if cfg!(test_seams) { "test-seams" } else { "production" };
#[cfg(target_os = "macos")]
const O_NOFOLLOW: i32 = 0x0100;
#[cfg(not(target_os = "macos"))]
const O_NOFOLLOW: i32 = 0o400000;

pub fn crc32(data: &[u8]) -> u32 {
    let mut c = !0u32;
    for &b in data {
        c ^= b as u32;
        for _ in 0..8 {
            c = if c & 1 == 1 { (c >> 1) ^ 0xEDB8_8320 } else { c >> 1 };
        }
    }
    !c
}
pub fn sha256(data: &[u8]) -> [u8; 32] {
    let mut s = Sha256::new();
    s.update(data);
    let h = s.hex();
    let mut out = [0u8; 32];
    for (i, o) in out.iter_mut().enumerate() {
        *o = u8::from_str_radix(&h[2 * i..2 * i + 2], 16).expect("sha256 hex");
    }
    out
}
pub fn hx(b: &[u8]) -> String {
    b.iter().map(|x| format!("{x:02x}")).collect()
}
/// A state hash on the wire: exactly 64 lowercase hex digits.
pub fn parse_hash(s: &str) -> Option<[u8; 32]> {
    if s.len() != 64 || !s.bytes().all(|b| b.is_ascii_digit() || (b'a'..=b'f').contains(&b)) { return None }
    let mut out = [0u8; 32];
    for (i, o) in out.iter_mut().enumerate() {
        *o = u8::from_str_radix(&s[2 * i..2 * i + 2], 16).ok()?;
    }
    Some(out)
}
/// Ids (tenant, request id, store id, policy name): `[A-Za-z0-9_-]{1,24}`.
pub fn canonical_id(id: &str) -> bool {
    !id.is_empty() && id.len() <= 24 && id.bytes().all(|b| b.is_ascii_alphanumeric() || b == b'_' || b == b'-')
}
/// Keys: `[A-Za-z0-9_.:@+-]{1,128}` (no space, no `=`, no `*`).
pub fn canonical_key(k: &str) -> bool {
    !k.is_empty() && k.len() <= 128 && k.bytes().all(|b| b.is_ascii_alphanumeric() || b"_.:@+-".contains(&b))
}
pub fn printable(s: &[u8]) -> bool {
    s.iter().all(|b| (0x20..0x7f).contains(b))
}

pub fn encode(seq: u64, now_ms: u64, wall_ms: u64, prev: &[u8; 32], payload: &str) -> Vec<u8> {
    let mut r = Vec::with_capacity(HDR + payload.len() + 4);
    r.extend_from_slice(MAGIC);
    r.extend_from_slice(&seq.to_le_bytes());
    r.extend_from_slice(&now_ms.to_le_bytes());
    r.extend_from_slice(&wall_ms.to_le_bytes());
    r.extend_from_slice(prev);
    r.extend_from_slice(&(payload.len() as u32).to_le_bytes());
    let hc = crc32(&r);
    r.extend_from_slice(&hc.to_le_bytes());
    r.extend_from_slice(payload.as_bytes());
    let crc = crc32(&r);
    r.extend_from_slice(&crc.to_le_bytes());
    r
}

pub struct KeyInfo {
    pub tenant: String,
    pub primitive: &'static str,
    pub hash: [u8; 32],
}
/// The engine's fold of the WAL: chain position, time floor, keys, used request ids, module states, policies.
#[derive(Default)]
pub struct Folded {
    pub store_id: String,
    pub genesis_hash: [u8; 32],
    pub pins: Vec<(String, String, String)>, // (policy name, primitive, SHA-256 of the file)
    pub seq: u64,
    pub tail: [u8; 32],
    pub last_ms: u64,
    pub len: u64,
    pub records: u64,
    pub keys: BTreeMap<String, KeyInfo>,
    pub ids: HashSet<String>,
    pub m: Modules,
    pub pol: PolicySet,
}

fn u64_le(b: &[u8]) -> u64 {
    u64::from_le_bytes(b.try_into().expect("8 bytes"))
}

impl Folded {
    /// Applies one record (genesis at seq 0). `dir`: where the pinned policy files are (None: do not load them).
    /// Err: the record is not valid here (CORRUPT_WAL at replay; MODULE_FAULT for a record about to be written).
    pub fn apply(&mut self, seq: u64, now_ms: u64, wall_ms: u64, payload: &str, hash: [u8; 32], rec_len: u64, dir: Option<&str>) -> Result<(), String> {
        if wall_ms > now_ms { return Err("WALL_AFTER_ENGINE_TIME".into()) }
        if seq == 0 {
            self.genesis(payload, hash, dir)?;
        } else {
            if self.records == 0 { return Err("NO_GENESIS".into()) }
            if now_ms < self.last_ms { return Err("TIME_WENT_BACK".into()) }
            self.effect(seq, now_ms, payload, hash)?;
        }
        self.seq = seq;
        self.tail = hash;
        self.last_ms = now_ms;
        self.len = self.len.checked_add(rec_len).ok_or("LENGTH")?;
        self.records += 1;
        Ok(())
    }
    fn genesis(&mut self, payload: &str, hash: [u8; 32], dir: Option<&str>) -> Result<(), String> {
        let t: Vec<&str> = payload.split(' ').collect();
        if t.len() < 6 || t[0] != "G" || t[1] != "pv2" { return Err("GENESIS_FORM".into()) }
        if !canonical_id(t[2]) || t[3].len() != 32 || parse_hash(&format!("{}{}", t[3], t[3])).is_none() { return Err("GENESIS_FORM".into()) }
        if t[4] != BUILD { return Err(format!("BUILD_MISMATCH the store is of build {}; this is the {BUILD} build", t[4])) }
        let n = crate::prim::dec_u64(t[5]).filter(|n| *n as usize <= MAX_POLICIES).ok_or("GENESIS_FORM")? as usize;
        if t.len() != 6 + 3 * n { return Err("GENESIS_FORM".into()) }
        for i in 0..n {
            let (name, prim, sha) = (t[6 + 3 * i], t[7 + 3 * i], t[8 + 3 * i]);
            if !canonical_id(name) || parse_hash(sha).is_none() || self.pins.iter().any(|p| p.0 == name) { return Err("GENESIS_FORM".into()) }
            self.pins.push((name.into(), prim.into(), sha.into()));
        }
        if let Some(dir) = dir {
            for (name, prim, sha) in self.pins.clone() {
                let bytes = read_private(&format!("{dir}/{}", policy_file(&name)), MAX_POLICY_FILE).map_err(|e| format!("POLICY_UNREADABLE {name} {e}"))?;
                if hx(&sha256(&bytes)) != sha { return Err(format!("POLICY_CHANGED {name}")) }
                let (got_name, got_prim) = self.pol.add(&bytes).map_err(|e| format!("POLICY_UNREADABLE {name} {e}"))?;
                if got_name != name || got_prim != prim { return Err(format!("POLICY_CHANGED {name}")) }
            }
        }
        self.store_id = t[2].into();
        self.genesis_hash = hash;
        Ok(())
    }
    /// `E <primitive> <op> <request_id> <tenant> <C|R> <n> <key_1> ... <key_n> | <module payload>`
    fn effect(&mut self, seq: u64, now_ms: u64, payload: &str, hash: [u8; 32]) -> Result<(), String> {
        let mut head = payload.splitn(8, ' ');
        let mut next = || head.next().ok_or_else(|| "EFFECT_FORM".to_string());
        let (e, prim, op, rid, tenant, kind, n, rest) = (next()?, next()?, next()?, next()?, next()?, next()?, next()?, next()?);
        if e != "E" { return Err("EFFECT_FORM".into()) }
        let prim = engine::primitive_name(prim).ok_or("UNKNOWN_PRIMITIVE")?;
        let spec = engine::op_spec(prim, op).ok_or("UNKNOWN_OP")?;
        let kind = match kind { "C" => Kind::Commit, "R" => Kind::Refusal, _ => return Err("EFFECT_FORM".into()) };
        let n = crate::prim::dec_u64(n).ok_or("EFFECT_FORM")? as usize;
        if n == 0 || n < spec.min_keys || n > spec.max_keys { return Err("KEY_COUNT".into()) }
        if !canonical_id(rid) || !canonical_id(tenant) { return Err("EFFECT_FORM".into()) }
        if self.ids.contains(rid) { return Err("REQUEST_ID_REUSED".into()) }
        let mut parts = rest.splitn(n + 1, ' ');
        let mut keys: Vec<&str> = Vec::with_capacity(n);
        for _ in 0..n {
            let k = parts.next().ok_or("EFFECT_FORM")?;
            if !canonical_key(k) || keys.last().map_or(false, |p| *p >= k) { return Err("KEY_ORDER".into()) }
            keys.push(k);
        }
        let tail = parts.next().ok_or("EFFECT_FORM")?;
        let module_payload = if tail == "|" { "" } else { tail.strip_prefix("| ").ok_or("EFFECT_FORM")? };
        if module_payload.len() > crate::prim::MAX_MODULE_PAYLOAD { return Err("PAYLOAD_TOO_LONG".into()) }
        for k in &keys {
            if let Some(info) = self.keys.get(*k) {
                if info.tenant != tenant { return Err("KEY_OF_ANOTHER_TENANT".into()) }
                if info.primitive != prim { return Err("KEY_KIND".into()) }
            }
        }
        let rec = Record { seq, now_ms, request_id: rid, tenant, op, kind, keys: &keys, payload: module_payload };
        engine::fold_module(&mut self.m, &self.pol, prim, &rec).map_err(|e| format!("MODULE {prim}: {e}"))?;
        for k in &keys {
            self.keys.insert(k.to_string(), KeyInfo { tenant: tenant.into(), primitive: prim, hash });
        }
        self.ids.insert(rid.into());
        Ok(())
    }
    /// The state hash of a key: the hash of the last record that touched it, or the genesis hash for a key that no
    /// record has touched.
    pub fn key_hash(&self, key: &str) -> [u8; 32] {
        self.keys.get(key).map_or(self.genesis_hash, |k| k.hash)
    }
}

/// Reads until `buf` is full or EOF. Returns the number of bytes read.
fn read_full(r: &mut impl Read, buf: &mut [u8]) -> io::Result<usize> {
    let mut got = 0;
    while got < buf.len() {
        match r.read(&mut buf[got..]) {
            Ok(0) => break,
            Ok(n) => got += n,
            Err(e) if e.kind() == io::ErrorKind::Interrupted => {}
            Err(e) => return Err(e),
        }
    }
    Ok(got)
}
/// `why` is the first word of the fault; the rest goes to the detail.
fn corrupt(index: u64, why: &str) -> Refusal {
    let (word, rest) = why.split_once(' ').unwrap_or((why, ""));
    refusal("CORRUPT_WAL", vec![("why", word.to_string()), ("record", index.to_string())], format!("the store is refused; there is no repair. {rest}"))
}

/// Folds the WAL as a stream (memory per record bounded by MAX_PAYLOAD). Returns the fold and the file length.
/// After the valid prefix, at most one incomplete record may follow, and only at the end of the file: bytes that
/// agree with a record start (a prefix of the magic and, once present, the expected seq), or a whole header whose
/// header check is valid and whose length runs past the end. Every other fault refuses the store.
pub fn scan(r: &mut impl Read, dir: Option<&str>, on: &mut dyn FnMut(u64, u64, u64, &str)) -> Result<(Folded, u64), Refusal> {
    let mut f = Folded::default();
    let (mut index, mut torn) = (0u64, 0u64);
    loop {
        let mut hdr = [0u8; HDR];
        let got = read_full(r, &mut hdr)?;
        if got == 0 { break }
        if got < HDR {
            let m = got.min(4);
            let seq_ok = got < 12 || u64_le(&hdr[4..12]) == index;
            if hdr[..m] != MAGIC[..m] || !seq_ok { return Err(corrupt(index, "TAIL_NOT_A_RECORD_START")) }
            torn = got as u64;
            break;
        }
        if &hdr[..4] != MAGIC || hdr[64..68] != crc32(&hdr[..64]).to_le_bytes() { return Err(corrupt(index, "HEADER")) }
        let len = u32::from_le_bytes(hdr[60..64].try_into().expect("4 bytes")) as usize;
        if u64_le(&hdr[4..12]) != index || len > MAX_PAYLOAD { return Err(corrupt(index, "SEQ_OR_LENGTH")) }
        let mut body = vec![0u8; len + 4];
        let got = read_full(r, &mut body)?;
        if got < body.len() {
            torn = (HDR + got) as u64;
            break;
        }
        let mut rec = hdr.to_vec();
        rec.extend_from_slice(&body);
        let payload = &rec[HDR..HDR + len];
        if rec[HDR + len..] != crc32(&rec[..HDR + len]).to_le_bytes() { return Err(corrupt(index, "CRC")) }
        if hdr[28..60] != f.tail { return Err(corrupt(index, "CHAIN")) }
        if !printable(payload) { return Err(corrupt(index, "PAYLOAD_BYTES")) }
        let text = std::str::from_utf8(payload).expect("printable ASCII");
        let (now_ms, wall_ms) = (u64_le(&hdr[12..20]), u64_le(&hdr[20..28]));
        let hash = sha256(&rec);
        if let Err(e) = f.apply(index, now_ms, wall_ms, text, hash, rec.len() as u64, dir) {
            return Err(corrupt(index, &e));
        }
        on(index, now_ms, wall_ms, text);
        index += 1;
    }
    if index == 0 { return Err(corrupt(0, "NO_GENESIS")) }
    let total = f.len + torn;
    Ok((f, total))
}

/// The effective user id, without `unsafe`: the owner of a new file that this process creates (O_CREAT|O_EXCL) in
/// the store folder, which is then removed. Once per process.
static EUID: OnceLock<Result<u32, String>> = OnceLock::new();
fn euid(dir: &str) -> Result<u32, String> {
    EUID.get_or_init(|| {
        for n in 0..16u32 {
            let p = format!("{dir}/.euid-probe-{}-{n}", std::process::id());
            match OpenOptions::new().write(true).create_new(true).mode(0o600).custom_flags(O_NOFOLLOW).open(&p) {
                Ok(f) => {
                    let uid = f.metadata().map(|m| m.uid());
                    drop(f);
                    let rm = fs::remove_file(&p);
                    let uid = uid.map_err(|e| format!("PROBE_FSTAT {:?}", e.kind()))?;
                    rm.map_err(|e| format!("PROBE_REMOVE {:?}", e.kind()))?;
                    return Ok(uid);
                }
                Err(e) if e.kind() == io::ErrorKind::AlreadyExists => continue,
                Err(e) => return Err(format!("PROBE {:?}", e.kind())),
            }
        }
        Err("PROBE no free name".into())
    })
    .clone()
}
fn unsafe_store(why: String) -> Refusal {
    refusal("UNSAFE_STORE", vec![("why", why.split(' ').next().unwrap_or("").to_string())], why)
}
/// The store folder: a directory (not a symbolic link), mode & 0o077 == 0, owner == the effective user.
fn check_dir(dir: &str) -> Result<u32, Refusal> {
    let m = fs::symlink_metadata(dir).map_err(|e| refusal("IO_ERROR", vec![("why", "NO_STORE".into())], format!("{:?}", e.kind())))?;
    if !m.file_type().is_dir() { return Err(unsafe_store("NOT_A_FOLDER the store path is not a folder (a symbolic link is refused)".into())) }
    if m.mode() & 0o077 != 0 { return Err(unsafe_store(format!("FOLDER_MODE {:o}: group or other bits are set; need 0700", m.mode() & 0o7777))) }
    let uid = euid(dir).map_err(|e| unsafe_store(format!("EUID {e}")))?;
    if m.uid() != uid { return Err(unsafe_store(format!("FOLDER_OWNER uid {} is not the effective uid {uid}", m.uid()))) }
    Ok(uid)
}
/// A store file: opened without following a symbolic link, the same file as its lstat, regular, mode & 0o077 == 0,
/// owner == the effective user.
fn check_file(f: &File, path: &str, uid: u32) -> Result<(), Refusal> {
    let lm = fs::symlink_metadata(path)?;
    let fm = f.metadata()?;
    if !lm.file_type().is_file() || !fm.file_type().is_file() || lm.dev() != fm.dev() || lm.ino() != fm.ino() {
        return Err(unsafe_store("NOT_A_REGULAR_FILE a store file is not a regular file".into()));
    }
    if fm.mode() & 0o077 != 0 { return Err(unsafe_store(format!("FILE_MODE {:o}: group or other bits are set; need 0600", fm.mode() & 0o7777))) }
    if fm.uid() != uid { return Err(unsafe_store(format!("FILE_OWNER uid {} is not the effective uid {uid}", fm.uid()))) }
    Ok(())
}
fn read_private(path: &str, max: u64) -> Result<Vec<u8>, String> {
    let f = OpenOptions::new().read(true).custom_flags(O_NOFOLLOW).open(path).map_err(|e| format!("{:?}", e.kind()))?;
    let dir = Path::new(path).parent().and_then(|p| p.to_str()).unwrap_or(".");
    let uid = euid(dir)?;
    check_file(&f, path, uid).map_err(|r| r.detail)?;
    let mut bytes = Vec::new();
    f.take(max + 1).read_to_end(&mut bytes).map_err(|e| format!("{:?}", e.kind()))?;
    if bytes.len() as u64 > max { return Err("TOO_LONG".into()) }
    Ok(bytes)
}
pub fn policy_file(name: &str) -> String {
    format!("policy-{name}.json")
}

/// Test seam, live only in the `--cfg test_seams` build: at the point PRIMITIVES_TEST_PAUSE_AT names, the process
/// writes `AT <point>` to stderr and waits for SIGKILL (the store lock stays held).
pub fn pause(point: &str) {
    let at = if cfg!(test_seams) { std::env::var("PRIMITIVES_TEST_PAUSE_AT").ok() } else { None };
    if at.as_deref() == Some(point) {
        eprintln!("AT {point}");
        loop {
            std::thread::park();
        }
    }
}

pub struct Store {
    wal: File,
    pub f: Folded,
}
/// Every command but `init` starts here: folder and file checks, the exclusive lock (bounded wait), the fold, the
/// cut of a torn last record, the pinned policies.
pub fn open(dir: &str) -> Result<Store, Refusal> {
    let uid = check_dir(dir)?;
    let path = format!("{dir}/{WAL}");
    let wal = OpenOptions::new().read(true).append(true).custom_flags(O_NOFOLLOW).open(&path).map_err(|e| unsafe_store(format!("WAL_OPEN {:?}", e.kind())))?;
    check_file(&wal, &path, uid)?;
    let deadline = Instant::now() + LOCK_WAIT;
    loop {
        match wal.try_lock() { // exclusive flock on the WAL, taken before any byte of the store is read
            Ok(()) => break,
            Err(TryLockError::WouldBlock) if Instant::now() < deadline => std::thread::sleep(Duration::from_millis(1)),
            Err(TryLockError::WouldBlock) => return Err(refusal("STORE_BUSY", vec![("retry_after_ms", "1000".into())], "another process held the store lock for 60 s")),
            Err(TryLockError::Error(e)) => return Err(e.into()),
        }
    }
    pause("locked");
    let (f, total) = scan(&mut BufReader::new(&wal), Some(dir), &mut |_, _, _, _| {})?;
    if f.len < total {
        let w = &wal;
        w.set_len(f.len)?; // the torn last record: it was never answered COMMITTED (the answer comes after its sync)
        w.sync_all()?;
    }
    Ok(Store { wal, f })
}
/// Every valid record again, for `replay` (on an open store: the lock is held).
pub fn records(s: &Store, dir: &str, on: &mut dyn FnMut(u64, u64, u64, &str)) -> Result<(), Refusal> {
    let mut w = &s.wal;
    io::Seek::seek(&mut w, io::SeekFrom::Start(0))?;
    scan(&mut BufReader::new(w).take(s.f.len), Some(dir), on).map(|_| ())
}

impl Store {
    /// Appends one record and makes it durable. Order: fold check -> write -> sync_all (F_FULLFSYNC on macOS) ->
    /// return; the caller answers only after this returns Ok. A failed write or sync: the WAL is cut back to its old
    /// length and synced (IO_ERROR, nothing committed); if that fails too, OUTCOME_UNKNOWN.
    pub fn append(&mut self, payload: &str, now: &Now) -> Result<(u64, [u8; 32]), Refusal> {
        let fault = |why: &str| refusal("MODULE_FAULT", vec![("why", why.to_string())], "the engine refused to write this record");
        if payload.len() > MAX_PAYLOAD { return Err(fault("RECORD_TOO_LONG")) }
        let seq = self.f.seq.checked_add(1).ok_or_else(|| fault("SEQ_OVERFLOW"))?;
        let rec = encode(seq, now.now_ms, now.wall_ms, &self.f.tail, payload);
        let hash = sha256(&rec);
        let old_len = self.f.len;
        // The writer and the fold agree: a record that the fold would refuse is never written.
        if let Err(e) = self.f.apply(seq, now.now_ms, now.wall_ms, payload, hash, rec.len() as u64, None) {
            return Err(refusal("MODULE_FAULT", vec![("why", "RECORD_NOT_FOLDABLE".into())], e));
        }
        pause("before_write");
        let mut w = &self.wal;
        let written = w.write_all(&rec);
        pause("before_sync");
        if let Err(e) = written.and_then(|()| self.wal.sync_all()) {
            let undone = self.wal.set_len(old_len).and_then(|()| self.wal.sync_all()); // no record may stay whose write or sync failed
            return if undone.is_ok() { Err(e.into()) } else { Err(refusal("OUTCOME_UNKNOWN", vec![], "a record may be in the WAL; nothing was answered as committed")) };
        }
        pause("synced");
        Ok((seq, hash))
    }
}

/// Creates a new store in a fresh private sibling folder, syncs every file and the folder, renames the folder into
/// place and syncs the parent folder. It never replaces an existing path.
pub fn init(dir: &str, store_id: &str, policy_paths: &[String], clock: &mut crate::clock::Clock) -> Result<String, Refusal> {
    let malformed = |why: &str, d: String| refusal("MALFORMED_POLICY", vec![("why", why.to_string())], d);
    if !canonical_id(store_id) { return Err(refusal("USAGE", vec![("why", "BAD_STORE_ID".into())], "store id: [A-Za-z0-9_-]{1,24}")) }
    if policy_paths.len() > MAX_POLICIES { return Err(malformed("TOO_MANY_POLICIES", String::new())) }
    let mut check = PolicySet::default();
    let mut loaded: Vec<(String, &'static str, Vec<u8>)> = Vec::new();
    for p in policy_paths {
        let mut bytes = Vec::new();
        File::open(p)?.take(MAX_POLICY_FILE + 1).read_to_end(&mut bytes)?;
        if bytes.len() as u64 > MAX_POLICY_FILE { return Err(malformed("TOO_LONG", p.clone())) }
        let (name, prim) = check.add(&bytes).map_err(|e| malformed("POLICY", e))?;
        if loaded.iter().any(|(n, _, _)| *n == name) { return Err(malformed("DUPLICATE_POLICY_NAME", name)) }
        loaded.push((name, prim, bytes));
    }
    let mut nonce = [0u8; 16];
    File::open("/dev/urandom").and_then(|mut f| f.read_exact(&mut nonce)).map_err(|_| refusal("IO_ERROR", vec![("why", "NO_RANDOM".into())], "/dev/urandom could not be read"))?;
    let target = Path::new(dir);
    if target.symlink_metadata().is_ok() { return Err(refusal("IO_ERROR", vec![("why", "STORE_EXISTS".into())], "the path exists already")) }
    let parent = match target.parent() { Some(p) if !p.as_os_str().is_empty() => p.to_path_buf(), _ => Path::new(".").to_path_buf() };
    let now = clock.read(0)?;
    let tmp = format!("{dir}.init-{}-{}", std::process::id(), now.wall_ms);
    DirBuilder::new().mode(0o700).create(&tmp)?;
    let made = (|| -> Result<[u8; 32], Refusal> {
        let mut pins = String::new();
        for (name, prim, bytes) in &loaded {
            let mut f = OpenOptions::new().write(true).create_new(true).mode(0o600).open(format!("{tmp}/{}", policy_file(name)))?;
            f.write_all(bytes)?;
            f.sync_all()?;
            pins.push_str(&format!(" {name} {prim} {}", hx(&sha256(bytes))));
        }
        let payload = format!("G pv2 {store_id} {} {BUILD} {}{pins}", hx(&nonce), loaded.len());
        let genesis = encode(0, now.now_ms, now.wall_ms, &[0u8; 32], &payload);
        let hash = sha256(&genesis);
        let mut probe = Folded::default();
        probe.apply(0, now.now_ms, now.wall_ms, &payload, hash, genesis.len() as u64, None).map_err(|e| malformed("GENESIS_NOT_FOLDABLE", e))?;
        let mut wal = OpenOptions::new().write(true).create_new(true).mode(0o600).open(format!("{tmp}/{WAL}"))?;
        wal.write_all(&genesis)?;
        wal.sync_all()?;
        File::open(&tmp)?.sync_all()?;
        Ok(hash)
    })();
    let hash = match made {
        Ok(h) => h,
        Err(e) => {
            let _ = fs::remove_dir_all(&tmp); // a refused init leaves no folder of its own
            return Err(e);
        }
    };
    if target.symlink_metadata().is_ok() {
        let _ = fs::remove_dir_all(&tmp);
        return Err(refusal("IO_ERROR", vec![("why", "STORE_EXISTS".into())], "the path exists already"));
    }
    fs::rename(&tmp, dir)?;
    if File::open(&parent).and_then(|p| p.sync_all()).is_err() {
        return Err(refusal("OUTCOME_UNKNOWN", vec![("why", "PARENT_SYNC".into())], "the store folder is in place but the parent folder sync failed"));
    }
    Ok(format!("INITIALIZED store_id={store_id} genesis={} build={BUILD} now_ms={}", hx(&hash), now.now_ms))
}
