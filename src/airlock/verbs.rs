//! The request verbs of `serve`. NATIVE CHECK, not proved. Grammar and answers: src/airlock/PROTOCOL.md.
//! Every write: parse (no file opened) -> store::open (flock, fold, ratchet, recovery) -> tenant -> request id ->
//! compare-and-swap -> policy -> append (sync, ratchet, sync) -> lock released -> one answer line.
use crate::helpers::{self, Node};
use crate::json::{self, J};
use crate::ledger::{parse_csv, Body, Key, MAX_FACTS, MAX_ROWS};
use crate::policy::{self, Verdict, REASONS};
use crate::store::{self, canonical_id, hx, money, parse_hash, Store};
use crate::{no, Code, Line, Refusal};
use std::collections::BTreeMap;
use std::io;

pub const MAX_READ_ROWS: usize = 100_000;

pub struct Ctx {
    pub dir: String,
    pub binary: Option<String>,
    pub node: Option<String>,
    pub helpers: Option<String>,
    pub checker: Option<String>,
}
impl Ctx {
    fn node(&self) -> Node<'_> {
        Node { node: self.node.as_deref(), helpers: self.helpers.as_deref(), checker: self.checker.as_deref() }
    }
}
fn toks(line: &str, min: usize, max: usize) -> Result<Vec<&str>, Refusal> {
    let t: Vec<&str> = line.split(' ').collect();
    if t.len() < min || t.len() > max || t.iter().any(|x| x.is_empty()) { return no(Code::Malformed, "FIELDS wrong number of fields or an empty field") }
    Ok(t)
}
fn id<'a>(s: &'a str, what: &str) -> Result<&'a str, Refusal> {
    if canonical_id(s) { Ok(s) } else { no(Code::Malformed, format!("BAD_ID {what}")) }
}
fn amount(s: &str, what: &str) -> Result<u64, Refusal> {
    money(s).map_or_else(|| no(Code::Malformed, format!("BAD_AMOUNT {what}")), Ok)
}
fn hash(s: &str) -> Result<u128, Refusal> {
    parse_hash(s).map_or_else(|| no(Code::Malformed, "BAD_HASH pre_state_hash"), Ok)
}
fn sig_hex(s: &str) -> bool {
    s.len() == 128 && s.bytes().all(|b| b.is_ascii_digit() || (b'a'..=b'f').contains(&b))
}

pub fn handle(ctx: &Ctx, raw: &[u8]) -> Result<String, Refusal> {
    if !raw.iter().all(|b| (0x20..0x7f).contains(b)) { return no(Code::Malformed, "NON_ASCII a request line is printable ASCII only") }
    let line = std::str::from_utf8(raw).expect("ASCII");
    match line.split(' ').next().unwrap_or("") {
        "OPEN_MONEY" => open_money(ctx, line),
        "REFUND" => refund(ctx, line),
        "OPEN_SAGA" => open_saga(ctx, line),
        "SAGA" => saga(ctx, line),
        "OPEN_INVENTORY" => open_inventory(ctx, line),
        "BOOK" => book(ctx, line),
        "OPEN_LEASE" => open_lease(ctx, line),
        "GET" => {
            let t = toks(line, 3, 3)?;
            get(&ctx.dir, id(t[1], "tenant")?, id(t[2], "key")?)
        }
        "STATE" => {
            toks(line, 1, 1)?;
            state(&ctx.dir)
        }
        _ => no(Code::Malformed, "UNKNOWN_VERB"),
    }
}

