#![forbid(unsafe_code)]
#![allow(unexpected_cfgs)] // `kill_points` is the one custom cfg: a test seam that is dead code in the production build
//! Native silicon sink (goal 19). Standard library only: no crate, no `unsafe`. NOT proved. The store of ONE charge and the gate of
//! its refund effects: request line -> private process of the CakeML refund binary -> exact decision frame -> checks under an
//! exclusive `flock` -> 64-byte record in `ledger.wal` -> `sync_all` -> ratchet entry in `ledger.epoch` -> `sync_all` -> one
//! `COMMITTED` line on stdout (the dispatch).
//! Record (64 bytes, little-endian):
//!   [0..3) "FSW"   [3] kind: 'G' genesis, '1'..'3' = index + 1 into REASONS   [4..12) epoch
//!   [12..28) pre_state_hash = FNV-1a-128 of the previous record (zero in the genesis record)
//!   [28..52) request id, NUL-padded (genesis: charge id)   [52..60) amount (genesis: original amount)
//!   [60..64) CRC-32/IEEE of bytes 0..60
//! FNV-1a-128 is NOT cryptographic: it is a compare-and-swap value and a chain against torn, spliced or restored
//! files. It authenticates nothing: whoever can write the two files or replace the binary is trusted. This program
//! does not hash the binary; its launcher must. `sync_all` is `fcntl(F_FULLFSYNC)` on macOS; the kernel and the
//! drive are assumptions. A restore of BOTH files is not detected. Delivery is at most once per commit (`replay`).
use std::collections::HashSet;
use std::convert::TryInto;
use std::fs::{File, OpenOptions};
use std::io::{self, BufRead, BufReader, Read, Write};
use std::process::{Command, Stdio};

