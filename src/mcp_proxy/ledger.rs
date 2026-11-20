//! `ledger.wal`: the native write-ahead state machine of the MCP airlock. Owner: worker LEDGER.
//! NATIVE CHECK and FINITE TEST, not proved. Standard library only, no `unsafe`.
//!
//! # What it does
//!
//! The ledger holds one chain of states. Epoch 0 is genesis. Each mutating call that passes the policy appends one
//! record and moves the head to epoch + 1. `commit` checks, in this order: (1) the request id is not committed yet
//! (`Duplicate`), (2) the caller's `pre` equals the head (`Mismatch`), then (3) it writes one record and calls
//! `sync_all()` before it returns `Committed`. `Duplicate` and `Mismatch` write nothing.
//!
//! # State hash (all integers big-endian; `frame(x)` = `u32 len(x) || x`)
//!
//! ```text
//! genesis = first16(SHA-256("forge-airlock-ledger-genesis-v1"))            (one fixed constant, no framing)
//! post    = first16(SHA-256( frame("forge-airlock-ledger-v1")
//!                         || frame(pre)                  16 bytes
//!                         || frame(epoch_be)             8 bytes, the epoch of the NEW record
//!                         || frame(SHA-256(request_id))  32 bytes, request id as UTF-8 bytes
//!                         || frame(tool)                 1..=1024 bytes, tool name as UTF-8 bytes
//!                         || frame(SHA-256(args_canon))  32 bytes, the raw request line bytes from PROXY ))
//! ```
//!
//! Every field has a length prefix, so two different field tuples give two different hash inputs.
//!
//! # Record layout in `ledger.wal` (the file is only a sequence of records; an empty file is genesis)
//!
//! ```text
//! offset  size  field
//! 0       4     magic "FAL1" (46 41 4c 31)
//! 4       4     N    = body length, u32 BE, 106 <= N <= 106 + 1024
//! 8       4     !N   = bitwise NOT of N, u32 BE (one damaged length byte is detected, never read as a torn tail)
//! 12      8     epoch u64 BE (record i has epoch i, i = 1, 2, ...)
//! 20      16    pre  (= post of record i-1, or genesis)
//! 36      16    post (= the state hash above)
//! 52      32    SHA-256(request_id)
//! 84      32    SHA-256(args_canon)
//! 116     2     T = tool length, u16 BE, 1 <= T <= 1024, N = 106 + T
//! 118     T     tool bytes
//! 12+N    32    check = SHA-256( frame("forge-airlock-ledger-record-v1") || frame(bytes 0 .. 12+N) )
//! ```
//!
//! # Store folder and file checks (on `open` and on `read_head`; round 3, findings R2 and D2)
//!
//! - The store folder (followed if it is a symlink) must be a directory with `mode & 0o022 == 0` (no group or other
//!   WRITE bit) and owner uid == euid. A folder of mode 0755 is accepted: others can read and list it, but they
//!   cannot add, remove or rename an entry (`ledger.wal` itself is 0600). A folder of mode 0775 or 0777 is refused.
//!   `open` creates a missing folder with mode 0700.
//! - `ledger.wal` must be a regular file (not a symlink), `mode & 0o077 == 0`, owner uid == euid.
//! - euid without `unsafe` and without a crate: the same method as `evidence.rs` (`crate::evidence::euid_probe`):
//!   create a new probe file with `O_CREAT | O_EXCL` in the store folder, read its owner with `fstat`, remove it.
//!   So `read_head` creates and removes one probe file in the store folder; it never writes `ledger.wal`. A store
//!   folder that is not writable is refused by both.
//! - Limits: the parent folders are not checked. A writer of a parent folder can rename the whole store folder away
//!   and put another one in its place; the start-up reconciliation with `evidence.wal` (in `proxy.rs`) is the check
//!   that finds a replaced or rolled-back ledger, and only while `evidence.wal` is intact.
//!
//! # Replay checks (on `open` and on `read_head`)
//!
//! For every record: magic, `N == !(!N)`, N in range, the per-record check, epoch = previous + 1, pre = previous
//! head, `post` recomputed from the fields, T consistent with N, and no request id digest seen before. Any failure
//! refuses the whole store. There is no repair.
//!
//! # Torn-tail rule
//!
//! A record is appended with one positional write, then `sync_all()`. A crash can leave an incomplete LAST record.
//! The rule: if the bytes after the last complete record are fewer than one full record, AND the bytes that are
//! present agree with a record start (the magic prefix; and `N`/`!N` once all 12 header bytes are present), then
//! this tail is a torn append. `open` cuts it off with `set_len` and `sync_all()` before any use. `read_head` ignores
//! it and changes nothing. A torn record was never acknowledged: `commit` returns `Committed` only after its
//! `sync_all()`, so no call was forwarded for it. Any other damage (a bad magic, a bad check, a full-length record
//! of zeros, a short tail that does not start like a record) refuses the store.
//!
//! # Limits (stated plainly)
//!
//! - The lock is an advisory `flock` (`File::try_lock`). It stops a second `mcp-proxy` on the same store. It does
//!   not stop a process that ignores the lock.
//! - The chain has no outside anchor. A cut exactly at a record boundary (the removal of the last N records) gives a
//!   valid shorter chain and is NOT detected here. The signed `evidence.wal` is the place to detect it.
//! - If `sync_all()` fails after a complete write, the ledger is poisoned and the call is not forwarded, but the
//!   record may be on disk; after a restart its epoch counts as consumed. The same holds for a crash between the
//!   commit and the forward: at most once, never twice.
//! - The durability claim is only as good as `fsync`/`F_FULLFSYNC` on the device and file system.
//! - `records_after` reads the file again from the start (used once at start-up, for the reconciliation with
//!   `evidence.wal`); it checks every record again and must end at the head held in memory.
//! - The set of committed request id digests (32 bytes + 8-byte epoch each) is the only state that grows.
use crate::hash::{h16, sha256, H16};
use std::collections::HashMap;
use std::fs::{self, File, OpenOptions};
use std::io::{self, BufReader, ErrorKind, Read, Seek, SeekFrom};
use std::os::unix::fs::{DirBuilderExt, FileExt, MetadataExt, OpenOptionsExt};
use std::path::{Path, PathBuf};

