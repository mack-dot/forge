//! Policy files (strict JSON, unknown keys refused) and the pure decision functions. NATIVE CHECK, not proved.
//! `eval_money` is the one function behind both a REFUND commit (parametric profile) and the `eval` subcommand.
//! `accepts` is a native transcription of `Accepts` in proposals/forge2-pillar3-dual-certificate/BookingDualCert.dfy,
//! restricted to non-negative integers; the Dafny-compiled checker (booking_check.cjs) must accept too.
use crate::json::{self, J};
use crate::ledger::{MAX_COLS, MAX_ROWS};
use crate::store::{canonical_id, money};

pub const REASONS: [&str; 3] = ["duplicate_charge", "service_not_delivered", "returned_item"];
const MAX_RULES: usize = 256;
const MAX_STATES: usize = 64;

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum Verdict {
    Commit,
    Cosign,
    Reject(&'static str),
}
impl Verdict {
    fn rank(self) -> u8 {
        match self { Verdict::Commit => 0, Verdict::Cosign => 1, Verdict::Reject(_) => 2 }
    }
}
pub struct Rule {
    pub reason: String,
    pub min: Option<u64>,
    pub max: Option<u64>,
    pub fact: Option<String>,
    pub verdict: Verdict,
}
pub struct Money {
    pub canonical: bool,
    pub rules: Vec<Rule>,
}
pub struct Saga {
    pub states: Vec<String>,
    pub initial: String,
    pub in_flight: Vec<String>,
    pub transitions: Vec<(String, String)>,
}
pub struct Inventory {
    pub max_alpha_bps: u64,
}
pub enum Body {
    Money(Money),
    Saga(Saga),
    Inventory(Inventory),
}
pub struct Policy {
    pub name: String,
    pub body: Body,
}
impl Policy {
    pub fn kind(&self) -> &'static str {
        match self.body { Body::Money(_) => "money", Body::Saga(_) => "saga", Body::Inventory(_) => "inventory" }
    }
    pub fn name(&self) -> &str {
        &self.name
    }
}

fn only(j: &J, allowed: &[&str]) -> Result<(), String> {
    match j {
        J::Obj(f) => match f.iter().find(|(k, _)| !allowed.contains(&k.as_str())) {
            Some((k, _)) => Err(format!("UNKNOWN_KEY {}", if canonical_id(k) { k.as_str() } else { "?" })),
            None => Ok(()),
        },
        _ => Err("NOT_OBJECT".into()),
    }
}
fn s<'a>(j: &'a J, k: &str) -> Result<&'a str, String> {
    match j.get(k) { Some(J::Str(v)) => Ok(v), _ => Err(format!("FIELD {k}")) }
}
fn id<'a>(j: &'a J, k: &str) -> Result<&'a str, String> {
    s(j, k).and_then(|v| if canonical_id(v) { Ok(v) } else { Err(format!("BAD_ID {k}")) })
}
fn amount(j: &J, k: &str) -> Result<Option<u64>, String> {
    match j.get(k) { None => Ok(None), Some(J::Str(v)) => money(v).map(Some).ok_or(format!("BAD_AMOUNT {k}")), _ => Err(format!("BAD_AMOUNT {k}")) }
}
fn ids(j: &J, k: &str, max: usize) -> Result<Vec<String>, String> {
    let Some(J::Arr(a)) = j.get(k) else { return Err(format!("FIELD {k}")) };
    let mut out: Vec<String> = Vec::new();
    for v in a {
        match v {
            J::Str(x) if canonical_id(x) && !out.contains(x) => out.push(x.clone()),
            _ => return Err(format!("BAD_LIST {k}")),
        }
    }
    if out.len() > max { return Err(format!("TOO_MANY {k}")) }
    Ok(out)
}

