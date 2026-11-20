//! Policy engine of the MCP airlock: policy file, fixed rules, tenant binds, fact-bound sub-caps,
//! scoped result filter. Owner: worker POLICY; round 3 repairs by REPAIR-POLICY (REVIEW-B findings 1, 2, 3).
//! NATIVE CHECK and FINITE TEST only. Nothing here is proved. Standard library only. No floating point.
//!
//! # Policy file (`--policy`, at most 1 MiB, strict JSON through `crate::json`)
//!
//! ```text
//! {"version": 1,                         required; the JSON number 1
//!  "tools": { "<name>": <tool>, ... },   required; an object; may be empty
//!  "clearing": { ... }}                  optional; any object; opaque to the proxy (Phase 3)
//! ```
//! Any other top-level key is refused. A tool name is 1 to 128 bytes, no control byte.
//! `<tool>` is an object with a required `"kind"`:
//!
//! - `{"kind": "passthrough"}`: no other key.
//! - `{"kind": "mutating", "rules": [<rule>...], "subcaps": [<subcap>...], "bind": [<bind>...],
//!   "args": "open" | "closed", "scope": [<key>...], "labels": "required" | "optional"}`: every key except
//!   `kind` is optional. `bind` and `scope`, when present, have 1 or more entries. `scope` and `labels`
//!   come together: each needs the other (a mutating result is often an acknowledgement with no label, so
//!   the author must choose). Default: `"args": "open"`.
//! - `{"kind": "sensitive_read", "scope": [<key>...]}`: `scope` required, 1 or more keys. Labels are
//!   always required for a read (no `labels` key).
//!
//! A scope `<key>` is 1 to 64 bytes of `[A-Za-z0-9_]` with at least one letter or digit. Two scope keys
//! of one tool must not have the same normalized form (see "Key normalization").
//!
//! `<rule>` = `{"arg": "<name>", ...}` with exactly ONE family of constraints:
//! - numeric: `"max": <dec>` and/or `"min": <dec>` (at least one). If `min` is absent, the
//!   lower bound is 0: a NEGATIVE value is refused. `min > max` is refused at load.
//! - string: `"equals": "<s>"` or `"one_of": ["<s>", ...]` (non-empty list).
//!
//! `<subcap>` = `{"arg": "<name>", "max_fact": "<template>", "min": <dec>?}`. The template is a fact
//! name with placeholders, for example `max_mg/{patient_id}/{medication}`. A placeholder name is
//! 1 to 64 bytes of `[A-Za-z0-9_]`. A literal part must not contain `{` or `}`. Default `min` is 0.
//!
//! `<bind>` = `{"fact": "<template>", "session": "<key>"}`, for example
//! `{"fact": "clinic/{patient_id}", "session": "clinic_id"}`. Same template syntax as `max_fact`. The session
//! key is 1 to 64 bytes of `[A-Za-z0-9_]`. Meaning: the object that the call names belongs to the session's
//! tenant. The TRUSTED fact named by the template must exist, must be an id fact, and its id must be equal
//! byte for byte to the session value of that key.
//!
//! `"args": "closed"`: every argument name must be named by the tool's policy: the `arg` of a rule or a
//! sub-cap, or a placeholder of a `max_fact` or `bind` template. Any other argument refuses the call (`ARGS`).
//! With `"args": "open"` (the default) an argument that nothing names passes with ANY value.
//!
//! `<dec>` = a JSON number, or a JSON string with the same grammar (see "Decimals").
//! An argument name is 1 to 128 bytes, no control byte.
//!
//! # Facts file (`--facts`, optional, at most 1 MiB)
//!
//! A flat JSON object: fact name (1 to 512 bytes, no control byte) -> value. A value is one of:
//! - `<dec>`: a decimal fact, for sub-caps (for example `"max_mg/PT-A-001/metoprolol": "50"`);
//! - `{"id": "<s>"}`: an id fact, for binds (for example `"clinic/PT-A-001": {"id": "Clinic_Alpha"}`).
//!   `<s>` is 1 to 256 bytes, no control byte (the syntax of a session value). The object has no other key.
//! Any other value is refused at load. Duplicate names are refused (the parser refuses them). This file is
//! the TRUSTED store; the upstream server is never asked for a fact. A decimal fact never satisfies a bind;
//! an id fact never satisfies a sub-cap. With no facts file, every sub-cap and every bind refuses.
//!
//! # Session (`--session k=v`)
//!
//! Keys are 1 to 64 bytes of `[A-Za-z0-9_]`; values are 1 to 256 bytes, no control byte.
//! A duplicate key is refused. A scope key absent from the session refuses every result of that tool;
//! a bind session key absent from the session refuses every call of that tool.
//!
//! # Decimals (exact; text comparison, never floating point)
//!
//! Grammar = the RFC 8259 number grammar: `-?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][+-]?[0-9]+)?`.
//! So `0500`, `+5`, `.5`, `5.`, ` 5`, `0x10`, `NaN`, `Infinity` are refused. `5e2` is EXACTLY 500
//! (the exponent is exact digit shifting, not a float). Limits: text at most 256 bytes, exponent
//! at most 6 digits. Anything outside the grammar or limits is refused, not rounded.
//! `-0`, `-0.0`, `-0e5` are exactly zero; they count as zero (not negative), so a default
//! `min` of 0 allows them. `500.00`, `500.0`, `500`, `5e2`, `5.00E+2` are all equal.
//!
//! # check_mutation (default deny), in this order; the first failure refuses the call
//!
//! 1. The tool must be mutating (`SHAPE`, `NOT_IN_POLICY`) and `args` must be an object (`SHAPE`).
//! 2. Binds (code `SCOPE_BIND`, `subcap = false`). A missing template argument, a template argument that is
//!    not a safe string or number (see below), a missing session value, a missing fact, a decimal fact,
//!    and an id that differs from the session value ALL give the one code `SCOPE_BIND`. The binds come
//!    FIRST, so a call on an object of another tenant gives `SCOPE_BIND` whatever its other arguments are
//!    (any dose, an unknown medication, an extra argument).
//! 3. `"args": "closed"`: an argument that the policy does not name (code `ARGS`, `subcap = false`).
//! 4. Rules (code `RULE`, `subcap = false`): a missing argument, a non-decimal argument (numeric rule), a
//!    non-string argument (string rule), a value out of bounds.
//! 5. Sub-caps (code `SUBCAP`, `subcap = true`): a missing or non-decimal capped argument, a missing
//!    template argument, a template argument that is not a safe string or number, a missing fact, an id
//!    fact, a value above the fact or below `min`.
//!
//! A template value is a JSON string or number of 1 to 128 bytes of `[A-Za-z0-9_.:@+-]` (so one argument
//! cannot forge `/`, `{`, `}` or another fact name). A number keeps its JSON text: `1001` and `1001.0`
//! name DIFFERENT facts; the wrong one is missing, so the call is refused (fail closed).
//!
//! # Codes and what a caller can learn (REVIEW-B finding 3)
//!
//! `Deny.code` is the only policy text that the proxy sends to the client. `Deny.detail` names facts and
//! values; it is for the proxy's stderr only. The code alone does not tell whether a fact exists or what
//! its value is: `SCOPE_BIND` is one code for "bind fact missing", "bind fact differs" and "bind fact is
//! not an id"; `SUBCAP` is one code for "fact missing", "fact exceeded", "below the minimum" and a bad
//! argument. Limits of this: (a) the client still sees OK against `SUBCAP`, so with its own objects it can
//! find a cap by binary search on the value, and it can tell a missing cap (every value refused) from a
//! present one (a small value passes). With a bind, this works only on objects whose bind fact equals the
//! session value (its own tenant). (b) A tool with sub-caps and NO bind (any policy that does not add one)
//! still answers OK or `SUBCAP` for objects of every tenant, so a caller can learn another tenant's caps.
//! (c) The proxy sends the verdict word with the code (`BLOCKED_POLICY` for `SCOPE_BIND`, `BLOCKED_SUBCAP`
//! for `SUBCAP`); it carries no more than the code.
//!
//! # check_read_result (scoped result filter, fail closed)
//!
//! It runs for every `sensitive_read` tool and for every `mutating` tool with a `scope` list
//! (`filters_result` is true exactly for these). Input: the `result` value of the upstream `tools/call`
//! response. Accepted shape only: `{"content": [<item>...], "structuredContent": {...}?, "isError": <bool>?}`.
//! Any other key (also `_meta`) is refused. An `<item>` must be exactly `{"type": "text", "text": "<s>"}`; an
//! image, audio, resource, resource_link, or an item with other keys (also `annotations`) is refused.
//! `isError: true` is refused (`UPSTREAM_ERROR`): its free text may carry PHI and has no labels.
//! Each `text` must parse as strict JSON (else `NOT_JSON`). Each PART (`structuredContent`, and each
//! text item) is walked through all objects, arrays, strings and object KEYS. For every scope key S:
//! - Label rule: every object key whose normalized form CONTAINS norm(S) (a "scope-variant key", for example
//!   `referring_clinic_id`) must be 1 to 128 bytes of `[A-Za-z0-9_ -]` and its normalized form must END
//!   with norm(S) (else `SCOPE_IN_TEXT`), and its value must be a string equal byte for byte to the session
//!   value (else `SCOPE`). Only a key whose normalized form EQUALS norm(S) counts as a label.
//! - Each part must contain at least one label for each scope key (else `UNLABELLED`); so an empty list is
//!   refused, and a result with no part is refused (`UNLABELLED`). Exception: a mutating tool with
//!   `"labels": "optional"` skips these two checks (its result is an acknowledgement and may have no label).
//! - JSON-like text: a string (value OR key) whose first character that is not Unicode white space is
//!   `{`, `[` or `"`. If it parses as strict JSON, it is walked too (up to 4 levels of JSON in strings;
//!   deeper is refused, `NESTED_TOO_DEEP`); its labels count for its part. If the strict parse fails for ANY
//!   reason (bad syntax, trailing text, a duplicate key, more than 64 levels, a leading form feed), the text
//!   check below runs (`SCOPE_IN_TEXT`) and then the string is refused anyway (`NESTED_NOT_JSON`).
//! - Text check, on every string value and every key that is not JSON-like and not a scope-variant key:
//!   the text is refused (`SCOPE_IN_TEXT`) when its normalized form contains norm(S), for example
//!   `CLINIC-ID: Clinic_Beta` or `clinicId=Clinic_Beta`. The check runs again after each of up to 4 rounds
//!   of `\uXXXX` decoding of the text (a literal backslash-u sequence; an escaped backslash,
//!   backslash-u-005c, can make a new one).
//!   A text that still holds a `\uXXXX` sequence after 4 rounds is refused (`ESCAPED_TEXT`).
//!
//! Key normalization: drop every byte that is not an ASCII letter or digit, then lowercase. So
//! `clinic_id`, `clinicId`, `CLINIC-ID`, `clinic id` are one key.
//!
//! # Known limits (what still passes; FINITE TEST against REVIEW-B `a1`, nothing proved)
//!
//! - An unlabelled record next to a labelled record in one part passes: the part has one label. Only
//!   "every scope-variant key carries the session value" and "each part has a label" are checked
//!   (REVIEW-B `a1` row 2: `{"clinic_id":"Clinic_Alpha","rows":[{"name":"Beta-One"}]}` passes).
//! - Another label word is not a scope key: `clinic`, `tenant`, `site`, `org` (`a1` row 3).
//! - Non-ASCII lookalikes are not seen: normalization keeps only ASCII letters and digits, so a key or a
//!   text with a Cyrillic `і` (`clinіc_id`, `a1` row 4) or with fullwidth letters is not the scope key.
//! - Free text of another tenant with no scope key name in it passes, as a value or as a key (a name, a
//!   note, a date). This includes the words BEFORE the scope name in a scope-variant key:
//!   `{"Clinic_Beta_Beta_One_clinic_id": "Clinic_Alpha"}` passes, and its key text reaches the client.
//! - Other encodings are not decoded: base64, URL encoding (`%5F`), HTML entities, `\x5f`, CSV, XML. Only
//!   `\uXXXX` is decoded, and only for the scope-name search.
//! - Text that does not START like JSON is plain text even when JSON follows (`note {"clinic":"B"}`): only
//!   the scope-name search applies to it.
//! - Trust in the upstream labels: a server that writes the session value on a foreign record defeats this
//!   filter. This filter checks labels, not the truth of the data.
//! - With `"labels": "optional"` (a mutating tool), a result with no scope key at all passes. The filter then
//!   refuses only scope-variant keys with another value, scope names in text, bad JSON-like text and bad
//!   shapes. The bind, not the filter, keeps the call on the session's tenant.
//! - False refusals (fail closed, by design): a text whose normalized form contains norm(S) by chance
//!   (`Clinic identifier` holds `clinicid`; `example.org id` holds `orgid`), and a text that starts with
//!   `{`, `[` or `"` and is not strict JSON (`[draft] note`, `"quoted" words`).
//!
//! # Shipped example policies (`examples/archia_mcp_showcase/policies/`)
//!
//! - `healthcare.policy.json`: `update_dosage` has the bind `clinic/{patient_id}` == session `clinic_id`, a
//!   sub-cap `mg <= max_mg/{patient_id}/{medication}`, `"args": "closed"` (only `patient_id`, `medication`
//!   and `mg`), and a result filter `scope: ["clinic_id"]` with `"labels": "optional"`: the server's
//!   update result has no `clinic_id` key, so required labels would drop every result. `get_patient_chart`
//!   has `scope: ["clinic_id"]`. `healthcare.facts.json` has one `clinic/<patient_id>` id fact per patient of
//!   `healthcare_server.py` and one `max_mg/<patient_id>/<medication>` fact per medication, both copied by
//!   hand from the server's data. Nothing detects a drift between this file and the server.
//! - `fintech.policy.json` binds NOTHING. `issue_payout` has no tenant argument, and its `invoice_id` is
//!   not bound to `org_id`: the policy does NOT stop a payout against an invoice of another organisation
//!   (for example `INV-B-2001` of `Org_Beta` from an `Org_Alpha` session). Its only constraint is
//!   `0 <= amount <= 500.00`; `invoice_id` and `vendor` pass with any value (`"args": "open"`; the server
//!   itself refuses unknown argument names). It has no result filter: the payout result (`status`,
//!   `payout_id`, `amount`, `invoice_id`, `vendor`, `balance`) carries no `org_id`, so a filter could check
//!   only the shape. `list_invoices` has `scope: ["org_id"]`.
use crate::json::{self, J};
use std::cmp::Ordering;
use std::io::Read;