/// Tenant isolation, then the request id, then compare-and-swap. In this order.
fn check_key<'a>(s: &'a Store, tenant: &str, key: &str, req: &str, pre: u128) -> Result<&'a Key, Refusal> {
    let Some(k) = s.l.keys.get(key) else { return no(Code::UnknownKey, "UNKNOWN_KEY") };
    if k.tenant != tenant { return no(Code::Breach, "KEY_OF_ANOTHER_TENANT") }
    if s.l.ids.contains(req) { return no(Code::Duplicate, "DUPLICATE_REQUEST_ID") }
    if k.hash != pre { return no(Code::Stale, hx(k.hash)) }
    Ok(k)
}
/// An open names no pre_state_hash: the key must be absent. A key that exists is STALE_STATE_HASH (same tenant)
/// or TENANT_ISOLATION_BREACH (another tenant).
fn check_open<'a>(s: &'a Store, tenant: &str, key: &str, req: &str, policy: &str, kind: &str) -> Result<&'a policy::Policy, Refusal> {
    if let Some(k) = s.l.keys.get(key) {
        if k.tenant != tenant { return no(Code::Breach, "KEY_OF_ANOTHER_TENANT") }
    }
    if s.l.ids.contains(req) { return no(Code::Duplicate, "DUPLICATE_REQUEST_ID") }
    if let Some(k) = s.l.keys.get(key) { return no(Code::Stale, hx(k.hash)) }
    match s.policies.get(policy) {
        Some(p) if p.kind() == kind => Ok(p),
        Some(_) => no(Code::Malformed, "POLICY_KIND the policy is of another airlock"),
        None => no(Code::Malformed, "UNKNOWN_POLICY"),
    }
}
fn commit(s: Store, req: &str, payload: String) -> Result<String, Refusal> {
    let (epoch, h) = s.append(&payload)?;
    Ok(format!("COMMITTED {req} {epoch} {} {payload}", hx(h)))
}
/// A terminal refusal (REJECTED_POLICY or REQUIRE_HUMAN_COSIGN). If a lease is open for the request id, a durable
/// CLOSE record is written (synced) before the answer.
fn verdict(s: Store, req: &str, code: Code, detail: &'static str) -> Result<String, Refusal> {
    if s.l.leases.contains_key(req) {
        let (epoch, _) = s.append(&format!("CLOSE {req} {} {detail}", code.name()))?;
        return no(code, format!("{detail} LEASE_CLOSED {epoch}"));
    }
    no(code, detail)
}

fn open_money(ctx: &Ctx, line: &str) -> Result<String, Refusal> {
    let t = toks(line, 6, 6 + MAX_FACTS)?;
    let (tenant, key, req, pol) = (id(t[1], "tenant")?, id(t[2], "key")?, id(t[3], "request_id")?, id(t[4], "policy")?);
    let original = amount(t[5], "original")?;
    let mut facts = BTreeMap::new();
    for f in &t[6..] {
        let Some((n, v)) = f.split_once('=') else { return no(Code::Malformed, "BAD_FACT") };
        if facts.insert(id(n, "fact")?.to_string(), amount(v, "fact")?).is_some() { return no(Code::Malformed, "DUPLICATE_FACT") }
    }
    let s = store::open(&ctx.dir)?;
    let p = check_open(&s, tenant, key, req, pol, "money")?;
    if let policy::Body::Money(m) = &p.body {
        if m.canonical && !facts.is_empty() { return no(Code::Malformed, "FACTS_NOT_ALLOWED in the canonical-refund profile") }
    }
    let facts: String = facts.iter().map(|(n, v)| format!(" {n}={v}")).collect();
    commit(s, req, format!("OPEN_MONEY {tenant} {key} {req} {pol} {original}{facts}"))
}

