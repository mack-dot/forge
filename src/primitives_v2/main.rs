#![forbid(unsafe_code)]
#![allow(unexpected_cfgs)] // `test_seams` is the one custom cfg: the test build lives ONLY in build/primitives_v2_test/
//! forge primitives engine, v2 (the "universal primitives pack" foundation and primitive 6). NATIVE CHECK: Rust,
//! standard library only, no crate, no `unsafe`. NOT PROVED. FINITE TESTS in tests/primitives_v2/.
//! One store folder, one write-ahead log (SHA-256 chain, CRC-32 per header and per record), an exclusive flock per
//! exchange, `sync_all` before COMMITTED, strict replay. The engine owns the clock (clock.rs). Primitives are pure
//! modules behind prim.rs: rate.rs (primitive 6), and the stubs ledger_graph.rs (7), taint.rs (8), farkas.rs (9).
//! Reused read-only from the Goal 20 engine (never edited): src/airlock/json.rs (strict JSON) and src/airlock/pin.rs
//! (SHA-256). Trust boundary: every rule holds only for a caller that reaches the store THROUGH this production
//! binary; whoever can write the store folder or run another build on it is trusted (PROTOCOL.md section 9).
//! Build:      rustc --edition 2021 -D unsafe_code -C opt-level=3 src/primitives_v2/main.rs -o build/primitives_v2/primitives-engine
//! Test build: rustc --edition 2021 -D unsafe_code -C opt-level=3 --cfg test_seams src/primitives_v2/main.rs -o build/primitives_v2_test/primitives-engine-seams
#[path = "../airlock/json.rs"]
#[allow(dead_code)]
mod json;
#[path = "../airlock/pin.rs"]
#[allow(dead_code)]
mod pin;

mod clock;
mod cosign_ttl;
mod engine;
mod farkas;
mod ledger_graph;
mod prim;
#[cfg(test_seams)]
mod probe;
mod rate;
mod store;
mod taint;

use engine::{clean, Wire};
use prim::{refusal, wire_value, Refusal};
use std::io::{self, BufRead, BufReader, Read, Write};

pub const MAX_LINE: usize = 65536;

impl From<io::Error> for Refusal {
    fn from(e: io::Error) -> Self {
        refusal("IO_ERROR", vec![("why", format!("{:?}", e.kind()))], format!("{e}"))
    }
}

/// The exit code of an answer word (PROTOCOL.md section 6). A module word that is not listed is a policy refusal (10).
pub fn exit_of(code: &str) -> i32 {
    match code {
        "COMMITTED" | "OK" | "STATE" | "REPLAY" | "INITIALIZED" | "TTL_OPEN" => 0,
        "USAGE" => 2,
        "MALFORMED_REQUEST" => 12,
        "STALE_STATE_HASH" => 13,
        "DUPLICATE_REQUEST_ID" => 14,
        "TENANT_ISOLATION_BREACH" => 16,
        "CORRUPT_WAL" => 17,
        "IO_ERROR" => 18,
        "OUTCOME_UNKNOWN" => 19,
        "DISPATCH_FAILED" => 20,
        "MALFORMED_POLICY" => 25,
        "STORE_BUSY" => 26,
        "NOT_IMPLEMENTED" => 27,
        "UNSAFE_STORE" => 28,
        "MODULE_FAULT" => 29,
        _ => 10,
    }
}
/// A fault of the store, the system or the answer: `serve` reads no further line after it.
pub fn is_fault(code: i32) -> bool {
    [17, 18, 19, 20, 28].contains(&code)
}

/// Prints one answer line. A refusal: `<CODE> <name>=<value>... [-- <detail>]`, values percent-encoded.
fn answer(result: Result<String, Wire>) -> i32 {
    let (code, text) = match result {
        Ok(text) => (0, text + "\n"),
        Err(w) => {
            let mut t = w.code.to_string();
            for (k, v) in &w.fields {
                t.push_str(&format!(" {k}={}", wire_value(v)));
            }
            if !w.detail.is_empty() { t.push_str(&format!(" -- {}", clean(&w.detail))) }
            (exit_of(w.code), t + "\n")
        }
    };
    let mut out = io::stdout().lock();
    if out.write_all(text.as_bytes()).and_then(|()| out.flush()).is_ok() { code } else { 20 }
}

pub enum Line {
    Whole(Vec<u8>),
    Oversized,
    NoEnd,
}
/// Reads one LF-terminated line of at most MAX_LINE bytes (the LF not counted). A longer line is skipped to its LF
/// with constant memory (the BufReader's buffer). None at EOF.
pub fn read_line(input: &mut impl BufRead) -> io::Result<Option<Line>> {
    let mut line = Vec::new();
    let n = input.by_ref().take(MAX_LINE as u64 + 1).read_until(b'\n', &mut line)?;
    if n == 0 { return Ok(None) }
    if line.last() == Some(&b'\n') {
        line.pop();
        return Ok(Some(Line::Whole(line)));
    }
    if line.len() > MAX_LINE {
        drop(line);
        input.skip_until(b'\n')?;
        return Ok(Some(Line::Oversized));
    }
    Ok(Some(Line::NoEnd))
}