pub enum Cas {
    /// The record is in `ledger.wal` and synced to disk. The caller may forward now.
    Committed { epoch: u64, pre: H16, post: H16 },
    /// `pre` is not the head. Nothing was written.
    Mismatch { epoch: u64, current: H16 },
    /// `request_id` is already committed. Nothing was written. Checked BEFORE the CAS.
    Duplicate { first_epoch: u64, epoch: u64, current: H16 },
}

const WAL: &str = "ledger.wal";
const MAGIC: [u8; 4] = *b"FAL1";
const HDR: usize = 12;
const FIXED_BODY: usize = 8 + 16 + 16 + 32 + 32 + 2;
const MAX_TOOL: usize = 1024;
const CHECK: usize = 32;
const MAX_RID: usize = 128;
const TAG_GENESIS: &[u8] = b"forge-airlock-ledger-genesis-v1";
const TAG_STATE: &[u8] = b"forge-airlock-ledger-v1";
const TAG_RECORD: &[u8] = b"forge-airlock-ledger-record-v1";

// O_NOFOLLOW from the OS headers (std has no portable constant). On a target not listed here the value is 0, and
// the lstat/fstat inode comparison in `check_file` is the only symlink guard.
#[cfg(any(target_os = "macos", target_os = "ios"))]
const O_NOFOLLOW: i32 = 0x0100;
#[cfg(all(target_os = "linux", any(target_arch = "aarch64", target_arch = "arm", target_arch = "powerpc", target_arch = "powerpc64")))]
const O_NOFOLLOW: i32 = 0o100000;
#[cfg(all(target_os = "linux", not(any(target_arch = "aarch64", target_arch = "arm", target_arch = "powerpc", target_arch = "powerpc64"))))]
const O_NOFOLLOW: i32 = 0o400000;
#[cfg(not(any(target_os = "macos", target_os = "ios", target_os = "linux")))]
const O_NOFOLLOW: i32 = 0;

/// The ledger genesis state `first16(SHA-256("forge-airlock-ledger-genesis-v1"))`. The one shared definition:
/// `evidence.rs` (verifier commit continuity) and `proxy.rs` (start-up reconciliation) call this function.
pub fn genesis() -> H16 {
    h16(&[TAG_GENESIS])
}

/// One ledger record, as `records_after` returns it.
#[derive(Debug, Clone, PartialEq)]
pub struct Rec {
    pub epoch: u64,
    pub pre: H16,
    pub post: H16,
    pub tool: String,
}

fn framed(parts: &[&[u8]]) -> Vec<u8> {
    let mut v = Vec::with_capacity(parts.iter().map(|p| p.len() + 4).sum());
    for p in parts {
        v.extend_from_slice(&(p.len() as u32).to_be_bytes());
        v.extend_from_slice(p);
    }
    v
}

fn state_hash(pre: &H16, epoch: u64, rid: &[u8; 32], tool: &[u8], args: &[u8; 32]) -> H16 {
    h16(&[&framed(&[TAG_STATE, pre, &epoch.to_be_bytes(), rid, tool, args])])
}

fn record_check(hdr_body: &[u8]) -> [u8; 32] {
    sha256(&[&framed(&[TAG_RECORD, hdr_body])])
}

fn encode(epoch: u64, pre: &H16, post: &H16, rid: &[u8; 32], args: &[u8; 32], tool: &[u8]) -> Vec<u8> {
    let n = (FIXED_BODY + tool.len()) as u32;
    let mut r = Vec::with_capacity(HDR + n as usize + CHECK);
    r.extend_from_slice(&MAGIC);
    r.extend_from_slice(&n.to_be_bytes());
    r.extend_from_slice(&(!n).to_be_bytes());
    r.extend_from_slice(&epoch.to_be_bytes());
    r.extend_from_slice(pre);
    r.extend_from_slice(post);
    r.extend_from_slice(rid);
    r.extend_from_slice(args);
    r.extend_from_slice(&(tool.len() as u16).to_be_bytes());
    r.extend_from_slice(tool);
    let c = record_check(&r);
    r.extend_from_slice(&c);
    r
}

/// Read until `buf` is full or end of file. Returns the count read.
fn read_full<R: Read>(r: &mut R, buf: &mut [u8]) -> io::Result<usize> {
    let mut n = 0;
    while n < buf.len() {
        match r.read(&mut buf[n..]) {
            Ok(0) => break,
            Ok(k) => n += k,
            Err(e) if e.kind() == ErrorKind::Interrupted => {}
            Err(e) => return Err(e),
        }
    }
    Ok(n)
}