const REC: usize = 64;
const MAX_LINE: usize = 255;
const MAX_MONEY: u64 = 9_223_372_036_854_775_807;
const REASONS: [&str; 3] = ["duplicate_charge", "service_not_delivered", "returned_item"];
const REJECT_FRAME: &[u8] = b"(refund-result-v1 False 0 \"\" \"\" \"\" 0)";
// Exit codes. `serve` exits with the code of its last answer (USAGE if there was none) and ends at the first code from 17 up.
// DISPATCH_FAILED: the answer line could not be written; a commit of that line stays committed and is not dispatched.
const COMMITTED: i32 = 0; const USAGE: i32 = 2; const CAKEML_REJECTED: i32 = 10; const BAD_FRAME: i32 = 11; const MALFORMED_ID: i32 = 12;
const STALE_STATE_HASH: i32 = 13; const DUPLICATE_REQUEST_ID: i32 = 14; const EPOCH_REGRESSION: i32 = 15; const MALFORMED_REQUEST: i32 = 16;
const CORRUPT_WAL: i32 = 17; const IO_ERROR: i32 = 18; const OUTCOME_UNKNOWN: i32 = 19; const DISPATCH_FAILED: i32 = 20;
/// A refusal: exit code and reason. It dispatches no effect. It leaves no record, except OUTCOME_UNKNOWN: there a record may stay.
struct Refusal(i32, String);
impl From<io::Error> for Refusal { fn from(e: io::Error) -> Self { Refusal(IO_ERROR, format!("IO_ERROR: {e}")) } }
fn no<T>(code: i32, why: &str) -> Result<T, Refusal> { Err(Refusal(code, why.to_string())) }
/// Test seam, live only in a build with `--cfg kill_points`: at the point that SINK_KILL_AT names, the process says so and waits for SIGKILL.
fn seam(point: &str) -> bool { cfg!(kill_points) && std::env::var("SINK_KILL_AT").as_deref() == Ok(point) }
fn cut(point: &str) { if seam(point) { eprintln!("AT {point}"); loop { std::thread::park(); } } }
/// Where a write is cut in two so that a kill point lies inside it. In the production build: never (`len`).
fn split(len: usize, point: &str) -> usize {
    if seam(point) { std::env::var("SINK_KILL_SPLIT").ok().and_then(|s| s.parse().ok()).unwrap_or(len / 2).min(len) } else { len }
}
fn crc32(data: &[u8]) -> u32 {
    let mut c = !0u32;
    for &b in data {
        c ^= b as u32;
        for _ in 0..8 { c = if c & 1 == 1 { (c >> 1) ^ 0xEDB8_8320 } else { c >> 1 }; }
    }
    !c
}
/// FNV-1a, 128 bits. NOT cryptographic (see the head of this file).
fn fnv128(data: &[u8]) -> u128 {
    data.iter().fold(0x6c62272e07bb014262b821756295c58d, |h: u128, &b| (h ^ b as u128).wrapping_mul(0x0000000001000000000000000000013b))
}
/// The one spelling of an id: 1 to 24 bytes of `[A-Za-z0-9_-]`. No NUL, no whitespace, no other byte.
fn canonical_id(id: &[u8]) -> bool { !id.is_empty() && id.len() <= 24 && id.iter().all(|b| b.is_ascii_alphanumeric() || *b == b'_' || *b == b'-') }
/// The one spelling of an amount: `0`, or a nonzero digit and up to 18 more digits; at most MAX_MONEY.
fn money(s: &str) -> Option<u64> {
    let canonical = s == "0" || (!s.starts_with('0') && (1..=19).contains(&s.len()) && s.bytes().all(|b| b.is_ascii_digit()));
    s.parse::<u64>().ok().filter(|v| canonical && *v <= MAX_MONEY)
}
/// The only output of the binary that authorizes this request.
fn frame(amount: u64, reason: &str, charge: &str, request: &str) -> String { format!("(refund-result-v1 True {amount} {reason} {charge} {request} 1)") }
fn encode(kind: u8, epoch: u64, pre_state_hash: u128, id: &str, amount: u64) -> [u8; REC] {
    let mut r = [0u8; REC];
    r[..4].copy_from_slice(&[b'F', b'S', b'W', kind]);
    r[4..12].copy_from_slice(&epoch.to_le_bytes());
    r[12..28].copy_from_slice(&pre_state_hash.to_le_bytes());
    r[28..28 + id.len()].copy_from_slice(id.as_bytes());
    r[52..60].copy_from_slice(&amount.to_le_bytes());
    let crc = crc32(&r[..60]);
    r[60..].copy_from_slice(&crc.to_le_bytes());
    r
}
/// The state of the ledger: the fold of its valid records. `effects` holds (kind, request id, amount) per commit.
#[derive(Default)]
struct Ledger {
    charge: String, original: u64, remaining: u64, epoch: u64, tail: u128, ids: HashSet<String>, effects: Vec<(u8, String, u64)>, len: usize,
}
/// Folds the WAL. The valid prefix must hold the genesis record, and the file may be at most 64 bytes longer
/// than it (one torn append). Everything else is CORRUPT_WAL.
fn scan(bytes: &[u8]) -> Result<Ledger, Refusal> {
    let mut l = Ledger::default();
    for (i, r) in bytes.chunks_exact(REC).enumerate() {
        let id = r[28..52].split(|&b| b == 0).next().unwrap_or(&[]);
        let amount = u64::from_le_bytes(r[52..60].try_into().expect("8 bytes"));
        let framed = &r[..3] == b"FSW" && r[60..] == crc32(&r[..60]).to_le_bytes() && r[4..12] == (i as u64).to_le_bytes()
            && r[12..28] == l.tail.to_le_bytes() && canonical_id(id) && r[28 + id.len()..52].iter().all(|&b| b == 0);
        let id = String::from_utf8_lossy(id).into_owned();
        if i == 0 && framed && r[3] == b'G' && amount <= MAX_MONEY {
            (l.charge, l.original, l.remaining) = (id, amount, amount);
        } else if i > 0 && framed && (b'1'..=b'3').contains(&r[3]) && amount <= l.remaining && l.ids.insert(id.clone()) {
            l.remaining -= amount;
            l.effects.push((r[3], id, amount));
        } else { break }
        (l.epoch, l.tail, l.len) = (i as u64, fnv128(r), (i + 1) * REC);
    }
    if l.len == 0 || bytes.len() - l.len > REC { return no(CORRUPT_WAL, "CORRUPT_WAL: no genesis record, or more than one record is not valid") }
    Ok(l)
}
fn push(ratchet: &mut File, epoch: u64) -> io::Result<()> {
    let e = epoch.to_le_bytes();
    ratchet.write_all(&[&e[..], &crc32(&e).to_le_bytes()[..]].concat()).and_then(|()| ratchet.sync_all())
}
/// Every command but `init` starts here: lock, fold, ratchet check, then recovery (cut a torn tail; make the state durable).
fn open_ledger(dir: &str) -> Result<(File, File, Ledger), Refusal> {
    let mut wal = OpenOptions::new().read(true).append(true).open(format!("{dir}/ledger.wal"))?;
    wal.lock()?; // exclusive flock; the kernel releases it when this process ends or is killed
    let (mut bytes, mut entries) = (Vec::new(), Vec::new());
    wal.read_to_end(&mut bytes)?;
    let l = scan(&bytes)?;
    let mut ratchet = OpenOptions::new().read(true).append(true).open(format!("{dir}/ledger.epoch"))?;
    ratchet.read_to_end(&mut entries)?;
    let valid = entries.chunks_exact(12).filter(|e| e[8..] == crc32(&e[..8]).to_le_bytes());
    let Some(floor) = valid.map(|e| u64::from_le_bytes(e[..8].try_into().expect("8 bytes"))).max() else {
        return no(CORRUPT_WAL, "CORRUPT_WAL: the ratchet has no valid entry");
    };
    if l.epoch < floor { return no(EPOCH_REGRESSION, "EPOCH_REGRESSION: the ledger is older than its ratchet (a restored file?)") }
    if entries.len() % 12 != 0 || l.len < bytes.len() || floor < l.epoch {
        ratchet.set_len((entries.len() - entries.len() % 12) as u64)?; // a torn ratchet entry
        wal.set_len(l.len as u64)?; // a torn record
        wal.sync_all()?;
        push(&mut ratchet, l.epoch)?;
    }
    Ok((wal, ratchet, l))
}
struct Request<'a> { tail: u128, wire: &'a str, charge: &'a str, request: &'a str, original: u64, remaining: u64, amount: u64, reason: &'a str }
/// The one accepted line: `<32 lowercase hex> (<charge> <request> <original> <remaining> <flag> <flag> <flag> <amount> <reason>)`.
fn parse(line: &str) -> Result<Request<'_>, Refusal> {
    let (hash, wire) = line.split_once(' ').unwrap_or((line, ""));
    let f: Vec<&str> = wire.strip_prefix('(').and_then(|w| w.strip_suffix(')')).unwrap_or("").split(' ').collect();
    let lower_hex = hash.len() == 32 && hash.bytes().all(|b| b.is_ascii_digit() || (b'a'..=b'f').contains(&b));
    if !lower_hex || f.len() != 9 || !f[4..7].iter().all(|flag| *flag == "True" || *flag == "False") {
        return no(MALFORMED_REQUEST, "MALFORMED_REQUEST: not `<32 hex> (charge request original remaining flag flag flag amount reason)`");
    }
    if !canonical_id(f[0].as_bytes()) || !canonical_id(f[1].as_bytes()) {
        return no(MALFORMED_ID, "MALFORMED_ID: an id is 1 to 24 bytes of [A-Za-z0-9_-]");
    }
    match (u128::from_str_radix(hash, 16), money(f[2]), money(f[3]), money(f[7]), canonical_id(f[8].as_bytes())) {
        (Ok(tail), Some(original), Some(remaining), Some(amount), true) => {
            Ok(Request { tail, wire, charge: f[0], request: f[1], original, remaining, amount, reason: f[8] })
        }
        _ => no(MALFORMED_REQUEST, "MALFORMED_REQUEST: an amount or the reason is not canonical"),
    }
}
/// One private process of the refund binary per request. Ok only for exit code 0, empty stderr and exactly `expect` on stdout.
fn ask_binary(binary: &str, wire: &str, expect: &str) -> Result<(), Refusal> {
    let mut child = Command::new(binary).env_clear().env("CML_HEAP_SIZE", "256").env("CML_STACK_SIZE", "256")
        .stdin(Stdio::piped()).stdout(Stdio::piped()).stderr(Stdio::piped()).spawn()?;
    let sent = child.stdin.take().expect("piped").write_all(wire.as_bytes()); // one write below PIPE_BUF; the pipe closes here: EOF
    let (mut out, mut err) = (Vec::new(), Vec::new());
    child.stdout.take().expect("piped").take(expect.len().max(REJECT_FRAME.len()) as u64 + 1).read_to_end(&mut out)?;
    child.stderr.take().expect("piped").take(1).read_to_end(&mut err)?;
    let clean = child.wait()?.code() == Some(0) && err.is_empty() && sent.is_ok(); // `code()` is None after a signal
    match (clean, out.as_slice()) {
        (true, o) if o == expect.as_bytes() => Ok(()),
        (true, REJECT_FRAME) => no(CAKEML_REJECTED, "CAKEML_REJECTED: the binary rejected the request"),
        _ => no(BAD_FRAME, "BAD_FRAME: the binary gave no exact decision frame"),
    }
}
/// Runs only after the binary accepted. Writes the record only if every check under the lock passes.
fn commit(dir: &str, r: &Request, accepted: &str) -> Result<String, Refusal> {
    let Some(kind) = REASONS.iter().position(|x| *x == r.reason) else {
        return no(BAD_FRAME, "BAD_FRAME: the accepted reason is not an approved reason");
    };
    let (mut wal, mut ratchet, l) = open_ledger(dir)?; // EPOCH_REGRESSION and CORRUPT_WAL come from here
    if l.ids.contains(r.request) { return no(DUPLICATE_REQUEST_ID, "DUPLICATE_REQUEST_ID: this request id is committed already") }
    if r.tail != l.tail || r.charge != l.charge || r.original != l.original || r.remaining != l.remaining {
        return no(STALE_STATE_HASH, "STALE_STATE_HASH: the request does not name the present state of the ledger");
    }
    if r.amount > l.remaining { return no(BAD_FRAME, "BAD_FRAME: the accepted amount is above the remaining amount") }
    let record = encode(b'1' + kind as u8, l.epoch + 1, l.tail, r.request, r.amount);
    cut("a");
    let at = split(REC, "b"); // REC in the production build: one write of 64 bytes
    let first = wal.write_all(&record[..at]);
    cut("b");
    let written = first.and_then(|()| wal.write_all(&record[at..]));
    cut("c");
    if let Err(e) = written.and_then(|()| wal.sync_all()) {
        let undone = wal.set_len(l.len as u64).and_then(|()| wal.sync_all()); // no record may stay whose write or sync failed
        return if undone.is_ok() { Err(e.into()) } else { no(OUTCOME_UNKNOWN, "OUTCOME_UNKNOWN: a record may be in the WAL; nothing was dispatched") };
    }
    cut("r");
    if push(&mut ratchet, l.epoch + 1).is_err() { return no(OUTCOME_UNKNOWN, "OUTCOME_UNKNOWN: the record is in the WAL; its ratchet entry failed") }
    drop((wal, ratchet)); // the lock ends here, before the dispatch
    cut("d");
    Ok(format!("COMMITTED {} {:032x} {accepted}", l.epoch + 1, fnv128(&record)))
}
fn handle(dir: &str, binary: &str, line: &str) -> Result<String, Refusal> {
    let r = parse(line)?; // bytes that are not UTF-8 arrive here as U+FFFD, which no field accepts
    let accepted = frame(r.amount, r.reason, r.charge, r.request);
    ask_binary(binary, r.wire, &accepted)?; // until this returns Ok, no ledger file is opened
    commit(dir, &r, &accepted)
}
/// Prints one answer line. For a commit this line is the dispatch: both syncs returned Ok before it.
fn answer(result: Result<String, Refusal>) -> i32 {
    let refused = |Refusal(code, why)| (code, format!("REJECT {code} {why}\n"));
    let (code, text) = result.map(|text| (COMMITTED, text + "\n")).unwrap_or_else(refused);
    let (mut out, at) = (io::stdout().lock(), split(text.len(), "e"));
    let first = out.write_all(&text.as_bytes()[..at]).and_then(|()| out.flush());
    cut("e");
    let rest = out.write_all(&text.as_bytes()[at..]).and_then(|()| out.flush());
    if first.is_ok() && rest.is_ok() { code } else { DISPATCH_FAILED }
}
/// Reads LF-terminated lines of at most MAX_LINE bytes. A longer line is dropped to its LF with constant memory.
fn serve(dir: &str, binary: &str) -> i32 {
    let (mut input, mut code) = (BufReader::with_capacity(65536, io::stdin()), USAGE);
    loop {
        let mut line = Vec::with_capacity(MAX_LINE + 1);
        let Ok(read) = input.by_ref().take(MAX_LINE as u64 + 1).read_until(b'\n', &mut line) else { return IO_ERROR };
        if read == 0 { return code }
        let (whole, long) = (line.pop() == Some(b'\n'), line.len() == MAX_LINE); // `long`: 256 bytes came with no LF
        if !whole && long && input.skip_until(b'\n').is_err() { return IO_ERROR }
        let why = if long { "MALFORMED_REQUEST: OVERSIZED: a line is longer than 255 bytes" } else { "MALFORMED_REQUEST: no line end" };
        code = answer(if whole { handle(dir, binary, &String::from_utf8_lossy(&line)) } else { no(MALFORMED_REQUEST, why) });
        if code >= CORRUPT_WAL { return code } // a fault of the ledger, of the system or of the answer: no further line is read
    }
}
/// Creates the two files of a new ledger. It never replaces an existing file.
fn init(dir: &str, charge: &str, original: &str) -> Result<String, Refusal> {
    let Some(original) = money(original).filter(|_| canonical_id(charge.as_bytes())) else {
        return no(MALFORMED_ID, "MALFORMED_ID: the charge id or the original amount is not canonical");
    };
    let (genesis, wal_path, epoch_path) = (encode(b'G', 0, 0, charge, original), format!("{dir}/ledger.wal"), format!("{dir}/ledger.epoch"));
    if std::fs::metadata(&wal_path).is_ok() || std::fs::metadata(&epoch_path).is_ok() { return no(IO_ERROR, "IO_ERROR: a ledger file exists already") }
    let mut ratchet = OpenOptions::new().append(true).create_new(true).open(&epoch_path)?; // first: a WAL never exists without its ratchet
    let wal = push(&mut ratchet, 0).and_then(|()| OpenOptions::new().write(true).create_new(true).open(&wal_path));
    let made = wal.and_then(|mut w| w.write_all(&genesis).and_then(|()| w.sync_all())).and_then(|()| File::open(dir)?.sync_all()); // and the two names
    if made.is_err() { let _ = (std::fs::remove_file(&wal_path), std::fs::remove_file(&epoch_path)); } // a refused init leaves no file of its own
    made?;
    Ok(format!("STATE 0 {:032x} {charge} {original} {original}", fnv128(&genesis)))
}
fn main() {
    let args: Vec<String> = std::env::args().collect();
    let code = match args.iter().map(String::as_str).collect::<Vec<_>>().as_slice() {
        [_, dir, "serve", binary] => serve(dir, binary),
        [_, dir, "init", charge, original] => answer(init(dir, charge, original)),
        [_, dir, "state"] => {
            answer(open_ledger(dir).map(|(_, _, l)| format!("STATE {} {:032x} {} {} {}", l.epoch, l.tail, l.charge, l.original, l.remaining)))
        }
        [_, dir, "replay"] => answer(open_ledger(dir).map(|(_, _, l)| {
            let effects = l.effects.iter().map(|e| format!("\nEFFECT {}", frame(e.2, REASONS[(e.0 - b'1') as usize], &l.charge, &e.1)));
            format!("REPLAY {}{}", l.effects.len(), effects.collect::<String>())
        })),
        _ => { eprintln!("usage: native_sink <dir> serve <refund-binary> | init <charge> <original> | state | replay"); USAGE }
    };
    std::process::exit(code);
}
