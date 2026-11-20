//! MCP stdio airlock core: line framing, routing, the upstream child process, ordered client output.
//! NATIVE CHECK and FINITE TEST, not proved. Standard library only. The wire is documented in PROTOCOL.md.
//!
//! Threads: the main thread reads client stdin and is the only writer to the upstream stdin. One reader thread
//! reads the upstream stdout. Both write to client stdout through the one process-wide stdout lock, one whole line
//! and one flush per write. Lock order: `core` first, then stdout. No upstream write happens under `core`.
//!
//! Memory: each reader has one fixed read chunk and one line buffer that is allocated once at its cap and never
//! grows. An over-cap line is discarded chunk by chunk; its bytes are never kept.
use crate::evidence::{Evidence, Verdict};
use crate::hash::{self, H16};
use crate::json::{self, J};
use crate::jsonw;
use crate::ledger::{Cas, Ledger};
use crate::policy::{Kind, Policy};
use std::collections::HashMap;
use std::io::{self, Read, Write};
use std::process::{ChildStdin, Command, Stdio};
use std::sync::{Arc, Mutex, MutexGuard};

/// Client line cap: 64 KiB, newline excluded.
pub const CLIENT_CAP: usize = 65_536;
/// Upstream line cap: 1 MiB, newline excluded.
pub const UPSTREAM_CAP: usize = 1 << 20;
const CHUNK: usize = 64 * 1024;
/// Most requests forwarded and not yet answered by the upstream server. More are refused.
const MAX_INFLIGHT: usize = 4096;
const READER_STACK: usize = 256 * 1024;
const NO_TOOL: &str = "-";

/// Longest number token that a client line may carry (finding R3: a long number can make the upstream parser fail
/// after the commit).
const MAX_NUMBER_TEXT: usize = 64;

/// A forwarded call whose upstream result goes through the result filter (`policy.filters_result`): a sensitive
/// read, or a mutating call with a result scope.
struct Pending {
    key: String,
    id: String,
    tool: String,
    /// `Some(epoch)` for a mutating call: it was committed at this epoch and forwarded, so its effect may have
    /// happened upstream even when its result is withheld.
    effect: Option<u64>,
}

/// One forwarded request with an id and no upstream response yet.
struct InFlight {
    /// The id as JSON text, for an answer that the proxy creates.
    id: String,
    /// True when an upstream line was discarded while this request was in flight (finding R7): that line may have
    /// been its response.
    maybe_discarded: bool,
}

/// State shared by the two threads.
struct Core {
    ev: Option<Evidence>,
    head: (u64, H16),
    /// Filtered calls in flight, in arrival order.
    pending: Vec<Pending>,
    /// Every forwarded request with an id that has no upstream response yet, by id key.
    inflight: HashMap<String, InFlight>,
    /// Ids of filtered calls that were already answered as dropped. A late upstream response with such an id is
    /// discarded, never passed.
    tombs: HashMap<String, ()>,
    upstream_dead: bool,
    /// Sticky receipt fault (findings R4, B6): set by the first receipt that could not be written. After it, no
    /// receipt is attempted, every `tools/call` is refused with 0 bytes upstream, and the process exits 1.
    fault: Option<String>,
}

struct Shared {
    core: Mutex<Core>,
    policy: Policy,
}

fn lock(m: &Mutex<Core>) -> MutexGuard<'_, Core> {
    // A poisoned lock means a thread panicked inside the airlock state: stop at once with exit code 1 (fail closed,
    // finding D3). Synced receipts and ledger records stay on disk; the upstream sees its stdin close.
    match m.lock() {
        Ok(g) => g,
        Err(_) => {
            eprintln!("mcp-proxy: the airlock state lock is poisoned (a thread panicked); exit 1");
            std::process::exit(1);
        }
    }
}

/// True when `line` has a raw control byte (below 0x20, or 0x7f). A JSON string cannot hold one raw, so such a
/// byte can only be white space between tokens (`\t`, `\r`) or an error. `\r` is a line end for some readers.
fn has_control(line: &[u8]) -> bool {
    line.iter().any(|&b| b < 0x20 || b == 0x7f)
}

/// True when some number token in `v` is longer than `MAX_NUMBER_TEXT` bytes (the parser keeps the source text).
fn long_number(v: &J) -> bool {
    match v {
        J::Num(t) => t.len() > MAX_NUMBER_TEXT,
        J::Arr(a) => a.iter().any(long_number),
        J::Obj(f) => f.iter().any(|(_, x)| long_number(x)),
        _ => false,
    }
}

/// A response to a filtered call passes only in this exact shape: the three members `jsonrpc` (= "2.0"), `id`
/// and `result`, nothing else (finding D1).
fn exact_result_shape(v: &J) -> bool {
    match v {
        J::Obj(f) => {
            f.len() == 3
                && f.iter().all(|(k, _)| matches!(k.as_str(), "jsonrpc" | "id" | "result"))
                && v.get("jsonrpc") == Some(&J::Str("2.0".into()))
        }
        _ => false,
    }
}

