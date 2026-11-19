//! The store of the airlock engine: one folder, one WAL, one ratchet, the pinned policy files. NATIVE CHECK, not proved.
//! Record (variable length, little-endian; layout in PROTOCOL.md):
//!   [0..4) "FAR1"  [4..12) epoch  [12..28) FNV-1a-128 of the previous record (zero in the genesis record)
//!   [28..32) payload length L (at most MAX_PAYLOAD)  [32..32+L) payload: printable ASCII  [32+L..36+L) CRC-32/IEEE of bytes 0..32+L
//! FNV-1a-128 is NOT cryptographic. It is a compare-and-swap value and a chain against torn, spliced or restored files.
//! It authenticates nothing: whoever can write the store folder is trusted.
use crate::ledger::Ledger;
use crate::policy::{self, Policy};
use crate::{cut, no, split, Code, Refusal};
use std::collections::HashMap;
use std::fs::{File, OpenOptions};
use std::io::{self, BufReader, Read, Write};
use std::path::Path;

pub const HDR: usize = 32;
pub const MAX_PAYLOAD: usize = 32768;
pub const MAX_MONEY: u64 = 9_223_372_036_854_775_807;
const MAGIC: &[u8; 4] = b"FAR1";
pub const WAL: &str = "airlock.wal";
pub const EPOCH: &str = "airlock.epoch";
const MAX_POLICY_FILE: u64 = 1 << 20;
const MAX_POLICIES: usize = 32;

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
/// FNV-1a, 128 bits. NOT cryptographic.
pub fn fnv128(data: &[u8]) -> u128 {
    data.iter().fold(0x6c62272e07bb014262b821756295c58d, |h: u128, &b| (h ^ b as u128).wrapping_mul(0x0000000001000000000000000000013b))
}
pub fn hx(h: u128) -> String {
    format!("{h:032x}")
}
/// A hash on the wire: exactly 32 lowercase hex digits.
pub fn parse_hash(s: &str) -> Option<u128> {
    let ok = s.len() == 32 && s.bytes().all(|b| b.is_ascii_digit() || (b'a'..=b'f').contains(&b));
    if ok { u128::from_str_radix(s, 16).ok() } else { None }
}
/// The one spelling of an id: 1 to 24 bytes of `[A-Za-z0-9_-]`.
pub fn canonical_id(id: &str) -> bool {
    !id.is_empty() && id.len() <= 24 && id.bytes().all(|b| b.is_ascii_alphanumeric() || b == b'_' || b == b'-')
}
/// The one spelling of an amount: `0`, or a nonzero digit and up to 18 more digits; at most MAX_MONEY.
pub fn money(s: &str) -> Option<u64> {
    let canonical = s == "0" || (!s.starts_with('0') && (1..=19).contains(&s.len()) && s.bytes().all(|b| b.is_ascii_digit()));
    if !canonical { return None }
    s.parse::<u64>().ok().filter(|v| *v <= MAX_MONEY)
}
pub fn encode(epoch: u64, prev: u128, payload: &str) -> Vec<u8> {
    let mut r = Vec::with_capacity(HDR + payload.len() + 4);
    r.extend_from_slice(MAGIC);
    r.extend_from_slice(&epoch.to_le_bytes());
    r.extend_from_slice(&prev.to_le_bytes());
    r.extend_from_slice(&(payload.len() as u32).to_le_bytes());
    r.extend_from_slice(payload.as_bytes());
    let crc = crc32(&r);
    r.extend_from_slice(&crc.to_le_bytes());
    r
}
fn path(dir: &str, name: &str) -> String {
    format!("{dir}/{name}")
}
pub fn policy_file(name: &str) -> String {
    format!("policy-{name}.json")
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
/// Folds the WAL as a stream; memory per record is bounded by MAX_PAYLOAD. `on` sees each valid record.
/// The valid prefix must hold the genesis record. After it, at most one incomplete record may follow, and only at
/// the end of the file (fewer than HDR bytes, or a header whose length runs past the end): a torn append.
/// Anything else is CORRUPT_WAL. Returns the fold and the length of the whole file.
pub fn scan(r: &mut impl Read, on: &mut dyn FnMut(u64, &str)) -> Result<(Ledger, u64), Refusal> {
    let mut l = Ledger::default();
    let (mut index, mut torn) = (0u64, 0u64);
    loop {
        let mut hdr = [0u8; HDR];
        let got = read_full(r, &mut hdr)?;
        if got == 0 { break }
        if got < HDR { torn = got as u64; break }
        let len = u32::from_le_bytes(hdr[28..32].try_into().expect("4 bytes")) as usize;
        if &hdr[..4] != MAGIC || len > MAX_PAYLOAD { return no(Code::CorruptWal, format!("CORRUPT_WAL record {index}: magic or length")) }
        let mut body = vec![0u8; len + 4];
        let got = read_full(r, &mut body)?;
        if got < body.len() { torn = (HDR + got) as u64; break }
        let mut rec = hdr.to_vec();
        rec.extend_from_slice(&body);
        let payload = &rec[HDR..HDR + len];
        let framed = rec[HDR + len..] == crc32(&rec[..HDR + len]).to_le_bytes()
            && hdr[4..12] == index.to_le_bytes()
            && hdr[12..28] == l.tail.to_le_bytes()
            && payload.iter().all(|b| (0x20..0x7f).contains(b));
        let hash = fnv128(&rec);
        let text = std::str::from_utf8(payload).unwrap_or("");
        if !framed || l.apply(index, text, hash).is_none() {
            return no(Code::CorruptWal, format!("CORRUPT_WAL record {index}: CRC, epoch, chain or content"));
        }
        on(index, text);
        l.tail = hash;
        l.epoch = index;
        l.len += rec.len() as u64;
        index += 1;
    }
    if index == 0 { return no(Code::CorruptWal, "CORRUPT_WAL no genesis record") }
    let total = l.len + torn;
    Ok((l, total))
}
fn push(ratchet: &mut File, epoch: u64) -> io::Result<()> {
    let e = epoch.to_le_bytes();
    ratchet.write_all(&[&e[..], &crc32(&e).to_le_bytes()[..]].concat()).and_then(|()| ratchet.sync_all())
}
pub struct Store {
    pub wal: File,
    ratchet: File,
    pub l: Ledger,
    pub policies: HashMap<String, Policy>,
}
/// Every command but `init` starts here: lock, fold, ratchet check, recovery, pinned policies.
pub fn open(dir: &str) -> Result<Store, Refusal> {
    let wal = OpenOptions::new().read(true).append(true).open(path(dir, WAL))?;
    wal.lock()?; // exclusive flock, taken before any file of the store is read; the kernel releases it at exit or kill
    let (l, total) = scan(&mut BufReader::new(&wal), &mut |_, _| {})?;
    let mut ratchet = OpenOptions::new().read(true).append(true).open(path(dir, EPOCH))?;
    let (mut size, mut floor) = (0u64, None::<u64>);
    {
        let mut rd = BufReader::new(&ratchet);
        let mut e = [0u8; 12];
        loop {
            let got = read_full(&mut rd, &mut e)?;
            size += got as u64;
            if got < 12 { break }
            if e[8..] == crc32(&e[..8]).to_le_bytes() {
                let v = u64::from_le_bytes(e[..8].try_into().expect("8 bytes"));
                floor = Some(floor.map_or(v, |f| f.max(v)));
            }
        }
    }
    let Some(floor) = floor else { return no(Code::CorruptWal, "CORRUPT_WAL the ratchet has no valid entry") };
    if l.epoch < floor { return no(Code::EpochRegression, "EPOCH_REGRESSION the WAL is older than its ratchet (a restored file?)") }
    if size % 12 != 0 || l.len < total || floor < l.epoch {
        ratchet.set_len(size - size % 12)?; // a torn ratchet entry
        let wal_ref = &wal;
        wal_ref.set_len(l.len)?; // a torn record
        wal_ref.sync_all()?;
        push(&mut ratchet, l.epoch)?;
    }
    let mut policies = HashMap::new();
    for pin in &l.pins {
        let mut bytes = Vec::new();
        File::open(path(dir, &policy_file(&pin.name)))?.take(MAX_POLICY_FILE + 1).read_to_end(&mut bytes)?;
        if fnv128(&bytes) != pin.hash { return no(Code::CorruptWal, format!("CORRUPT_WAL POLICY_CHANGED {}", pin.name)) }
        let p = policy::parse(&bytes).map_err(|e| Refusal(Code::CorruptWal, format!("CORRUPT_WAL POLICY_UNREADABLE {e}")))?;
        if p.kind() != pin.kind || p.name() != pin.name { return no(Code::CorruptWal, "CORRUPT_WAL POLICY_CHANGED") }
        policies.insert(pin.name.clone(), p);
    }
    Ok(Store { wal, ratchet, l, policies })
}
/// Prints every valid record again (for `replay`); call it on an open store (the lock is held).
pub fn records(s: &Store, on: &mut dyn FnMut(u64, &str)) -> Result<(), Refusal> {
    let mut f = &s.wal;
    io::Seek::seek(&mut f, io::SeekFrom::Start(0))?;
    scan(&mut BufReader::new(f).take(s.l.len), on).map(|_| ())
}
impl Store {
    /// Appends one record and makes it durable. Order: fold check -> write -> sync_all (F_FULLFSYNC on macOS)
    /// -> ratchet entry -> sync_all -> lock released. A failed write or sync leaves no record, or answers OUTCOME_UNKNOWN.
    pub fn append(self, payload: &str) -> Result<(u64, u128), Refusal> {
        let Store { wal, mut ratchet, mut l, .. } = self;
        let (old_len, epoch) = (l.len, l.epoch + 1);
        if payload.len() > MAX_PAYLOAD { return no(Code::Malformed, "RECORD_TOO_LONG") }
        let rec = encode(epoch, l.tail, payload);
        let hash = fnv128(&rec);
        // The writer and the fold must agree: a record that the fold would refuse is never written.
        if l.apply(epoch, payload, hash).is_none() { return no(Code::Malformed, "RECORD_NOT_FOLDABLE") }
        let mut w = &wal;
        cut("a");
        let at = split(rec.len(), "b");
        let first = w.write_all(&rec[..at]);
        cut("b");
        let written = first.and_then(|()| w.write_all(&rec[at..]));
        cut("c");
        if let Err(e) = written.and_then(|()| wal.sync_all()) {
            let undone = wal.set_len(old_len).and_then(|()| wal.sync_all()); // no record may stay whose write or sync failed
            return if undone.is_ok() { Err(e.into()) } else { no(Code::OutcomeUnknown, "OUTCOME_UNKNOWN a record may be in the WAL; nothing was answered as committed") };
        }
        cut("r");
        if push(&mut ratchet, epoch).is_err() { return no(Code::OutcomeUnknown, "OUTCOME_UNKNOWN the record is in the WAL; its ratchet entry failed") }
        drop((wal, ratchet)); // the lock ends here, before the answer
        cut("d");
        Ok((epoch, hash))
    }
}
/// Creates a new store. It never replaces an existing path: it builds the store in a fresh sibling folder,
/// syncs every file and the folder, renames the folder into place, and syncs the parent folder.
pub fn init(dir: &str, store_id: &str, policy_paths: &[String], pubkey: Option<&str>) -> Result<String, Refusal> {
    if !canonical_id(store_id) { return no(Code::Malformed, "BAD_ID store_id") }
    if let Some(k) = pubkey {
        if k.len() != 64 || !k.bytes().all(|b| b.is_ascii_digit() || (b'a'..=b'f').contains(&b)) { return no(Code::Malformed, "BAD_PUBKEY") }
    }
    if policy_paths.len() > MAX_POLICIES { return no(Code::MalformedPolicy, "TOO_MANY_POLICIES") }
    let mut loaded: Vec<(String, &'static str, Vec<u8>)> = Vec::new();
    for p in policy_paths {
        let mut bytes = Vec::new();
        File::open(p)?.take(MAX_POLICY_FILE + 1).read_to_end(&mut bytes)?;
        let pol = policy::parse(&bytes).map_err(|e| Refusal(Code::MalformedPolicy, e))?;
        if loaded.iter().any(|(n, _, _)| n == pol.name()) { return no(Code::MalformedPolicy, "DUPLICATE_POLICY_NAME") }
        loaded.push((pol.name().to_string(), pol.kind(), bytes));
    }
    let target = Path::new(dir);
    if target.symlink_metadata().is_ok() { return no(Code::IoError, "STORE_EXISTS the path exists already") }
    let parent = match target.parent() { Some(p) if !p.as_os_str().is_empty() => p.to_path_buf(), _ => Path::new(".").to_path_buf() };
    let nanos = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map(|d| d.as_nanos()).unwrap_or(0);
    let tmp = format!("{dir}.init-{}-{nanos}", std::process::id());
    std::fs::create_dir(&tmp)?;
    let made = (|| -> Result<(u128, u64), Refusal> {
        let mut pins = String::new();
        for (name, kind, bytes) in &loaded {
            let mut f = OpenOptions::new().write(true).create_new(true).open(path(&tmp, &policy_file(name)))?;
            f.write_all(bytes)?;
            f.sync_all()?;
            pins.push_str(&format!(" {name} {kind} {}", hx(fnv128(bytes))));
        }
        let genesis = encode(0, 0, &format!("GENESIS 1 {store_id} {} {}{pins}", pubkey.unwrap_or("-"), loaded.len()));
        let mut ratchet = OpenOptions::new().append(true).create_new(true).open(path(&tmp, EPOCH))?;
        push(&mut ratchet, 0)?;
        let mut wal = OpenOptions::new().write(true).create_new(true).open(path(&tmp, WAL))?;
        wal.write_all(&genesis)?;
        wal.sync_all()?;
        File::open(&tmp)?.sync_all()?;
        let mut check = Ledger::default();
        if check.apply(0, std::str::from_utf8(&genesis[HDR..genesis.len() - 4]).unwrap_or(""), 0).is_none() {
            return no(Code::Malformed, "GENESIS_NOT_FOLDABLE");
        }
        cut("i");
        Ok((fnv128(&genesis), genesis.len() as u64))
    })();
    let done = made.and_then(|(h, genesis_len)| {
        if target.symlink_metadata().is_ok() { return no(Code::IoError, "STORE_EXISTS the path exists already") }
        std::fs::rename(&tmp, dir)?;
        let parent_synced = (|| -> io::Result<()> {
        File::open(&parent)?.sync_all()?;
            Ok(())
        })();
        if let Err(e) = parent_synced { return undo_init(dir, &tmp, &parent, genesis_len, e) }
        Ok(h)
    });
    match done {
        Ok(h) => Ok(format!("INITIALIZED {store_id} {}", hx(h))),
        Err(e) => {
            let _ = std::fs::remove_dir_all(&tmp); // a refused init leaves no folder of its own
            Err(e)
        }
    }
}
/// The sync of the parent folder failed after the rename: the store must not stay behind a refusal. Under the store
/// lock, and only if no other process has written a record yet, the WAL is emptied and synced (a process that opened
/// the store meanwhile then gets CORRUPT_WAL, never a commit), the folder is renamed back and removed, and the parent
/// folder is synced again. All of that worked: IO_ERROR, no store. Any step failed, or a record was written:
/// OUTCOME_UNKNOWN, and the store (live, or with an empty WAL) may stay.
fn undo_init(dir: &str, tmp: &str, parent: &Path, genesis_len: u64, e: io::Error) -> Result<u128, Refusal> {
    let unknown = |why: &str| no(Code::OutcomeUnknown, format!("OUTCOME_UNKNOWN init: the parent folder sync failed and {why}; the store may stay"));
    let Ok(wal) = OpenOptions::new().write(true).open(path(dir, WAL)) else { return unknown("the WAL could not be opened") };
    if wal.lock().is_err() { return unknown("the WAL could not be locked") }
    if !matches!(wal.metadata(), Ok(m) if m.len() == genesis_len) { return unknown("another process wrote to the store") }
    if wal.set_len(0).and_then(|()| wal.sync_all()).is_err() { return unknown("the WAL could not be emptied") }
    let removed = std::fs::rename(dir, tmp).and_then(|()| std::fs::remove_dir_all(tmp)).and_then(|()| File::open(parent)?.sync_all());
    if removed.is_err() { return unknown("the store could not be removed") }
    Err(e.into())
}
