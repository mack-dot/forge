//! Primitive 9, `farkas`: the check of a Farkas infeasibility certificate. NATIVE CHECK that MIRRORS the Dafny
//! predicate `FarkasCert.Accepts` of src/primitives_v2/dafny/FarkasCert.dfy. This Rust code is NOT proved and NOT
//! compiled from Dafny. The tie between the two is a FINITE differential test (tests/primitives_v2/test_farkas.py,
//! case `differential`): the Dafny predicate, compiled by the pinned Dafny's Python back end, and this check answer
//! the same on thousands of random and edge-case systems. Why not compiled from Dafny: the Dafny 4.11 Rust back end
//! emits code that needs the `dafny_runtime` crate (rustc with no crate: exit 1, E0432); see the P9 report.
//!
//! What the Dafny lemma `Soundness` says (PROVED in a Dafny run, about the Dafny predicate only): if
//! `Accepts(A, b, y)`, then NO non-negative INTEGER vector x satisfies `A x >= b`. Not stated there: rational or real
//! x; completeness (an integer-infeasible system can be rational-feasible, and then no certificate exists); anything
//! about any solver or about this file.
//!
//! Wire (a stateless check, PROTOCOL.md section 7.4: no key, no record, no receipt; the request id stays fresh):
//!   `DO farkas check <request_id> <tenant> 0 <json>`
//!   <json> is one strict JSON object with exactly the keys "A" (array of 1..64 rows, each an array of 1..64
//!   integers, all rows of one length n), "b" (array of m integers, m = number of rows) and "y" (array of m integers).
//!   An integer is a JSON number `-?(0|[1-9][0-9]*)` (no fraction, no exponent, no `-0`) in the signed 64-bit range.
//!   The system is `A x >= b, x >= 0`; y is the certificate of the claim "no x exists".
//! Answers, first match wins:
//!   `MALFORMED_REQUEST why=FARKAS_JSON|FARKAS_KEYS|FARKAS_NUMBER` (exit 12): not the format above.
//!   `SHAPE why=ROWS|COLS|ROW_LEN|B_LEN|Y_LEN|ENTRY_RANGE [row=] [col=]` (exit 10): sizes, shapes or an entry outside
//!       the signed 64-bit range (`FarkasCert.Shape` is false).
//!   `CERT_REJECTED claim=INFEASIBILITY_NOT_PROVED reason=Y_NEGATIVE row=<i>` (exit 10): y[i] < 0 (first i).
//!   `CERT_REJECTED claim=INFEASIBILITY_NOT_PROVED reason=YTA_POSITIVE col=<j>` (exit 10): (y^T A)[j] > 0 (first j).
//!   `CERT_REJECTED claim=INFEASIBILITY_NOT_PROVED reason=YTB_NOT_POSITIVE` (exit 10): y^T b <= 0.
//!   `OVERFLOW claim=INFEASIBILITY_NOT_PROVED why=ARITH [col=<j>]` (exit 10): a sum left the i128 range (checked
//!       arithmetic; fail closed: never a proof). The Dafny predicate has no overflow (mathematical integers), so
//!       OVERFLOW can stand for an input that the Dafny predicate accepts: then the check refuses a valid
//!       certificate. It never accepts because of an overflow.
//!   `OK verdict=INFEASIBILITY_PROVED scope=nonneg_integer_x rows=<m> cols=<n> system_sha256=<h> cert_sha256=<h>`
//!       (exit 0): every clause of Accepts holds.
//!   Every refusal after the parse also carries `system_sha256=`. A refusal is never "feasible": the check never says
//!   that a solution exists.
//! Digests: system_sha256 = SHA-256 of the canonical text `{"A":[[a11,...],...],"b":[b1,...]}` (no spaces, canonical
//! decimals); cert_sha256 = SHA-256 of `{"y":[y1,...]}`. They bind the verdict to the exact system and certificate.
//! Policy files: none (`init` refuses a farkas policy: `MALFORMED_POLICY NO_POLICY`). Records: none (`fold` refuses
//! any record of this primitive).
use crate::json::J;
use crate::pin::Sha256;
use crate::prim::{refusal, Cas, Decision, Now, OpSpec, Policies, Primitive, Record, Refusal, Request};

pub struct Farkas;

pub struct Policy;

#[derive(Default)]
pub struct State;

pub const MAX_ROWS: usize = 64;
pub const MAX_COLS: usize = 64;
const NOT_PROVED: &str = "INFEASIBILITY_NOT_PROVED";

