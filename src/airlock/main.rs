#![forbid(unsafe_code)]
#![allow(unexpected_cfgs)] // `kill_points` is the one custom cfg: a test seam that is dead code in the production build
//! forge-airlock engine (Goal 20). NATIVE CHECK: Rust, standard library only, no crate, no `unsafe`. NOT PROVED.
//! Generalizes src/silicon_sink/sink.rs (unchanged) to many keys with a tenant field and three write airlocks:
//! money, saga, inventory; plus a read airlock (READ) and durable obligation leases.
//! PROVED CORE only where stated: the CakeML refund binary decides a `canonical-refund` REFUND; the Dafny-compiled
//! BookingDualCert checker (run by Node: Node and the Dafny compiler are trusted) must accept a BOOK. Everything
//! else here (WAL, fold, CAS, parametric money rules, saga table, cosign wiring, read airlock, leases) is a native
//! check with finite tests. `sync_all` is fcntl(F_FULLFSYNC) on macOS; the kernel and the drive are assumptions.
//! FNV-1a-128 is not cryptographic. Cosign signatures are verified by the system OpenSSH, `/usr/bin/ssh-keygen -Y
//! verify` (a trusted assumption, with its LibreSSL; no Node, no V8), after native checks of the SSHSIG form
//! (cosign.rs); the engine never reads a private key. Pins: the refund binary (compiled-in SHA-256), the Node binary
//! of an inventory store (SHA-256 in the genesis record), the booking helper (compiled in); ssh-keygen is checked
//! (root-owned, not writable by group or other, no symbolic link on its path), not pinned. Trust boundary: every rule
//! holds only for a caller that goes through this engine; whoever can write the store folder or run another engine
//! build on it is trusted (PROTOCOL.md section 11). Wire: PROTOCOL.md.
mod cosign;
mod helpers;
mod json;
mod ledger;
mod pin;
mod policy;
mod store;
mod verbs;

use std::io::{self, BufRead, BufReader, Read, Write};

pub const MAX_LINE: usize = 65536;

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum Code {
    // `Breach` (TENANT_ISOLATION_BREACH, 16): since the per-tenant namespaces (review D3) only the read airlock gives it
    // (a row set that holds a row of another tenant). No write, GET or lease answer gives it any more: a key of another
    // tenant is UNKNOWN_KEY. The tenant field is not authenticated (PROTOCOL.md section 11): the name is kept for the wire.
    Ok, Usage, RejectedPolicy, RequireHumanCosign, Malformed, Stale, Duplicate, EpochRegression, Breach, CorruptWal,
    IoError, OutcomeUnknown, DispatchFailed, UnknownKey, HelperFailed, BadFrame, DroppedObligation, MalformedPolicy,
}
impl Code {
    pub fn num(self) -> i32 {
        use Code::*;
        match self {
            Ok => 0, Usage => 2, RejectedPolicy => 10, RequireHumanCosign => 11, Malformed => 12, Stale => 13, Duplicate => 14,
            EpochRegression => 15, Breach => 16, CorruptWal => 17, IoError => 18, OutcomeUnknown => 19, DispatchFailed => 20,
            UnknownKey => 21, HelperFailed => 22, BadFrame => 23, DroppedObligation => 24, MalformedPolicy => 25,
        }
    }
    pub fn name(self) -> &'static str {
        use Code::*;
        match self {
            Ok => "OK", Usage => "USAGE", RejectedPolicy => "REJECTED_POLICY", RequireHumanCosign => "REQUIRE_HUMAN_COSIGN",
            Malformed => "MALFORMED_REQUEST", Stale => "STALE_STATE_HASH", Duplicate => "DUPLICATE_REQUEST_ID",
            EpochRegression => "EPOCH_REGRESSION", Breach => "TENANT_ISOLATION_BREACH", CorruptWal => "CORRUPT_WAL",
            IoError => "IO_ERROR", OutcomeUnknown => "OUTCOME_UNKNOWN", DispatchFailed => "DISPATCH_FAILED",
            UnknownKey => "UNKNOWN_KEY", HelperFailed => "HELPER_FAILED", BadFrame => "BAD_FRAME",
            DroppedObligation => "DROPPED_OBLIGATION", MalformedPolicy => "MALFORMED_POLICY",
        }
    }
}
/// A fault of the ledger, of the system or of the answer: `serve` reads no further line after it.
pub fn is_fault(code: i32) -> bool {
    [15, 17, 18, 19, 20].contains(&code)
}
/// A refusal: code and detail. It leaves no effect record, except OUTCOME_UNKNOWN: there a record may stay.
pub struct Refusal(pub Code, pub String);
impl From<io::Error> for Refusal {
    fn from(e: io::Error) -> Self {
        Refusal(Code::IoError, format!("{e}").replace('\n', " "))
    }
}
pub fn no<T>(code: Code, why: impl Into<String>) -> Result<T, Refusal> {
    Err(Refusal(code, why.into()))
}
/// Test seam, live only in a build with `--cfg kill_points`: at the point that AIRLOCK_KILL_AT names, the process says so and waits for SIGKILL.
pub fn seam(point: &str) -> bool {
    cfg!(kill_points) && std::env::var("AIRLOCK_KILL_AT").as_deref() == Ok(point)
}
pub fn cut(point: &str) {
    if seam(point) {
        eprintln!("AT {point}");
        loop {
            std::thread::park();
        }
    }
}
/// Where a write is cut in two so that a kill point lies inside it. In the production build: never (`len`).
pub fn split(len: usize, point: &str) -> usize {
    if seam(point) { std::env::var("AIRLOCK_KILL_SPLIT").ok().and_then(|s| s.parse().ok()).unwrap_or(len / 2).min(len) } else { len }
}