fn serve(dir: &str) -> i32 {
    let mut ctx = engine::Ctx { dir: dir.to_string(), clock: clock::Clock::new() };
    let mut input = BufReader::with_capacity(1 << 16, io::stdin());
    let mut code = 2;
    loop {
        let line = match read_line(&mut input) {
            Err(_) => return 18,
            Ok(None) => return code,
            Ok(Some(l)) => l,
        };
        let result = match line {
            Line::Whole(b) => engine::handle(&mut ctx, &b),
            Line::Oversized => Err(refusal("MALFORMED_REQUEST", vec![("why", "OVERSIZED".into()), ("max_line", MAX_LINE.to_string())], "the line was skipped").into()),
            Line::NoEnd => Err(refusal("MALFORMED_REQUEST", vec![("why", "NO_LINE_END".into())], "").into()),
        };
        code = answer(result);
        if is_fault(code) { return code }
    }
}

fn replay(dir: &str) -> Result<String, Wire> {
    let s = store::open(dir)?;
    let mut lines = String::new();
    let mut n = 0u64;
    store::records(&s, dir, &mut |seq, now, wall, p| {
        n += 1;
        lines.push_str(&format!("\nRECORD {seq} {now} {wall} {p}"));
    })?;
    Ok(format!("REPLAY records={n}{lines}"))
}

fn cosign_message(dir: &str, rid: &str, pre: &str, not_after: &str, action: &str) -> Result<String, Wire> {
    let not_after = cosign_ttl::parse_ms(not_after).ok_or_else(|| refusal("USAGE", vec![("why", "NOT_AFTER_MS".into())], ""))?;
    let s = store::open(dir)?;
    Ok(cosign_ttl::message(&s.f.store_id, &store::hx(&s.f.genesis_hash), rid, pre, not_after, action)?)
}
fn cosign_ttl_cmd(dir: &str, not_after: &str, max_ttl: &str) -> Result<String, Wire> {
    let (Some(not_after), Some(max_ttl)) = (cosign_ttl::parse_ms(not_after), cosign_ttl::parse_ms(max_ttl)) else {
        return Err(refusal("USAGE", vec![("why", "MS".into())], "cosign-ttl <dir> <not_after_ms> <max_ttl_ms>").into());
    };
    let s = store::open(dir)?;
    let now = clock::Clock::new().read(s.f.last_ms)?;
    let left = cosign_ttl::ttl_check(not_after, max_ttl, &now).map_err(|r| {
        let mut w = Wire::from(r);
        w.fields.push(("now_ms".into(), now.now_ms.to_string()));
        w.fields.push(("skew_ms".into(), now.skew_ms.to_string()));
        w
    })?;
    Ok(format!("TTL_OPEN left_ms={left} now_ms={} skew_ms={} signature=NOT_CHECKED", now.now_ms, now.skew_ms))
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let a: Vec<&str> = args.iter().map(String::as_str).collect();
    let usage = || {
        eprintln!("usage: primitives-engine init <dir> [--store-id ID] [--policy FILE]...");
        eprintln!("       primitives-engine serve|state|replay <dir> | get <dir> <tenant> <key>");
        eprintln!("       primitives-engine cosign-message <dir> <request_id> <pre_state_hash|*> <not_after_ms> <action>");
        eprintln!("       primitives-engine cosign-ttl <dir> <not_after_ms> <max_ttl_ms>");
        2
    };
    let code = match a.get(1..).unwrap_or(&[]) {
        ["init", dir, rest @ ..] => {
            let (mut id, mut policies, mut ok, mut i) = (None, Vec::new(), true, 0);
            while i < rest.len() {
                match (rest[i], rest.get(i + 1)) {
                    ("--store-id", Some(v)) if id.is_none() => id = Some(v.to_string()),
                    ("--policy", Some(v)) => policies.push(v.to_string()),
                    _ => ok = false,
                }
                i += 2;
            }
            if !ok { usage() } else {
                let mut clock = clock::Clock::new();
                let id = id.unwrap_or_else(|| "store".to_string());
                answer(store::init(dir, &id, &policies, &mut clock).map_err(Wire::from))
            }
        }
        ["serve", dir] => serve(dir),
        ["state", dir] => {
            let mut ctx = engine::Ctx { dir: dir.to_string(), clock: clock::Clock::new() };
            answer(engine::state(&mut ctx, true).map_err(Wire::from))
        }
        ["get", dir, tenant, key] => {
            let mut ctx = engine::Ctx { dir: dir.to_string(), clock: clock::Clock::new() };
            answer(engine::get(&mut ctx, tenant, key).map_err(Wire::from))
        }
        ["replay", dir] => answer(replay(dir)),
        ["cosign-message", dir, rid, pre, not_after, action] => match cosign_message(dir, rid, pre, not_after, action) {
            Ok(m) => {
                let mut out = io::stdout().lock();
                if out.write_all(m.as_bytes()).and_then(|()| out.flush()).is_ok() { 0 } else { 20 }
            }
            Err(w) => answer(Err(w)),
        },
        ["cosign-ttl", dir, not_after, max_ttl] => answer(cosign_ttl_cmd(dir, not_after, max_ttl)),
        _ => usage(),
    };
    std::process::exit(code);
}