const MAX_FILE: u64 = 1 << 20;
const MAX_DEC_TEXT: usize = 256;
const MAX_EXP_DIGITS: usize = 6;
const MAX_NEST: usize = 4;
const MAX_TEMPLATE_VALUE: usize = 128;
const MAX_ID: usize = 256;
const MAX_VARIANT_KEY: usize = 128;
const UNESCAPE_ROUNDS: usize = 4;

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum Kind {
    Mutating,
    SensitiveRead,
    Passthrough,
}

/// Why a call or a result is refused. `code` is a short stable word (for example SUBCAP, SCOPE_BIND, RULE,
/// SCOPE, SHAPE); it is the ONLY part that the proxy sends to the client. `detail` is for stderr only: it
/// names facts and values (see "Codes and what a caller can learn").
#[derive(Debug)]
pub struct Deny {
    pub subcap: bool,
    pub code: &'static str,
    pub detail: String,
}

fn deny(code: &'static str, detail: String) -> Deny {
    Deny { subcap: false, code, detail }
}
fn deny_sub(detail: String) -> Deny {
    Deny { subcap: true, code: "SUBCAP", detail }
}
fn deny_bind(detail: String) -> Deny {
    Deny { subcap: false, code: "SCOPE_BIND", detail }
}

/// An exact decimal: value = (-1)^neg * digits * 10^exp. `digits` has no leading and no trailing
/// zero ('0'..'9' bytes); empty digits = zero, and zero always has neg = false.
#[derive(Debug, Clone, PartialEq)]
struct Dec {
    neg: bool,
    digits: Vec<u8>,
    exp: i64,
}