struct Replayed {
    epoch: u64,
    head: H16,
    ids: HashMap<[u8; 32], u64>,
    /// Length of the complete, checked records.
    good_len: u64,
    /// Bytes of a torn last record after `good_len` (0 = none).
    torn: u64,
}

/// Replay and check every record. With `keep = Some((after, out))`, every record with `epoch > after` is also
/// pushed to `out`.
fn replay<R: Read>(r: &mut R, mut keep: Option<(u64, &mut Vec<Rec>)>) -> Result<Replayed, String> {
    let mut st = Replayed { epoch: 0, head: genesis(), ids: HashMap::new(), good_len: 0, torn: 0 };
    let mut rec = vec![0u8; HDR + FIXED_BODY + MAX_TOOL + CHECK];
    let io = |e: io::Error| format!("ledger.wal: read error: {e}");
    loop {
        let off = st.good_len;
        let n = read_full(r, &mut rec[..HDR]).map_err(io)?;
        if n == 0 {
            return Ok(st);
        }
        let m = n.min(4);
        if rec[..m] != MAGIC[..m] {
            return Err(format!("ledger.wal: damaged record at offset {off}: bad magic; store refused"));
        }
        if n < HDR {
            st.torn = n as u64;
            return Ok(st);
        }
        let len = u32::from_be_bytes(rec[4..8].try_into().unwrap());
        let inv = u32::from_be_bytes(rec[8..12].try_into().unwrap());
        if len != !inv {
            return Err(format!("ledger.wal: damaged record at offset {off}: length check failed; store refused"));
        }
        let len = len as usize;
        if !(FIXED_BODY + 1..=FIXED_BODY + MAX_TOOL).contains(&len) {
            return Err(format!("ledger.wal: damaged record at offset {off}: body length {len} out of range; store refused"));
        }
        let total = HDR + len + CHECK;
        let k = read_full(r, &mut rec[HDR..total]).map_err(io)?;
        if k < len + CHECK {
            st.torn = (HDR + k) as u64;
            return Ok(st);
        }
        let (hb, chk) = rec[..total].split_at(HDR + len);
        if record_check(hb) != chk {
            return Err(format!("ledger.wal: damaged record at offset {off}: integrity hash mismatch; store refused"));
        }
        let b = &hb[HDR..];
        let epoch = u64::from_be_bytes(b[0..8].try_into().unwrap());
        let pre: H16 = b[8..24].try_into().unwrap();
        let post: H16 = b[24..40].try_into().unwrap();
        let rid: [u8; 32] = b[40..72].try_into().unwrap();
        let args: [u8; 32] = b[72..104].try_into().unwrap();
        let tlen = u16::from_be_bytes([b[104], b[105]]) as usize;
        let tool = &b[106..];
        if tlen != tool.len() {
            return Err(format!("ledger.wal: record at offset {off}: tool length disagrees with body length; store refused"));
        }
        if Some(epoch) != st.epoch.checked_add(1) {
            return Err(format!("ledger.wal: record at offset {off}: epoch {epoch}, expected {}; store refused", st.epoch as u128 + 1));
        }
        if pre != st.head {
            return Err(format!("ledger.wal: record at offset {off} (epoch {epoch}): pre does not match the previous state; store refused"));
        }
        if post != state_hash(&pre, epoch, &rid, tool, &args) {
            return Err(format!("ledger.wal: record at offset {off} (epoch {epoch}): post does not match its fields; store refused"));
        }
        if let Some(first) = st.ids.insert(rid, epoch) {
            return Err(format!("ledger.wal: record at offset {off} (epoch {epoch}): request id already used at epoch {first}; store refused"));
        }
        if let Some((after, out)) = keep.as_mut() {
            if epoch > *after {
                let tool = std::str::from_utf8(tool)
                    .map_err(|_| format!("ledger.wal: record at offset {off} (epoch {epoch}): tool name is not UTF-8"))?;
                out.push(Rec { epoch, pre, post, tool: tool.to_string() });
            }
        }
        st.epoch = epoch;
        st.head = post;
        st.good_len += total as u64;
    }
}

/// Open `path` without following a symlink at the last component, then check that it is the same regular file as the
/// lstat result, with no group or world bits (mode & 0o077 == 0), owned by `euid`.
fn check_file(f: &File, path: &Path, euid: u32) -> Result<(), String> {
    let lm = fs::symlink_metadata(path).map_err(|e| format!("{}: lstat: {e}", path.display()))?;
    let fm = f.metadata().map_err(|e| format!("{}: fstat: {e}", path.display()))?;
    if !lm.file_type().is_file() || !fm.file_type().is_file() {
        return Err(format!("{}: not a regular file (symlinks are refused)", path.display()));
    }
    if lm.dev() != fm.dev() || lm.ino() != fm.ino() {
        return Err(format!("{}: file changed during open; refused", path.display()));
    }
    if fm.mode() & 0o077 != 0 {
        return Err(format!("{}: mode {:o} gives group or other access; need 0600", path.display(), fm.mode() & 0o7777));
    }
    if fm.uid() != euid {
        return Err(format!("{}: owner uid {} is not the euid {euid}; refused", path.display(), fm.uid()));
    }
    Ok(())
}

