//! Evidence: `evidence.wal`, the key check, `ssh-keygen -Y sign`, and `verify-evidence`.
//! Owner: worker EVIDENCE. NATIVE CHECK and FINITE TEST. Nothing here is proved.
//!
//! # File format of `evidence.wal` (version 1)
//!
//! All integers are big-endian. The file is:
//!
//!     MAGIC  frame*
//!
//! - `MAGIC` = the 30 ASCII bytes `forge-airlock-evidence-wal-v1\n`.
//! - `frame` = `type u8 | len u32 | payload (len bytes) | check (8 bytes)`.
//!   `check` = the first 8 bytes of `SHA-256("forge-airlock-evidence-frame-v1" | type | len | payload)`.
//!   The check has no key. It finds torn or damaged frames. It does NOT stop a forger; the chain and the
//!   signatures do that.
//! - Type `0x01`, RECORD frame, `len == 153`: `index u64 | record (113 bytes) | chain (32 bytes)`.
//! - Type `0x02`, SIGNATURE frame, `9 <= len <= 8 + 4096`: `index u64 | armor`. `armor` is the exact stdout of
//!   `ssh-keygen -Y sign` (`-----BEGIN SSH SIGNATURE-----\n` ... `-----END SSH SIGNATURE-----\n`).
//!
//! Record (113 bytes, the directive layout):
//! `epoch u64 | timestamp u64 | agent_id 32 | tool 32 | pre_hash 16 | post_hash 16 | verdict u8`.
//! - `timestamp`: Unix time in MILLISECONDS. With the `test_clock` seam: `test_clock + (index - 1)`.
//! - `agent_id`: UTF-8, 1 to 32 bytes, no NUL byte, zero-padded. A longer or empty name is refused at `open`.
//! - `tool`: UTF-8, 1 to 32 bytes, no NUL byte, zero-padded. Any other tool name (empty, longer than 32 bytes,
//!   or with a NUL byte) is replaced by the first 32 characters of the lowercase hex SHA-256 of the name.
//!   Limit: a real tool name of 32 hex characters can look the same as such a replacement.
//! - `verdict`: 1 COMMITTED, 2 BLOCKED_CAS, 3 BLOCKED_DUPLICATE, 4 BLOCKED_POLICY, 5 BLOCKED_SUBCAP,
//!   6 READ_ALLOWED, 7 READ_DROPPED, 8 BLOCKED_MALFORMED. For 2, 3, 4, 5 and 8, `post_hash == pre_hash`.
//!
//! Chain. Records are numbered from 1. `chain_0 = SHA-256("forge-airlock-evidence-genesis-v1")`.
//! `chain_i = SHA-256("forge-airlock-evidence-v1" | chain_{i-1} | record_i)`. The parts have fixed lengths
//! (25, 32 and 113 bytes), so the concatenation is unambiguous. The RECORD frame of record `i` stores
//! `chain_i`; the verifier recomputes it.
//!
//! Signature. The signed message is the 64 lowercase hex characters of `chain_i`, with no newline. The
//! namespace is `forge-airlock-evidence`. The signer is `/usr/bin/ssh-keygen -Y sign -f KEY -n NAMESPACE`,
//! message on stdin, armor on stdout (checked on this machine with OpenSSH_10.3p1). An absolute path, an empty
//! environment, the working folder `/`, and no shell.
//!
//! Order rules (the one verifier checks them):
//! - RECORD frames have the indexes 1, 2, 3, ... in file order.
//! - SIGNATURE frames have the indexes 1, 2, 3, ... in file order, and the SIGNATURE frame of record `i` comes
//!   after the RECORD frame of record `i`. Exactly one SIGNATURE frame for each record.
//! - `sync` mode writes `R1 S1 R2 S2 ...`. `async` mode writes, for example, `R1 R2 S1 R3 S2 S3`. Both obey
//!   the rules above, so the one verifier accepts both.
//!
//! # Modes
//!
//! - `sync`: `append` computes the record and the chain, signs, writes the RECORD and the SIGNATURE frame in one
//!   write, then `sync_data` (on macOS, std uses `F_FULLFSYNC`). If signing fails, nothing is written.
//! - `async`: `append` writes the RECORD frame and syncs it, then gives `(index, chain)` to one signer thread.
//!   The thread signs in order, appends each SIGNATURE frame and syncs it. `finish` drains the thread. A signer
//!   error makes every later `append` and `finish` return `Err` (fail closed).
//! - After a write or sync error, the object is broken: every later call returns `Err`.
//!
//! # Opening an existing file
//!
//! - The file is opened with `O_NOFOLLOW`, then checked by `fstat`: regular, `mode & 0o077 == 0`, uid == euid.
//!   A new file gets mode 0600. An exclusive `flock` (`File::try_lock`) refuses a second writer. The lock is
//!   advisory: a process that does not ask for it is not stopped.
//! - The whole file is parsed. Every frame check, every order rule and every chain link is checked again from
//!   `chain_0`. Any failure refuses the open. Signatures are NOT verified at open (that needs the allowed
//!   signers file; use `verify-evidence`).
//! - Torn tail: CUT. When the last frame is incomplete (the file ends inside its header or inside its declared
//!   length), the file is truncated to the end of the last complete frame. Reason: `append` returns only after a
//!   sync, so an incomplete frame was never acknowledged. A COMPLETE frame with a bad check is NOT cut: the open
//!   is refused, because this can be damage and not a tear.
//! - Records without a signature (an `async` crash, or a torn SIGNATURE frame): SIGN THEM FIRST, in order, then
//!   continue. Reason: each such record was durable before the crash; refusing would block the store for ever.
//!   Limit: such a record can belong to an `append` that never returned to its caller.
//!
//! # Key check (pre-flight rule 3)
//!
//! - `open(key, O_RDONLY | O_NOFOLLOW | O_NONBLOCK)`, then `fstat` on the OPEN handle: a regular file,
//!   `mode & 0o077 == 0`, `uid == euid`. `O_NONBLOCK` stops a FIFO from hanging the open. `O_NOFOLLOW` covers
//!   only the LAST path component; a symlink in a parent folder is followed.
//! - euid without `unsafe` and without a crate: `open` creates a new probe file with `O_CREAT | O_EXCL` in the
//!   store folder, reads its owner with `fstat`, and removes it. The kernel gives a new file the owner euid (on
//!   Linux, the fsuid, which equals euid unless `setfsuid` was used). Limits: a file system that ignores or maps
//!   owners (some network, FUSE, FAT or "ignore ownership" volumes) can report another uid; the key check then
//!   normally refuses (fail closed), but if the key is on a volume with the same mapping, the uid test proves
//!   nothing. The store folder must be writable.
//! - Honest limit: a 0600 key does not stop another process of the SAME OS user. It can read the key and sign.
//! - Check-to-use window: `ssh-keygen` opens the key again BY PATH. (Passing the checked handle as a file
//!   descriptor needs `pre_exec`, which is `unsafe`; `-f /dev/stdin` fails because `ssh-keygen` then also reads a
//!   public key from the same path.) Reduction: before and after each signature, `open` compares `lstat(path)`
//!   (regular, same device and inode) with the held handle, and checks `fstat` of the handle again (regular,
//!   mode, uid). What remains: a path swapped to another file and back between the two checks, or a change of
//!   the content of the same inode (that needs write access to the key, so the same user), is not detected.
//!
//! # Verifier
//!
//! `verify-evidence <evidence.wal> --allowed-signers FILE [--identity NAME]`. The default identity is
//! `forge-airlock`. Build the allowed signers file from the public key `KEY.pub` (fields: type, base64,
//! comment) as one line:
//!
//!     forge-airlock namespaces="forge-airlock-evidence" ssh-ed25519 AAAA...
//!
//! for example `printf 'forge-airlock namespaces="forge-airlock-evidence" %s\n' "$(cut -d' ' -f1,2 KEY.pub)"`.
//! It checks offline: the magic, every frame check and length, the order rules, every chain link from
//! `chain_0`, the zero padding of the names, known verdicts only, epochs never decreasing, `post == pre` for
//! every blocked verdict, the armor shape, and exactly one signature per record that
//! `/usr/bin/ssh-keygen -Y verify -f FILE -I NAME -n forge-airlock-evidence -s SIG` accepts with the chain hex
//! on stdin. Signature files go into a new private 0700 folder under the temporary folder, removed at the end.
//! Output: one line per record, then `final_chain=<hex>`, then `VERIFIED records=<n> signatures=<n> chain=OK`
//! (exit 0), or `FAILED at=<index> ...` with the first failing record index (exit 1). Usage error: exit 2.
//! A file with no record (empty, or the magic only) FAILS (exit 1): nothing to verify is not a pass.
//! A torn tail FAILS in the verifier (only `open` cuts it).
//! Honest limit: removal of WHOLE trailing records (with their signatures) is NOT detected. Every remaining
//! record still verifies. Only an outside anchor (the last `final_chain` value, kept elsewhere) finds it.
//! Compare the printed `final_chain` with the anchor.