impl Dec {
    fn parse(t: &str) -> Option<Dec> {
        if t.is_empty() || t.len() > MAX_DEC_TEXT {
            return None;
        }
        let b = t.as_bytes();
        let mut i = 0;
        let neg = b[0] == b'-';
        if neg {
            i += 1;
        }
        let int_start = i;
        while i < b.len() && b[i].is_ascii_digit() {
            i += 1;
        }
        let int = &b[int_start..i];
        if int.is_empty() || (int.len() > 1 && int[0] == b'0') {
            return None;
        }
        let mut frac: &[u8] = &[];
        if i < b.len() && b[i] == b'.' {
            i += 1;
            let s = i;
            while i < b.len() && b[i].is_ascii_digit() {
                i += 1;
            }
            frac = &b[s..i];
            if frac.is_empty() {
                return None;
            }
        }
        let mut e: i64 = 0;
        if i < b.len() && (b[i] == b'e' || b[i] == b'E') {
            i += 1;
            let mut eneg = false;
            if i < b.len() && (b[i] == b'+' || b[i] == b'-') {
                eneg = b[i] == b'-';
                i += 1;
            }
            let s = i;
            while i < b.len() && b[i].is_ascii_digit() {
                i += 1;
            }
            let ed = &b[s..i];
            if ed.is_empty() || ed.len() > MAX_EXP_DIGITS {
                return None;
            }
            for &c in ed {
                e = e * 10 + (c - b'0') as i64;
            }
            if eneg {
                e = -e;
            }
        }
        if i != b.len() {
            return None;
        }
        let mut digits: Vec<u8> = int.iter().chain(frac.iter()).copied().collect();
        let mut exp = e - frac.len() as i64;
        let lead = digits.iter().take_while(|&&c| c == b'0').count();
        digits.drain(..lead);
        while digits.last() == Some(&b'0') {
            digits.pop();
            exp += 1;
        }
        if digits.is_empty() {
            return Some(Dec { neg: false, digits, exp: 0 });
        }
        Some(Dec { neg, digits, exp })
    }

    fn from_json(v: &J) -> Option<Dec> {
        match v {
            J::Num(t) | J::Str(t) => Dec::parse(t),
            _ => None,
        }
    }

    fn zero() -> Dec {
        Dec { neg: false, digits: Vec::new(), exp: 0 }
    }

    fn cmp_mag(a: &Dec, b: &Dec) -> Ordering {
        match (a.digits.is_empty(), b.digits.is_empty()) {
            (true, true) => return Ordering::Equal,
            (true, false) => return Ordering::Less,
            (false, true) => return Ordering::Greater,
            _ => {}
        }
        // Position of the most significant digit.
        let la = a.digits.len() as i64 + a.exp;
        let lb = b.digits.len() as i64 + b.exp;
        if la != lb {
            return la.cmp(&lb);
        }
        let n = a.digits.len().max(b.digits.len());
        for i in 0..n {
            let x = a.digits.get(i).copied().unwrap_or(b'0');
            let y = b.digits.get(i).copied().unwrap_or(b'0');
            if x != y {
                return x.cmp(&y);
            }
        }
        Ordering::Equal
    }