/// Prints one answer line: `<CODE_NAME> <detail>` for a refusal; the success text as given. Returns the exit code.
fn answer(result: Result<String, Refusal>) -> i32 {
    let (code, text) = match result {
        Ok(text) => (0, text + "\n"),
        Err(Refusal(c, why)) => {
            let why = why.replace('\n', " ");
            let text = if why.is_empty() || why == c.name() { c.name().to_string() } else if why.starts_with(&format!("{} ", c.name())) { why } else { format!("{} {why}", c.name()) };
            (c.num(), text + "\n")
        }
    };
    let (mut out, at) = (io::stdout().lock(), split(text.len(), "e"));
    let first = out.write_all(&text.as_bytes()[..at]).and_then(|()| out.flush());
    cut("e");
    let rest = out.write_all(&text.as_bytes()[at..]).and_then(|()| out.flush());
    if first.is_ok() && rest.is_ok() { code } else { Code::DispatchFailed.num() }
}

pub enum Line {
    Whole(Vec<u8>),
    Oversized,
    NoEnd,
}
/// Reads one LF-terminated line of at most MAX_LINE bytes (the LF not counted). A longer line is skipped to its LF
/// with constant memory. None at EOF.
pub fn read_line(input: &mut impl BufRead) -> io::Result<Option<Line>> {
    let mut line = Vec::new();
    let n = input.by_ref().take(MAX_LINE as u64 + 1).read_until(b'\n', &mut line)?;
    if n == 0 { return Ok(None) }
    if line.last() == Some(&b'\n') {
        line.pop();
        return Ok(Some(Line::Whole(line)));
    }
    if line.len() > MAX_LINE {
        input.skip_until(b'\n')?;
        return Ok(Some(Line::Oversized));
    }
    Ok(Some(Line::NoEnd))
}

fn serve(ctx: &verbs::Ctx) -> i32 {
    let mut input = BufReader::with_capacity(1 << 16, io::stdin());
    let mut code = Code::Usage.num();
    loop {
        let line = match read_line(&mut input) {
            Err(_) => return Code::IoError.num(),
            Ok(None) => return code,
            Ok(Some(l)) => l,
        };
        let result = match line {
            Line::Whole(b) if b.starts_with(b"READ ") => verbs::read_verb(&b, &mut || read_line(&mut input)),
            Line::Whole(b) => verbs::handle(ctx, &b),
            Line::Oversized => no(Code::Malformed, format!("OVERSIZED a line is longer than {MAX_LINE} bytes")),
            Line::NoEnd => no(Code::Malformed, "NO_LINE_END"),
        };
        code = answer(result);
        if is_fault(code) { return code }
    }
}