pub fn parse(bytes: &[u8]) -> Result<Policy, String> {
    let text = std::str::from_utf8(bytes).map_err(|_| "NOT_UTF8".to_string())?;
    let j = json::parse(text).map_err(|e| format!("JSON {e}"))?;
    if j.get("version") != Some(&J::Num("1".into())) { return Err("VERSION".into()) }
    let name = id(&j, "name")?.to_string();
    let body = match s(&j, "airlock")? {
        "money" => {
            let canonical = match s(&j, "profile")? { "parametric" => false, "canonical-refund" => true, _ => return Err("PROFILE".into()) };
            if canonical {
                only(&j, &["airlock", "version", "name", "profile"])?;
                Body::Money(Money { canonical, rules: Vec::new() })
            } else {
                only(&j, &["airlock", "version", "name", "profile", "rules"])?;
                let Some(J::Arr(list)) = j.get("rules") else { return Err("FIELD rules".into()) };
                if list.is_empty() || list.len() > MAX_RULES { return Err("RULE_COUNT".into()) }
                let mut rules = Vec::new();
                for r in list {
                    only(r, &["reason", "verdict", "min_amount", "max_amount", "max_reason_total_fact"])?;
                    let verdict = match s(r, "verdict")? {
                        "COMMIT" => Verdict::Commit,
                        "REQUIRE_HUMAN_COSIGN" => Verdict::Cosign,
                        "REJECTED_POLICY" => Verdict::Reject("RULE"),
                        _ => return Err("VERDICT".into()),
                    };
                    let (min, max) = (amount(r, "min_amount")?, amount(r, "max_amount")?);
                    if let (Some(a), Some(b)) = (min, max) {
                        if a > b { return Err("MIN_ABOVE_MAX".into()) }
                    }
                    let fact = match r.get("max_reason_total_fact") { None => None, Some(_) => Some(id(r, "max_reason_total_fact")?.to_string()) };
                    rules.push(Rule { reason: id(r, "reason")?.to_string(), min, max, fact, verdict });
                }
                Body::Money(Money { canonical, rules })
            }
        }
        "saga" => {
            only(&j, &["airlock", "version", "name", "states", "initial", "in_flight", "transitions"])?;
            let states = ids(&j, "states", MAX_STATES)?;
            let initial = id(&j, "initial")?.to_string();
            let in_flight = ids(&j, "in_flight", MAX_STATES)?;
            if states.is_empty() || !states.contains(&initial) || in_flight.iter().any(|x| !states.contains(x)) { return Err("STATES".into()) }
            let Some(J::Arr(list)) = j.get("transitions") else { return Err("FIELD transitions".into()) };
            let mut transitions = Vec::new();
            for p in list {
                let pair = match p {
                    J::Arr(v) => match v.as_slice() {
                        [J::Str(a), J::Str(b)] if states.contains(a) && states.contains(b) => (a.clone(), b.clone()),
                        _ => return Err("TRANSITION".into()),
                    },
                    _ => return Err("TRANSITION".into()),
                };
                if transitions.contains(&pair) || transitions.len() >= MAX_STATES * MAX_STATES { return Err("TRANSITION".into()) }
                transitions.push(pair);
            }
            Body::Saga(Saga { states, initial, in_flight, transitions })
        }
        "inventory" => {
            only(&j, &["airlock", "version", "name", "max_alpha_bps"])?;
            let max_alpha_bps = amount(&j, "max_alpha_bps")?.filter(|v| *v <= 10000).ok_or("BAD_AMOUNT max_alpha_bps")?;
            Body::Inventory(Inventory { max_alpha_bps })
        }
        _ => return Err("AIRLOCK".into()),
    };
    Ok(Policy { name, body })
}

/// The money decision. Built-in checks first (ZERO_AMOUNT, TOTAL_CAP), then the rules. When several rules match,
/// the most restrictive verdict wins: REJECTED_POLICY > REQUIRE_HUMAN_COSIGN > COMMIT.
pub fn eval_money(m: &Money, reason: &str, amount: u64, remaining: u64, reason_total: u64, facts: &dyn Fn(&str) -> Option<u64>) -> Verdict {
    if amount == 0 { return Verdict::Reject("ZERO_AMOUNT") }
    if amount > remaining { return Verdict::Reject("TOTAL_CAP") }
    let (mut best, mut capped): (Option<Verdict>, bool) = (None, false);
    for r in m.rules.iter().filter(|r| r.reason == reason) {
        if r.min.map_or(false, |v| amount < v) || r.max.map_or(false, |v| amount > v) { continue }
        if let Some(f) = &r.fact {
            let within = facts(f).zip(reason_total.checked_add(amount)).map_or(false, |(cap, t)| t <= cap);
            if !within { capped = true; continue }
        }
        if best.map_or(true, |b| r.verdict.rank() > b.rank()) { best = Some(r.verdict) }
    }
    best.unwrap_or(Verdict::Reject(if capped { "REASON_CAP" } else { "NO_RULE" }))
}