    fn cmp(&self, o: &Dec) -> Ordering {
        match (self.neg, o.neg) {
            (false, true) => Ordering::Greater,
            (true, false) => Ordering::Less,
            (false, false) => Dec::cmp_mag(self, o),
            (true, true) => Dec::cmp_mag(o, self),
        }
    }
}

#[derive(Debug)]
enum Rule {
    Num { arg: String, min: Dec, max: Option<Dec> },
    Str { arg: String, allowed: Vec<String> },
}

#[derive(Debug)]
enum Part {
    Lit(String),
    Arg(String),
}

#[derive(Debug)]
struct Subcap {
    arg: String,
    template: Vec<Part>,
    template_text: String,
    min: Dec,
}

#[derive(Debug)]
struct Bind {
    template: Vec<Part>,
    template_text: String,
    session: String,
}

/// A trusted fact: a decimal (sub-caps) or an id (binds).
#[derive(Debug)]
enum Fact {
    Dec(Dec),
    Id(String),
}

#[derive(Debug)]
struct Tool {
    name: String,
    kind: Kind,
    rules: Vec<Rule>,
    subcaps: Vec<Subcap>,
    binds: Vec<Bind>,
    closed: bool,
    scope: Vec<String>,
    labels_required: bool,
}

pub struct Policy {
    tools: Vec<Tool>,
    facts: Vec<(String, Fact)>,
    session: Vec<(String, String)>,
}

fn read_bounded(path: &str, what: &str) -> Result<String, String> {
    let f = std::fs::File::open(path).map_err(|e| format!("{what}: cannot open {path}: {e}"))?;
    let md = f.metadata().map_err(|e| format!("{what}: cannot stat {path}: {e}"))?;
    if !md.is_file() {
        return Err(format!("{what}: {path} is not a regular file"));
    }
    if md.len() > MAX_FILE {
        return Err(format!("{what}: {path} is larger than {MAX_FILE} bytes"));
    }
    let mut buf = Vec::new();
    f.take(MAX_FILE + 1)
        .read_to_end(&mut buf)
        .map_err(|e| format!("{what}: cannot read {path}: {e}"))?;
    if buf.len() as u64 > MAX_FILE {
        return Err(format!("{what}: {path} is larger than {MAX_FILE} bytes"));
    }
    String::from_utf8(buf).map_err(|_| format!("{what}: {path} is not UTF-8"))
}

/// `session`: the `--session key=value` pairs of the command line (for example clinic_id=Clinic_Alpha).
pub fn load(policy_path: &str, facts_path: Option<&str>, session: &[(String, String)]) -> Result<Policy, String> {
    let p = read_bounded(policy_path, "policy")?;
    let f = match facts_path {
        Some(fp) => Some(read_bounded(fp, "facts")?),
        None => None,
    };
    load_from_text(&p, f.as_deref(), session)
}

fn no_ctl(s: &str) -> bool {
    !s.chars().any(|c| c.is_control())
}
fn ident(s: &str, max: usize) -> bool {
    !s.is_empty()
        && s.len() <= max
        && s.bytes().all(|c| c.is_ascii_alphanumeric() || c == b'_')
}
fn norm_key(k: &str) -> String {
    k.bytes().filter(|c| c.is_ascii_alphanumeric()).map(|c| (c.to_ascii_lowercase()) as char).collect()
}
/// A session value or an id fact: 1 to 256 bytes, no control byte.
fn id_text(s: &str) -> bool {
    !s.is_empty() && s.len() <= MAX_ID && no_ctl(s)
}

fn obj<'a>(v: &'a J, what: &str) -> Result<&'a Vec<(String, J)>, String> {
    match v {
        J::Obj(f) => Ok(f),
        _ => Err(format!("{what}: not an object")),
    }
}
fn arr<'a>(v: &'a J, what: &str) -> Result<&'a Vec<J>, String> {
    match v {
        J::Arr(a) => Ok(a),
        _ => Err(format!("{what}: not an array")),
    }
}
fn only_keys(f: &[(String, J)], allowed: &[&str], what: &str) -> Result<(), String> {
    for (k, _) in f {
        if !allowed.contains(&k.as_str()) {
            return Err(format!("{what}: unknown key {k:?}"));
        }
    }
    Ok(())
}
fn arg_name(v: Option<&J>, what: &str) -> Result<String, String> {
    match v {
        Some(J::Str(s)) if !s.is_empty() && s.len() <= 128 && no_ctl(s) => Ok(s.clone()),
        Some(_) => Err(format!("{what}: \"arg\" must be a string of 1 to 128 bytes, no control byte")),
        None => Err(format!("{what}: \"arg\" missing")),
    }
}
fn dec_field(v: &J, what: &str) -> Result<Dec, String> {
    Dec::from_json(v).ok_or_else(|| format!("{what}: not an exact decimal"))
}

fn parse_rule(v: &J, what: &str) -> Result<Rule, String> {
    let f = obj(v, what)?;
    only_keys(f, &["arg", "max", "min", "equals", "one_of"], what)?;
    let arg = arg_name(v.get("arg"), what)?;
    let numeric = v.get("max").is_some() || v.get("min").is_some();
    let stringy = v.get("equals").is_some() || v.get("one_of").is_some();
    match (numeric, stringy) {
        (true, true) => Err(format!("{what}: numeric and string constraints in one rule")),
        (false, false) => Err(format!("{what}: no constraint")),
        (true, false) => {
            let max = match v.get("max") {
                Some(m) => Some(dec_field(m, &format!("{what}.max"))?),
                None => None,
            };
            let min = match v.get("min") {
                Some(m) => dec_field(m, &format!("{what}.min"))?,
                None => Dec::zero(),
            };
            if let Some(mx) = &max {
                if min.cmp(mx) == Ordering::Greater {
                    return Err(format!("{what}: min is greater than max"));
                }
            }
            Ok(Rule::Num { arg, min, max })
        }
        (false, true) => {
            if v.get("equals").is_some() && v.get("one_of").is_some() {
                return Err(format!("{what}: both equals and one_of"));
            }
            let allowed = if let Some(e) = v.get("equals") {
                match e {
                    J::Str(s) => vec![s.clone()],
                    _ => return Err(format!("{what}.equals: not a string")),
                }
            } else {
                let a = arr(v.get("one_of").unwrap(), &format!("{what}.one_of"))?;
                if a.is_empty() {
                    return Err(format!("{what}.one_of: empty"));
                }
                let mut out = Vec::new();
                for x in a {
                    match x {
                        J::Str(s) => out.push(s.clone()),
                        _ => return Err(format!("{what}.one_of: not all strings")),
                    }
                }
                out
            };
            Ok(Rule::Str { arg, allowed })
        }
    }
}

