//! The module interface of the primitives engine. NATIVE CHECK, not proved. Standard library only, no `unsafe`.
//!
//! A primitive is a PURE module: no I/O, no clock read, no process spawn, no global state, no randomness. It gets
//! the parsed request, its own folded state, its policies and the engine's `Now`. It returns a `Decision`. The
//! engine alone reads the clock, takes the lock, checks tenants, request ids and state hashes, writes the WAL,
//! syncs it, and answers. At replay the engine calls `fold` once per record of the module, in WAL order, with the
//! time that the engine wrote into that record; `fold` rebuilds the state and checks the record strictly.
//!
//! Binding rules for every module (PROTOCOL.md section 7):
//! - `decide` and `fold` agree: the engine folds a new record BEFORE it writes it; a record that `fold` refuses is
//!   never written (`MODULE_FAULT why=RECORD_NOT_FOLDABLE`).
//! - `fold` refuses (Err) every payload that `decide` could not have produced. An Err at replay refuses the whole
//!   store (`CORRUPT_WAL`).
//! - A refusal never carries a secret, a value of the request document, or data of another tenant. The detail is for
//!   a human; the repair fields are for a program.
//! - Every key of a request is in canonical order (strictly ascending bytes). One record touches all keys of the
//!   request; the engine sets the state hash of each of them to the hash of that record.
//! - Arithmetic: `checked_*` or u128; never a wrapping or a panicking operation on request data.
#![allow(dead_code)] // the interface: fields and variants that primitives 7 to 9 use
use crate::json::J;
use std::collections::BTreeMap;

/// The engine's trusted time for one exchange. Read ONLY by the engine (clock.rs); a request field is never a time.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Now {
    /// The time the engine decides with and writes into the record: max(wall, newest record time, monotonic floor).
    pub now_ms: u64,
    /// The raw wall-clock reading (ms since the Unix epoch; 0 for a clock before 1970).
    pub wall_ms: u64,
    /// How far the wall clock is behind `now_ms` (0 when it is not behind).
    pub skew_ms: u64,
}

/// Whether an op may name `*` in place of a pre-state hash (no compare-and-swap for that key).
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Cas {
    /// Every key needs its exact present state hash.
    Required,
    /// A key may give `*`: the module decides on the present state under the lock, whatever the caller saw.
    AnyAllowed,
}

/// One op of a module: its name, how many keys it takes, and its compare-and-swap rule.
/// `max_keys == 0` makes a stateless op: it writes no record (only `Decision::Answer` or `Decision::Refuse`).
pub struct OpSpec {
    pub op: &'static str,
    pub min_keys: usize,
    pub max_keys: usize,
    pub cas: Cas,
}

/// One key of a request. `exists` is false for a key that no record has touched.
pub struct KeyView<'a> {
    pub key: &'a str,
    pub exists: bool,
}

/// A parsed request, after the engine's grammar checks, tenant checks, request-id check and compare-and-swap.
pub struct Request<'a> {
    pub request_id: &'a str,
    pub tenant: &'a str,
    pub op: &'a str,
    /// Canonical order: strictly ascending bytes; 0 to MAX_KEYS keys.
    pub keys: &'a [KeyView<'a>],
    /// The rest of the request line after the keys (printable ASCII, may be empty). The module parses it strictly.
    pub args: &'a str,
}

/// Whether a record holds a commit (`C`) or the state change of a refusal (`R`).
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Kind {
    Commit,
    Refusal,
}

/// One record of the module as the fold sees it.
pub struct Record<'a> {
    pub seq: u64,
    /// The engine time written in the record header. Non-decreasing along the WAL (the engine checks it).
    pub now_ms: u64,
    pub request_id: &'a str,
    pub tenant: &'a str,
    pub op: &'a str,
    pub kind: Kind,
    /// Canonical order, as in the request.
    pub keys: &'a [&'a str],
    /// The module payload: printable ASCII, at most MAX_MODULE_PAYLOAD bytes, may be empty.
    pub payload: &'a str,
}

/// A structured, repairable refusal. Wire: `<CODE> <k>=<v>... [-- <detail>]` (PROTOCOL.md section 5).
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Refusal {
    /// `[A-Z][A-Z0-9_]{2,47}`, not an engine-reserved word (see RESERVED).
    pub code: &'static str,
    /// Machine-readable repair fields. Name `[a-z][a-z0-9_.]{0,31}`, not in RESERVED_FIELDS, not `hash.*`; the engine
    /// percent-encodes values (`wire_value`).
    pub repair: Vec<(&'static str, String)>,
    /// For a human. No secret, no request value, no data of another tenant.
    pub detail: String,
}

/// What a module decides for one request.
pub enum Decision {
    /// No record. The request id stays fresh.
    Refuse(Refusal),
    /// One record of kind `R` with this payload (the state change of the refusal, e.g. a counted rejection), then
    /// the refusal answer. The record uses the request id up. Only for ops with at least one key.
    RefuseDurable(Refusal, String),
    /// One record of kind `C` with this payload, then `COMMITTED`. Only for ops with at least one key.
    Commit(String),
    /// No record: a stateless verdict (`OK verdict=<word> <fields> [-- detail]`). The request id stays fresh.
    Answer(&'static str, Vec<(&'static str, String)>, String),
}