/// Start-up reconciliation of `ledger.wal` and `evidence.wal` (finding R2). `L` = ledger head epoch, `E` = epoch of
/// the last `Committed` receipt (0 when there is none).
/// - `E > L`, or `E == L` with another state hash: refuse (the ledger was rolled back, removed or replaced).
/// - `L > E`: the documented crash window between the ledger sync and the receipt. For each ledger record after `E`,
///   append one `Committed` receipt (timestamp = recovery time) and print one line to stderr. The first recovered
///   `pre` must equal the post of the last receipt (or genesis), and the records must follow each other.
pub fn reconcile(ledger: &Ledger, ev: &mut Evidence) -> Result<(), String> {
    let (l, lh) = ledger.head();
    let genesis = crate::ledger::genesis();
    let (e, eh) = ev.last_commit().unwrap_or((0, genesis));
    if e > l {
        return Err(format!(
            "evidence.wal has a Committed receipt at epoch {e} but ledger.wal ends at epoch {l}: the ledger was rolled back, removed or replaced; refused"
        ));
    }
    if e == l {
        if eh != lh {
            return Err(format!(
                "ledger.wal and evidence.wal both end at epoch {l} with different state hashes (ledger {}, evidence {}): refused",
                hash::hex(&lh),
                hash::hex(&eh)
            ));
        }
        return Ok(());
    }
    let recs = ledger.records_after(e)?;
    if recs.len() as u64 != l - e {
        return Err(format!("ledger.wal: {} records after epoch {e}, expected {}", recs.len(), l - e));
    }
    let mut prev = eh;
    for (i, r) in recs.iter().enumerate() {
        if r.epoch != e + 1 + i as u64 || r.pre != prev {
            return Err(format!(
                "ledger record at epoch {} does not follow the last receipt (epoch {e}, post {}): refused",
                r.epoch,
                hash::hex(&eh)
            ));
        }
        ev.append(r.epoch, &r.tool, &r.pre, &r.post, Verdict::Committed)
            .map_err(|x| format!("recovery receipt for epoch {}: {x}", r.epoch))?;
        eprintln!(
            "mcp-proxy: recovered receipt COMMITTED epoch={} tool={:?} post={} (the ledger record had no receipt; crash window between ledger sync and receipt; timestamp = recovery time)",
            r.epoch,
            r.tool,
            hash::hex(&r.post)
        );
        prev = r.post;
    }
    Ok(())
}

/// Write one whole line and flush. Errors (the client closed its end) are ignored: the airlock keeps its
/// enforcement and its records; only the answer is lost.
fn emit(bytes: &[u8]) {
    let out = io::stdout();
    let mut o = out.lock();
    let _ = o.write_all(bytes).and_then(|_| o.write_all(b"\n")).and_then(|_| o.flush());
}

/// Fast search for b'\n' (8 bytes at a time).
fn find_nl(s: &[u8]) -> Option<usize> {
    const LO: u64 = 0x0101_0101_0101_0101;
    const HI: u64 = 0x8080_8080_8080_8080;
    const NL: u64 = LO * b'\n' as u64;
    let mut i = 0;
    while i + 8 <= s.len() {
        let w = u64::from_ne_bytes(s[i..i + 8].try_into().unwrap()) ^ NL;
        if (w.wrapping_sub(LO) & !w & HI) != 0 {
            break;
        }
        i += 8;
    }
    s[i..].iter().position(|&b| b == b'\n').map(|p| i + p)
}

/// Read `r` to its end, split it into lines (newline removed), call `on` for each line of at most `cap`
/// bytes (`Some(line)`) and once with `None` for each longer line (after its end). A last line without newline is
/// a line. Memory: `chunk` plus `line` (capacity `cap + 1`); the buffers never grow.
fn frame<R: Read>(mut r: R, cap: usize, mut on: impl FnMut(Option<&mut Vec<u8>>)) {
    let mut chunk = vec![0u8; CHUNK];
    let mut line: Vec<u8> = Vec::with_capacity(cap + 1);
    let mut over = false;
    loop {
        let n = match r.read(&mut chunk) {
            Ok(0) => break,
            Ok(n) => n,
            Err(e) if e.kind() == io::ErrorKind::Interrupted => continue,
            Err(_) => break,
        };
        let mut s = &chunk[..n];
        while !s.is_empty() {
            let (part, end) = match find_nl(s) {
                Some(p) => (&s[..p], Some(p + 1)),
                None => (s, None),
            };
            if !over {
                if line.len() + part.len() > cap {
                    over = true;
                    line.clear();
                } else {
                    line.extend_from_slice(part);
                }
            }
            match end {
                Some(p) => {
                    if over {
                        on(None);
                        over = false;
                    } else {
                        on(Some(&mut line));
                    }
                    line.clear();
                    s = &s[p..];
                }
                None => s = &[],
            }
        }
    }
    if over {
        on(None);
    } else if !line.is_empty() {
        on(Some(&mut line));
    }
}

/// True for a JSON integer in the one form that every common JSON library echoes unchanged:
/// `0` or `-?[1-9][0-9]{0,14}` (at most 15 digits, exact in an IEEE double).
fn canonical_int(t: &str) -> bool {
    let d = t.strip_prefix('-').unwrap_or(t);
    if d == "0" {
        return t == "0";
    }
    !d.is_empty() && d.len() <= 15 && d.as_bytes()[0] != b'0' && d.bytes().all(|c| c.is_ascii_digit())
}