fn parse_template(t: &str, what: &str) -> Result<Vec<Part>, String> {
    if t.is_empty() || t.len() > 512 || !no_ctl(t) {
        return Err(format!("{what}: a fact template must be 1 to 512 bytes, no control byte"));
    }
    let mut parts = Vec::new();
    let mut rest = t;
    while !rest.is_empty() {
        if let Some(r) = rest.strip_prefix('{') {
            let end = r.find('}').ok_or_else(|| format!("{what}: unclosed '{{' in a fact template"))?;
            let name = &r[..end];
            if !ident(name, 64) {
                return Err(format!("{what}: bad placeholder {name:?} in a fact template"));
            }
            parts.push(Part::Arg(name.to_string()));
            rest = &r[end + 1..];
        } else {
            let end = rest.find(|c| c == '{' || c == '}').unwrap_or(rest.len());
            if end == 0 {
                return Err(format!("{what}: stray '}}' in a fact template"));
            }
            parts.push(Part::Lit(rest[..end].to_string()));
            rest = &rest[end..];
        }
    }
    Ok(parts)
}

fn parse_subcap(v: &J, what: &str) -> Result<Subcap, String> {
    let f = obj(v, what)?;
    only_keys(f, &["arg", "max_fact", "min"], what)?;
    let arg = arg_name(v.get("arg"), what)?;
    let template_text = match v.get("max_fact") {
        Some(J::Str(s)) => s.clone(),
        Some(_) => return Err(format!("{what}.max_fact: not a string")),
        None => return Err(format!("{what}: \"max_fact\" missing")),
    };
    let template = parse_template(&template_text, what)?;
    let min = match v.get("min") {
        Some(m) => dec_field(m, &format!("{what}.min"))?,
        None => Dec::zero(),
    };
    Ok(Subcap { arg, template, template_text, min })
}

fn parse_bind(v: &J, what: &str) -> Result<Bind, String> {
    let f = obj(v, what)?;
    only_keys(f, &["fact", "session"], what)?;
    let template_text = match v.get("fact") {
        Some(J::Str(s)) => s.clone(),
        Some(_) => return Err(format!("{what}.fact: not a string")),
        None => return Err(format!("{what}: \"fact\" missing")),
    };
    let template = parse_template(&template_text, what)?;
    let session = match v.get("session") {
        Some(J::Str(s)) if ident(s, 64) => s.clone(),
        Some(_) => return Err(format!("{what}.session: must be 1 to 64 bytes of [A-Za-z0-9_]")),
        None => return Err(format!("{what}: \"session\" missing")),
    };
    Ok(Bind { template, template_text, session })
}

fn parse_scope(v: &J, what: &str) -> Result<Vec<String>, String> {
    let s = arr(v, &format!("{what}.scope"))?;
    if s.is_empty() {
        return Err(format!("{what}.scope: empty"));
    }
    let mut norms: Vec<String> = Vec::new();
    let mut out = Vec::new();
    for x in s {
        let k = match x {
            J::Str(k) if ident(k, 64) && !norm_key(k).is_empty() => k.clone(),
            _ => return Err(format!("{what}.scope: each key must be 1 to 64 bytes of [A-Za-z0-9_]")),
        };
        let n = norm_key(&k);
        if norms.contains(&n) {
            return Err(format!("{what}.scope: two keys normalize to {n:?}"));
        }
        norms.push(n);
        out.push(k);
    }
    Ok(out)
}

fn parse_tool(name: &str, v: &J) -> Result<Tool, String> {
    let what = format!("tools.{name}");
    if name.is_empty() || name.len() > 128 || !no_ctl(name) {
        return Err(format!("tool name {name:?}: must be 1 to 128 bytes, no control byte"));
    }
    let f = obj(v, &what)?;
    let kind = match v.get("kind") {
        Some(J::Str(k)) if k == "mutating" => Kind::Mutating,
        Some(J::Str(k)) if k == "sensitive_read" => Kind::SensitiveRead,
        Some(J::Str(k)) if k == "passthrough" => Kind::Passthrough,
        Some(_) => return Err(format!("{what}.kind: must be \"mutating\", \"sensitive_read\" or \"passthrough\"")),
        None => return Err(format!("{what}: \"kind\" missing")),
    };
    let mut t = Tool {
        name: name.to_string(),
        kind,
        rules: Vec::new(),
        subcaps: Vec::new(),
        binds: Vec::new(),
        closed: false,
        scope: Vec::new(),
        labels_required: true,
    };
    match kind {
        Kind::Passthrough => only_keys(f, &["kind"], &what)?,
        Kind::Mutating => {
            only_keys(f, &["kind", "rules", "subcaps", "bind", "args", "scope", "labels"], &what)?;
            if let Some(r) = v.get("rules") {
                for (i, x) in arr(r, &format!("{what}.rules"))?.iter().enumerate() {
                    t.rules.push(parse_rule(x, &format!("{what}.rules[{i}]"))?);
                }
            }
            if let Some(s) = v.get("subcaps") {
                for (i, x) in arr(s, &format!("{what}.subcaps"))?.iter().enumerate() {
                    t.subcaps.push(parse_subcap(x, &format!("{what}.subcaps[{i}]"))?);
                }
            }
            if let Some(b) = v.get("bind") {
                let a = arr(b, &format!("{what}.bind"))?;
                if a.is_empty() {
                    return Err(format!("{what}.bind: empty"));
                }
                for (i, x) in a.iter().enumerate() {
                    t.binds.push(parse_bind(x, &format!("{what}.bind[{i}]"))?);
                }
            }
            t.closed = match v.get("args") {
                None => false,
                Some(J::Str(s)) if s == "open" => false,
                Some(J::Str(s)) if s == "closed" => true,
                Some(_) => return Err(format!("{what}.args: must be \"open\" or \"closed\"")),
            };
            if let Some(s) = v.get("scope") {
                t.scope = parse_scope(s, &what)?;
            }
            t.labels_required = match v.get("labels") {
                None if t.scope.is_empty() => true,
                None => return Err(format!("{what}: a mutating \"scope\" needs an explicit \"labels\"")),
                Some(_) if t.scope.is_empty() => return Err(format!("{what}.labels: needs a \"scope\" list")),
                Some(J::Str(s)) if s == "required" => true,
                Some(J::Str(s)) if s == "optional" => false,
                Some(_) => return Err(format!("{what}.labels: must be \"required\" or \"optional\"")),
            };
        }
        Kind::SensitiveRead => {
            only_keys(f, &["kind", "scope"], &what)?;
            t.scope = parse_scope(v.get("scope").ok_or_else(|| format!("{what}: \"scope\" missing"))?, &what)?;
        }
    }
    Ok(t)
}