/// One booking certificate. Every integer is a canonical decimal string, 0 to 9223372036854775807.
pub struct Cert {
    pub a: Vec<Vec<u64>>,
    pub c: Vec<u64>,
    pub w: Vec<u64>,
    pub x: Vec<u64>,
    pub y: Vec<u64>,
    pub z: Vec<u64>,
    pub alpha: u64,
}
fn vec_of(j: &J, k: &str, max: usize) -> Result<Vec<u64>, &'static str> {
    let Some(J::Arr(a)) = j.get(k) else { return Err("CERT_FIELD") };
    if a.is_empty() || a.len() > max { return Err("CERT_SHAPE") }
    a.iter().map(|v| match v { J::Str(s) => money(s).ok_or("CERT_INTEGER"), _ => Err("CERT_INTEGER") }).collect()
}
pub fn parse_cert(text: &str) -> Result<Cert, &'static str> {
    let j = json::parse(text).map_err(|_| "CERT_JSON")?;
    only(&j, &["A", "c", "w", "x", "y", "z", "alpha_bps"]).map_err(|_| "CERT_FIELD")?;
    let Some(J::Arr(rows)) = j.get("A") else { return Err("CERT_FIELD") };
    if rows.is_empty() || rows.len() > MAX_ROWS { return Err("CERT_SHAPE") }
    let mut a = Vec::new();
    for r in rows {
        a.push(vec_of(&J::Obj(vec![("r".into(), r.clone())]), "r", MAX_COLS)?);
    }
    let alpha = match j.get("alpha_bps") { Some(J::Str(s)) => money(s).ok_or("CERT_INTEGER")?, _ => return Err("CERT_FIELD") };
    let cert = Cert { a, c: vec_of(&j, "c", MAX_ROWS)?, w: vec_of(&j, "w", MAX_COLS)?, x: vec_of(&j, "x", MAX_COLS)?, y: vec_of(&j, "y", MAX_ROWS)?, z: vec_of(&j, "z", MAX_COLS)?, alpha };
    let (m, n) = (cert.c.len(), cert.w.len());
    let shape = cert.a.len() == m && cert.y.len() == m && cert.x.len() == n && cert.z.len() == n && cert.a.iter().all(|r| r.len() == n);
    if !shape { return Err("CERT_SHAPE") }
    Ok(cert)
}
/// The canonical JSON text sent to booking_check.cjs: the values the engine checked, in a fixed order.
pub fn cert_json(c: &Cert) -> String {
    let v = |x: &[u64]| format!("[{}]", x.iter().map(|n| format!("\"{n}\"")).collect::<Vec<_>>().join(","));
    let a = c.a.iter().map(|r| v(r)).collect::<Vec<_>>().join(",");
    format!("{{\"A\":[{a}],\"c\":{},\"w\":{},\"x\":{},\"y\":{},\"z\":{},\"alpha_bps\":\"{}\"}}", v(&c.c), v(&c.w), v(&c.x), v(&c.y), v(&c.z), c.alpha)
}
fn dot(a: &[u64], b: &[u64]) -> Option<u128> {
    a.iter().zip(b).try_fold(0u128, |s, (x, y)| s.checked_add((*x as u128).checked_mul(*y as u128)?))
}
/// Row usage A*x. None on overflow.
pub fn usage(c: &Cert) -> Option<Vec<u128>> {
    c.a.iter().map(|r| dot(r, &c.x)).collect()
}
/// Native `Accepts` (BookingDualCert.dfy) on non-negative integers: x is 0/1, A x <= c, A^T y + z >= w,
/// and (10000 - alpha_bps) * (y.c + sum z) <= 10000 * w.x. Err: the reason code, or OVERFLOW.
pub fn accepts(c: &Cert) -> Result<(), &'static str> {
    if c.alpha > 10000 { return Err("ALPHA_ABOVE_POLICY") }
    if c.x.iter().any(|v| *v > 1) { return Err("NOT_BINARY") }
    let used = usage(c).ok_or("OVERFLOW")?;
    if used.iter().zip(&c.c).any(|(u, cap)| *u > *cap as u128) { return Err("OVERBOOKED") }
    for j in 0..c.w.len() {
        let col = c.a.iter().zip(&c.y).try_fold(0u128, |s, (r, y)| s.checked_add((r[j] as u128).checked_mul(*y as u128)?)).ok_or("OVERFLOW")?;
        if (c.w[j] as u128) > col.checked_add(c.z[j] as u128).ok_or("OVERFLOW")? { return Err("DUAL_INFEASIBLE") }
    }
    let bound = dot(&c.y, &c.c).and_then(|d| c.z.iter().try_fold(d, |s, z| s.checked_add(*z as u128))).ok_or("OVERFLOW")?;
    let lhs = ((10000 - c.alpha) as u128).checked_mul(bound).ok_or("OVERFLOW")?;
    let rhs = dot(&c.w, &c.x).and_then(|v| v.checked_mul(10000)).ok_or("OVERFLOW")?;
    if lhs > rhs { return Err("GAP_TOO_LARGE") }
    Ok(())
}