/// The canonical integer text of a JSON number when its value is an exact integer (`5`, `5.0`, `5e0`, `500e-2`
/// all give "5"). None otherwise, or when it has more than 40 digits.
fn int_value_text(t: &str) -> Option<String> {
    let (neg, rest) = match t.strip_prefix('-') {
        Some(r) => (true, r),
        None => (false, t),
    };
    let (mant, exp) = match rest.find(['e', 'E']) {
        Some(p) => (&rest[..p], rest[p + 1..].parse::<i64>().ok()?),
        None => (rest, 0),
    };
    let (ip, fp) = match mant.find('.') {
        Some(p) => (&mant[..p], &mant[p + 1..]),
        None => (mant, ""),
    };
    let mut digits: String = format!("{ip}{fp}");
    let mut e = exp.checked_sub(fp.len() as i64)?;
    let lead = digits.bytes().take_while(|&c| c == b'0').count();
    digits.drain(..lead);
    if digits.is_empty() {
        return Some("0".into());
    }
    while e < 0 {
        if !digits.ends_with('0') {
            return None;
        }
        digits.pop();
        e += 1;
    }
    if digits.len() as i64 + e > 40 {
        return None;
    }
    for _ in 0..e {
        digits.push('0');
    }
    Some(if neg { format!("-{digits}") } else { digits })
}

/// Map key of a client request id. A string and a number with the same text share one key on purpose: a later
/// request that collides in this way is refused, so an upstream that changes the id type cannot cross responses.
fn client_key(id: &J) -> Option<String> {
    match id {
        J::Str(s) => Some(s.clone()),
        J::Num(t) if canonical_int(t) => Some(t.clone()),
        _ => None,
    }
}

/// Map key of an upstream response id (same key space as `client_key`).
fn upstream_key(id: &J) -> Option<String> {
    match id {
        J::Str(s) => Some(s.clone()),
        J::Num(t) => int_value_text(t),
        _ => None,
    }
}

/// `forge-airlock/request_id`: 1 to 128 bytes of `[A-Za-z0-9._:-]`.
fn valid_request_id(s: &str) -> bool {
    (1..=128).contains(&s.len()) && s.bytes().all(|c| c.is_ascii_alphanumeric() || matches!(c, b'.' | b'_' | b':' | b'-'))
}

impl Core {
    /// Append one receipt. A blocked action or a read records `pre == post == head`. The first failure sets the
    /// sticky fault; after it no receipt is attempted (a later receipt could break the epoch order of the log).
    fn receipt(&mut self, epoch: u64, tool: &str, pre: &H16, post: &H16, v: Verdict) -> Result<(), String> {
        if let Some(f) = &self.fault {
            return Err(format!("an earlier receipt failed ({f})"));
        }
        let r = match self.ev.as_mut() {
            Some(ev) => ev.append(epoch, tool, pre, post, v),
            None => Err("evidence log is closed".into()),
        };
        if let Err(e) = &r {
            eprintln!("mcp-proxy: EVIDENCE FAULT: receipt not written: {e}; every later tools/call is refused; the exit code will be 1");
            self.fault = Some(e.clone());
        }
        r
    }
    fn receipt_at_head(&mut self, tool: &str, v: Verdict) -> Result<(), String> {
        let (e, h) = self.head;
        self.receipt(e, tool, &h, &h, v)
    }
    /// Answer one filtered call as dropped: a read gets the dropped-read shape, a mutating call the dropped-result
    /// shape (its effect may have happened upstream). Receipt `ReadDropped` at the head.
    fn answer_dropped(&mut self, p: &Pending, reason: &str) {
        let _ = self.receipt_at_head(&p.tool, Verdict::ReadDropped);
        match p.effect {
            None => emit(jsonw::dropped_read(&p.id, reason).as_bytes()),
            Some(epoch) => emit(jsonw::dropped_result(&p.id, reason, epoch).as_bytes()),
        }
    }
    /// Answer every pending filtered call as dropped and tombstone its id.
    fn drop_all_pending(&mut self, reason: &str) {
        for p in std::mem::take(&mut self.pending) {
            self.inflight.remove(&p.key);
            self.tombs.insert(p.key.clone(), ());
            self.answer_dropped(&p, reason);
        }
    }
}

struct Proxy {
    sh: Arc<Shared>,
    ledger: Ledger,
    up: Option<ChildStdin>,
}