/// The store folder: a directory, `mode & 0o022 == 0`, owner uid == euid. Returns the euid (probe in the folder).
fn check_dir(dir: &Path) -> Result<u32, String> {
    let m = fs::metadata(dir).map_err(|e| format!("{}: {e}", dir.display()))?;
    if !m.is_dir() {
        return Err(format!("{}: not a directory", dir.display()));
    }
    if m.mode() & 0o022 != 0 {
        return Err(format!(
            "{}: store folder mode {:o} lets group or others write it (need mode & 0o022 == 0, for example 0700); refused",
            dir.display(),
            m.mode() & 0o7777
        ));
    }
    let euid = crate::evidence::euid_probe(dir)?;
    if m.uid() != euid {
        return Err(format!("{}: store folder owner uid {} is not the euid {euid}; refused", dir.display(), m.uid()));
    }
    Ok(euid)
}

fn open_nofollow(path: &Path, write: bool, create_new: bool) -> io::Result<File> {
    let mut o = OpenOptions::new();
    o.read(true).write(write).custom_flags(O_NOFOLLOW);
    if create_new {
        o.create_new(true).mode(0o600);
    }
    o.open(path)
}

/// `fsync` of a directory, so a new directory entry is durable.
fn sync_dir(dir: &Path) -> Result<(), String> {
    File::open(dir).and_then(|d| d.sync_all()).map_err(|e| format!("{}: directory sync: {e}", dir.display()))
}

fn check_rid(id: &str) -> Result<(), String> {
    let ok = (1..=MAX_RID).contains(&id.len()) && id.bytes().all(|c| c.is_ascii_alphanumeric() || matches!(c, b'.' | b'_' | b':' | b'-'));
    if ok { Ok(()) } else { Err("ledger: request id must be 1 to 128 bytes of [A-Za-z0-9._:-]".into()) }
}

pub struct Ledger {
    /// Holds the exclusive `flock` for the life of the value; the lock goes away on drop (close).
    file: File,
    path: PathBuf,
    epoch: u64,
    head: H16,
    ids: HashMap<[u8; 32], u64>,
    len: u64,
    /// Set by the first write or sync error. Every later `commit` returns `Err`.
    poisoned: Option<String>,
}

impl Ledger {
    /// Create or open `<dir>/ledger.wal`, take an exclusive lock for the life of the value, replay and check the chain.
    /// `dir` is created (mode 0700) if it is missing; its parent must exist.
    pub fn open(dir: &Path) -> Result<Ledger, String> {
        let mut new_dir = false;
        match fs::metadata(dir) {
            Ok(m) if m.is_dir() => {}
            Ok(_) => return Err(format!("{}: not a directory", dir.display())),
            Err(e) if e.kind() == ErrorKind::NotFound => {
                fs::DirBuilder::new().mode(0o700).create(dir).map_err(|e| format!("{}: create directory: {e}", dir.display()))?;
                new_dir = true;
            }
            Err(e) => return Err(format!("{}: {e}", dir.display())),
        }
        let euid = check_dir(dir)?;
        let path = dir.join(WAL);
        let (file, created) = match open_nofollow(&path, true, true) {
            Ok(f) => (f, true),
            Err(e) if e.kind() == ErrorKind::AlreadyExists => {
                (open_nofollow(&path, true, false).map_err(|e| format!("{}: open: {e} (a symlink is refused)", path.display()))?, false)
            }
            Err(e) => return Err(format!("{}: create: {e}", path.display())),
        };
        match file.try_lock() {
            Ok(()) => {}
            Err(fs::TryLockError::WouldBlock) => {
                return Err(format!("{}: locked by another process (is a second mcp-proxy using this store?)", path.display()))
            }
            Err(fs::TryLockError::Error(e)) => return Err(format!("{}: lock: {e}", path.display())),
        }
        check_file(&file, &path, euid)?;
        if created {
            file.sync_all().map_err(|e| format!("{}: sync: {e}", path.display()))?;
            sync_dir(dir)?;
            if new_dir {
                if let Some(p) = dir.parent().filter(|p| !p.as_os_str().is_empty()) {
                    sync_dir(p)?;
                }
            }
        }
        let st = replay(&mut BufReader::with_capacity(64 * 1024, &file), None)?;
        if st.torn > 0 {
            // Torn-tail rule (see the top of this file): cut the incomplete last record, make the cut durable, go on.
            file.set_len(st.good_len).map_err(|e| format!("{}: cut torn tail: {e}", path.display()))?;
            file.sync_all().map_err(|e| format!("{}: sync after cut: {e}", path.display()))?;
        }
        Ok(Ledger { file, path, epoch: st.epoch, head: st.head, ids: st.ids, len: st.good_len, poisoned: None })
    }

    /// (epoch, state hash) of the head. Epoch 0 = genesis.
    pub fn head(&self) -> (u64, H16) {
        (self.epoch, self.head)
    }

    /// Every record with `epoch > after`, in order. Reads `ledger.wal` again from the start (only the bytes of the
    /// complete records that this value knows) and checks every record again. Used once at start-up.
    pub fn records_after(&self, after: u64) -> Result<Vec<Rec>, String> {
        let mut f = &self.file;
        f.seek(SeekFrom::Start(0)).map_err(|e| format!("{}: seek: {e}", self.path.display()))?;
        let mut out = Vec::new();
        let st = replay(&mut BufReader::with_capacity(64 * 1024, f.take(self.len)), Some((after, &mut out)))?;
        if st.torn != 0 || st.good_len != self.len || st.epoch != self.epoch || st.head != self.head {
            return Err(format!("{}: re-read does not end at the head in memory; refused", self.path.display()));
        }
        Ok(out)
    }