/// An entry of the input: Ok(Some(v)) an integer in i64; Ok(None) a canonical integer outside i64; Err not an integer.
fn int_of(j: &J) -> Result<Option<i64>, ()> {
    let J::Num(t) = j else { return Err(()) };
    let digits = t.strip_prefix('-').unwrap_or(t);
    let canonical = !digits.is_empty() && digits.bytes().all(|c| c.is_ascii_digit()) && (digits == "0" || !digits.starts_with('0')) && t != "-0";
    if !canonical { return Err(()) }
    Ok(t.parse::<i64>().ok())
}

enum Bad {
    Malformed(&'static str),
    Shape(&'static str, Vec<(&'static str, String)>),
}

fn vec_of(j: &J) -> Result<Vec<Option<i64>>, Bad> {
    let J::Arr(items) = j else { return Err(Bad::Malformed("FARKAS_KEYS")) };
    items.iter().map(|x| int_of(x).map_err(|()| Bad::Malformed("FARKAS_NUMBER"))).collect()
}

/// The parsed system before the range check: rows of A, b, y (None = a canonical integer outside i64).
type Raw = (Vec<Vec<Option<i64>>>, Vec<Option<i64>>, Vec<Option<i64>>);

fn parse(args: &str) -> Result<Raw, Bad> {
    let doc = crate::json::parse(args).map_err(|_| Bad::Malformed("FARKAS_JSON"))?;
    let J::Obj(fields) = &doc else { return Err(Bad::Malformed("FARKAS_KEYS")) };
    if fields.len() != 3 || ["A", "b", "y"].iter().any(|k| doc.get(k).is_none()) { return Err(Bad::Malformed("FARKAS_KEYS")) }
    let J::Arr(rows) = doc.get("A").expect("checked") else { return Err(Bad::Malformed("FARKAS_KEYS")) };
    let a = rows.iter().map(vec_of).collect::<Result<Vec<_>, _>>()?;
    Ok((a, vec_of(doc.get("b").expect("checked"))?, vec_of(doc.get("y").expect("checked"))?))
}

fn shape_ok(raw: &Raw) -> Result<(Vec<Vec<i64>>, Vec<i64>, Vec<i64>), Bad> {
    let (a, b, y) = raw;
    let m = a.len();
    if m < 1 || m > MAX_ROWS { return Err(Bad::Shape("ROWS", vec![])) }
    let n = a[0].len();
    if n < 1 || n > MAX_COLS { return Err(Bad::Shape("COLS", vec![])) }
    if let Some(i) = a.iter().position(|r| r.len() != n) { return Err(Bad::Shape("ROW_LEN", vec![("row", i.to_string())])) }
    if b.len() != m { return Err(Bad::Shape("B_LEN", vec![])) }
    if y.len() != m { return Err(Bad::Shape("Y_LEN", vec![])) }
    let range = |what: &'static str, v: &[Option<i64>], row: Option<usize>| -> Result<Vec<i64>, Bad> {
        match v.iter().position(|x| x.is_none()) {
            None => Ok(v.iter().map(|x| x.expect("checked")).collect()),
            Some(k) => {
                let mut f = vec![("in", what.to_string())];
                if let Some(r) = row { f.push(("row", r.to_string())); f.push(("col", k.to_string())) } else { f.push(("row", k.to_string())) }
                Err(Bad::Shape("ENTRY_RANGE", f))
            }
        }
    };
    let mut aa = Vec::with_capacity(m);
    for (i, r) in a.iter().enumerate() {
        aa.push(range("A", r, Some(i))?);
    }
    Ok((aa, range("b", b, None)?, range("y", y, None)?))
}

fn canon_vec(v: &[i64]) -> String {
    let parts: Vec<String> = v.iter().map(|x| x.to_string()).collect();
    format!("[{}]", parts.join(","))
}
fn sha_hex(text: &str) -> String {
    let mut h = Sha256::new();
    h.update(text.as_bytes());
    h.hex()
}
/// SHA-256 of `{"A":[[...],...],"b":[...]}`.
pub fn system_digest(a: &[Vec<i64>], b: &[i64]) -> String {
    let rows: Vec<String> = a.iter().map(|r| canon_vec(r)).collect();
    sha_hex(&format!("{{\"A\":[{}],\"b\":{}}}", rows.join(","), canon_vec(b)))
}
/// SHA-256 of `{"y":[...]}`.
pub fn cert_digest(y: &[i64]) -> String {
    sha_hex(&format!("{{\"y\":{}}}", canon_vec(y)))
}

/// The outcome of the check on in-range, well-shaped values. Mirrors `FarkasCert.Accepts` after `Shape`.
pub enum Outcome {
    Proved,
    YNegative(usize),
    YtaPositive(usize),
    YtbNotPositive,
    Overflow(Option<usize>),
}