fn parse_fact(k: &str, v: &J) -> Result<Fact, String> {
    match v {
        J::Obj(f) => {
            only_keys(f, &["id"], &format!("facts.{k}"))?;
            match v.get("id") {
                Some(J::Str(s)) if id_text(s) => Ok(Fact::Id(s.clone())),
                Some(_) => Err(format!("facts.{k}.id: must be a string of 1 to {MAX_ID} bytes, no control byte")),
                None => Err(format!("facts.{k}: an object fact must be {{\"id\": \"<s>\"}}")),
            }
        }
        _ => Ok(Fact::Dec(dec_field(v, &format!("facts.{k}"))?)),
    }
}

/// The text form of `load`. Used by `load` and by the finite tests.
pub(crate) fn load_from_text(policy: &str, facts: Option<&str>, session: &[(String, String)]) -> Result<Policy, String> {
    let root = json::parse(policy).map_err(|e| format!("policy: bad JSON ({e})"))?;
    let f = obj(&root, "policy")?;
    only_keys(f, &["version", "tools", "clearing"], "policy")?;
    match root.get("version") {
        Some(J::Num(n)) if n == "1" => {}
        Some(_) => return Err("policy.version: must be the number 1".into()),
        None => return Err("policy: \"version\" missing".into()),
    }
    if let Some(c) = root.get("clearing") {
        obj(c, "policy.clearing")?;
    }
    let tf = obj(root.get("tools").ok_or("policy: \"tools\" missing")?, "policy.tools")?;
    let mut tools = Vec::new();
    for (name, v) in tf {
        tools.push(parse_tool(name, v)?);
    }

    let mut fv = Vec::new();
    if let Some(ft) = facts {
        let fr = json::parse(ft).map_err(|e| format!("facts: bad JSON ({e})"))?;
        for (k, v) in obj(&fr, "facts")? {
            if k.is_empty() || k.len() > 512 || !no_ctl(k) {
                return Err(format!("facts: bad fact name {k:?}"));
            }
            if fv.iter().any(|(n, _): &(String, Fact)| n == k) {
                return Err(format!("facts: duplicate fact {k:?}"));
            }
            fv.push((k.clone(), parse_fact(k, v)?));
        }
    }

    let mut sv: Vec<(String, String)> = Vec::new();
    for (k, v) in session {
        if !ident(k, 64) {
            return Err(format!("session: bad key {k:?} (1 to 64 bytes of [A-Za-z0-9_])"));
        }
        if !id_text(v) {
            return Err(format!("session: bad value for {k:?} (1 to 256 bytes, no control byte)"));
        }
        if sv.iter().any(|(n, _)| n == k) {
            return Err(format!("session: duplicate key {k:?}"));
        }
        sv.push((k.clone(), v.clone()));
    }
    Ok(Policy { tools, facts: fv, session: sv })
}

fn template_value(v: &J) -> Option<&str> {
    let s = match v {
        J::Str(s) | J::Num(s) => s.as_str(),
        _ => return None,
    };
    let ok = !s.is_empty()
        && s.len() <= MAX_TEMPLATE_VALUE
        && s.bytes().all(|c| c.is_ascii_alphanumeric() || matches!(c, b'_' | b'.' | b':' | b'@' | b'+' | b'-'));
    if ok {
        Some(s)
    } else {
        None
    }
}

/// The fact name of a template for these arguments. Err = the name of the bad placeholder.
fn fact_name<'a>(template: &'a [Part], args: &J) -> Result<String, (&'a str, &'static str)> {
    let mut name = String::new();
    for p in template {
        match p {
            Part::Lit(l) => name.push_str(l),
            Part::Arg(a) => {
                let av = args.get(a).ok_or((a.as_str(), "missing"))?;
                let tv = template_value(av).ok_or((a.as_str(), "is not a safe string or number"))?;
                name.push_str(tv);
            }
        }
    }
    Ok(name)
}

/// JSON-like text: the first character that is not Unicode white space is `{`, `[` or `"`.
fn json_like(s: &str) -> bool {
    matches!(s.trim_start_matches(char::is_whitespace).chars().next(), Some('{' | '[' | '"'))
}

/// One round of `\uXXXX` decoding (a pair of surrogate escapes gives one character; a lone surrogate
/// escape gives U+FFFD). None = nothing to decode.
fn unescape_u(s: &str) -> Option<String> {
    fn hex4(b: &[u8]) -> Option<u32> {
        if b.len() < 4 {
            return None;
        }
        let t = std::str::from_utf8(&b[..4]).ok()?;
        if !t.bytes().all(|c| c.is_ascii_hexdigit()) {
            return None;
        }
        u32::from_str_radix(t, 16).ok()
    }
    let b = s.as_bytes();
    let mut out: Vec<u8> = Vec::with_capacity(b.len());
    let mut i = 0;
    let mut changed = false;
    while i < b.len() {
        if b[i] == b'\\' && i + 1 < b.len() && b[i + 1] == b'u' {
            if let Some(c) = hex4(&b[i + 2..]) {
                let mut ch = None;
                let mut used = 6;
                if (0xD800..0xDC00).contains(&c) && b.get(i + 6) == Some(&b'\\') && b.get(i + 7) == Some(&b'u') {
                    if let Some(lo) = hex4(&b[i + 8..]) {
                        if (0xDC00..0xE000).contains(&lo) {
                            ch = char::from_u32(0x10000 + ((c - 0xD800) << 10) + (lo - 0xDC00));
                            used = 12;
                        }
                    }
                }
                let ch = ch.or_else(|| char::from_u32(c)).unwrap_or('\u{FFFD}');
                let mut buf = [0u8; 4];
                out.extend_from_slice(ch.encode_utf8(&mut buf).as_bytes());
                i += used;
                changed = true;
                continue;
            }
        }
        out.push(b[i]);
        i += 1;
    }
    if changed {
        Some(String::from_utf8(out).expect("only whole characters are replaced"))
    } else {
        None
    }
}

struct Walk<'a> {
    keys: Vec<(String, String, &'a str)>, // (scope key, normalized key, session value)
    counts: Vec<usize>,
}