/// Run the airlock until the client closes stdin. Returns the process exit code.
pub fn run(policy: Policy, ledger: Ledger, evidence: Evidence, server: &[String]) -> i32 {
    let head = ledger.head();
    let mut child = match Command::new(&server[0]).args(&server[1..]).stdin(Stdio::piped()).stdout(Stdio::piped()).stderr(Stdio::inherit()).spawn() {
        Ok(c) => c,
        Err(e) => {
            eprintln!("mcp-proxy: cannot start the upstream server {:?}: {e}", server[0]);
            if let Err(e) = evidence.finish() {
                eprintln!("mcp-proxy: evidence finish: {e}");
            }
            return 1;
        }
    };
    let up_in = child.stdin.take().expect("piped stdin");
    let up_out = child.stdout.take().expect("piped stdout");
    let sh = Arc::new(Shared {
        core: Mutex::new(Core {
            ev: Some(evidence),
            head,
            pending: Vec::new(),
            inflight: HashMap::new(),
            tombs: HashMap::new(),
            upstream_dead: false,
            fault: None,
        }),
        policy,
    });
    let sh2 = Arc::clone(&sh);
    let reader = std::thread::Builder::new().name("upstream".into()).stack_size(READER_STACK).spawn(move || upstream_loop(&sh2, up_out));
    let reader = match reader {
        Ok(r) => r,
        Err(e) => {
            eprintln!("mcp-proxy: cannot start the upstream reader: {e}");
            let _ = child.kill();
            let _ = child.wait();
            return 1;
        }
    };

    let mut px = Proxy { sh, ledger, up: Some(up_in) };
    let stdin = io::stdin();
    frame(stdin.lock(), CLIENT_CAP, |ev| match ev {
        Some(line) => px.client_line(line),
        None => px.frame_error(-32700, "Parse error", "LINE_TOO_LONG"),
    });

    // End of client input: close the upstream stdin, let the upstream output drain, wait for the server.
    drop(px.up.take());
    let reader_panicked = reader.join().is_err();
    if reader_panicked {
        eprintln!("mcp-proxy: the upstream reader stopped with a panic; exit 1");
    }
    let code = match child.wait() {
        Ok(st) => {
            use std::os::unix::process::ExitStatusExt;
            st.code().unwrap_or_else(|| 128 + st.signal().unwrap_or(0))
        }
        Err(e) => {
            eprintln!("mcp-proxy: wait for the upstream server: {e}");
            1
        }
    };
    let (ev, fault) = {
        let mut c = lock(&px.sh.core);
        (c.ev.take(), c.fault.clone())
    };
    let mut failed = reader_panicked;
    if let Some(ev) = ev {
        if let Err(e) = ev.finish() {
            eprintln!("mcp-proxy: evidence finish failed: {e}; exit 1");
            failed = true;
        }
    }
    if let Some(f) = fault {
        eprintln!("mcp-proxy: exit 1: a receipt was not written in this run ({f})");
        failed = true;
    }
    // A receipt fault or a reader panic gives exit 1 whatever the upstream exit code was (R4, B6, D3).
    if failed {
        1
    } else {
        code
    }
}

impl Proxy {
    /// Write the line (plus newline) to the upstream stdin. False when the upstream is gone.
    fn forward(&mut self, line: &mut Vec<u8>) -> bool {
        let Some(up) = self.up.as_mut() else { return false };
        line.push(b'\n'); // capacity is cap + 1: no reallocation
        let ok = up.write_all(line).is_ok();
        line.pop();
        if !ok {
            self.up = None;
        }
        ok
    }

    /// A line that is not a usable JSON-RPC message: JSON-RPC error with `"id": null`, receipt BlockedMalformed,
    /// nothing forwarded.
    fn frame_error(&mut self, code: i32, message: &str, detail: &str) {
        self.frame_error_id("null", code, message, detail)
    }

    /// As `frame_error`, with the request id echoed when the line had a usable one (`"null"` otherwise).
    fn frame_error_id(&mut self, id: &str, code: i32, message: &str, detail: &str) {
        let mut c = lock(&self.sh.core);
        let mut detail = detail.to_string();
        if c.receipt_at_head(NO_TOOL, Verdict::BlockedMalformed).is_err() {
            detail.push_str("; receipt not written (EVIDENCE_FAULT)");
        }
        let (e, h) = c.head;
        emit(jsonw::error(id, code, message, "BLOCKED_MALFORMED", &detail, e, &hash::hex(&h)).as_bytes());
    }

    /// Refuse a request that has an id: -32001 Airlock Invariant Breach. With `receipt`, one receipt at the head.
    fn refuse(&mut self, id: &str, tool: &str, receipt: Option<Verdict>, word: &str, detail: &str) {
        let mut c = lock(&self.sh.core);
        let mut detail = detail.to_string();
        if let Some(v) = receipt {
            if c.receipt_at_head(tool, v).is_err() {
                detail.push_str("; receipt not written (EVIDENCE_FAULT)");
            }
        }
        let (e, h) = c.head;
        emit(jsonw::error(id, -32001, "Airlock Invariant Breach", word, &detail, e, &hash::hex(&h)).as_bytes());
    }

