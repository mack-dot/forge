//! The request engine: grammar, module registry, tenant and request-id checks, the multi-key compare-and-swap, the
//! write of one record per effect. NATIVE CHECK, not proved. The modules decide; this file never decides a policy.
//!
//! Order for `DO` (PROTOCOL.md section 4): grammar (no file opened) -> lock and fold -> trusted Now -> tenant of every
//! key -> key kind -> request id -> compare-and-swap of EVERY key (all hashes checked before anything is written) ->
//! module decision -> at most one record (all keys of the request in it) -> sync -> lock released -> answer.
use crate::clock::Clock;
use crate::farkas::Farkas;
use crate::json::{self, J};
use crate::ledger_graph::LedgerGraph;
use crate::prim::{refusal, wire_value, Cas, Decision, KeyView, Now, OpSpec, Policies, Primitive, Record, Refusal, Request, RESERVED, RESERVED_FIELDS};
use crate::rate::RateWindow;
use crate::store::{self, canonical_id, canonical_key, hx, parse_hash};
use crate::taint::Taint;

pub const MAX_KEYS: usize = 16;

/// The folded state of every module.
#[derive(Default)]
pub struct Modules {
    pub rate: <RateWindow as Primitive>::State,
    pub ledger_graph: <LedgerGraph as Primitive>::State,
    pub taint: <Taint as Primitive>::State,
    pub farkas: <Farkas as Primitive>::State,
    #[cfg(test_seams)]
    pub probe: <crate::probe::CasProbe as Primitive>::State,
}
/// The pinned policies of every module, by policy name.
#[derive(Default)]
pub struct PolicySet {
    pub rate: Policies<<RateWindow as Primitive>::Policy>,
    pub ledger_graph: Policies<<LedgerGraph as Primitive>::Policy>,
    pub taint: Policies<<Taint as Primitive>::Policy>,
    pub farkas: Policies<<Farkas as Primitive>::Policy>,
    #[cfg(test_seams)]
    pub probe: Policies<<crate::probe::CasProbe as Primitive>::Policy>,
}

/// The registered primitive names (the test module only in the test-seams build).
pub fn primitive_name(p: &str) -> Option<&'static str> {
    #[allow(unused_mut)] // the test-seams build adds the test module
    let mut names = vec![RateWindow::NAME, LedgerGraph::NAME, Taint::NAME, Farkas::NAME];
    #[cfg(test_seams)]
    names.push(crate::probe::CasProbe::NAME);
    names.into_iter().find(|n| *n == p)
}
pub fn op_spec(prim: &str, op: &str) -> Option<&'static OpSpec> {
    let ops: &'static [OpSpec] = match prim {
        p if p == RateWindow::NAME => RateWindow::OPS,
        p if p == LedgerGraph::NAME => LedgerGraph::OPS,
        p if p == Taint::NAME => Taint::OPS,
        p if p == Farkas::NAME => Farkas::OPS,
        #[cfg(test_seams)]
        p if p == crate::probe::CasProbe::NAME => crate::probe::CasProbe::OPS,
        _ => return None,
    };
    ops.iter().find(|s| s.op == op)
}

impl PolicySet {
    /// Parses one policy file: strict JSON object with `primitive`, `version` (the JSON number 1), `name` (an id),
    /// then the module's own keys. Returns (name, primitive).
    pub fn add(&mut self, bytes: &[u8]) -> Result<(String, &'static str), String> {
        let text = std::str::from_utf8(bytes).map_err(|_| "NOT_UTF8".to_string())?;
        let doc = json::parse(text).map_err(|e| e.to_string())?;
        let s = |k: &str| match doc.get(k) { Some(J::Str(v)) => Some(v.clone()), _ => None };
        let prim = s("primitive").and_then(|p| primitive_name(&p)).ok_or("PRIMITIVE")?;
        if doc.get("version") != Some(&J::Num("1".into())) { return Err("VERSION".into()) }
        let name = s("name").filter(|n| canonical_id(n)).ok_or("NAME")?;
        let dup = || format!("DUPLICATE_POLICY_NAME {name}");
        macro_rules! put {
            ($field:ident, $m:ty) => {{
                let p = <$m>::parse_policy(&doc)?;
                if self.$field.insert(name.clone(), p).is_some() { return Err(dup()) }
            }};
        }
        match prim {
            p if p == RateWindow::NAME => put!(rate, RateWindow),
            p if p == LedgerGraph::NAME => put!(ledger_graph, LedgerGraph),
            p if p == Taint::NAME => put!(taint, Taint),
            p if p == Farkas::NAME => put!(farkas, Farkas),
            #[cfg(test_seams)]
            p if p == crate::probe::CasProbe::NAME => put!(probe, crate::probe::CasProbe),
            _ => return Err("PRIMITIVE".into()),
        }
        Ok((name, prim))
    }
}