use crate::hash::{self, H16};
use std::fs::{DirBuilder, File, OpenOptions};
use std::io::{BufReader, Read, Write};
use std::os::unix::fs::{DirBuilderExt, MetadataExt, OpenOptionsExt};
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use std::sync::{mpsc, Arc, Mutex};
use std::thread::JoinHandle;
use std::time::{SystemTime, UNIX_EPOCH};

#[cfg(target_os = "macos")]
const O_NOFOLLOW: i32 = 0x0100;
#[cfg(target_os = "macos")]
const O_NONBLOCK: i32 = 0x0004;
#[cfg(all(target_os = "linux", any(target_arch = "x86_64", target_arch = "x86")))]
const O_NOFOLLOW: i32 = 0o400000;
#[cfg(all(target_os = "linux", target_arch = "aarch64"))]
const O_NOFOLLOW: i32 = 0o100000;
#[cfg(target_os = "linux")]
const O_NONBLOCK: i32 = 0o4000;
#[cfg(not(any(
    target_os = "macos",
    all(target_os = "linux", any(target_arch = "x86_64", target_arch = "x86", target_arch = "aarch64"))
)))]
compile_error!("evidence.rs: O_NOFOLLOW is defined only for macOS and Linux x86/x86_64/aarch64");

const SSH_KEYGEN: &str = "/usr/bin/ssh-keygen";
pub const NAMESPACE: &str = "forge-airlock-evidence";
pub const DEFAULT_IDENTITY: &str = "forge-airlock";
const MAGIC: &[u8] = b"forge-airlock-evidence-wal-v1\n";
const CHAIN_TAG: &[u8] = b"forge-airlock-evidence-v1";
const GENESIS_TAG: &[u8] = b"forge-airlock-evidence-genesis-v1";
const FRAME_TAG: &[u8] = b"forge-airlock-evidence-frame-v1";
const T_RECORD: u8 = 0x01;
const T_SIG: u8 = 0x02;
const RECORD_LEN: usize = 113;
const REC_PAYLOAD: usize = 8 + RECORD_LEN + 32;
const MAX_ARMOR: usize = 4096;
const CHECK_LEN: usize = 8;
const ARMOR_BEGIN: &str = "-----BEGIN SSH SIGNATURE-----\n";
const ARMOR_END: &str = "-----END SSH SIGNATURE-----\n";