/// sum_i u[i] * v[i] in i128, every step checked. None: an overflow.
fn dot(u: impl Iterator<Item = (i64, i64)>) -> Option<i128> {
    let mut s: i128 = 0;
    for (p, q) in u {
        s = s.checked_add((p as i128).checked_mul(q as i128)?)?;
    }
    Some(s)
}

pub fn check(a: &[Vec<i64>], b: &[i64], y: &[i64]) -> Outcome {
    if let Some(i) = y.iter().position(|v| *v < 0) { return Outcome::YNegative(i) }
    let n = a[0].len();
    for j in 0..n {
        match dot(y.iter().zip(a.iter()).map(|(yi, row)| (*yi, row[j]))) {
            None => return Outcome::Overflow(Some(j)),
            Some(s) if s > 0 => return Outcome::YtaPositive(j),
            Some(_) => {}
        }
    }
    match dot(y.iter().copied().zip(b.iter().copied())) {
        None => Outcome::Overflow(None),
        Some(s) if s > 0 => Outcome::Proved,
        Some(_) => Outcome::YtbNotPositive,
    }
}

fn rejected(reason: &'static str, mut f: Vec<(&'static str, String)>, sys: &str) -> Refusal {
    let mut repair = vec![("claim", NOT_PROVED.to_string()), ("reason", reason.to_string())];
    repair.append(&mut f);
    repair.push(("system_sha256", sys.to_string()));
    refusal("CERT_REJECTED", repair, "the certificate does not prove infeasibility; this does not mean that the system is feasible")
}

impl Primitive for Farkas {
    const NAME: &'static str = "farkas";
    const OPS: &'static [OpSpec] = &[OpSpec { op: "check", min_keys: 0, max_keys: 0, cas: Cas::Required }];
    type Policy = Policy;
    type State = State;

    fn parse_policy(_doc: &J) -> Result<Policy, String> {
        Err("NO_POLICY farkas takes no policy file".into())
    }

    fn decide(req: &Request, _state: &State, _policies: &Policies<Policy>, _now: &Now) -> Decision {
        if req.op != "check" || !req.keys.is_empty() {
            return Decision::Refuse(refusal("MALFORMED_REQUEST", vec![("why", "FARKAS_OP".into())], "farkas check takes no key"));
        }
        let parsed = parse(req.args).and_then(|raw| shape_ok(&raw));
        let (a, b, y) = match parsed {
            Ok(v) => v,
            Err(Bad::Malformed(why)) => {
                return Decision::Refuse(refusal("MALFORMED_REQUEST", vec![("why", why.into())], "args: one JSON object {\"A\": [[int,...],...], \"b\": [int,...], \"y\": [int,...]}"));
            }
            Err(Bad::Shape(why, mut f)) => {
                let mut repair = vec![("why", why.to_string())];
                repair.append(&mut f);
                return Decision::Refuse(refusal("SHAPE", repair, "1..64 rows, 1..64 columns, |b| = |y| = rows, entries in the signed 64-bit range"));
            }
        };
        let sys = system_digest(&a, &b);
        match check(&a, &b, &y) {
            Outcome::Proved => Decision::Answer(
                "INFEASIBILITY_PROVED",
                vec![
                    ("scope", "nonneg_integer_x".into()),
                    ("rows", a.len().to_string()),
                    ("cols", a[0].len().to_string()),
                    ("system_sha256", sys),
                    ("cert_sha256", cert_digest(&y)),
                ],
                "y >= 0, y^T A <= 0, y^T b > 0: no x >= 0 satisfies A x >= b (NATIVE CHECK of the Dafny predicate)".into(),
            ),
            Outcome::YNegative(i) => Decision::Refuse(rejected("Y_NEGATIVE", vec![("row", i.to_string())], &sys)),
            Outcome::YtaPositive(j) => Decision::Refuse(rejected("YTA_POSITIVE", vec![("col", j.to_string())], &sys)),
            Outcome::YtbNotPositive => Decision::Refuse(rejected("YTB_NOT_POSITIVE", vec![], &sys)),
            Outcome::Overflow(col) => {
                let mut repair = vec![("claim", NOT_PROVED.to_string()), ("why", "ARITH".to_string())];
                if let Some(j) = col { repair.push(("col", j.to_string())) }
                repair.push(("system_sha256", sys));
                Decision::Refuse(refusal("OVERFLOW", repair, "a sum left the i128 range; nothing is proved"))
            }
        }
    }

    fn fold(_state: &mut State, _rec: &Record, _policies: &Policies<Policy>) -> Result<(), String> {
        Err("NO_RECORD farkas writes no record".into())
    }

    fn describe(_state: &State, _key: &str, _policies: &Policies<Policy>, _now: &Now) -> Option<Vec<(&'static str, String)>> {
        None
    }
}