pub fn fold_module(m: &mut Modules, pol: &PolicySet, prim: &str, rec: &Record) -> Result<(), String> {
    match prim {
        p if p == RateWindow::NAME => RateWindow::fold(&mut m.rate, rec, &pol.rate),
        p if p == LedgerGraph::NAME => LedgerGraph::fold(&mut m.ledger_graph, rec, &pol.ledger_graph),
        p if p == Taint::NAME => Taint::fold(&mut m.taint, rec, &pol.taint),
        p if p == Farkas::NAME => Farkas::fold(&mut m.farkas, rec, &pol.farkas),
        #[cfg(test_seams)]
        p if p == crate::probe::CasProbe::NAME => crate::probe::CasProbe::fold(&mut m.probe, rec, &pol.probe),
        _ => Err("UNKNOWN_PRIMITIVE".into()),
    }
}
fn decide_module(f: &store::Folded, prim: &str, req: &Request, now: &Now) -> Decision {
    match prim {
        p if p == RateWindow::NAME => RateWindow::decide(req, &f.m.rate, &f.pol.rate, now),
        p if p == LedgerGraph::NAME => LedgerGraph::decide(req, &f.m.ledger_graph, &f.pol.ledger_graph, now),
        p if p == Taint::NAME => Taint::decide(req, &f.m.taint, &f.pol.taint, now),
        p if p == Farkas::NAME => Farkas::decide(req, &f.m.farkas, &f.pol.farkas, now),
        #[cfg(test_seams)]
        p if p == crate::probe::CasProbe::NAME => crate::probe::CasProbe::decide(req, &f.m.probe, &f.pol.probe, now),
        _ => Decision::Refuse(refusal("MALFORMED_REQUEST", vec![("why", "UNKNOWN_PRIMITIVE".into())], "")),
    }
}
fn describe_module(f: &store::Folded, prim: &str, key: &str, now: &Now) -> Option<Vec<(&'static str, String)>> {
    match prim {
        p if p == RateWindow::NAME => RateWindow::describe(&f.m.rate, key, &f.pol.rate, now),
        p if p == LedgerGraph::NAME => LedgerGraph::describe(&f.m.ledger_graph, key, &f.pol.ledger_graph, now),
        p if p == Taint::NAME => Taint::describe(&f.m.taint, key, &f.pol.taint, now),
        p if p == Farkas::NAME => Farkas::describe(&f.m.farkas, key, &f.pol.farkas, now),
        #[cfg(test_seams)]
        p if p == crate::probe::CasProbe::NAME => crate::probe::CasProbe::describe(&f.m.probe, key, &f.pol.probe, now),
        _ => None,
    }
}

pub struct Ctx {
    pub dir: String,
    pub clock: Clock,
}
fn malformed(why: &str, detail: &str) -> Refusal {
    refusal("MALFORMED_REQUEST", vec![("why", why.to_string())], detail)
}
/// One field and the rest of the text after ONE space. Err for an empty field (a double, leading or trailing space).
fn field(s: &str) -> Result<(&str, Option<&str>), Refusal> {
    let (a, b) = match s.find(' ') { Some(i) => (&s[..i], Some(&s[i + 1..])), None => (s, None) };
    if a.is_empty() || b == Some("") { return Err(malformed("SPACING", "fields are separated by exactly one space")) }
    Ok((a, b))
}
fn fields(s: &str, n: usize) -> Result<(Vec<&str>, Option<&str>), Refusal> {
    let (mut out, mut rest) = (Vec::with_capacity(n), Some(s));
    for _ in 0..n {
        let (a, b) = field(rest.ok_or_else(|| malformed("FIELDS", "too few fields"))?)?;
        out.push(a);
        rest = b;
    }
    Ok((out, rest))
}