#[derive(Debug, Clone, Copy, PartialEq)]
#[repr(u8)]
pub enum Verdict {
    Committed = 1,
    BlockedCas = 2,
    BlockedDuplicate = 3,
    BlockedPolicy = 4,
    BlockedSubcap = 5,
    ReadAllowed = 6,
    ReadDropped = 7,
    BlockedMalformed = 8,
}

fn verdict_name(v: u8) -> Option<&'static str> {
    Some(match v {
        1 => "COMMITTED",
        2 => "BLOCKED_CAS",
        3 => "BLOCKED_DUPLICATE",
        4 => "BLOCKED_POLICY",
        5 => "BLOCKED_SUBCAP",
        6 => "READ_ALLOWED",
        7 => "READ_DROPPED",
        8 => "BLOCKED_MALFORMED",
        _ => return None,
    })
}

fn is_blocked(v: u8) -> bool {
    matches!(v, 2 | 3 | 4 | 5 | 8)
}

// ---------------------------------------------------------------- chain and frames

fn genesis() -> [u8; 32] {
    hash::sha256(&[GENESIS_TAG])
}

fn chain_next(prev: &[u8; 32], rec: &[u8]) -> [u8; 32] {
    hash::sha256(&[CHAIN_TAG, prev, rec])
}

fn frame_check(t: u8, payload: &[u8]) -> [u8; CHECK_LEN] {
    let len = (payload.len() as u32).to_be_bytes();
    let d = hash::sha256(&[FRAME_TAG, &[t], &len, payload]);
    let mut o = [0u8; CHECK_LEN];
    o.copy_from_slice(&d[..CHECK_LEN]);
    o
}

fn frame(t: u8, payload: &[u8]) -> Vec<u8> {
    let mut v = Vec::with_capacity(5 + payload.len() + CHECK_LEN);
    v.push(t);
    v.extend_from_slice(&(payload.len() as u32).to_be_bytes());
    v.extend_from_slice(payload);
    v.extend_from_slice(&frame_check(t, payload));
    v
}

fn record_frame(idx: u64, rec: &[u8; RECORD_LEN], chain: &[u8; 32]) -> Vec<u8> {
    let mut p = Vec::with_capacity(REC_PAYLOAD);
    p.extend_from_slice(&idx.to_be_bytes());
    p.extend_from_slice(rec);
    p.extend_from_slice(chain);
    frame(T_RECORD, &p)
}

fn sig_frame(idx: u64, armor: &[u8]) -> Vec<u8> {
    let mut p = Vec::with_capacity(8 + armor.len());
    p.extend_from_slice(&idx.to_be_bytes());
    p.extend_from_slice(armor);
    frame(T_SIG, &p)
}

enum Frame {
    Rec { idx: u64, rec: [u8; RECORD_LEN], chain: [u8; 32] },
    Sig { idx: u64, armor: Vec<u8> },
}

struct Parsed {
    header: bool,
    frames: Vec<Frame>,
    /// Byte length of the magic plus every complete, checked frame.
    valid_len: u64,
    /// Some(reason) when the file ends inside a frame (or inside the magic).
    torn: Option<String>,
}

/// Read until `buf` is full or end of file. Returns the number of bytes read.
fn read_full<R: Read>(r: &mut R, buf: &mut [u8]) -> Result<usize, String> {
    let mut n = 0;
    while n < buf.len() {
        match r.read(&mut buf[n..]) {
            Ok(0) => break,
            Ok(k) => n += k,
            Err(e) if e.kind() == std::io::ErrorKind::Interrupted => {}
            Err(e) => return Err(format!("read error: {e}")),
        }
    }
    Ok(n)
}