    fn client_line(&mut self, line: &mut Vec<u8>) {
        let text = match std::str::from_utf8(line) {
            Ok(t) => t,
            Err(_) => return self.frame_error(-32700, "Parse error", "NOT_UTF8"),
        };
        if text.bytes().all(|b| b == b' ') {
            return; // an empty line (or spaces only) carries no message
        }
        // Raw control bytes (findings R1, R3): a `\r` (also directly before the `\n`), a `\t` or any other byte
        // below 0x20, or 0x7f. A reader that splits lines on `\r` could see other messages than this proxy.
        if has_control(line) {
            return self.frame_error(-32700, "Parse error", "CONTROL_BYTE");
        }
        let v = match json::parse(text) {
            Ok(v) => v,
            Err(e) => return self.frame_error(-32700, "Parse error", e),
        };
        match &v {
            J::Obj(_) => {}
            J::Arr(_) => return self.frame_error(-32600, "Invalid Request", "BATCH_NOT_SUPPORTED"),
            _ => return self.frame_error(-32600, "Invalid Request", "NOT_AN_OBJECT"),
        }
        // A number token longer than 64 bytes anywhere (finding R3: the upstream parser may fail on it after a
        // commit).
        if long_number(&v) {
            return self.frame_error(-32600, "Invalid Request", "NUMBER_TOO_LONG");
        }
        // Every client message must say `"jsonrpc": "2.0"` exactly (finding R3: a server answers another value
        // with `"id": null`, after a commit, and the id slot never comes free).
        if v.get("jsonrpc") != Some(&J::Str("2.0".into())) {
            let idt = v.get("id").filter(|j| client_key(j).is_some()).and_then(jsonw::id_text);
            return self.frame_error_id(idt.as_deref().unwrap_or("null"), -32600, "Invalid Request", "BAD_JSONRPC_VERSION");
        }
        let method = match v.get("method") {
            None => {
                // A response of the client to a server request: forward unchanged.
                if !self.forward(line) {
                    eprintln!("mcp-proxy: a client response was not forwarded: upstream gone");
                }
                return;
            }
            Some(J::Str(m)) => m.as_str(),
            Some(_) => return self.frame_error(-32600, "Invalid Request", "METHOD_NOT_A_STRING"),
        };
        // Request (with id) or notification (no id).
        let id = match v.get("id") {
            None => None,
            Some(j) => match (client_key(j), jsonw::id_text(j)) {
                (Some(k), Some(t)) => Some((k, t)),
                _ => return self.frame_error(-32600, "Invalid Request", "BAD_ID"),
            },
        };
        if method == "forge-airlock/state" {
            if let Some((_, idt)) = id {
                let c = lock(&self.sh.core);
                let (e, h) = c.head;
                emit(jsonw::state_result(&idt, e, &hash::hex(&h)).as_bytes());
            }
            return;
        }
        let Some((key, idt)) = id else {
            if method == "tools/call" {
                return self.frame_error(-32600, "Invalid Request", "TOOLS_CALL_WITHOUT_ID");
            }
            if !self.forward(line) {
                eprintln!("mcp-proxy: a client notification was not forwarded: upstream gone");
            }
            return;
        };
        let tool_for_receipt = if method == "tools/call" {
            match v.get("params").and_then(|p| p.get("name")) {
                Some(J::Str(n)) => n.clone(),
                _ => NO_TOOL.to_string(),
            }
        } else {
            method.to_string()
        };
        {
            let c = lock(&self.sh.core);
            let clash = c.inflight.contains_key(&key) || c.tombs.contains_key(&key);
            let full = c.inflight.len() + c.tombs.len() >= MAX_INFLIGHT;
            let dead = c.upstream_dead;
            let fault = c.fault.is_some();
            drop(c);
            if fault && method == "tools/call" {
                // Sticky receipt fault: no tools/call of any kind passes, and no receipt is attempted.
                return self.refuse(&idt, &tool_for_receipt, None, "EVIDENCE_FAULT", "an earlier receipt was not written; no tools/call is forwarded in this run");
            }
            if clash {
                return self.refuse(&idt, &tool_for_receipt, Some(Verdict::BlockedMalformed), "BLOCKED_MALFORMED", "ID_IN_FLIGHT");
            }
            if full {
                return self.refuse(&idt, &tool_for_receipt, Some(Verdict::BlockedMalformed), "BLOCKED_MALFORMED", "TOO_MANY_IN_FLIGHT");
            }
            if dead || self.up.is_none() {
                // The upstream closed its output: no answer can come back. Nothing is forwarded, no epoch is used.
                return self.refuse(&idt, &tool_for_receipt, None, "UPSTREAM_GONE", "the upstream server is gone; nothing was forwarded");
            }
        }
        if method != "tools/call" {
            return self.forward_request(line, key, idt, None, false);
        }
        self.tools_call(line, &v, key, idt);
    }

    /// Track a request with an id (and, with `filter`, its filtered call) and forward it. With `tools_call`, a
    /// sticky receipt fault seen under the lock refuses it (0 bytes upstream).
    fn forward_request(&mut self, line: &mut Vec<u8>, key: String, idt: String, filter: Option<Pending>, tools_call: bool) {
        let tool = filter.as_ref().map(|p| p.tool.clone()).unwrap_or_else(|| NO_TOOL.to_string());
        {
            let mut c = lock(&self.sh.core);
            if tools_call && c.fault.is_some() {
                drop(c);
                return self.refuse(&idt, &tool, None, "EVIDENCE_FAULT", "an earlier receipt was not written; no tools/call is forwarded in this run");
            }
            c.inflight.insert(key.clone(), InFlight { id: idt.clone(), maybe_discarded: false });
            if let Some(p) = filter {
                c.pending.push(p);
            }
        }
        if !self.forward(line) {
            let mut c = lock(&self.sh.core);
            c.inflight.remove(&key);
            c.pending.retain(|p| p.key != key);
            drop(c);
            self.refuse(&idt, &tool, None, "UPSTREAM_GONE", "the upstream server is gone; nothing was forwarded");
        }
    }