    /// One mutating call. `Err` = I/O fault: the caller fails closed (no forward).
    pub fn commit(&mut self, request_id: &str, tool: &str, args_canon: &[u8], pre: &H16) -> Result<Cas, String> {
        if let Some(p) = &self.poisoned {
            return Err(format!("ledger poisoned by an earlier I/O fault ({p}); restart the proxy"));
        }
        check_rid(request_id)?;
        if tool.is_empty() || tool.len() > MAX_TOOL {
            return Err(format!("ledger: tool name must be 1 to {MAX_TOOL} bytes"));
        }
        let rid = sha256(&[request_id.as_bytes()]);
        if let Some(&first_epoch) = self.ids.get(&rid) {
            return Ok(Cas::Duplicate { first_epoch, epoch: self.epoch, current: self.head });
        }
        if *pre != self.head {
            return Ok(Cas::Mismatch { epoch: self.epoch, current: self.head });
        }
        let epoch = self.epoch.checked_add(1).ok_or("ledger: epoch overflow")?;
        let args = sha256(&[args_canon]);
        let post = state_hash(pre, epoch, &rid, tool.as_bytes(), &args);
        let rec = encode(epoch, pre, &post, &rid, &args, tool.as_bytes());
        if let Err(e) = self.file.write_all_at(&rec, self.len) {
            let m = format!("{}: write: {e}", self.path.display());
            self.poisoned = Some(m.clone());
            return Err(m);
        }
        // `sync_all` before `Committed`. On macOS and iOS, Rust's std implements it with fcntl(F_FULLFSYNC): the
        // kernel pushes the file data and metadata to the drive and asks the drive to flush its write cache (plain
        // fsync on macOS does not flush the drive cache). On Linux it calls fsync(2): data and metadata go to the
        // device, and the kernel sends a cache flush when the file system uses barriers (the default on ext4/xfs).
        if let Err(e) = self.file.sync_all() {
            let m = format!("{}: sync: {e}", self.path.display());
            self.poisoned = Some(m.clone());
            return Err(m);
        }
        self.len += rec.len() as u64;
        self.epoch = epoch;
        self.head = post;
        self.ids.insert(rid, epoch);
        Ok(Cas::Committed { epoch, pre: *pre, post })
    }
}