/// Parse frames. `Err` = damage that is not a torn tail (bad magic, bad type or length, bad check).
fn parse<R: Read>(r: R) -> Result<Parsed, String> {
    let mut r = BufReader::new(r);
    let mut out = Parsed { header: false, frames: Vec::new(), valid_len: 0, torn: None };
    let mut m = vec![0u8; MAGIC.len()];
    let n = read_full(&mut r, &mut m)?;
    if n == 0 {
        return Ok(out);
    }
    if n < MAGIC.len() {
        if m[..n] == MAGIC[..n] {
            out.torn = Some(format!("file ends inside the magic ({n} bytes)"));
            return Ok(out);
        }
        return Err("bad magic".into());
    }
    if m != MAGIC {
        return Err("bad magic".into());
    }
    out.header = true;
    out.valid_len = MAGIC.len() as u64;
    loop {
        let off = out.valid_len;
        let mut h = [0u8; 5];
        let n = read_full(&mut r, &mut h)?;
        if n == 0 {
            return Ok(out);
        }
        if n < 5 {
            out.torn = Some(format!("file ends inside a frame header at offset {off}"));
            return Ok(out);
        }
        let t = h[0];
        let len = u32::from_be_bytes([h[1], h[2], h[3], h[4]]) as usize;
        let ok = match t {
            T_RECORD => len == REC_PAYLOAD,
            T_SIG => (9..=8 + MAX_ARMOR).contains(&len),
            _ => false,
        };
        if !ok {
            return Err(format!("bad frame type {t} or length {len} at offset {off}"));
        }
        let mut body = vec![0u8; len + CHECK_LEN];
        let n = read_full(&mut r, &mut body)?;
        if n < body.len() {
            out.torn = Some(format!("file ends inside a frame at offset {off}"));
            return Ok(out);
        }
        let (payload, chk) = body.split_at(len);
        if frame_check(t, payload)[..] != chk[..] {
            return Err(format!("frame check mismatch at offset {off}"));
        }
        let mut ib = [0u8; 8];
        ib.copy_from_slice(&payload[..8]);
        let idx = u64::from_be_bytes(ib);
        if t == T_RECORD {
            let mut rec = [0u8; RECORD_LEN];
            rec.copy_from_slice(&payload[8..8 + RECORD_LEN]);
            let mut chain = [0u8; 32];
            chain.copy_from_slice(&payload[8 + RECORD_LEN..]);
            out.frames.push(Frame::Rec { idx, rec, chain });
        } else {
            out.frames.push(Frame::Sig { idx, armor: payload[8..].to_vec() });
        }
        out.valid_len += (5 + len + CHECK_LEN) as u64;
    }
}

struct Entry {
    rec: [u8; RECORD_LEN],
    chain: [u8; 32],
    sig: Option<Vec<u8>>,
}

/// Apply the order rules. Returns the entries in order, plus the first violation as (record index, reason).
fn order(frames: Vec<Frame>) -> (Vec<Entry>, Option<(u64, String)>) {
    let mut es: Vec<Entry> = Vec::new();
    let mut signed: u64 = 0;
    for f in frames {
        match f {
            Frame::Rec { idx, rec, chain } => {
                let want = es.len() as u64 + 1;
                if idx != want {
                    return (es, Some((want, format!("record frame has index {idx}, expected {want}"))));
                }
                es.push(Entry { rec, chain, sig: None });
            }
            Frame::Sig { idx, armor } => {
                let want = signed + 1;
                if idx != want {
                    return (es, Some((want, format!("signature frame has index {idx}, expected {want}"))));
                }
                if idx > es.len() as u64 {
                    return (es, Some((idx, "signature frame before its record frame".into())));
                }
                es[(idx - 1) as usize].sig = Some(armor);
                signed = idx;
            }
        }
    }
    (es, None)
}

fn armor_ok(a: &[u8]) -> bool {
    let s = match std::str::from_utf8(a) {
        Ok(s) => s,
        Err(_) => return false,
    };
    if a.len() > MAX_ARMOR || !s.starts_with(ARMOR_BEGIN) || !s.ends_with(ARMOR_END) {
        return false;
    }
    if s.len() < ARMOR_BEGIN.len() + ARMOR_END.len() {
        return false;
    }
    let inner = &s[ARMOR_BEGIN.len()..s.len() - ARMOR_END.len()];
    if inner.is_empty() || !inner.ends_with('\n') {
        return false;
    }
    inner[..inner.len() - 1].split('\n').all(|l| {
        !l.is_empty() && l.len() <= 76 && l.bytes().all(|c| c.is_ascii_alphanumeric() || matches!(c, b'+' | b'/' | b'='))
    })
}

// ---------------------------------------------------------------- names

fn name_field(s: &str) -> Option<[u8; 32]> {
    let b = s.as_bytes();
    if b.is_empty() || b.len() > 32 || b.contains(&0) {
        return None;
    }
    let mut o = [0u8; 32];
    o[..b.len()].copy_from_slice(b);
    Some(o)
}

fn tool_field(tool: &str) -> [u8; 32] {
    match name_field(tool) {
        Some(f) => f,
        None => {
            let h = hash::hex(&hash::sha256(&[tool.as_bytes()]));
            let mut o = [0u8; 32];
            o.copy_from_slice(&h.as_bytes()[..32]);
            o
        }
    }
}

/// Some(text) when the field is 1..32 bytes of UTF-8 with canonical zero padding, else None.
fn field_text(f: &[u8]) -> Option<String> {
    let end = f.iter().position(|&c| c == 0).unwrap_or(f.len());
    if end == 0 || f[end..].iter().any(|&c| c != 0) {
        return None;
    }
    std::str::from_utf8(&f[..end]).ok().map(|s| s.escape_debug().to_string())
}

// ---------------------------------------------------------------- key