pub type Policies<P> = BTreeMap<String, P>;

/// The interface. Each module implements it on a unit struct in its own file.
pub trait Primitive {
    /// The primitive name on the wire and in policy files: `[a-z][a-z0-9_]{1,31}`.
    const NAME: &'static str;
    /// The ops of the module.
    const OPS: &'static [OpSpec];
    type Policy;
    type State: Default;
    /// One policy file (strict JSON, already parsed). The engine has checked the envelope (`primitive`, `version`
    /// = 1, `name`); `policy_fields` checks the exact key set. Err: `MALFORMED_POLICY <text>` at init and replay.
    fn parse_policy(doc: &J) -> Result<Self::Policy, String>;
    /// The decision. Pure: the same inputs give the same Decision.
    fn decide(req: &Request, state: &Self::State, policies: &Policies<Self::Policy>, now: &Now) -> Decision;
    /// Applies one record of this module. Strict: Err for any payload `decide` could not have produced.
    fn fold(state: &mut Self::State, rec: &Record, policies: &Policies<Self::Policy>) -> Result<(), String>;
    /// `GET` fields of one key of this module at `now` (None: the module has no state for the key).
    fn describe(state: &Self::State, key: &str, policies: &Policies<Self::Policy>, now: &Now) -> Option<Vec<(&'static str, String)>>;
}

/// Codes that only the engine may answer with. A module that returns one (or a bad field name) gets
/// `MODULE_FAULT why=BAD_REFUSAL` or `why=BAD_ANSWER`, and nothing is written.
pub const RESERVED: &[&str] = &[
    "COMMITTED", "OK", "STATE", "REPLAY", "RECORD", "INITIALIZED", "USAGE", "STALE_STATE_HASH", "DUPLICATE_REQUEST_ID",
    "TENANT_ISOLATION_BREACH", "CORRUPT_WAL", "IO_ERROR", "OUTCOME_UNKNOWN", "DISPATCH_FAILED", "UNSAFE_STORE",
    "STORE_BUSY", "MODULE_FAULT", "MALFORMED_POLICY",
];
/// Repair-field names the engine adds itself.
pub const RESERVED_FIELDS: &[&str] = &["request_id", "seq", "now_ms", "skew_ms", "verdict", "effect", "stale"];
pub const MAX_MODULE_PAYLOAD: usize = 65536;

pub fn refusal(code: &'static str, repair: Vec<(&'static str, String)>, detail: impl Into<String>) -> Refusal {
    Refusal { code, repair, detail: detail.into() }
}

/// Canonical decimal u64: `0`, or a nonzero digit and up to 19 more digits; at most u64::MAX. Nothing else.
pub fn dec_u64(s: &str) -> Option<u64> {
    let canonical = s == "0" || (!s.starts_with('0') && (1..=20).contains(&s.len()) && s.bytes().all(|b| b.is_ascii_digit()));
    if !canonical { return None }
    s.parse::<u64>().ok()
}

/// The fields of a policy object: exactly the envelope keys and `keys`, each value a JSON string. Err names the
/// first fault. Values are returned as text; the module parses them (`dec_u64` for numbers).
pub fn policy_fields<'a>(doc: &'a J, keys: &[&str]) -> Result<BTreeMap<String, &'a str>, String> {
    let J::Obj(fields) = doc else { return Err("NOT_OBJECT".into()) };
    let mut out = BTreeMap::new();
    for (k, v) in fields {
        if ["primitive", "version", "name"].contains(&k.as_str()) { continue }
        if !keys.contains(&k.as_str()) { return Err(format!("UNKNOWN_KEY {}", wire_value(k))) }
        let J::Str(s) = v else { return Err(format!("NOT_STRING {k}")) };
        out.insert(k.clone(), s.as_str());
    }
    for k in keys {
        if !out.contains_key(*k) { return Err(format!("MISSING {k}")) }
    }
    Ok(out)
}

/// Percent-encoding of a repair value: bytes outside `[A-Za-z0-9._~:/@$\[\]+,-]` become `%XX` (so `%`, space, `=`
/// and every non-printable byte are encoded). A client decodes with standard percent-decoding.
pub fn wire_value(s: &str) -> String {
    let mut o = String::with_capacity(s.len());
    for b in s.bytes() {
        if b.is_ascii_alphanumeric() || b"._~:/@$[]+,-".contains(&b) { o.push(b as char) } else { o.push_str(&format!("%{b:02X}")) }
    }
    o
}