/// `eval <policy.json>`: lines `EVAL <reason> <amount> <remaining> <reason_total> [<fact>=<value>]...` on stdin.
fn eval(file: &str) -> i32 {
    let mut bytes = Vec::new();
    let read = std::fs::File::open(file).and_then(|f| f.take(1 << 20).read_to_end(&mut bytes));
    let parsed = match read {
        Err(e) => return answer(no(Code::MalformedPolicy, format!("UNREADABLE {:?}", e.kind()))),
        Ok(_) => policy::parse(&bytes),
    };
    let m = match parsed {
        Ok(policy::Policy { body: policy::Body::Money(m), .. }) if !m.canonical => m,
        Ok(_) => return answer(no(Code::MalformedPolicy, "EVAL_NEEDS_PARAMETRIC_MONEY_POLICY")),
        Err(e) => return answer(no(Code::MalformedPolicy, e)),
    };
    let mut input = BufReader::new(io::stdin());
    let mut code = 0;
    loop {
        let result = match read_line(&mut input) {
            Err(_) => return Code::IoError.num(),
            Ok(None) => return code,
            Ok(Some(Line::Whole(b))) => eval_line(&m, &b),
            Ok(Some(_)) => no(Code::Malformed, "OVERSIZED or NO_LINE_END"),
        };
        code = answer(result);
        if is_fault(code) { return code }
    }
}
fn eval_line(m: &policy::Money, raw: &[u8]) -> Result<String, Refusal> {
    let text = std::str::from_utf8(raw).unwrap_or("");
    let t: Vec<&str> = text.split(' ').collect();
    let bad = || Refusal(Code::Malformed, "EVAL `EVAL <reason> <amount> <remaining> <reason_total> [<fact>=<value>]...`".into());
    if t.len() < 5 || t[0] != "EVAL" || !store::canonical_id(t[1]) { return Err(bad()) }
    let nums: Option<Vec<u64>> = t[2..5].iter().map(|x| store::money(x)).collect();
    let nums = nums.ok_or_else(bad)?;
    let mut facts = std::collections::BTreeMap::new();
    for f in &t[5..] {
        let (n, v) = f.split_once('=').ok_or_else(bad)?;
        let v = store::money(v).filter(|_| store::canonical_id(n)).ok_or_else(bad)?;
        if facts.insert(n.to_string(), v).is_some() { return Err(bad()) }
    }
    let fact = |n: &str| facts.get(n).copied();
    Ok(match policy::eval_money(m, t[1], nums[0], nums[1], nums[2], &fact) {
        policy::Verdict::Commit => "COMMIT".into(),
        policy::Verdict::Cosign => "REQUIRE_HUMAN_COSIGN".into(),
        policy::Verdict::Reject(c) => format!("REJECTED_POLICY {c}"),
    })
}

/// `leases <dir> [--sweep [--now MS] | --all]`. Read-only: a sweep writes no record (a dropped lease stays open and is
/// reported again by the next sweep). Exit 24 if a sweep reports at least one DROPPED_OBLIGATION. `--all` also lists
/// each closed lease with the record that closed it, so an obligation closed by a rejection stays visible. A lease in
/// the state PENDING_COSIGN (review D6) is open: listed with that state, swept as PENDING_COSIGN before its deadline
/// and as DROPPED_OBLIGATION after it.
fn leases(dir: &str, sweep: bool, all: bool, now: Option<u64>) -> i32 {
    let s = match store::open(dir) { Ok(s) => s, Err(e) => return answer(Err(e)) };
    let now = now.unwrap_or_else(|| std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map(|d| d.as_millis() as u64).unwrap_or(u64::MAX));
    let mut list: Vec<(&String, &ledger::Lease)> = s.l.leases.iter().filter(|(_, l)| all || l.is_open()).map(|((_, req), l)| (req, l)).collect();
    list.sort_by_key(|(_, l)| l.epoch);
    let open = s.l.open_leases();
    let mut text = String::new();
    let mut dropped = 0;
    for (req, l) in &list {
        let (deadline, tenant, key) = (&l.deadline, &l.tenant, &l.key);
        let pending = l.pending.as_ref().map(|(epoch, detail)| format!(" PENDING_COSIGN {epoch} {detail}"));
        if !sweep {
            let status = match (&l.closed, &pending) {
                (Some((epoch, verdict, detail)), _) => format!(" CLOSED {epoch} {verdict} {detail}"),
                (None, Some(p)) => p.clone(),
                (None, None) => if all { " OPEN".to_string() } else { String::new() },
            };
            text.push_str(&format!("\nLEASE {req} {deadline} {tenant} {key}{status}"));
        } else if now > *deadline {
            dropped += 1;
            text.push_str(&format!("\nDROPPED_OBLIGATION {req} {deadline} {tenant} {key}"));
        } else if let Some((_, detail)) = &l.pending {
            // review D6: a cosign verdict was given and the signed retry has not come yet (not dropped before the deadline)
            text.push_str(&format!("\nPENDING_COSIGN {req} {deadline} {tenant} {key} {detail}"));
        }
    }
    let head = if sweep { format!("SWEEP {open} {dropped} now={now}") } else if all { format!("LEASES {open} all={}", list.len()) } else { format!("LEASES {open}") };
    drop(s);
    let code = answer(Ok(head + &text));
    if code == 0 && dropped > 0 { Code::DroppedObligation.num() } else { code }
}

