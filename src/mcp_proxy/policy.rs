//! Policy engine of the MCP airlock: policy file, fixed rules, fact-bound sub-caps, scoped-read filter.
//! Owner: worker POLICY. NATIVE CHECK and FINITE TEST only. Nothing here is proved.
//! Standard library only. No floating point anywhere.
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
//! - `{"kind": "mutating", "rules": [<rule>...], "subcaps": [<subcap>...]}`: both lists optional.
//! - `{"kind": "sensitive_read", "scope": ["clinic_id", ...]}`: `scope` required, 1 or more keys.
//!   A scope key is 1 to 64 bytes of `[A-Za-z0-9_]` with at least one letter or digit. Two scope keys
//!   of one tool must not have the same normalized form (see "Key normalization").
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
//! `<dec>` = a JSON number, or a JSON string with the same grammar (see "Decimals").
//! An argument name is 1 to 128 bytes, no control byte.
//!
//! # Facts file (`--facts`, optional, at most 1 MiB)
//!
//! A flat JSON object: fact name (1 to 512 bytes, no control byte) -> `<dec>`. Duplicate names are
//! refused (the parser refuses them). This file is the TRUSTED store; the upstream server is never
//! asked for a fact. With no facts file, every sub-cap refuses (missing fact).
//!
//! # Session (`--session k=v`)
//!
//! Keys are 1 to 64 bytes of `[A-Za-z0-9_]`; values are 1 to 256 bytes, no control byte.
//! A duplicate key is refused. A scope key absent from the session refuses every read of that tool.
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
//! # check_mutation (default deny)
//!
//! `args` must be an object. Rules first, then sub-caps; the first failure refuses the call.
//! A rule refuses: a missing argument, a non-decimal argument (numeric rule), a non-string argument
//! (string rule), a value out of bounds. Code `RULE`, `subcap = false`.
//! A sub-cap refuses (code `SUBCAP`, `subcap = true`): a missing or non-decimal capped argument,
//! a missing template argument, a template argument that is not a string or number, a template
//! value outside `[A-Za-z0-9_.:@+-]` or longer than 128 bytes or empty (so one argument cannot
//! forge `/`, `{`, `}` or another fact name), a missing fact, a value above the fact or below `min`.
//! A number used in a template keeps its JSON text: `1001` and `1001.0` name DIFFERENT facts;
//! the wrong one is missing, so the call is refused (fail closed).
//!
//! # check_read_result (scoped-read filter, fail closed)
//!
//! Input: the `result` value of the upstream `tools/call` response. Accepted shape only:
//! `{"content": [<item>...], "structuredContent": {...}?, "isError": <bool>?}`. Any other key
//! (also `_meta`) is refused. An `<item>` must be exactly `{"type": "text", "text": "<s>"}`; an image,
//! audio, resource, resource_link, or an item with other keys (also `annotations`) is refused.
//! `isError: true` is refused (`UPSTREAM_ERROR`): its free text may carry PHI and has no labels.
//! Each `text` must parse as strict JSON (else `NOT_JSON`). Each PART (`structuredContent`, and each
//! text item) is walked through all objects and arrays. For every scope key S of the tool:
//! - every object key whose normalized form CONTAINS norm(S) (so also `referring_clinic_id`) must
//!   have a string value equal byte for byte to the session value (else `SCOPE`); only a key whose
//!   normalized form EQUALS norm(S) counts as a label;
//! - each part must contain at least one such key (else `UNLABELLED`); so an empty list is refused;
//! - a result with no part is refused (`UNLABELLED`).
//! Nested JSON in a string: every string value whose first non-blank byte is `{`, `[` or `"` and
//! that parses as strict JSON is walked too (up to 4 nesting levels; deeper is refused). Its labels
//! count for its part. A plain string (not JSON) that contains a scope key name (ASCII case
//! ignored) is refused (`SCOPE_IN_TEXT`), for example the free text `clinic_id: Clinic_Beta`.
//!
//! Key normalization: drop every byte that is not an ASCII letter or digit, then lowercase. So
//! `clinic_id`, `clinicId`, `CLINIC-ID`, `clinic id` are one key.
//!
//! # Known limits (evasions NOT covered)
//!
//! - Another label word: `clinic`, `tenant`, `site`, a non-ASCII lookalike key (`clinіc_id` with a
//!   Cyrillic letter). Those keys are not seen as scope keys.
//! - An unlabelled record next to a labelled record in one part: the part has one label, so it
//!   passes. Only "every scope-key occurrence matches" and "each part has one label" are checked.
//! - PHI of another clinic in free text with no scope key name in it (a name, a note, a date).
//! - Data in another encoding inside a string: base64, URL encoding, CSV, XML, a JSON text that is
//!   not strict (truncated, single quotes). Truncated JSON passes only if it has no scope key name.
//! - Trust in the upstream labels: a server that writes the session clinic on a foreign record
//!   defeats this filter. This filter checks labels, not the truth of the data.
use crate::json::{self, J};
use std::cmp::Ordering;
use std::io::Read;