impl<'a> Walk<'a> {
    /// The text check: no scope key name in the normalized text, also after `\uXXXX` decoding.
    fn text(&self, s: &str, what: &str) -> Result<(), Deny> {
        let mut cur = std::borrow::Cow::Borrowed(s);
        for round in 0..=UNESCAPE_ROUNDS {
            let n = norm_key(&cur);
            for (k, nk, _) in &self.keys {
                if n.contains(nk.as_str()) {
                    let how = if round == 0 { String::new() } else { format!(" after {round} round(s) of \\u decoding") };
                    return Err(deny("SCOPE_IN_TEXT", format!("{what} contains the scope key name {k:?}{how}")));
                }
            }
            match unescape_u(&cur) {
                Some(next) if round < UNESCAPE_ROUNDS => cur = std::borrow::Cow::Owned(next),
                Some(_) => {
                    return Err(deny("ESCAPED_TEXT", format!("{what} still holds \\u escapes after {UNESCAPE_ROUNDS} rounds")))
                }
                None => return Ok(()),
            }
        }
        Ok(())
    }

    fn value(&mut self, v: &J, level: usize) -> Result<(), Deny> {
        match v {
            J::Obj(fields) => {
                for (k, x) in fields {
                    // Every key is inspected (REVIEW-B finding 2): a JSON-like key is a carrier, walked
                    // or refused like a JSON-like string value.
                    if json_like(k) {
                        self.string(k, level, "an object key")?;
                        self.value(x, level)?;
                        continue;
                    }
                    let nk = norm_key(k);
                    // A key whose normalized form CONTAINS a normalized scope key (for example
                    // `referring_clinic_id`) is a scope-variant key: identifier text that ENDS with the scope
                    // key, with the session value. Only an exact normalized match counts as a label.
                    let mut scoped = false;
                    for i in 0..self.keys.len() {
                        if !nk.contains(self.keys[i].1.as_str()) {
                            continue;
                        }
                        scoped = true;
                        let shape_ok = k.len() <= MAX_VARIANT_KEY
                            && k.bytes().all(|c| c.is_ascii_alphanumeric() || matches!(c, b'_' | b'-' | b' '))
                            && nk.ends_with(self.keys[i].1.as_str());
                        if !shape_ok {
                            return Err(deny(
                                "SCOPE_IN_TEXT",
                                format!("key {k:?} holds the scope key name {:?} but is not a scope-variant key", self.keys[i].0),
                            ));
                        }
                        match x {
                            J::Str(s) if s == self.keys[i].2 => {
                                if nk == self.keys[i].1 {
                                    self.counts[i] += 1;
                                }
                            }
                            J::Str(_) => {
                                return Err(deny("SCOPE", format!("key {k:?} has a value other than the session {}", self.keys[i].0)))
                            }
                            _ => return Err(deny("SCOPE", format!("key {k:?} has a non-string value"))),
                        }
                    }
                    if !scoped {
                        self.text(k, "an object key")?;
                        self.value(x, level)?; // a scoped value is the session value itself: nothing more to walk
                    }
                }
                Ok(())
            }
            J::Arr(items) => {
                for x in items {
                    self.value(x, level)?;
                }
                Ok(())
            }
            J::Str(s) => self.string(s, level, "a string"),
            _ => Ok(()),
        }
    }

    fn string(&mut self, s: &str, level: usize, what: &str) -> Result<(), Deny> {
        if json_like(s) {
            match json::parse(s) {
                Ok(inner) => {
                    if level + 1 > MAX_NEST {
                        return Err(deny("NESTED_TOO_DEEP", format!("JSON nested in strings deeper than {MAX_NEST} levels")));
                    }
                    return self.value(&inner, level + 1);
                }
                Err(e) => {
                    self.text(s, what)?;
                    return Err(deny("NESTED_NOT_JSON", format!("{what} starts like JSON but is not strict JSON ({e})")));
                }
            }
        }
        self.text(s, what)
    }

    fn part(&mut self, v: &J, what: &str, labels_required: bool) -> Result<(), Deny> {
        for c in self.counts.iter_mut() {
            *c = 0;
        }
        self.value(v, 0)?;
        if labels_required {
            for (i, (k, _, _)) in self.keys.iter().enumerate() {
                if self.counts[i] == 0 {
                    return Err(deny("UNLABELLED", format!("{what} has no {k:?} label")));
                }
            }
        }
        Ok(())
    }
}

impl Policy {
    fn tool(&self, name: &str) -> Option<&Tool> {
        self.tools.iter().find(|t| t.name == name)
    }

    fn fact(&self, name: &str) -> Option<&Fact> {
        self.facts.iter().find(|(n, _)| n == name).map(|(_, f)| f)
    }

    fn session_value(&self, key: &str) -> Option<&str> {
        self.session.iter().find(|(n, _)| n == key).map(|(_, v)| v.as_str())
    }

    /// None = the tool is not in the policy: the proxy refuses the call (default deny).
    pub fn kind(&self, tool: &str) -> Option<Kind> {
        self.tool(tool).map(|t| t.kind)
    }

    /// True for every `sensitive_read` tool and for every `mutating` tool with a `scope` list: the proxy
    /// sends the upstream result of such a call through `check_read_result`.
    pub fn filters_result(&self, tool: &str) -> bool {
        match self.tool(tool) {
            Some(t) => t.kind == Kind::SensitiveRead || (t.kind == Kind::Mutating && !t.scope.is_empty()),
            None => false,
        }
    }