    fn tools_call(&mut self, line: &mut Vec<u8>, v: &J, key: String, idt: String) {
        let malformed = |px: &mut Proxy, tool: &str, d: &str| px.refuse(&idt, tool, Some(Verdict::BlockedMalformed), "BLOCKED_MALFORMED", d);
        let params = match v.get("params") {
            Some(p @ J::Obj(_)) => p,
            _ => return malformed(self, NO_TOOL, "PARAMS_NOT_AN_OBJECT"),
        };
        let tool = match params.get("name") {
            Some(J::Str(n)) => n.as_str(),
            _ => return malformed(self, NO_TOOL, "NAME_NOT_A_STRING"),
        };
        let empty = J::Obj(Vec::new());
        let args = match params.get("arguments") {
            None => &empty,
            Some(a @ J::Obj(_)) => a,
            Some(_) => return malformed(self, tool, "ARGUMENTS_NOT_AN_OBJECT"),
        };
        let kind = match self.sh.policy.kind(tool) {
            Some(k) => k,
            None => return malformed(self, tool, "TOOL_NOT_IN_POLICY"),
        };
        match kind {
            Kind::Passthrough => self.forward_request(line, key, idt, None, true),
            Kind::SensitiveRead => {
                let p = Pending { key: key.clone(), id: idt.clone(), tool: tool.to_string(), effect: None };
                self.forward_request(line, key, idt, Some(p), true)
            }
            Kind::Mutating => self.mutate(line, params, tool, args, key, idt),
        }
    }

    fn mutate(&mut self, line: &mut Vec<u8>, params: &J, tool: &str, args: &J, key: String, idt: String) {
        let malformed = |px: &mut Proxy, d: &str| px.refuse(&idt, tool, Some(Verdict::BlockedMalformed), "BLOCKED_MALFORMED", d);
        let meta = match params.get("_meta") {
            Some(m @ J::Obj(_)) => m,
            _ => return malformed(self, "META_MISSING"),
        };
        let rid = match meta.get("forge-airlock/request_id") {
            Some(J::Str(s)) if valid_request_id(s) => s.as_str(),
            _ => return malformed(self, "BAD_REQUEST_ID"),
        };
        let pre = match meta.get("forge-airlock/pre_state_hash") {
            Some(J::Str(s)) => match hash::unhex16(s) {
                Some(h) => h,
                None => return malformed(self, "BAD_PRE_STATE_HASH"),
            },
            _ => return malformed(self, "BAD_PRE_STATE_HASH"),
        };
        // (1) Policy rules, fact-bound sub-caps and scope binds. Only the fixed `Deny.code` goes to the client; the
        // detail can name a foreign fact or its value (finding B3), so it goes to stderr only.
        if let Err(d) = self.sh.policy.check_mutation(tool, args) {
            let (v, w) = if d.subcap { (Verdict::BlockedSubcap, "BLOCKED_SUBCAP") } else { (Verdict::BlockedPolicy, "BLOCKED_POLICY") };
            eprintln!("mcp-proxy: {w} {tool:?}: {}: {}", d.code, d.detail);
            return self.refuse(&idt, tool, Some(v), w, d.code);
        }
        if self.up.is_none() || lock(&self.sh.core).upstream_dead {
            return self.refuse(&idt, tool, None, "UPSTREAM_GONE", "the upstream server is gone; no epoch consumed");
        }
        let filtered = self.sh.policy.filters_result(tool);
        // (2) Ledger: duplicate check, CAS, record synced to disk. (3) Receipt. Both under the state lock, so the
        // receipt order follows the epoch order.
        let mut c = lock(&self.sh.core);
        if c.fault.is_some() {
            drop(c);
            return self.refuse(&idt, tool, None, "EVIDENCE_FAULT", "an earlier receipt was not written; no tools/call is forwarded in this run; no epoch consumed");
        }
        let res = self.ledger.commit(rid, tool, line, &pre);
        let (epoch, pre, post) = match res {
            Err(e) => {
                eprintln!("mcp-proxy: LEDGER_FAULT: {e}");
                let (he, hh) = c.head;
                emit(jsonw::error(&idt, -32001, "Airlock Invariant Breach", "LEDGER_FAULT", &e, he, &hash::hex(&hh)).as_bytes());
                return;
            }
            Ok(Cas::Mismatch { epoch, current }) => {
                c.head = (epoch, current);
                drop(c);
                let d = format!("pre_state_hash {} is not the head {}", hash::hex(&pre), hash::hex(&current));
                return self.refuse(&idt, tool, Some(Verdict::BlockedCas), "BLOCKED_CAS", &d);
            }
            Ok(Cas::Duplicate { first_epoch, epoch, current }) => {
                c.head = (epoch, current);
                drop(c);
                let d = format!("request_id {rid} was committed at epoch {first_epoch}");
                return self.refuse(&idt, tool, Some(Verdict::BlockedDuplicate), "BLOCKED_DUPLICATE", &d);
            }
            Ok(Cas::Committed { epoch, pre, post }) => (epoch, pre, post),
        };
        c.head = (epoch, post);
        if c.receipt(epoch, tool, &pre, &post, Verdict::Committed).is_err() {
            let d = format!("epoch {epoch} is consumed; the call was NOT forwarded; receipt not written; the next start writes this receipt from ledger.wal");
            emit(jsonw::error(&idt, -32001, "Airlock Invariant Breach", "EVIDENCE_FAULT", &d, epoch, &hash::hex(&post)).as_bytes());
            return;
        }
        c.inflight.insert(key.clone(), InFlight { id: idt.clone(), maybe_discarded: false });
        if filtered {
            c.pending.push(Pending { key: key.clone(), id: idt.clone(), tool: tool.to_string(), effect: Some(epoch) });
        }
        drop(c);
        // (4) Only now forward the original line bytes.
        if !self.forward(line) {
            let mut c = lock(&self.sh.core);
            c.inflight.remove(&key);
            c.pending.retain(|p| p.key != key);
            let d = format!("epoch {epoch} is committed; the forward failed: the upstream server is gone");
            emit(jsonw::error(&idt, -32001, "Airlock Invariant Breach", "COMMITTED_NOT_FORWARDED", &d, epoch, &hash::hex(&post)).as_bytes());
        }
    }
}