/// The canonical cosign message (DESIGN.md). No field can hold a line end.
pub fn cosign_message(store_id: &str, req: &str, pre: &str, action: &str) -> String {
    format!("forge-airlock-cosign-v1\n{store_id}\n{req}\n{pre}\n{action}\n")
}
/// Parses `REFUND <tenant> <key> <request_id> <pre_state_hash> <reason> <amount> [<signature>]`.
fn parse_refund(line: &str) -> Result<(Vec<&str>, Option<&str>), Refusal> {
    let t = toks(line, 7, 8)?;
    if t[0] != "REFUND" { return no(Code::Malformed, "UNKNOWN_VERB") }
    for (i, what) in [(1, "tenant"), (2, "key"), (3, "request_id"), (5, "reason")] {
        id(t[i], what)?;
    }
    hash(t[4])?;
    amount(t[6], "amount")?;
    let sig = t.get(7).copied();
    if sig.map_or(false, |x| !sig_hex(x)) { return no(Code::Malformed, "BAD_SIGNATURE a signature is 128 lowercase hex digits") }
    Ok((t, sig))
}
/// `cosign-message <dir> <action>`: the bytes the human signs. The action is a REFUND line without a signature.
pub fn cosign_message_cmd(dir: &str, action: &str) -> Result<String, Refusal> {
    let (t, sig) = parse_refund(action)?;
    if sig.is_some() { return no(Code::Malformed, "ACTION_HAS_SIGNATURE") }
    let s = store::open(dir)?;
    Ok(cosign_message(&s.l.store_id, t[3], t[4], action))
}
fn refund(ctx: &Ctx, line: &str) -> Result<String, Refusal> {
    let (t, sig) = parse_refund(line)?;
    let (tenant, key, req, pre, reason) = (t[1], t[2], t[3], hash(t[4])?, t[5]);
    let amount = money(t[6]).expect("checked");
    let action = t[..7].join(" ");
    let s = store::open(&ctx.dir)?;
    let k = check_key(&s, tenant, key, req, pre)?;
    let Body::Money { policy: pol, original, remaining, facts, totals } = &k.body else { return no(Code::Malformed, "KEY_KIND not a money key") };
    let (original, remaining, total) = (*original, *remaining, totals.get(reason).copied().unwrap_or(0));
    let Some(policy::Body::Money(m)) = s.policies.get(pol).map(|p| &p.body) else { return no(Code::CorruptWal, "CORRUPT_WAL POLICY_MISSING") };
    let mut cosigned = 0;
    if m.canonical {
        // PROVED CORE for the decision: the CakeML binary. The three flags are set by the engine, not by the
        // caller: enabled = the key was opened under this profile; opened = the request id is fresh (checked
        // above); candidate = the request passed the grammar. The engine refuses amount 0 natively first.
        if amount == 0 { return verdict(s, req, Code::RejectedPolicy, "ZERO_AMOUNT") }
        let wire = format!("({key} {req} {original} {remaining} True True True {amount} {reason})");
        let expect = format!("(refund-result-v1 True {amount} {reason} {key} {req} 1)");
        if !helpers::refund_binary(ctx.binary.as_deref(), &wire, &expect)? { return verdict(s, req, Code::RejectedPolicy, "CAKEML_REJECTED") }
        if amount > remaining || !REASONS.contains(&reason) { return no(Code::BadFrame, "BAD_FRAME the binary accepted what the native check refuses") }
    } else {
        let fact = |n: &str| facts.get(n).copied();
        match policy::eval_money(m, reason, amount, remaining, total, &fact) {
            Verdict::Commit => {}
            Verdict::Reject(code) => return verdict(s, req, Code::RejectedPolicy, code),
            Verdict::Cosign => {
                let Some(sig) = sig else { return verdict(s, req, Code::RequireHumanCosign, "COSIGN_REQUIRED") };
                let Some(pk) = s.l.pubkey.clone() else { return verdict(s, req, Code::RequireHumanCosign, "NO_COSIGN_KEY") };
                let msg = cosign_message(&s.l.store_id, req, t[4], &action);
                if !helpers::cosign_verify(&ctx.node(), &pk, sig, &msg)? { return verdict(s, req, Code::RequireHumanCosign, "COSIGN_INVALID") }
                cosigned = 1;
            }
        }
    }
    commit(s, req, format!("REFUND {tenant} {key} {req} {reason} {amount} {cosigned}"))
}

fn open_saga(ctx: &Ctx, line: &str) -> Result<String, Refusal> {
    let t = toks(line, 5, 5)?;
    let (tenant, key, req, pol) = (id(t[1], "tenant")?, id(t[2], "key")?, id(t[3], "request_id")?, id(t[4], "policy")?);
    let s = store::open(&ctx.dir)?;
    let policy::Body::Saga(sp) = &check_open(&s, tenant, key, req, pol, "saga")?.body else { unreachable!("kind checked") };
    let initial = sp.initial.clone();
    commit(s, req, format!("OPEN_SAGA {tenant} {key} {req} {pol} {initial}"))
}
fn saga(ctx: &Ctx, line: &str) -> Result<String, Refusal> {
    let t = toks(line, 6, 8)?;
    if t.len() == 7 { return no(Code::Malformed, "PAIR a processor needs an idempotency key") }
    let (tenant, key, req, pre, to) = (id(t[1], "tenant")?, id(t[2], "key")?, id(t[3], "request_id")?, hash(t[4])?, id(t[5], "state")?);
    let pair = if t.len() == 8 { Some((id(t[6], "processor")?.to_string(), id(t[7], "idempotency_key")?.to_string())) } else { None };
    let s = store::open(&ctx.dir)?;
    let k = check_key(&s, tenant, key, req, pre)?;
    let Body::Saga { policy: pol, state: cur, pair: held } = &k.body else { return no(Code::Malformed, "KEY_KIND not a saga key") };
    let Some(policy::Body::Saga(sp)) = s.policies.get(pol).map(|p| &p.body) else { return no(Code::CorruptWal, "CORRUPT_WAL POLICY_MISSING") };
    let (cur_in, to_in) = (sp.in_flight.contains(cur), sp.in_flight.contains(&to.to_string()));
    let decision = if !sp.states.iter().any(|x| x == to) {
        Some("UNKNOWN_STATE")
    } else if cur_in && pair != *held {
        Some("PROCESSOR_IN_FLIGHT") // another processor or idempotency key while the key is in flight
    } else if !sp.transitions.iter().any(|(a, b)| a == cur && b == to) {
        Some("NO_TRANSITION")
    } else if to_in && pair.is_none() {
        Some("PAIR_REQUIRED")
    } else if !to_in && !cur_in && pair.is_some() {
        Some("PAIR_NOT_ALLOWED")
    } else {
        None
    };
    if let Some(code) = decision { return verdict(s, req, Code::RejectedPolicy, code) }
    let (p, i) = match (to_in, &pair) { (true, Some((p, i))) => (p.as_str(), i.as_str()), _ => ("-", "-") };
    let payload = format!("SAGA {tenant} {key} {req} {to} {p} {i}");
    commit(s, req, payload)
}