/// A module refusal or answer field set must keep the wire grammar: a code word, field names, no reserved word.
fn check_code(code: &str) -> bool {
    let b = code.as_bytes();
    (3..=48).contains(&b.len()) && b[0].is_ascii_uppercase() && b.iter().all(|c| c.is_ascii_uppercase() || c.is_ascii_digit() || *c == b'_') && !RESERVED.contains(&code)
}
fn check_fields(f: &[(&'static str, String)]) -> bool {
    f.iter().all(|(k, _)| {
        let b = k.as_bytes();
        (1..=32).contains(&b.len()) && b[0].is_ascii_lowercase() && b.iter().all(|c| c.is_ascii_lowercase() || c.is_ascii_digit() || *c == b'_' || *c == b'.')
            && !RESERVED_FIELDS.contains(k) && !k.starts_with("hash.")
    })
}
fn module_fault(why: &str) -> Refusal {
    refusal("MODULE_FAULT", vec![("why", why.to_string())], "the module returned a result that breaks the interface; nothing was written")
}
fn clock_fields(now: &Now) -> Vec<(&'static str, String)> {
    vec![("now_ms", now.now_ms.to_string()), ("skew_ms", now.skew_ms.to_string())]
}

/// An engine answer that is not a success: the code word, wire fields (names may hold a key, as in `hash.<key>`),
/// a human detail. main.rs prints it as `<CODE> <name>=<value>... [-- <detail>]`, values percent-encoded.
pub struct Wire {
    pub code: &'static str,
    pub fields: Vec<(String, String)>,
    pub detail: String,
}
impl From<Refusal> for Wire {
    fn from(r: Refusal) -> Wire {
        Wire { code: r.code, fields: r.repair.into_iter().map(|(k, v)| (k.to_string(), v)).collect(), detail: r.detail }
    }
}

/// The answer to one request line (Ok: a success line without its line end).
pub fn handle(ctx: &mut Ctx, line: &[u8]) -> Result<String, Wire> {
    if !store::printable(line) { return Err(malformed("NON_ASCII", "a request line is printable ASCII only").into()) }
    let text = std::str::from_utf8(line).expect("printable ASCII");
    let (verb, rest) = field(text)?;
    match (verb, rest) {
        ("STATE", None) => Ok(state(ctx, false)?),
        ("GET", Some(r)) => {
            let (t, extra) = fields(r, 2)?;
            if extra.is_some() { return Err(malformed("FIELDS", "GET <tenant> <key>").into()) }
            Ok(get(ctx, t[0], t[1])?)
        }
        ("DO", Some(r)) => do_request(ctx, r),
        _ => Err(malformed("UNKNOWN_VERB", "verbs: DO, GET, STATE").into()),
    }
}

/// `STATE`: the clock and the chain position. `operator` (the `state` subcommand) adds the key and id counts.
pub fn state(ctx: &mut Ctx, operator: bool) -> Result<String, Refusal> {
    let s = store::open(&ctx.dir)?;
    let now = ctx.clock.read(s.f.last_ms)?;
    let f = &s.f;
    let mut out = format!(
        "STATE store_id={} seq={} tail={} last_ms={} now_ms={} wall_ms={} skew_ms={} build={}",
        f.store_id, f.seq, hx(&f.tail), f.last_ms, now.now_ms, now.wall_ms, now.skew_ms, store::BUILD
    );
    if operator { out.push_str(&format!(" keys={} ids={} genesis={}", f.keys.len(), f.ids.len(), hx(&f.genesis_hash))) }
    Ok(out)
}

pub fn get(ctx: &mut Ctx, tenant: &str, key: &str) -> Result<String, Refusal> {
    if !canonical_id(tenant) { return Err(malformed("BAD_TENANT", "tenant: [A-Za-z0-9_-]{1,24}")) }
    if !canonical_key(key) { return Err(malformed("BAD_KEY", "key: [A-Za-z0-9_.:@+-]{1,128}")) }
    let s = store::open(&ctx.dir)?;
    let now = ctx.clock.read(s.f.last_ms)?;
    let Some(info) = s.f.keys.get(key) else {
        return Ok(format!("OK key={} hash={} exists=0 now_ms={} skew_ms={}", wire_value(key), hx(&s.f.genesis_hash), now.now_ms, now.skew_ms));
    };
    if info.tenant != tenant { return Err(refusal("TENANT_ISOLATION_BREACH", vec![("why", "KEY_OF_ANOTHER_TENANT".into())], "")) }
    let mut out = format!("OK key={} hash={} exists=1 primitive={} now_ms={} skew_ms={}", wire_value(key), hx(&info.hash), info.primitive, now.now_ms, now.skew_ms);
    for (k, v) in describe_module(&s.f, info.primitive, key, &now).unwrap_or_default() {
        out.push_str(&format!(" {k}={}", wire_value(&v)));
    }
    Ok(out)
}

/// `DO <primitive> <op> <request_id> <tenant> <n> <key_1> <hash_1> ... <key_n> <hash_n> [<args>]`
fn do_request(ctx: &mut Ctx, r: &str) -> Result<String, Wire> {
    let (head, rest) = fields(r, 5)?;
    let (prim, op, rid, tenant, n) = (head[0], head[1], head[2], head[3], head[4]);
    let prim = primitive_name(prim).ok_or_else(|| malformed("UNKNOWN_PRIMITIVE", "primitives: rate_window, ledger_graph, taint_egress, farkas"))?;
    let spec = op_spec(prim, op).ok_or_else(|| malformed("UNKNOWN_OP", ""))?;
    if !canonical_id(rid) { return Err(malformed("BAD_REQUEST_ID", "request id: [A-Za-z0-9_-]{1,24}").into()) }
    if !canonical_id(tenant) { return Err(malformed("BAD_TENANT", "tenant: [A-Za-z0-9_-]{1,24}").into()) }
    let n = crate::prim::dec_u64(n).filter(|n| *n as usize <= MAX_KEYS).ok_or_else(|| malformed("KEY_COUNT", "0 to 16 keys"))? as usize;
    if n < spec.min_keys || n > spec.max_keys { return Err(malformed("KEY_COUNT", "the op takes another number of keys").into()) }
    let (kh, args) = if n == 0 { (Vec::new(), rest) } else { fields(rest.unwrap_or(""), 2 * n)? };
    let args = args.unwrap_or("");
    if args.starts_with(' ') || args.ends_with(' ') { return Err(malformed("SPACING", "fields are separated by exactly one space").into()) }
    let mut keys: Vec<(&str, Option<[u8; 32]>)> = Vec::with_capacity(n);
    for i in 0..n {
        let (k, h) = (kh[2 * i], kh[2 * i + 1]);
        if !canonical_key(k) { return Err(malformed("BAD_KEY", "key: [A-Za-z0-9_.:@+-]{1,128}").into()) }
        if let Some((prev, _)) = keys.last() {
            if *prev == k { return Err(malformed("DUPLICATE_KEY", "a key is named twice").into()) }
            if *prev > k { return Err(malformed("KEY_ORDER", "keys must be in strictly ascending byte order").into()) }
        }
        let pre = match h {
            "*" if spec.cas == Cas::AnyAllowed => None,
            "*" => return Err(malformed("CAS_REQUIRED", "this op needs the present state hash of every key").into()),
            h => Some(parse_hash(h).ok_or_else(|| malformed("BAD_HASH", "a state hash is 64 lowercase hex digits or *"))?),
        };
        keys.push((k, pre));
    }

    let mut s = store::open(&ctx.dir)?;
    let now = ctx.clock.read(s.f.last_ms)?;
    for (k, _) in &keys {
        if let Some(info) = s.f.keys.get(*k) {
            if info.tenant != tenant { return Err(refusal("TENANT_ISOLATION_BREACH", vec![("why", "KEY_OF_ANOTHER_TENANT".into()), ("key", k.to_string())], "").into()) }
            if info.primitive != prim { return Err(malformed("KEY_KIND", "the key belongs to another primitive").into()) }
        }
    }
    if s.f.ids.contains(rid) { return Err(refusal("DUPLICATE_REQUEST_ID", vec![], "").into()) }
    // The multi-key compare-and-swap: EVERY key is compared before anything is written; one stale key refuses all.
    let mut stale: Vec<(String, String)> = Vec::new();
    for (k, pre) in &keys {
        let present = s.f.key_hash(k);
        if pre.is_some_and(|p| p != present) { stale.push((format!("hash.{k}"), hx(&present))) }
    }
    if !stale.is_empty() {
        let mut f = vec![("stale".to_string(), stale.len().to_string())];
        f.extend(stale);
        return Err(Wire { code: "STALE_STATE_HASH", fields: f, detail: String::new() });
    }

    let views: Vec<KeyView> = keys.iter().map(|(k, _)| KeyView { key: k, exists: s.f.keys.contains_key(*k) }).collect();
    let req = Request { request_id: rid, tenant, op, keys: &views, args };
    let decision = decide_module(&s.f, prim, &req, &now);
    let (kind, payload, refused) = match decision {
        Decision::Refuse(r) => {
            if !check_code(r.code) || !check_fields(&r.repair) { return Err(module_fault("BAD_REFUSAL").into()) }
            let mut w = Wire::from(r);
            w.fields.extend(clock_fields(&now).into_iter().map(|(k, v)| (k.to_string(), v)));
            return Err(w);
        }
        Decision::Answer(verdict, f, detail) => {
            if !check_code(verdict) || !check_fields(&f) { return Err(module_fault("BAD_ANSWER").into()) }
            let mut out = format!("OK verdict={verdict}");
            for (k, v) in f.iter().chain(clock_fields(&now).iter()) {
                out.push_str(&format!(" {k}={}", wire_value(v)));
            }
            if !detail.is_empty() { out.push_str(&format!(" -- {}", clean(&detail))) }
            return Ok(out);
        }
        Decision::Commit(p) => ("C", p, None),
        Decision::RefuseDurable(r, p) => {
            if !check_code(r.code) || !check_fields(&r.repair) { return Err(module_fault("BAD_REFUSAL").into()) }
            ("R", p, Some(r))
        }
    };
    if n == 0 { return Err(module_fault("WRITE_WITHOUT_KEY").into()) }
    if payload.len() > crate::prim::MAX_MODULE_PAYLOAD || !store::printable(payload.as_bytes()) { return Err(module_fault("BAD_PAYLOAD").into()) }
    let names: Vec<&str> = keys.iter().map(|(k, _)| *k).collect();
    let mut record = format!("E {prim} {op} {rid} {tenant} {kind} {n} {} |", names.join(" "));
    if !payload.is_empty() {
        record.push(' ');
        record.push_str(&payload);
    }
    let (seq, hash) = s.append(&record, &now)?;
    drop(s); // the lock ends here, after the sync, before the answer
    let mut tail: Vec<(String, String)> = vec![("request_id".into(), rid.into()), ("seq".into(), seq.to_string())];
    tail.extend(clock_fields(&now).into_iter().map(|(k, v)| (k.to_string(), v)));
    tail.extend(names.iter().map(|k| (format!("hash.{k}"), hx(&hash))));
    match refused {
        None => {
            let mut out = "COMMITTED".to_string();
            for (k, v) in tail.iter() {
                out.push_str(&format!(" {k}={}", wire_value(v)));
            }
            out.push_str(&format!(" effect={}", wire_value(&payload)));
            Ok(out)
        }
        Some(r) => {
            let mut w = Wire::from(r);
            w.fields.extend(tail);
            Err(w)
        }
    }
}
pub fn clean(s: &str) -> String {
    s.bytes().map(|b| if (0x20..0x7f).contains(&b) { b as char } else { '?' }).collect()
}