fn euid_probe(dir: &Path) -> Result<u32, String> {
    let nanos = SystemTime::now().duration_since(UNIX_EPOCH).map(|d| d.as_nanos()).unwrap_or(0);
    for n in 0..16u32 {
        let p = dir.join(format!(".forge-airlock-euid-probe-{}-{}-{}", std::process::id(), nanos, n));
        match OpenOptions::new().write(true).create_new(true).mode(0o600).custom_flags(O_NOFOLLOW).open(&p) {
            Ok(f) => {
                let md = f.metadata().map_err(|e| format!("euid probe fstat: {e}"));
                drop(f);
                let rm = std::fs::remove_file(&p);
                let md = md?;
                rm.map_err(|e| format!("euid probe remove: {e}"))?;
                return Ok(md.uid());
            }
            Err(e) if e.kind() == std::io::ErrorKind::AlreadyExists => continue,
            Err(e) => return Err(format!("euid probe in {}: {e}", dir.display())),
        }
    }
    Err("euid probe: no free probe name".into())
}

struct Key {
    path: PathBuf,
    handle: File,
    dev: u64,
    ino: u64,
    euid: u32,
}

fn check_md(md: &std::fs::Metadata, euid: u32, what: &str) -> Result<(), String> {
    if !md.file_type().is_file() {
        return Err(format!("{what}: not a regular file"));
    }
    if md.mode() & 0o077 != 0 {
        return Err(format!("{what}: mode {:o} gives access to group or others (need mode & 0o077 == 0)", md.mode() & 0o7777));
    }
    if md.uid() != euid {
        return Err(format!("{what}: owner uid {} is not the euid {euid}", md.uid()));
    }
    Ok(())
}

fn open_key(path: &str, euid: u32) -> Result<Key, String> {
    let mut p = PathBuf::from(path);
    if p.is_relative() {
        p = std::env::current_dir().map_err(|e| format!("key: current dir: {e}"))?.join(p);
    }
    let handle = OpenOptions::new()
        .read(true)
        .custom_flags(O_NOFOLLOW | O_NONBLOCK)
        .open(&p)
        .map_err(|e| format!("key {}: open with O_NOFOLLOW refused: {e}", p.display()))?;
    let md = handle.metadata().map_err(|e| format!("key: fstat: {e}"))?;
    check_md(&md, euid, "key")?;
    Ok(Key { path: p, dev: md.dev(), ino: md.ino(), handle, euid })
}

impl Key {
    /// Compare the path with the held handle (device, inode) and check the handle again.
    fn recheck(&self) -> Result<(), String> {
        let md = self.handle.metadata().map_err(|e| format!("key: fstat: {e}"))?;
        check_md(&md, self.euid, "key")?;
        let lm = std::fs::symlink_metadata(&self.path).map_err(|e| format!("key: lstat: {e}"))?;
        if !lm.file_type().is_file() || lm.dev() != self.dev || lm.ino() != self.ino {
            return Err("key: the path no longer names the checked file (device/inode changed)".into());
        }
        Ok(())
    }

    fn sign(&self, chain: &[u8; 32]) -> Result<Vec<u8>, String> {
        self.recheck()?;
        let mut child = Command::new(SSH_KEYGEN)
            .args(["-Y", "sign", "-f"])
            .arg(&self.path)
            .args(["-n", NAMESPACE])
            .env_clear()
            .current_dir("/")
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .spawn()
            .map_err(|e| format!("spawn {SSH_KEYGEN}: {e}"))?;
        let msg = hash::hex(chain);
        {
            let mut si = child.stdin.take().ok_or("ssh-keygen: no stdin")?;
            si.write_all(msg.as_bytes()).map_err(|e| format!("ssh-keygen stdin: {e}"))?;
        }
        let out = child.wait_with_output().map_err(|e| format!("ssh-keygen wait: {e}"))?;
        if !out.status.success() {
            let err = String::from_utf8_lossy(&out.stderr[..out.stderr.len().min(512)]).into_owned();
            return Err(format!("ssh-keygen -Y sign failed ({}): {}", out.status, err.trim()));
        }
        if !armor_ok(&out.stdout) {
            return Err("ssh-keygen -Y sign: output is not an SSH SIGNATURE armor".into());
        }
        self.recheck()?;
        Ok(out.stdout)
    }
}

// ---------------------------------------------------------------- writer

struct Shared {
    file: Mutex<File>,
    err: Mutex<Option<String>>,
}

impl Shared {
    fn write_sync(&self, bytes: &[u8]) -> Result<(), String> {
        let mut f = self.file.lock().map_err(|_| "evidence: file mutex poisoned".to_string())?;
        f.write_all(bytes).map_err(|e| format!("evidence.wal write: {e}"))?;
        f.sync_data().map_err(|e| format!("evidence.wal sync: {e}"))
    }
    fn set_err(&self, e: String) {
        if let Ok(mut g) = self.err.lock() {
            if g.is_none() {
                *g = Some(e);
            }
        }
    }
    fn get_err(&self) -> Option<String> {
        match self.err.lock() {
            Ok(g) => g.clone(),
            Err(_) => Some("evidence: error mutex poisoned".into()),
        }
    }
}

pub struct Evidence {
    shared: Arc<Shared>,
    key: Arc<Key>,
    head: [u8; 32],
    next: u64,
    agent: [u8; 32],
    test_clock: Option<u64>,
    tx: Option<mpsc::Sender<(u64, [u8; 32])>>,
    worker: Option<JoinHandle<()>>,
    broken: Option<String>,
}