fn open_inventory(ctx: &Ctx, line: &str) -> Result<String, Refusal> {
    let t = toks(line, 6, 6)?;
    let (tenant, key, req, pol) = (id(t[1], "tenant")?, id(t[2], "key")?, id(t[3], "request_id")?, id(t[4], "policy")?);
    let Some(c) = parse_csv(t[5], MAX_ROWS) else { return no(Code::Malformed, "BAD_CAPACITY a list of 1 to 64 amounts, comma separated") };
    let s = store::open(&ctx.dir)?;
    check_open(&s, tenant, key, req, pol, "inventory")?;
    let c = c.iter().map(u64::to_string).collect::<Vec<_>>().join(",");
    commit(s, req, format!("OPEN_INVENTORY {tenant} {key} {req} {pol} {c}"))
}
fn book(ctx: &Ctx, line: &str) -> Result<String, Refusal> {
    let t: Vec<&str> = line.splitn(6, ' ').collect();
    if t.len() != 6 { return no(Code::Malformed, "FIELDS") }
    let (tenant, key, req, pre) = (id(t[1], "tenant")?, id(t[2], "key")?, id(t[3], "request_id")?, hash(t[4])?);
    let cert = policy::parse_cert(t[5]).or_else(|e| no(Code::Malformed, e))?;
    let s = store::open(&ctx.dir)?;
    let k = check_key(&s, tenant, key, req, pre)?;
    let Body::Inventory { policy: pol, remaining } = &k.body else { return no(Code::Malformed, "KEY_KIND not an inventory key") };
    let Some(policy::Body::Inventory(ip)) = s.policies.get(pol).map(|p| &p.body) else { return no(Code::CorruptWal, "CORRUPT_WAL POLICY_MISSING") };
    let decision = if cert.c != *remaining {
        Some("CAPACITY_MISMATCH")
    } else if cert.alpha > ip.max_alpha_bps {
        Some("ALPHA_ABOVE_POLICY")
    } else {
        match policy::accepts(&cert) { Ok(()) => None, Err("OVERFLOW") => return no(Code::Malformed, "OVERFLOW"), Err(e) => Some(e) }
    };
    if let Some(code) = decision { return verdict(s, req, Code::RejectedPolicy, code) }
    // PROVED CORE source for the check: the Dafny-compiled BookingDualCert checker, run by Node (trusted).
    if !helpers::booking_check(&ctx.node(), &policy::cert_json(&cert))? { return verdict(s, req, Code::RejectedPolicy, "CHECKER_REJECTED") }
    let used = policy::usage(&cert).ok_or(Refusal(Code::Malformed, "OVERFLOW".into()))?;
    let after: Option<Vec<u64>> = cert.c.iter().zip(&used).map(|(c, u)| (*c as u128).checked_sub(*u).map(|v| v as u64)).collect();
    let Some(after) = after else { return verdict(s, req, Code::RejectedPolicy, "OVERBOOKED") };
    let x: String = cert.x.iter().map(|v| if *v == 1 { '1' } else { '0' }).collect();
    let after = after.iter().map(u64::to_string).collect::<Vec<_>>().join(",");
    commit(s, req, format!("BOOK {tenant} {key} {req} {x} {after}"))
}