/// The upstream stdout reader. Server requests and notifications (a `method`, no `result`/`error`) pass unchanged.
/// A response passes only when its id is in flight; a response to a filtered call passes only after the filter.
fn upstream_loop<R: Read>(sh: &Shared, out: R) {
    frame(out, UPSTREAM_CAP, |ev| match ev {
        Some(line) => upstream_line(sh, line),
        None => bad_upstream_line(sh, "UPSTREAM_LINE_TOO_LONG"),
    });
    let mut c = lock(&sh.core);
    c.upstream_dead = true;
    c.drop_all_pending("UPSTREAM_EOF");
    // Every other request in flight gets an answer, so the client does not wait for ever. The text says whether an
    // upstream line was discarded while the request was in flight (finding R7: that line may have been its answer).
    let (e, h) = c.head;
    let mut gone: Vec<InFlight> = c.inflight.drain().map(|(_, f)| f).collect();
    gone.sort_by(|a, b| a.id.cmp(&b.id));
    for f in gone {
        let (word, detail) = if f.maybe_discarded {
            (
                "UPSTREAM_LINE_DISCARDED",
                "an upstream line was discarded (over the 1 MiB cap or not valid) while this request was in flight; it may have been the response; no response was passed; the upstream output then closed",
            )
        } else {
            ("UPSTREAM_GONE", "the upstream server closed its output with no response to this request")
        };
        emit(jsonw::error(&f.id, -32001, "Airlock Invariant Breach", word, detail, e, &hash::hex(&h)).as_bytes());
    }
}

/// An upstream line that cannot be attributed: it is discarded (0 bytes to the client). Every pending filtered call
/// is answered as dropped, because the discarded line may have been its response. Every other request in flight is
/// marked: at the end of the upstream output it is answered with `UPSTREAM_LINE_DISCARDED`.
fn bad_upstream_line(sh: &Shared, reason: &str) {
    eprintln!("mcp-proxy: upstream line discarded: {reason}");
    let mut c = lock(&sh.core);
    c.drop_all_pending(reason);
    for f in c.inflight.values_mut() {
        f.maybe_discarded = true;
    }
}