    /// Binds, closed arguments, rules and fact-bound sub-caps of one mutating call, in that order.
    /// `args` = `params.arguments`.
    pub fn check_mutation(&self, tool: &str, args: &J) -> Result<(), Deny> {
        let t = match self.tool(tool) {
            Some(t) if t.kind == Kind::Mutating => t,
            Some(_) => return Err(deny("SHAPE", format!("tool {tool:?} is not mutating"))),
            None => return Err(deny("NOT_IN_POLICY", format!("tool {tool:?} is not in the policy"))),
        };
        let fields = match args {
            J::Obj(f) => f,
            _ => return Err(deny("SHAPE", "arguments is not an object".into())),
        };
        // Binds FIRST (REVIEW-B findings 1 and 3): one code for every bind failure.
        for b in &t.binds {
            let name = fact_name(&b.template, args)
                .map_err(|(a, why)| deny_bind(format!("bind template argument {a:?} {why}")))?;
            let sv = self
                .session_value(&b.session)
                .ok_or_else(|| deny_bind(format!("session has no {:?}", b.session)))?;
            match self.fact(&name) {
                Some(Fact::Id(id)) if id == sv => {}
                Some(Fact::Id(_)) => {
                    return Err(deny_bind(format!("fact {name:?} (from {:?}) differs from the session {:?}", b.template_text, b.session)))
                }
                Some(Fact::Dec(_)) => return Err(deny_bind(format!("fact {name:?} is a decimal, not an id"))),
                None => {
                    return Err(deny_bind(format!("fact {name:?} (from {:?}) missing in the trusted store", b.template_text)))
                }
            }
        }
        if t.closed {
            for (k, _) in fields {
                let named = t.rules.iter().any(|r| match r {
                    Rule::Num { arg, .. } | Rule::Str { arg, .. } => arg == k,
                })
                    || t.subcaps.iter().any(|s| &s.arg == k || s.template.iter().any(|p| matches!(p, Part::Arg(a) if a == k)))
                    || t.binds.iter().any(|b| b.template.iter().any(|p| matches!(p, Part::Arg(a) if a == k)));
                if !named {
                    return Err(deny("ARGS", format!("argument {k:?} is not named by the policy (args closed)")));
                }
            }
        }
        for r in &t.rules {
            match r {
                Rule::Num { arg, min, max } => {
                    let v = args.get(arg).ok_or_else(|| deny("RULE", format!("argument {arg:?} missing")))?;
                    let d = Dec::from_json(v).ok_or_else(|| deny("RULE", format!("argument {arg:?} is not an exact decimal")))?;
                    if d.cmp(min) == Ordering::Less {
                        return Err(deny("RULE", format!("argument {arg:?} is below the minimum")));
                    }
                    if let Some(mx) = max {
                        if d.cmp(mx) == Ordering::Greater {
                            return Err(deny("RULE", format!("argument {arg:?} is above the maximum")));
                        }
                    }
                }
                Rule::Str { arg, allowed } => match args.get(arg) {
                    Some(J::Str(s)) if allowed.iter().any(|a| a == s) => {}
                    Some(J::Str(_)) => return Err(deny("RULE", format!("argument {arg:?} is not an allowed value"))),
                    Some(_) => return Err(deny("RULE", format!("argument {arg:?} is not a string"))),
                    None => return Err(deny("RULE", format!("argument {arg:?} missing"))),
                },
            }
        }
        for s in &t.subcaps {
            let v = args.get(&s.arg).ok_or_else(|| deny_sub(format!("argument {:?} missing", s.arg)))?;
            let d = Dec::from_json(v).ok_or_else(|| deny_sub(format!("argument {:?} is not an exact decimal", s.arg)))?;
            let name = fact_name(&s.template, args)
                .map_err(|(a, why)| deny_sub(format!("template argument {a:?} {why}")))?;
            let cap = match self.fact(&name) {
                Some(Fact::Dec(c)) => c,
                Some(Fact::Id(_)) => return Err(deny_sub(format!("fact {name:?} is an id, not a decimal"))),
                None => {
                    return Err(deny_sub(format!("fact {name:?} (from {:?}) missing in the trusted store", s.template_text)))
                }
            };
            if d.cmp(&s.min) == Ordering::Less {
                return Err(deny_sub(format!("argument {:?} is below the sub-cap minimum", s.arg)));
            }
            if d.cmp(cap) == Ordering::Greater {
                return Err(deny_sub(format!("argument {:?} is above the fact {name:?}", s.arg)));
            }
        }
        Ok(())
    }

    /// Scoped result filter over the upstream `result` value of one call of a tool with
    /// `filters_result(tool)` (a sensitive read, or a mutating tool with `scope`). Fail closed.
    pub fn check_read_result(&self, tool: &str, result: &J) -> Result<(), Deny> {
        let t = match self.tool(tool) {
            Some(t) if t.kind == Kind::SensitiveRead => t,
            Some(t) if t.kind == Kind::Mutating && !t.scope.is_empty() => t,
            Some(_) => return Err(deny("SHAPE", format!("tool {tool:?} has no result filter"))),
            None => return Err(deny("NOT_IN_POLICY", format!("tool {tool:?} is not in the policy"))),
        };
        let labels_required = t.kind == Kind::SensitiveRead || t.labels_required;
        let mut keys = Vec::new();
        for k in &t.scope {
            let sv = self.session_value(k).ok_or_else(|| deny("NO_SESSION", format!("session has no {k:?}")))?;
            keys.push((k.clone(), norm_key(k), sv));
        }
        let n = keys.len();
        let mut w = Walk { keys, counts: vec![0; n] };

        let fields = match result {
            J::Obj(f) => f,
            _ => return Err(deny("SHAPE", "result is not an object".into())),
        };
        for (k, _) in fields {
            if !matches!(k.as_str(), "content" | "structuredContent" | "isError") {
                return Err(deny("SHAPE", format!("result has an unknown key {k:?}")));
            }
        }
        match result.get("isError") {
            None | Some(J::Bool(false)) => {}
            Some(J::Bool(true)) => return Err(deny("UPSTREAM_ERROR", "upstream result has isError true".into())),
            Some(_) => return Err(deny("SHAPE", "isError is not a boolean".into())),
        }
        let content = match result.get("content") {
            Some(J::Arr(a)) => a,
            Some(_) => return Err(deny("SHAPE", "content is not an array".into())),
            None => return Err(deny("SHAPE", "content missing".into())),
        };
        let mut parts = 0usize;
        if let Some(sc) = result.get("structuredContent") {
            if !matches!(sc, J::Obj(_)) {
                return Err(deny("SHAPE", "structuredContent is not an object".into()));
            }
            w.part(sc, "structuredContent", labels_required)?;
            parts += 1;
        }
        for (i, item) in content.iter().enumerate() {
            let f = match item {
                J::Obj(f) => f,
                _ => return Err(deny("NOT_TEXT", format!("content[{i}] is not an object"))),
            };
            if item.get("type") != Some(&J::Str("text".into())) {
                return Err(deny("NOT_TEXT", format!("content[{i}] is not a text item")));
            }
            if f.iter().any(|(k, _)| k != "type" && k != "text") {
                return Err(deny("NOT_TEXT", format!("content[{i}] has a key other than type and text")));
            }
            let text = match item.get("text") {
                Some(J::Str(s)) => s,
                _ => return Err(deny("NOT_TEXT", format!("content[{i}].text is not a string"))),
            };
            let v = json::parse(text).map_err(|e| deny("NOT_JSON", format!("content[{i}].text is not strict JSON ({e})")))?;
            w.part(&v, &format!("content[{i}]"), labels_required)?;
            parts += 1;
        }
        if parts == 0 && labels_required {
            return Err(deny("UNLABELLED", "result has no content".into()));
        }
        Ok(())
    }
}