pub struct Options<'a> {
    pub dir: &'a Path,
    pub key_path: &'a str,
    pub agent_id: &'a str,
    /// true: `append` returns after the signature is on disk. false: a signer thread signs in order.
    pub sync_sign: bool,
    /// Test seam: timestamp = value + (record index - 1); the first record of a file gets the value itself.
    /// None = wall clock, Unix time in MILLISECONDS.
    pub test_clock: Option<u64>,
}

impl Evidence {
    /// Check the key file (O_NOFOLLOW, fstat: regular, uid == euid, mode & 0o077 == 0), open or continue `evidence.wal`.
    pub fn open(o: &Options) -> Result<Evidence, String> {
        let agent = name_field(o.agent_id).ok_or("agent id must be 1 to 32 bytes of UTF-8 with no NUL byte")?;
        let euid = euid_probe(o.dir)?;
        let key = open_key(o.key_path, euid)?;
        let wal = o.dir.join("evidence.wal");
        let mut file = OpenOptions::new()
            .read(true)
            .append(true)
            .create(true)
            .mode(0o600)
            .custom_flags(O_NOFOLLOW)
            .open(&wal)
            .map_err(|e| format!("{}: open: {e}", wal.display()))?;
        match file.try_lock() {
            Ok(()) => {}
            Err(std::fs::TryLockError::WouldBlock) => return Err("evidence.wal is locked by another process".into()),
            Err(std::fs::TryLockError::Error(e)) => return Err(format!("evidence.wal lock: {e}")),
        }
        let md = file.metadata().map_err(|e| format!("evidence.wal fstat: {e}"))?;
        check_md(&md, euid, "evidence.wal")?;
        let parsed = parse(&mut file).map_err(|e| format!("evidence.wal refused: {e}"))?;
        if let Some(t) = &parsed.torn {
            eprintln!("evidence.wal: torn tail cut ({t}); kept {} bytes", parsed.valid_len);
            file.set_len(parsed.valid_len).map_err(|e| format!("evidence.wal cut: {e}"))?;
            file.sync_all().map_err(|e| format!("evidence.wal sync: {e}"))?;
        }
        let header = parsed.header;
        let (entries, bad) = order(parsed.frames);
        if let Some((i, why)) = bad {
            return Err(format!("evidence.wal refused at record {i}: {why}"));
        }
        let mut head = genesis();
        for (n, e) in entries.iter().enumerate() {
            if chain_next(&head, &e.rec) != e.chain {
                return Err(format!("evidence.wal refused at record {}: chain link mismatch", n + 1));
            }
            head = e.chain;
        }
        let shared = Arc::new(Shared { file: Mutex::new(file), err: Mutex::new(None) });
        if !header {
            shared.write_sync(MAGIC)?;
            File::open(o.dir)
                .and_then(|d| d.sync_all())
                .map_err(|e| format!("store folder sync: {e}"))?;
        }
        // Sign records that have no signature (in order), before any new record.
        for (n, e) in entries.iter().enumerate() {
            if e.sig.is_none() {
                let idx = n as u64 + 1;
                let armor = key.sign(&e.chain)?;
                shared.write_sync(&sig_frame(idx, &armor))?;
            }
        }
        let key = Arc::new(key);
        let mut ev = Evidence {
            shared,
            key,
            head,
            next: entries.len() as u64 + 1,
            agent,
            test_clock: o.test_clock,
            tx: None,
            worker: None,
            broken: None,
        };
        if !o.sync_sign {
            let (tx, rx) = mpsc::channel::<(u64, [u8; 32])>();
            let sh = Arc::clone(&ev.shared);
            let k = Arc::clone(&ev.key);
            let h = std::thread::Builder::new()
                .name("evidence-signer".into())
                .spawn(move || {
                    for (idx, chain) in rx {
                        if sh.get_err().is_some() {
                            continue;
                        }
                        let r = k.sign(&chain).and_then(|a| sh.write_sync(&sig_frame(idx, &a)));
                        if let Err(e) = r {
                            sh.set_err(format!("signer, record {idx}: {e}"));
                        }
                    }
                })
                .map_err(|e| format!("spawn signer thread: {e}"))?;
            ev.tx = Some(tx);
            ev.worker = Some(h);
        }
        Ok(ev)
    }

    fn timestamp(&self, idx: u64) -> Result<u64, String> {
        match self.test_clock {
            Some(v) => v.checked_add(idx - 1).ok_or_else(|| "test clock overflow".to_string()),
            None => SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .map(|d| d.as_millis() as u64)
                .map_err(|_| "clock before 1970".to_string()),
        }
    }