/// Flags: `names` take one value each (at most once), `multi` may repeat, `bools` take no value (at most once).
fn flag_values(rest: &[String], names: &[&str], multi: &str, bools: &[&str]) -> Option<(std::collections::HashMap<String, String>, Vec<String>, Vec<String>)> {
    let (mut one, mut many, mut seen) = (std::collections::HashMap::new(), Vec::new(), Vec::new());
    let mut i = 0;
    while i < rest.len() {
        let f = rest[i].as_str();
        if bools.contains(&f) {
            if seen.iter().any(|x| x == f) { return None }
            seen.push(f.to_string());
            i += 1;
            continue;
        }
        let v = rest.get(i + 1)?.clone();
        if f == multi {
            many.push(v);
        } else if names.contains(&f) && !one.contains_key(f) {
            one.insert(f.to_string(), v);
        } else {
            return None;
        }
        i += 2;
    }
    Some((one, many, seen))
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let usage = || {
        eprintln!("usage: airlock-engine init <dir> [--store-id ID] [--policy FILE]... [--cosign-pubkey SSH_ED25519_BASE64] [--node P]");
        eprintln!("       airlock-engine serve <dir> [--refund-binary P] [--node P] [--checker MODEL]");
        eprintln!("       airlock-engine state|replay <dir> | get <dir> <tenant> <key> | leases <dir> [--sweep [--now MS] | --all]");
        eprintln!("       airlock-engine eval <policy.json> | cosign-message <dir> <action> | cosign-info | sha256 <file> | base64-decode <token>");
        Code::Usage.num()
    };
    let a: Vec<&str> = args.iter().map(String::as_str).collect();
    let rest: Vec<String> = args.iter().skip(3).cloned().collect();
    let code = match a.get(1..).unwrap_or(&[]) {
        ["init", dir, ..] => match flag_values(&rest, &["--store-id", "--cosign-pubkey", "--node"], "--policy", &[]) {
            Some((one, policies, _)) => {
                let id = one.get("--store-id").cloned().unwrap_or_else(|| {
                    let seed = format!("{:?}{}", std::time::SystemTime::now(), std::process::id());
                    format!("st-{}", &store::hx(store::fnv128(seed.as_bytes()))[..21])
                });
                answer(store::init(dir, &id, &policies, one.get("--cosign-pubkey").map(String::as_str), one.get("--node").map(String::as_str)))
            }
            _ => usage(),
        },
        // No `--helpers`: the helpers are compiled into the engine (a caller-chosen helper folder was the review's R1).
        ["serve", dir, ..] => match flag_values(&rest, &["--refund-binary", "--node", "--checker"], "", &[]) {
            Some((one, many, _)) if many.is_empty() => {
                let g = |k: &str| one.get(k).cloned();
                serve(&verbs::Ctx { dir: dir.to_string(), binary: g("--refund-binary"), node: g("--node"), checker: g("--checker"), node_pin: Default::default() })
            }
            _ => usage(),
        },
        ["state", dir] => answer(verbs::state(dir)),
        ["get", dir, tenant, key] => answer(verbs::get(dir, tenant, key)),
        ["replay", dir] => answer(store::open(dir).and_then(|s| {
            let mut lines = String::new();
            let mut n = 0;
            store::records(&s, &mut |epoch, p| {
                let kind = p.split(' ').next().unwrap_or("");
                if ["OPEN_MONEY", "REFUND", "OPEN_SAGA", "SAGA", "OPEN_INVENTORY", "BOOK"].contains(&kind) {
                    n += 1;
                    lines.push_str(&format!("\nEFFECT {epoch} {p}"));
                }
            })?;
            Ok(format!("REPLAY {n}{lines}"))
        })),
        ["leases", dir, ..] => match flag_values(&rest, &["--now"], "", &["--sweep", "--all"]) {
            Some((one, many, b)) if many.is_empty() => {
                let (sweep, all) = (b.iter().any(|x| x == "--sweep"), b.iter().any(|x| x == "--all"));
                match one.get("--now").map(|v| store::money(v)) {
                    _ if sweep && all => usage(),
                    Some(_) if !sweep => usage(),
                    Some(None) => usage(),
                    now => leases(dir, sweep, all, now.flatten()),
                }
            }
            _ => usage(),
        },
        ["eval", file] => eval(file),
        ["sha256", file] => answer(pin::file_sha256(file).map(|h| format!("SHA256 {h}")).map_err(Refusal::from)),
        // test vectors of the strict base64 decoder of cosign.rs (hex of the bytes, or a refusal)
        ["base64-decode", token] => answer(cosign::b64_decode(token).map(|b| format!("BASE64 {}", b.iter().map(|x| format!("{x:02x}")).collect::<String>())).ok_or(Refusal(Code::Malformed, "BAD_BASE64".into()))),
        ["cosign-info"] => answer(cosign::info()),
        ["cosign-message", dir, action] => match verbs::cosign_message_cmd(dir, action) {
            Ok(m) => {
                let mut out = io::stdout().lock();
                if out.write_all(m.as_bytes()).and_then(|()| out.flush()).is_ok() { 0 } else { Code::DispatchFailed.num() }
            }
            Err(e) => answer(Err(e)),
        },
        _ => usage(),
    };
    std::process::exit(code);
}