/// Read-only replay of `<dir>/ledger.wal` for `mcp-proxy state DIR`: no lock, no write to `ledger.wal`, no cut (the
/// euid probe creates and removes one file in the store folder). It checks the folder, the file and every complete
/// record like `open` does. A torn last record (for example an append in progress by a running proxy) is
/// ignored, so the result is the head that `open` would give. A missing file is an error, not genesis.
pub fn read_head(dir: &Path) -> Result<(u64, H16), String> {
    let path = dir.join(WAL);
    let euid = check_dir(dir)?;
    let f = open_nofollow(&path, false, false).map_err(|e| format!("{}: open: {e} (a symlink is refused)", path.display()))?;
    check_file(&f, &path, euid)?;
    let st = replay(&mut BufReader::with_capacity(64 * 1024, &f), None)?;
    Ok((st.epoch, st.head))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::hash::hex;
    use std::sync::atomic::{AtomicUsize, Ordering};
    use std::sync::{Arc, Barrier, Mutex};
    use std::time::Instant;

    static N: AtomicUsize = AtomicUsize::new(0);

    /// A fresh, empty test directory (not yet created). Base: $LEDGER_TEST_DIR, else the system temp directory.
    fn tdir(name: &str) -> PathBuf {
        let base = std::env::var_os("LEDGER_TEST_DIR").map(PathBuf::from).unwrap_or_else(std::env::temp_dir);
        let d = base.join(format!("ledger-{}-{}-{name}", std::process::id(), N.fetch_add(1, Ordering::SeqCst)));
        let _ = fs::remove_dir_all(&d);
        d
    }
    fn wal(d: &Path) -> PathBuf {
        d.join(WAL)
    }
    fn size(d: &Path) -> u64 {
        fs::metadata(wal(d)).unwrap().len()
    }
    fn put(d: &Path, bytes: &[u8]) {
        fs::create_dir_all(d).unwrap();
        let mut o = OpenOptions::new();
        o.write(true).create(true).truncate(true).mode(0o600);
        let f = o.open(wal(d)).unwrap();
        f.write_all_at(bytes, 0).unwrap();
    }
    fn committed(c: Cas) -> (u64, H16) {
        match c {
            Cas::Committed { epoch, post, .. } => (epoch, post),
            _ => panic!("expected Committed"),
        }
    }
    /// A store with three records of different tool lengths. Returns the dir, the file bytes, and the record bounds.
    fn three(name: &str) -> (PathBuf, Vec<u8>, Vec<(usize, usize)>, Vec<(u64, H16)>) {
        let d = tdir(name);
        let mut l = Ledger::open(&d).unwrap();
        let mut heads = vec![l.head()];
        for (i, t) in ["issue_payout", "update_dosage", "x"].iter().enumerate() {
            let h = l.head().1;
            heads.push(committed(l.commit(&format!("req-{i}"), t, format!("{{\"n\":{i}}}").as_bytes(), &h).unwrap()));
        }
        drop(l);
        let bytes = fs::read(wal(&d)).unwrap();
        let mut bounds = vec![];
        let mut o = 0;
        while o < bytes.len() {
            let n = u32::from_be_bytes(bytes[o + 4..o + 8].try_into().unwrap()) as usize;
            bounds.push((o, o + HDR + n + CHECK));
            o += HDR + n + CHECK;
        }
        assert_eq!(bounds.len(), 3);
        (d, bytes, bounds, heads)
    }

    #[test]
    fn genesis_and_fresh_store() {
        assert_eq!(hex(&genesis()), hex(&h16(&[b"forge-airlock-ledger-genesis-v1"])));
        let d = tdir("fresh");
        let l = Ledger::open(&d).unwrap();
        assert_eq!(l.head(), (0, genesis()));
        assert_eq!(size(&d), 0);
        let m = fs::metadata(wal(&d)).unwrap();
        assert_eq!(m.mode() & 0o777, 0o600);
        drop(l);
        assert_eq!(read_head(&d).unwrap(), (0, genesis()));
        assert!(read_head(&tdir("missing")).is_err());
    }

    #[test]
    fn commit_and_state_hash_layout() {
        let d = tdir("commit");
        let mut l = Ledger::open(&d).unwrap();
        let g = genesis();
        let line = br#"{"jsonrpc":"2.0","id":1,"method":"tools/call"}"#;
        let c = l.commit("pay-1", "issue_payout", line, &g).unwrap();
        let (e, post) = committed(c);
        assert_eq!(e, 1);
        // Recompute the documented state hash by hand, independent of `framed`.
        let mut v = vec![];
        for p in [&b"forge-airlock-ledger-v1"[..], &g, &1u64.to_be_bytes(), &sha256(&[b"pay-1"]), b"issue_payout", &sha256(&[line])] {
            v.extend_from_slice(&(p.len() as u32).to_be_bytes());
            v.extend_from_slice(p);
        }
        assert_eq!(post, h16(&[&v]));
        assert_eq!(l.head(), (1, post));
        assert_eq!(size(&d), (HDR + FIXED_BODY + 12 + CHECK) as u64);
        let b = fs::read(wal(&d)).unwrap();
        assert_eq!(&b[0..4], b"FAL1");
        assert_eq!(&b[36..52], &post);
    }

    #[test]
    fn stale_pre_is_mismatch_and_writes_nothing() {
        let d = tdir("stale");
        let mut l = Ledger::open(&d).unwrap();
        let g = genesis();
        let (_, p1) = committed(l.commit("a", "t", b"x", &g).unwrap());
        let s = size(&d);
        match l.commit("b", "t", b"x", &g).unwrap() {
            Cas::Mismatch { epoch, current } => assert_eq!((epoch, current), (1, p1)),
            _ => panic!("expected Mismatch"),
        }
        assert_eq!(size(&d), s);
        assert_eq!(l.head(), (1, p1));
        // The refused id is not consumed: it commits later with the right pre.
        committed(l.commit("b", "t", b"x", &p1).unwrap());
    }

    #[test]
    fn duplicate_before_cas() {
        let d = tdir("dup");
        let mut l = Ledger::open(&d).unwrap();
        let g = genesis();
        let (_, p1) = committed(l.commit("same", "t", b"x", &g).unwrap());
        let s = size(&d);
        for pre in [g, p1, [7u8; 16]] {
            match l.commit("same", "t", b"other args", &pre).unwrap() {
                Cas::Duplicate { first_epoch, epoch, current } => assert_eq!((first_epoch, epoch, current), (1, 1, p1)),
                _ => panic!("expected Duplicate"),
            }
            assert_eq!(size(&d), s);
        }
        drop(l);
        // Also after a reopen (the id set is rebuilt from the file).
        let mut l = Ledger::open(&d).unwrap();
        assert!(matches!(l.commit("same", "t", b"x", &p1).unwrap(), Cas::Duplicate { first_epoch: 1, .. }));
    }

    #[test]
    fn bad_inputs_are_err_without_write() {
        let d = tdir("inputs");
        let mut l = Ledger::open(&d).unwrap();
        let g = genesis();
        for id in ["", "has space", "ü", &"a".repeat(129)] {
            assert!(l.commit(id, "t", b"x", &g).is_err());
        }
        assert!(l.commit("ok", "", b"x", &g).is_err());
        assert!(l.commit("ok", &"t".repeat(1025), b"x", &g).is_err());
        assert_eq!(size(&d), 0);
        committed(l.commit(&"a".repeat(128), &"t".repeat(1024), b"x", &g).unwrap());
        drop(l);
        assert_eq!(Ledger::open(&d).unwrap().head().0, 1);
    }

    #[test]
    fn reopen_same_head_and_lock() {
        let (d, _, _, heads) = three("reopen");
        let l = Ledger::open(&d).unwrap();
        assert_eq!(l.head(), heads[3]);
        assert_eq!(read_head(&d).unwrap(), heads[3]);
        let e = Ledger::open(&d).err().expect("second open must fail");
        assert!(e.contains("locked"), "{e}");
        // read_head needs no lock.
        assert_eq!(read_head(&d).unwrap(), heads[3]);
        drop(l);
        assert_eq!(Ledger::open(&d).unwrap().head(), heads[3]);
    }

    #[test]
    fn torn_tail_is_cut_on_open_and_ignored_by_read_head() {
        let (d, bytes, bounds, heads) = three("torn");
        let (s3, e3) = bounds[2];
        for cut in s3 + 1..e3 {
            put(&d, &bytes[..cut]);
            assert_eq!(read_head(&d).unwrap(), heads[2], "cut {cut}");
            assert_eq!(size(&d), cut as u64, "read_head must not write");
            let mut l = Ledger::open(&d).unwrap_or_else(|e| panic!("cut {cut}: {e}"));
            assert_eq!(l.head(), heads[2]);
            assert_eq!(size(&d), s3 as u64);
            // The cut record's id was never acknowledged; it may commit again.
            let (ep, _) = committed(l.commit("req-2", "x", b"{\"n\":2}", &heads[2].1).unwrap());
            assert_eq!(ep, 3);
            drop(l);
            assert_eq!(Ledger::open(&d).unwrap().head(), heads[3]);
        }
    }

    #[test]
    fn garbage_tail_is_refused() {
        let (d, bytes, _, _) = three("garbage");
        for tail in [&[0u8][..], &[0u8; 5], &[0u8; 300], b"FAL2", b"XAL1"] {
            let mut b = bytes.clone();
            b.extend_from_slice(tail);
            put(&d, &b);
            assert!(Ledger::open(&d).is_err());
            assert!(read_head(&d).is_err());
            assert_eq!(size(&d), b.len() as u64);
        }
    }

    #[test]
    fn any_flipped_byte_refuses_the_store() {
        let (d, bytes, _, _) = three("flip");
        for i in 0..bytes.len() {
            for mask in [0x01u8, 0x80, 0xff] {
                let mut b = bytes.clone();
                b[i] ^= mask;
                put(&d, &b);
                assert!(Ledger::open(&d).is_err(), "byte {i} mask {mask:#x} accepted by open");
                assert!(read_head(&d).is_err(), "byte {i} mask {mask:#x} accepted by read_head");
                assert_eq!(size(&d), b.len() as u64, "a refused store must not be cut");
            }
        }
    }

    #[test]
    fn reordered_or_removed_middle_record_refuses() {
        let (d, bytes, bn, _) = three("order");
        let r = |k: usize| &bytes[bn[k].0..bn[k].1];
        let cases: Vec<Vec<u8>> = vec![
            [r(0), r(2), r(1)].concat(),
            [r(1), r(0), r(2)].concat(),
            [r(0), r(2)].concat(),
            [r(1), r(2)].concat(),
            [r(0), r(1), r(1)].concat(),
            [r(0), r(1), r(2), r(2)].concat(),
        ];
        for c in cases {
            put(&d, &c);
            assert!(Ledger::open(&d).is_err());
            assert!(read_head(&d).is_err());
        }
        // Stated limit: removal of the LAST record gives a valid shorter chain (no outside anchor).
        put(&d, &[r(0), r(1)].concat());
        assert_eq!(Ledger::open(&d).unwrap().head().0, 2);
    }

    #[test]
    fn symlink_and_mode_are_refused() {
        let d = tdir("link");
        fs::create_dir_all(&d).unwrap();
        let target = d.join("real.wal");
        put(&d, b"");
        fs::rename(wal(&d), &target).unwrap();
        std::os::unix::fs::symlink(&target, wal(&d)).unwrap();
        assert!(Ledger::open(&d).is_err());
        assert!(read_head(&d).is_err());
        let d2 = tdir("mode");
        drop(Ledger::open(&d2).unwrap());
        fs::set_permissions(wal(&d2), std::os::unix::fs::PermissionsExt::from_mode(0o644)).unwrap();
        assert!(Ledger::open(&d2).is_err());
    }

    #[test]
    fn twenty_threads_race_one_pre() {
        let d = tdir("race");
        let l = Arc::new(Mutex::new(Ledger::open(&d).unwrap()));
        let g = genesis();
        let bar = Arc::new(Barrier::new(20));
        let hs: Vec<_> = (0..20)
            .map(|i| {
                let (l, bar) = (l.clone(), bar.clone());
                std::thread::spawn(move || {
                    bar.wait();
                    match l.lock().unwrap().commit(&format!("payout-{i}"), "issue_payout", b"{\"amount\":\"500.00\"}", &g).unwrap() {
                        Cas::Committed { .. } => 0,
                        Cas::Mismatch { .. } => 1,
                        Cas::Duplicate { .. } => 2,
                    }
                })
            })
            .collect();
        let mut c = [0; 3];
        for h in hs {
            c[h.join().unwrap()] += 1;
        }
        assert_eq!(c, [1, 19, 0]);
        let head = l.lock().unwrap().head();
        assert_eq!(head.0, 1);
        drop(l);
        assert_eq!(read_head(&d).unwrap(), head);
    }

    #[test]
    fn poisoned_after_write_error() {
        let d = tdir("poison");
        let mut l = Ledger::open(&d).unwrap();
        // Make the next positional write fail: replace the handle with a read-only one on the same file.
        l.file = File::open(wal(&d)).unwrap();
        let g = genesis();
        assert!(l.commit("a", "t", b"x", &g).is_err());
        let e = l.commit("b", "t", b"x", &g).err().unwrap();
        assert!(e.contains("poisoned"), "{e}");
        assert_eq!(size(&d), 0);
    }

    // ---- round 3 repairs (REVIEW-A R2 and D2; contract round 3, ledger.rs). Each case fails on the code of 65ccdc55.

    fn chmod(p: &Path, mode: u32) {
        fs::set_permissions(p, std::os::unix::fs::PermissionsExt::from_mode(mode)).unwrap();
    }

    /// R2: a store folder that group or others can write is refused by `open` and by `read_head`; 0755 and 0700 pass.
    #[test]
    fn store_folder_writable_by_group_or_other_is_refused() {
        let (d, _, _, heads) = three("dirmode");
        for mode in [0o777, 0o775, 0o757, 0o722, 0o720, 0o702] {
            chmod(&d, mode);
            let e = Ledger::open(&d).err().unwrap_or_else(|| panic!("open accepted folder mode {mode:o}"));
            assert!(e.contains("store folder mode"), "{mode:o}: {e}");
            let e = read_head(&d).err().unwrap_or_else(|| panic!("read_head accepted folder mode {mode:o}"));
            assert!(e.contains("store folder mode"), "{mode:o}: {e}");
        }
        for mode in [0o755, 0o750, 0o700] {
            chmod(&d, mode);
            assert_eq!(Ledger::open(&d).unwrap_or_else(|e| panic!("{mode:o}: {e}")).head(), heads[3]);
            assert_eq!(read_head(&d).unwrap(), heads[3]);
        }
        // A folder that `open` creates gets 0700, and the probe file is gone again.
        let n = tdir("newdir");
        drop(Ledger::open(&n).unwrap());
        assert_eq!(fs::metadata(&n).unwrap().mode() & 0o777, 0o700);
        let names: Vec<_> = fs::read_dir(&n).unwrap().map(|e| e.unwrap().file_name()).collect();
        assert_eq!(names, vec![std::ffi::OsString::from(WAL)]);
        read_head(&n).unwrap();
        assert_eq!(fs::read_dir(&n).unwrap().count(), 1, "read_head must leave no probe file");
    }

    /// D2: `ledger.wal` must be owned by the euid. No second uid exists in a unit test, so the check is driven
    /// with a uid that is not the euid; the real euid passes.
    #[test]
    fn wal_owner_other_than_euid_is_refused() {
        let d = tdir("owner");
        drop(Ledger::open(&d).unwrap());
        let euid = crate::evidence::euid_probe(&d).unwrap();
        let f = open_nofollow(&wal(&d), false, false).unwrap();
        check_file(&f, &wal(&d), euid).unwrap();
        let e = check_file(&f, &wal(&d), euid.wrapping_add(1)).err().expect("foreign owner accepted");
        assert!(e.contains("owner uid"), "{e}");
        assert_eq!(check_dir(&d).unwrap(), euid);
    }

    /// `records_after`: the records after an epoch, with their fields, also after a commit in the same session.
    #[test]
    fn records_after_gives_the_tail() {
        let (d, _, _, heads) = three("after");
        let mut l = Ledger::open(&d).unwrap();
        let all = l.records_after(0).unwrap();
        let tools: Vec<&str> = all.iter().map(|r| r.tool.as_str()).collect();
        assert_eq!(tools, ["issue_payout", "update_dosage", "x"]);
        for (i, r) in all.iter().enumerate() {
            assert_eq!(r.epoch, i as u64 + 1);
            assert_eq!(r.pre, heads[i].1);
            assert_eq!(r.post, heads[i + 1].1);
        }
        assert_eq!(l.records_after(1).unwrap(), all[1..].to_vec());
        assert!(l.records_after(3).unwrap().is_empty());
        assert!(l.records_after(u64::MAX).unwrap().is_empty());
        let (e4, p4) = committed(l.commit("req-9", "issue_payout", b"{}", &heads[3].1).unwrap());
        assert_eq!(e4, 4);
        let tail = l.records_after(3).unwrap();
        assert_eq!(tail, vec![Rec { epoch: 4, pre: heads[3].1, post: p4, tool: "issue_payout".into() }]);
        // A commit after `records_after` still goes to the end of the file (the read moves no write position).
        let (e5, _) = committed(l.commit("req-10", "x", b"{}", &p4).unwrap());
        assert_eq!(e5, 5);
        drop(l);
        assert_eq!(read_head(&d).unwrap().0, 5);
    }

    /// Run with `--ignored --nocapture`: median wall time of one `commit` (write + sync_all) over 200 commits.
    #[test]
    #[ignore]
    fn bench_commit_median_of_200() {
        let d = tdir("bench");
        let mut l = Ledger::open(&d).unwrap();
        let mut t = Vec::with_capacity(200);
        for i in 0..200 {
            let h = l.head().1;
            let s = Instant::now();
            committed(l.commit(&format!("bench-{i}"), "issue_payout", b"{\"jsonrpc\":\"2.0\",\"id\":7,\"method\":\"tools/call\"}", &h).unwrap());
            t.push(s.elapsed().as_micros());
        }
        t.sort();
        println!(
            "commit_us n=200 min={} p10={} median={} p90={} p99={} max={}",
            t[0], t[20], (t[99] + t[100]) / 2, t[180], t[198], t[199]
        );
        let s = Instant::now();
        let l2 = { drop(l); Ledger::open(&d).unwrap() };
        println!("reopen_200_records_us={} epoch={}", s.elapsed().as_micros(), l2.head().0);
    }
}