fn open_lease(ctx: &Ctx, line: &str) -> Result<String, Refusal> {
    let t = toks(line, 3, 3)?;
    let (req, deadline) = (id(t[1], "request_id")?, amount(t[2], "deadline_ms")?);
    let s = store::open(&ctx.dir)?;
    if s.l.ids.contains(req) { return no(Code::Duplicate, "DUPLICATE_REQUEST_ID") }
    if s.l.leases.contains_key(req) { return no(Code::Duplicate, "LEASE_OPEN a lease is open for this request id") }
    let (epoch, _) = s.append(&format!("LEASE {req} {deadline}"))?;
    Ok(format!("LEASE_OPENED {req} {epoch} {deadline}"))
}

/// `OK <state_hash> <kind> <field>=<value>...`
pub fn get(dir: &str, tenant: &str, key: &str) -> Result<String, Refusal> {
    let s = store::open(dir)?;
    let Some(k) = s.l.keys.get(key) else { return no(Code::UnknownKey, "UNKNOWN_KEY") };
    if k.tenant != tenant { return no(Code::Breach, "KEY_OF_ANOTHER_TENANT") }
    let rest = match &k.body {
        Body::Money { policy, original, remaining, facts, totals } => {
            let f: String = facts.iter().map(|(n, v)| format!(" fact.{n}={v}")).collect();
            let r: String = totals.iter().map(|(n, v)| format!(" total.{n}={v}")).collect();
            format!("money policy={policy} original={original} remaining={remaining}{f}{r}")
        }
        Body::Saga { policy, state, pair } => {
            let (p, i) = pair.as_ref().map_or(("-", "-"), |(p, i)| (p.as_str(), i.as_str()));
            format!("saga policy={policy} state={state} processor={p} idempotency_key={i}")
        }
        Body::Inventory { policy, remaining } => {
            format!("inventory policy={policy} remaining={}", remaining.iter().map(u64::to_string).collect::<Vec<_>>().join(","))
        }
    };
    Ok(format!("OK {} {rest}", hx(k.hash)))
}
pub fn state(dir: &str) -> Result<String, Refusal> {
    let s = store::open(dir)?;
    let l = &s.l;
    Ok(format!("STATE {} {} {} keys={} effects={} leases={}", l.epoch, hx(l.tail), l.store_id, l.keys.len(), l.effects, l.leases.len()))
}

/// One row of the read airlock: a strict JSON object whose `tenant_id` is a string equal to `tenant`.
fn row_ok(tenant: &str, row: &[u8]) -> Result<(), &'static str> {
    let text = std::str::from_utf8(row).map_err(|_| "NOT_UTF8")?;
    let j = json::parse(text)?;
    match (&j, j.get("tenant_id")) {
        (J::Obj(_), Some(J::Str(t))) if t == tenant => Ok(()),
        (J::Obj(_), Some(J::Str(_))) => Err("TENANT_MISMATCH"),
        (J::Obj(_), Some(_)) => Err("TENANT_NOT_STRING"),
        (J::Obj(_), None) => Err("TENANT_MISSING"),
        _ => Err("NOT_OBJECT"),
    }
}
/// `READ <tenant> <n>` and then n row lines. All n lines are read, also after a failure, so the stream stays in step.
/// OK only if the tenant is canonical and every row passes; else TENANT_ISOLATION_BREACH (0 rows released).
pub fn read_verb(raw: &[u8], next: &mut dyn FnMut() -> io::Result<Option<Line>>) -> Result<String, Refusal> {
    let text = std::str::from_utf8(raw).unwrap_or("");
    let t: Vec<&str> = text.split(' ').collect();
    let n = match t.as_slice() {
        ["READ", _, n] => n.parse::<usize>().ok().filter(|v| v.to_string() == *n && *v <= MAX_READ_ROWS),
        _ => None,
    };
    let Some(n) = n else { return no(Code::Malformed, "READ_HEADER `READ <tenant> <n>` with 0 <= n <= 100000") };
    let tenant = t[1];
    let mut first: Option<String> = (!canonical_id(tenant)).then(|| "TENANT_NOT_CANONICAL".to_string());
    for i in 0..n {
        let why = match next()? {
            None => return no(Code::Breach, format!("ROWS_MISSING {i} of {n} rows came")),
            Some(Line::Whole(row)) => row_ok(tenant, &row).err(),
            Some(Line::Oversized) => Some("OVERSIZED"),
            Some(Line::NoEnd) => Some("NO_LINE_END"),
        };
        if let (None, Some(w)) = (&first, why) { first = Some(format!("ROW {i} {w}")) }
    }
    match first { None => Ok(format!("OK {n}")), Some(w) => no(Code::Breach, w) }
}