fn upstream_line(sh: &Shared, line: &mut Vec<u8>) {
    if line.iter().all(|&b| b == b' ') {
        return;
    }
    // A raw control byte (for example `\r`): the client may split the line in another place (finding D1).
    if has_control(line) {
        return bad_upstream_line(sh, "UPSTREAM_CONTROL_BYTE");
    }
    let v = match std::str::from_utf8(line).ok().and_then(|t| json::parse(t).ok()) {
        Some(v @ J::Obj(_)) => v,
        _ => return bad_upstream_line(sh, "UPSTREAM_LINE_NOT_A_JSON_OBJECT"),
    };
    let has_method = v.get("method").is_some();
    let is_response = v.get("result").is_some() || v.get("error").is_some();
    if has_method && is_response {
        // Both a request and a response: no reader agrees on what it is (finding D1). Discard only this line. A
        // pending call stays pending: its real response is still filtered, and the end of the upstream output
        // drops it if no response comes.
        eprintln!("mcp-proxy: upstream line discarded: UPSTREAM_METHOD_AND_RESPONSE");
        return;
    }
    if has_method {
        // Server request or notification: NOT filtered (stated limit, PROTOCOL.md section 8).
        return emit(line);
    }
    let key = v.get("id").and_then(upstream_key);
    let mut c = lock(&sh.core);
    let Some(key) = key else {
        let pending = !c.pending.is_empty();
        drop(c);
        if pending {
            return bad_upstream_line(sh, "UPSTREAM_RESPONSE_WITHOUT_USABLE_ID");
        }
        eprintln!("mcp-proxy: upstream response without a usable id discarded");
        return;
    };
    if c.tombs.remove(&key).is_some() {
        eprintln!("mcp-proxy: late upstream response to a dropped call discarded");
        return;
    }
    // A response passes only once and only for an id that this proxy forwarded (finding T1; the smuggled-answer
    // half of R1).
    if c.inflight.remove(&key).is_none() {
        eprintln!("mcp-proxy: upstream response with an id that is not in flight discarded");
        return;
    }
    let Some(i) = c.pending.iter().position(|p| p.key == key) else {
        drop(c);
        return emit(line);
    };
    let p = c.pending.remove(i);
    let verdict: Result<(), &str> = if !exact_result_shape(&v) {
        Err(if v.get("result").is_none() { "NO_RESULT" } else { "RESPONSE_SHAPE" })
    } else {
        match v.get("result") {
            Some(r) => sh.policy.check_read_result(&p.tool, r).map_err(|d| {
                eprintln!("mcp-proxy: result of {:?} dropped: {}: {}", p.tool, d.code, d.detail);
                d.code
            }),
            None => Err("NO_RESULT"),
        }
    };
    match verdict {
        Ok(()) if p.effect.is_some() => emit(line), // the Committed receipt of this call already exists
        Ok(()) => match c.receipt_at_head(&p.tool, Verdict::ReadAllowed) {
            Ok(()) => emit(line),
            Err(_) => emit(jsonw::dropped_read(&p.id, "EVIDENCE_FAULT").as_bytes()),
        },
        Err(code) => c.answer_dropped(&p, code),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn newline_search() {
        for n in 0..40 {
            let mut v = vec![b'x'; n];
            assert_eq!(find_nl(&v), None);
            for p in 0..n {
                v[p] = b'\n';
                assert_eq!(find_nl(&v), Some(p));
                v[p] = b'x';
            }
        }
        assert_eq!(find_nl(&[0x8a, 0x0a]), Some(1));
        assert_eq!(find_nl(&[0x0b, 0x09, 0x8a, 0x8b, 0, 0, 0, 0, 0x0a]), Some(8));
    }

    #[test]
    fn framing_caps_and_discard() {
        let mut input = b"{\"a\":1}\n".to_vec();
        input.extend(std::iter::repeat(b'z').take(200_000));
        input.extend_from_slice(b"\nok\nexact");
        let mut lines = Vec::new();
        let mut overs = 0;
        frame(&input[..], 10, |e| match e {
            Some(l) => lines.push(l.clone()),
            None => overs += 1,
        });
        assert_eq!(lines, vec![b"{\"a\":1}".to_vec(), b"ok".to_vec(), b"exact".to_vec()]);
        assert_eq!(overs, 1);
        let mut overs = 0;
        frame(&b"0123456789\n01234567890"[..], 10, |e| match e {
            Some(l) => assert_eq!(l.len(), 10),
            None => overs += 1,
        });
        assert_eq!(overs, 1, "a last line over the cap without newline is refused");
    }

    #[test]
    fn ids() {
        for t in ["0", "7", "-7", "123456789012345"] {
            assert!(canonical_int(t), "{t}");
        }
        for t in ["-0", "07", "1.0", "1e2", "1234567890123456", "", "-"] {
            assert!(!canonical_int(t), "{t}");
        }
        for (t, w) in [("5", Some("5")), ("5.0", Some("5")), ("5e0", Some("5")), ("500e-2", Some("5")), ("0.5e1", Some("5")), ("-0", Some("0")), ("0.0e5", Some("0")), ("5.5", None), ("-12.000", Some("-12")), ("1e2", Some("100")), ("1e999", None)] {
            assert_eq!(int_value_text(t).as_deref(), w, "{t}");
        }
        assert!(valid_request_id("pay-1:a.b_c"));
        assert!(!valid_request_id(""));
        assert!(!valid_request_id("a b"));
        assert!(!valid_request_id(&"a".repeat(129)));
        assert!(valid_request_id(&"a".repeat(128)));
    }

    #[test]
    fn line_rules() {
        assert!(has_control(b"{\"a\":1}\r"));
        assert!(has_control(b"{\"a\":\t1}"));
        assert!(has_control(b"{\"a\":1}\x7f"));
        assert!(!has_control("{\"a\":\"\u{2028}é\"} ".as_bytes()));
        let n64 = format!("{{\"a\":[1,{{\"b\":{}}}]}}", "9".repeat(64));
        let n65 = format!("{{\"a\":[1,{{\"b\":{}}}]}}", "9".repeat(65));
        assert!(!long_number(&json::parse(&n64).unwrap()));
        assert!(long_number(&json::parse(&n65).unwrap()));
        for (t, ok) in [
            (r#"{"jsonrpc":"2.0","id":1,"result":{}}"#, true),
            (r#"{"id":1,"result":{},"jsonrpc":"2.0"}"#, true),
            (r#"{"jsonrpc":"2.0","id":1,"result":{},"leak":{}}"#, false),
            (r#"{"jsonrpc":"1.0","id":1,"result":{}}"#, false),
            (r#"{"jsonrpc":"2.0","id":1,"error":{}}"#, false),
            (r#"{"jsonrpc":"2.0","result":{},"method":"x"}"#, false),
        ] {
            assert_eq!(exact_result_shape(&json::parse(t).unwrap()), ok, "{t}");
        }
    }
}