const MAX_FILE: u64 = 1 << 20;
const MAX_DEC_TEXT: usize = 256;
const MAX_EXP_DIGITS: usize = 6;
const MAX_NEST: usize = 4;
const MAX_TEMPLATE_VALUE: usize = 128;

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum Kind {
    Mutating,
    SensitiveRead,
    Passthrough,
}

/// Why a call or a result is refused. `code` is a short stable word (for example SUBCAP, RULE, SCOPE, SHAPE).
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
struct Tool {
    name: String,
    kind: Kind,
    rules: Vec<Rule>,
    subcaps: Vec<Subcap>,
    scope: Vec<String>,
}

pub struct Policy {
    tools: Vec<Tool>,
    facts: Vec<(String, Dec)>,
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
        return Err(format!("{what}: max_fact must be 1 to 512 bytes, no control byte"));
    }
    let mut parts = Vec::new();
    let mut rest = t;
    while !rest.is_empty() {
        if let Some(r) = rest.strip_prefix('{') {
            let end = r.find('}').ok_or_else(|| format!("{what}: unclosed '{{' in max_fact"))?;
            let name = &r[..end];
            if !ident(name, 64) {
                return Err(format!("{what}: bad placeholder {name:?} in max_fact"));
            }
            parts.push(Part::Arg(name.to_string()));
            rest = &r[end + 1..];
        } else {
            let end = rest.find(|c| c == '{' || c == '}').unwrap_or(rest.len());
            if end == 0 {
                return Err(format!("{what}: stray '}}' in max_fact"));
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
    let mut t = Tool { name: name.to_string(), kind, rules: Vec::new(), subcaps: Vec::new(), scope: Vec::new() };
    match kind {
        Kind::Passthrough => only_keys(f, &["kind"], &what)?,
        Kind::Mutating => {
            only_keys(f, &["kind", "rules", "subcaps"], &what)?;
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
        }
        Kind::SensitiveRead => {
            only_keys(f, &["kind", "scope"], &what)?;
            let s = arr(v.get("scope").ok_or_else(|| format!("{what}: \"scope\" missing"))?, &format!("{what}.scope"))?;
            if s.is_empty() {
                return Err(format!("{what}.scope: empty"));
            }
            let mut norms: Vec<String> = Vec::new();
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
                t.scope.push(k);
            }
        }
    }
    Ok(t)
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
            if fv.iter().any(|(n, _): &(String, Dec)| n == k) {
                return Err(format!("facts: duplicate fact {k:?}"));
            }
            fv.push((k.clone(), dec_field(v, &format!("facts.{k}"))?));
        }
    }

    let mut sv: Vec<(String, String)> = Vec::new();
    for (k, v) in session {
        if !ident(k, 64) {
            return Err(format!("session: bad key {k:?} (1 to 64 bytes of [A-Za-z0-9_])"));
        }
        if v.is_empty() || v.len() > 256 || !no_ctl(v) {
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

struct Walk<'a> {
    keys: Vec<(String, String, &'a str)>, // (scope key, normalized key, session value)
    counts: Vec<usize>,
}

impl<'a> Walk<'a> {
    fn value(&mut self, v: &J, level: usize) -> Result<(), Deny> {
        match v {
            J::Obj(fields) => {
                for (k, x) in fields {
                    let nk = norm_key(k);
                    // A key whose normalized form CONTAINS a normalized scope key (for example
                    // `referring_clinic_id`) must also carry the session value. Only an exact
                    // normalized match counts as a label.
                    let mut scoped = false;
                    for i in 0..self.keys.len() {
                        if !nk.contains(self.keys[i].1.as_str()) {
                            continue;
                        }
                        scoped = true;
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
            J::Str(s) => self.string(s, level),
            _ => Ok(()),
        }
    }

    fn string(&mut self, s: &str, level: usize) -> Result<(), Deny> {
        let first = s.trim_start_matches(|c| matches!(c, ' ' | '\t' | '\n' | '\r')).bytes().next();
        if matches!(first, Some(b'{' | b'[' | b'"')) {
            if let Ok(inner) = json::parse(s) {
                if level + 1 > MAX_NEST {
                    return Err(deny("NESTED_TOO_DEEP", format!("JSON nested in strings deeper than {MAX_NEST} levels")));
                }
                return self.value(&inner, level + 1);
            }
        }
        let low = s.to_ascii_lowercase();
        for (k, _, _) in &self.keys {
            if low.contains(&k.to_ascii_lowercase()) {
                return Err(deny("SCOPE_IN_TEXT", format!("plain text contains the scope key name {k:?}")));
            }
        }
        Ok(())
    }

    fn part(&mut self, v: &J, what: &str) -> Result<(), Deny> {
        for c in self.counts.iter_mut() {
            *c = 0;
        }
        self.value(v, 0)?;
        for (i, (k, _, _)) in self.keys.iter().enumerate() {
            if self.counts[i] == 0 {
                return Err(deny("UNLABELLED", format!("{what} has no {k:?} label")));
            }
        }
        Ok(())
    }
}

impl Policy {
    fn tool(&self, name: &str) -> Option<&Tool> {
        self.tools.iter().find(|t| t.name == name)
    }

    fn fact(&self, name: &str) -> Option<&Dec> {
        self.facts.iter().find(|(n, _)| n == name).map(|(_, d)| d)
    }

    /// None = the tool is not in the policy: the proxy refuses the call (default deny).
    pub fn kind(&self, tool: &str) -> Option<Kind> {
        self.tool(tool).map(|t| t.kind)
    }

    /// Rules and fact-bound sub-caps of one mutating call. `args` = `params.arguments`.
    pub fn check_mutation(&self, tool: &str, args: &J) -> Result<(), Deny> {
        let t = match self.tool(tool) {
            Some(t) if t.kind == Kind::Mutating => t,
            Some(_) => return Err(deny("SHAPE", format!("tool {tool:?} is not mutating"))),
            None => return Err(deny("NOT_IN_POLICY", format!("tool {tool:?} is not in the policy"))),
        };
        if !matches!(args, J::Obj(_)) {
            return Err(deny("SHAPE", "arguments is not an object".into()));
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
            let mut name = String::new();
            for p in &s.template {
                match p {
                    Part::Lit(l) => name.push_str(l),
                    Part::Arg(a) => {
                        let av = args.get(a).ok_or_else(|| deny_sub(format!("template argument {a:?} missing")))?;
                        let tv = template_value(av)
                            .ok_or_else(|| deny_sub(format!("template argument {a:?} is not a safe string or number")))?;
                        name.push_str(tv);
                    }
                }
            }
            let cap = self
                .fact(&name)
                .ok_or_else(|| deny_sub(format!("fact {name:?} (from {:?}) missing in the trusted store", s.template_text)))?;
            if d.cmp(&s.min) == Ordering::Less {
                return Err(deny_sub(format!("argument {:?} is below the sub-cap minimum", s.arg)));
            }
            if d.cmp(cap) == Ordering::Greater {
                return Err(deny_sub(format!("argument {:?} is above the fact {name:?}", s.arg)));
            }
        }
        Ok(())
    }

    /// Scoped-read filter over the upstream `result` value of one sensitive read. Fail closed.
    pub fn check_read_result(&self, tool: &str, result: &J) -> Result<(), Deny> {
        let t = match self.tool(tool) {
            Some(t) if t.kind == Kind::SensitiveRead => t,
            Some(_) => return Err(deny("SHAPE", format!("tool {tool:?} is not a sensitive read"))),
            None => return Err(deny("NOT_IN_POLICY", format!("tool {tool:?} is not in the policy"))),
        };
        let mut keys = Vec::new();
        for k in &t.scope {
            let sv = self
                .session
                .iter()
                .find(|(n, _)| n == k)
                .map(|(_, v)| v.as_str())
                .ok_or_else(|| deny("NO_SESSION", format!("session has no {k:?}")))?;
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
            w.part(sc, "structuredContent")?;
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
            w.part(&v, &format!("content[{i}]"))?;
            parts += 1;
        }
        if parts == 0 {
            return Err(deny("UNLABELLED", "result has no content".into()));
        }
        Ok(())
    }
}