    /// One receipt. `Err` = the receipt is not durable: the caller fails closed for a mutating call.
    pub fn append(&mut self, epoch: u64, tool: &str, pre: &H16, post: &H16, verdict: Verdict) -> Result<(), String> {
        if let Some(e) = &self.broken {
            return Err(format!("evidence broken: {e}"));
        }
        if let Some(e) = self.shared.get_err() {
            return Err(format!("evidence signer failed: {e}"));
        }
        if is_blocked(verdict as u8) && pre != post {
            return Err("evidence: a blocked verdict needs post_hash == pre_hash".into());
        }
        let idx = self.next;
        let mut rec = [0u8; RECORD_LEN];
        rec[0..8].copy_from_slice(&epoch.to_be_bytes());
        rec[8..16].copy_from_slice(&self.timestamp(idx)?.to_be_bytes());
        rec[16..48].copy_from_slice(&self.agent);
        rec[48..80].copy_from_slice(&tool_field(tool));
        rec[80..96].copy_from_slice(pre);
        rec[96..112].copy_from_slice(post);
        rec[112] = verdict as u8;
        let chain = chain_next(&self.head, &rec);
        match &self.tx {
            None => {
                // Sign first: a failed signature writes nothing.
                let armor = self.key.sign(&chain)?;
                let mut bytes = record_frame(idx, &rec, &chain);
                bytes.extend_from_slice(&sig_frame(idx, &armor));
                if let Err(e) = self.shared.write_sync(&bytes) {
                    self.broken = Some(e.clone());
                    return Err(e);
                }
            }
            Some(tx) => {
                if let Err(e) = self.shared.write_sync(&record_frame(idx, &rec, &chain)) {
                    self.broken = Some(e.clone());
                    return Err(e);
                }
                if tx.send((idx, chain)).is_err() {
                    let e = "signer thread is gone".to_string();
                    self.broken = Some(e.clone());
                    // The record is durable but will not be signed in this run; the next open signs it.
                    return Err(e);
                }
            }
        }
        self.head = chain;
        self.next = idx + 1;
        Ok(())
    }

    /// Drain the signer, sync, close. Called at end of input.
    pub fn finish(mut self) -> Result<(), String> {
        drop(self.tx.take());
        if let Some(h) = self.worker.take() {
            h.join().map_err(|_| "signer thread panicked".to_string())?;
        }
        if let Some(e) = self.shared.get_err() {
            return Err(format!("evidence signer failed: {e}"));
        }
        if let Some(e) = &self.broken {
            return Err(format!("evidence broken: {e}"));
        }
        let f = self.shared.file.lock().map_err(|_| "evidence: file mutex poisoned".to_string())?;
        f.sync_all().map_err(|e| format!("evidence.wal sync: {e}"))
    }
}

// ---------------------------------------------------------------- verifier

struct TmpDir(PathBuf);
impl Drop for TmpDir {
    fn drop(&mut self) {
        let _ = std::fs::remove_dir_all(&self.0);
    }
}

fn private_tmp() -> Result<TmpDir, String> {
    let base = std::env::temp_dir();
    let nanos = SystemTime::now().duration_since(UNIX_EPOCH).map(|d| d.as_nanos()).unwrap_or(0);
    for n in 0..64u32 {
        let p = base.join(format!("forge-airlock-verify-{}-{}-{}", std::process::id(), nanos, n));
        match DirBuilder::new().mode(0o700).create(&p) {
            Ok(()) => {
                let t = TmpDir(p);
                let md = std::fs::symlink_metadata(&t.0).map_err(|e| format!("temp folder: {e}"))?;
                if !md.is_dir() || md.mode() & 0o777 != 0o700 {
                    return Err("temp folder: not a private 0700 folder".into());
                }
                return Ok(t);
            }
            Err(e) if e.kind() == std::io::ErrorKind::AlreadyExists => continue,
            Err(e) => return Err(format!("temp folder: {e}")),
        }
    }
    Err("temp folder: no free name".into())
}

fn ssh_verify(allowed: &str, ident: &str, sigfile: &Path, chain: &[u8; 32]) -> Result<(), String> {
    let mut child = Command::new(SSH_KEYGEN)
        .args(["-Y", "verify", "-f", allowed, "-I", ident, "-n", NAMESPACE, "-s"])
        .arg(sigfile)
        .env_clear()
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .map_err(|e| format!("spawn {SSH_KEYGEN}: {e}"))?;
    {
        let mut si = child.stdin.take().ok_or("ssh-keygen: no stdin")?;
        si.write_all(hash::hex(chain).as_bytes()).map_err(|e| format!("ssh-keygen stdin: {e}"))?;
    }
    let out = child.wait_with_output().map_err(|e| format!("ssh-keygen wait: {e}"))?;
    let so = String::from_utf8_lossy(&out.stdout);
    let good = format!("Good \"{NAMESPACE}\" signature for {ident} ");
    if out.status.success() && so.starts_with(&good) {
        Ok(())
    } else {
        let err = String::from_utf8_lossy(&out.stderr[..out.stderr.len().min(300)]).into_owned();
        let msg = format!("{} {}", so.chars().take(200).collect::<String>().trim(), err.trim());
        Err(format!("ssh-keygen -Y verify refused ({}): {}", out.status, msg.trim().replace('\n', " / ")))
    }
}

fn usage() -> i32 {
    eprintln!("usage: verify-evidence <evidence.wal> --allowed-signers FILE [--identity NAME]   (default identity: {DEFAULT_IDENTITY})");
    2
}

/// `forge-mcp-proxy verify-evidence <evidence.wal> --allowed-signers <file>`: prints a report, returns the exit code
/// (0 = every record, chain link and signature holds). `args` are the words after `verify-evidence`; a leading
/// `verify-evidence` word is skipped.
pub fn verify_cli(args: &[String]) -> i32 {
    let mut a = args;
    if a.first().map(|s| s == "verify-evidence").unwrap_or(false) {
        a = &a[1..];
    }
    let (mut wal, mut allowed, mut ident) = (None, None, None);
    let mut i = 0;
    while i < a.len() {
        match a[i].as_str() {
            "--allowed-signers" if i + 1 < a.len() && allowed.is_none() => {
                allowed = Some(a[i + 1].clone());
                i += 2;
            }
            "--identity" if i + 1 < a.len() && ident.is_none() => {
                ident = Some(a[i + 1].clone());
                i += 2;
            }
            s if !s.starts_with("--") && wal.is_none() => {
                wal = Some(s.to_string());
                i += 1;
            }
            _ => return usage(),
        }
    }
    let (wal, allowed) = match (wal, allowed) {
        (Some(w), Some(a)) => (w, a),
        _ => return usage(),
    };
    let ident = ident.unwrap_or_else(|| DEFAULT_IDENTITY.to_string());
    if ident.is_empty() || ident.starts_with('-') || allowed.is_empty() {
        return usage();
    }
    verify(&wal, &allowed, &ident)
}

fn fail(at: u64, ok: u64, why: &str) -> i32 {
    println!("FAILED at={at} records_ok={ok} reason={why}");
    1
}

fn verify(wal: &str, allowed: &str, ident: &str) -> i32 {
    if let Err(e) = File::open(allowed) {
        return fail(0, 0, &format!("cannot read allowed signers file: {e}"));
    }
    let f = match File::open(wal) {
        Ok(f) => f,
        Err(e) => return fail(0, 0, &format!("cannot open {wal}: {e}")),
    };
    let parsed = match parse(f) {
        Ok(p) => p,
        Err(e) => return fail(0, 0, &format!("framing: {e}")),
    };
    let torn = parsed.torn.clone();
    let (entries, bad) = order(parsed.frames);
    if entries.is_empty() && bad.is_none() && torn.is_none() {
        return fail(0, 0, "no records (nothing to verify is not a pass)");
    }
    let tmp = match private_tmp() {
        Ok(t) => t,
        Err(e) => return fail(0, 0, &e),
    };
    let mut head = genesis();
    let mut prev_epoch = 0u64;
    let mut sigs = 0u64;
    for (n, e) in entries.iter().enumerate() {
        let idx = n as u64 + 1;
        if let Some((bi, why)) = &bad {
            if *bi <= idx {
                return fail(*bi, n as u64, why);
            }
        }
        let r = &e.rec;
        let epoch = u64::from_be_bytes(r[0..8].try_into().unwrap());
        let ts = u64::from_be_bytes(r[8..16].try_into().unwrap());
        let agent = field_text(&r[16..48]);
        let tool = field_text(&r[48..80]);
        let (pre, post, v) = (&r[80..96], &r[96..112], r[112]);
        let vname = verdict_name(v);
        let mut why: Option<String> = None;
        if chain_next(&head, r) != e.chain {
            why = Some("chain link mismatch".into());
        } else if agent.is_none() || tool.is_none() {
            why = Some("agent or tool field is not 1..32 bytes of UTF-8 with zero padding".into());
        } else if vname.is_none() {
            why = Some(format!("unknown verdict {v}"));
        } else if epoch < prev_epoch {
            why = Some(format!("epoch {epoch} decreases (previous {prev_epoch})"));
        } else if is_blocked(v) && pre != post {
            why = Some("blocked verdict with post != pre".into());
        } else {
            match &e.sig {
                None => why = Some("record has no signature".into()),
                Some(a) if !armor_ok(a) => why = Some("signature armor shape is wrong".into()),
                Some(a) => {
                    let sp = tmp.0.join(format!("r{idx}.sig"));
                    let w = OpenOptions::new()
                        .write(true)
                        .create_new(true)
                        .mode(0o600)
                        .custom_flags(O_NOFOLLOW)
                        .open(&sp)
                        .and_then(|mut f| f.write_all(a));
                    match w {
                        Err(err) => why = Some(format!("cannot write signature file: {err}")),
                        Ok(()) => {
                            if let Err(err) = ssh_verify(allowed, ident, &sp, &e.chain) {
                                why = Some(err);
                            }
                            let _ = std::fs::remove_file(&sp);
                        }
                    }
                }
            }
        }
        println!(
            "#{idx} epoch={epoch} ts={ts} agent={} tool={} pre={} post={} verdict={} {}",
            agent.unwrap_or_else(|| "?".into()),
            tool.unwrap_or_else(|| "?".into()),
            hash::hex(pre),
            hash::hex(post),
            vname.unwrap_or("?"),
            if why.is_none() { "OK" } else { "FAIL" }
        );
        if let Some(w) = why {
            return fail(idx, n as u64, &w);
        }
        sigs += 1;
        head = e.chain;
        prev_epoch = epoch;
    }
    let n = entries.len() as u64;
    if let Some((bi, why)) = bad {
        return fail(bi, n, &why);
    }
    if let Some(t) = torn {
        return fail(n + 1, n, &format!("torn tail: {t}"));
    }
    drop(tmp);
    println!("final_chain={}", hash::hex(&head));
    println!("VERIFIED records={n} signatures={sigs} chain=OK");
    0
}
