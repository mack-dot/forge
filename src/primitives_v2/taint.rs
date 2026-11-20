//! Primitive 8, `taint_egress`: a stateless egress check of ONE JSON document against field labels. NATIVE CHECK,
//! not proved; FINITE TEST in tests/primitives_v2/test_taint.py. A pure module (prim.rs): no I/O, no clock read.
//!
//! Stateless (PROTOCOL.md section 7.4): no key, no record, no receipt; the request id stays fresh.
//!
//! # 1. Model
//!
//! A policy declares LABELS on fields and, per DESTINATION, the labels that may leave to it. Labels: `PII`, `PHI`,
//! `SECRET_KEY`, `TENANT:<id>` (`<id>` = `[A-Za-z0-9_-]{1,24}`), and the policy's own words in `labels`
//! (`[A-Z][A-Z0-9_]{1,31}`). Labels are SETS. Destinations: `PUBLIC_HTTP`, `LLM_STDOUT`, any `[A-Z][A-Z0-9_]{1,31}`
//! the policy names, and `TENANT:<id>` (the policy entry `TENANT:*` holds the labels for every tenant destination).
//!
//! A node gets labels from three sources, all unioned:
//! - (a) NAME RULES of the policy, `{"path": P, "labels": [...]}`. `P` = `$` then `(.name|[])*` (ANCHORED at the
//!   root: the whole logical path must match), or `name(.name|[])*` (UNANCHORED: the rule matches the END of the
//!   logical path, at any depth). `name` = `[A-Za-z0-9_-]{1,64}`, compared after normalization; `[]` matches any
//!   array index. The LOGICAL path of a node is its path of normalized key names and array indices; the `value`
//!   step of a label carrier and the step into JSON inside a string are NOT in it (both are transparent).
//! - (b) In-document CARRIERS: an object `{"$taint": [<label>...], "value": <any>}` (exactly these two members,
//!   names compared after normalization) labels itself with the listed labels; an object with a member whose
//!   normalized name is `tenantid` (`tenant_id`, `tenantId`, `TENANT-ID`, ...) and whose value is a canonical id
//!   string labels the object `TENANT:<id>`. A carrier with a bad shape: `MALFORMED_CARRIER`; a label word the
//!   policy does not know: `UNKNOWN_LABEL` (fail closed, never ignored).
//! - INHERITANCE: a node's labels are its own plus every ancestor's, through objects, arrays, carriers and JSON in
//!   strings, to any depth. A forbidden label is reported ONCE, at the topmost node that carries it (the node that
//!   is refused contains everything below it); nodes below that carry the same label again are not counted.
//!
//! Key normalization (name rules, carriers, `AMBIGUOUS_KEY`), on the key AFTER the parser has decoded every `\u`
//! escape: fullwidth ASCII U+FF01..U+FF5E becomes ASCII; U+017F (long s) becomes `s` and U+212A (Kelvin sign)
//! becomes `k` (the two non-ASCII letters whose Unicode simple case fold is an ASCII letter); `_`, `-` and every
//! Unicode White_Space code point (space, NBSP, U+2000..U+200A, U+3000, ...) are dropped; ASCII A-Z becomes a-z.
//! Nothing else: no full Unicode case fold (`ß` stays, it does not become `ss`), no NFC/NFKC, no homoglyph map.
//! (Review finding L3: before the repair, keys with NBSP or `ſ` passed a rule for `ssn`.) Two keys of one object that are equal after
//! normalization: `AMBIGUOUS_KEY` (a lenient reader may merge them). Raw duplicate keys: the strict parser refuses
//! the document (`MALFORMED_REQUEST why=BAD_JSON error=DUPLICATE_KEY`).
//!
//! Decision for destination D: every label of every node must be allowed for D. A tenant label `TENANT:x` is
//! allowed for `TENANT:a` only when x == a (the policy cannot allow another tenant's label to a tenant
//! destination; `TENANT:*` lists no tenant label). For another destination it is allowed when the destination
//! lists `TENANT:*` or `TENANT:x`. Any other label is allowed when the destination lists it.
//!
//! # 2. Modes: which ALLOW says what
//!
//! - `"mode": "detect"` (allow by default). An UNLABELLED field passes with any value. ALLOW says only: "no name rule
//!   and no carrier puts a label on this document that the destination forbids". It is a DETECTOR of labelled
//!   fields, NOT a guarantee that no secret leaves: a secret under a name that no rule names passes.
//! - `"mode": "strict"` (allow-list). Every node must be COVERED by a name rule (the rule matches the node or an
//!   ancestor; `"labels": []` declares a public field), except: a container whose logical path is empty (the root,
//!   also through a root carrier or a root JSON string) or is a proper prefix of an ANCHORED rule (the way to a
//!   declared field). An uncovered node: `UNLABELLED_FIELD`, once per uncovered subtree. A carrier adds labels but
//!   NEVER covers (the document's author must not be able to declare its own data public). ALLOW then says: "every
//!   key and leaf of this document sits at a place the policy declared, and no declared or carried label is
//!   forbidden for the destination". It still does NOT say that a VALUE at a declared public place holds no secret.
//!
//! # 3. The walk
//!
//! 1. Strict parse of the document (src/airlock/json.rs: duplicate keys, lone surrogates, control bytes, trailing
//!    bytes, depth > 64 refused): else `MALFORMED_REQUEST why=BAD_JSON error=<word>`.
//! 2. Expansion: every string VALUE (also inside carriers) that LOOKS LIKE JSON (after leading Unicode White_Space,
//!    default-ignorable code points and C0/C1 controls U+0000..U+001F, U+007F..U+009F it starts with `{`, `[` or
//!    `"`, or with the fullwidth `｛`, `［` or `＂`) is strict-parsed and takes the place of the
//!    string, recursively, to MAX_NESTED = 4 levels. A JSON-like string that fails the strict parse stays a string
//!    and is refused (`OPAQUE_JSON error=<parser word>`): a lenient reader downstream could parse it (trailing
//!    comma, form feed, NBSP, duplicate key, trailing text, depth 65+). False refusals by design: `"quoted" words`,
//!    `[draft] note`. Text that does not START like JSON is plain text (`note {"ssn":1}` passes in detect mode).
//!    A JSON opener after a control (`\u001e{...}`: Python's `str.strip()` removes U+001C..U+001F) or a fullwidth
//!    opener is refused as `OPAQUE_JSON` (review finding L3: before the repair such a string was plain text).
//! 3. Bounds over the EXPANDED document, all counted before any label is checked, all order-independent, refused
//!    whole, never truncated and passed: nodes (every value, plus one for each expanded string) > MAX_NODES =
//!    16384: `TAINT_LIMIT why=TOO_MANY_NODES`; then a node deeper than MAX_DEPTH = 32 (root 0; an expanded
//!    string's content sits at the string's depth): `why=TOO_DEEP`; then a JSON-like string at level 4:
//!    `why=NESTED_TOO_DEEP`. Every loop is iterative (explicit stacks); the parser recurses at most 65 levels per
//!    string. The request line bound (65,536 bytes) bounds the document bytes.
//! 4. One pre-order walk in CANONICAL order: object members in ascending order of their raw key bytes (UTF-8),
//!    array items by index, a JSON string's content right after the string. The result does not depend on the
//!    order of keys in the document (case `order`).
//!
//! Every object key is checked: `UNSAFE_KEY why=` `TOO_LONG` (> 256 UTF-8 bytes), `CONTROL` (U+0000..U+001F,
//! U+007F..U+009F), `IGNORABLE` (Default_Ignorable_Code_Point: zero-width, bidi controls, variation selectors,
//! tags; an invisible covert channel), `JSON_LIKE` (a key that looks like JSON: a whole record can hide in a key),
//! `CARRIER_NAME` (the normalized key CONTAINS `tenantid` or `$taint` but is not equal to it: `tenant_id=b`,
//! `tenant_id_old`; false refusals by design).
//!
//! # 4. Wire
//!
//! `DO taint_egress check <request_id> <tenant> 0 <policy> <destination> <json>`. The document is the rest of the
//! line, printable ASCII (non-ASCII as `\u` escapes). The engine's `<tenant>` field is not compared with the
//! destination: the caller names the destination.
//!
//! ALLOW: `OK verdict=ALLOW policy= destination= mode=detect|strict sha256=<SHA-256 of the exact document bytes>
//! bytes=<length> nodes=<expanded nodes> now_ms= skew_ms=`.
//!
//! Refusals (exit 10; no record), in this precedence; each reports the FIRST finding of its class in the canonical
//! order and `more=<count of further findings of the same class>`:
//! 1. `UNKNOWN_POLICY`, `UNKNOWN_DESTINATION`, `MALFORMED_REQUEST why=TAINT_ARGS|BAD_JSON [error=]` (exit 12).
//! 2. `TAINT_LIMIT why=TOO_MANY_NODES|TOO_DEEP|NESTED_TOO_DEEP max=<bound>` (no path).
//! 3. Structure: `UNSAFE_KEY json_path= why=`, `OPAQUE_JSON json_path= error=`, `AMBIGUOUS_KEY json_path=`,
//!    `UNKNOWN_LABEL json_path=`, `MALFORMED_CARRIER json_path= why=SHAPE|LABELS_NOT_ARRAY|LABEL_NOT_STRING|TENANT_ID`.
//! 4. `TAINT_EGRESS_BLOCKED json_path= label= more=` (several labels at one node: the first in byte order).
//! 5. `UNLABELLED_FIELD json_path= more=` (strict mode only).
//!
//! `json_path` grammar: `$` (root), then per step `.<name>` | `.~<i>` | `[<i>]` | `@`. `.<name>` is the NORMALIZED
//! key, shown only when it is a name of a policy rule path, `value` or `tenantid` (policy words, not document data)
//! and the key is not unsafe. Every other key is shown as `.~<i>`: its 0-based rank among the object's keys in raw
//! byte order. A key is never echoed (it may BE the secret), so no escaping of dots, brackets, quotes or control
//! bytes is needed, and a path is at most 33 steps of at most 65 bytes plus 4 `@`. `[<i>]` is an array index; `@`
//! steps into the JSON parsed from the string at that place (`@@` for double-encoded JSON). The path is
//! unambiguous: names are `[a-z0-9$]` words, `~` and `[` start other step kinds.
//! A `label` is shown as written, except a tenant label, shown as `TENANT` (its id is document data). No refusal
//! carries a value, a key, a tenant id from the document, or a digest (case `leak` searches every refusal).
//!
//! # 5. "0 bytes leaked" is the CALLER's property
//!
//! This module only answers ALLOW or a refusal; the engine prints only that answer and never forwards the
//! document. A caller gets "0 bytes leaked" only if it (1) emits nothing unless the answer is `OK verdict=ALLOW`,
//! (2) emits EXACTLY the bytes it sent for the check: it compares SHA-256 and length of the bytes it is about to
//! emit with `sha256=` and `bytes=` of the ALLOW and refuses on a difference (an SDK must send its serialized bytes
//! once and emit those same bytes, never re-serialize its own object: the Goal 20 review, finding 3), (3) emits to
//! the destination it named in the check, and (4) treats any other answer, a missing answer or an engine fault as
//! a refusal. Nothing here enforces (1) to (4).
//!
//! # 6. Policy file
//!
//! `{"primitive": "taint_egress", "version": 1, "name": "<id>", "mode": "detect"|"strict", "labels": ["<WORD>"...],
//!   "fields": [{"path": "<P>", "labels": ["<label>"...]}...], "destinations": {"<DEST>"|"TENANT:*": ["<label>"|"TENANT:*"...]}}`
//! Exact key sets. At most 256 rules, 1 to 64 destinations. Refused (`MALFORMED_POLICY`): an unknown label, a
//! duplicate label in one list, a duplicate rule (same anchoring and normalized path), a bad path, a tenant label or
//! `TENANT:*` in the `TENANT:*` list, `TENANT:*` in a rule, a custom word equal to a fixed label or `TENANT`.
//!
//! # 7. Known limits (each row TRIED: case `evasions` of tests/primitives_v2/test_taint.py asserts the result)
//!
//! | Evasion | Result |
//! | --- | --- |
//! | secret value under an unlabelled, allowed name | detect: ALLOW (passes). strict: `UNLABELLED_FIELD` unless the name is covered; under a covered public name: ALLOW (passes) |
//! | encodings of a VALUE: base64, hex, percent, HTML entities, `\x` | values are never read: ALLOW under an unlabelled name; blocked under a labelled name (by the name, not the content) |
//! | encodings of a KEY: `ss%6E`, `&#115;sn`, literal `\x73sn` | not decoded: detect ALLOW (passes); strict `UNLABELLED_FIELD`. JSON `ssn` IS decoded by the parser: blocked |
//! | compressed (gzip+base64) or split secret across fields | ALLOW under unlabelled names (passes) |
//! | numbers as carriers | a number under an unlabelled name: ALLOW (passes); under a labelled name: blocked |
//! | homoglyph key (Cyrillic `ѕsn`) | not folded: detect ALLOW (passes); strict `UNLABELLED_FIELD` |
//! | Kelvin sign in `api_Key`, long s in `ſsn`, NBSP or U+3000 in `ssn\u00a0` | folded or dropped: blocked |
//! | full case fold: `ßn` (Python `casefold()` gives `ssn`), ligature `ﬀ`, dotless `ı` | not folded: detect ALLOW (passes); strict `UNLABELLED_FIELD` |
//! | compatibility forms (NFKC): superscript or circled letters, math alphanumerics | not folded: detect ALLOW (passes); strict `UNLABELLED_FIELD` |
//! | JSON in a string after a control (`\u001e{`, `\u0000{`, `\u0008{`) or with a fullwidth opener (`｛`) | `OPAQUE_JSON` (refused) |
//! | JSON in a string after a printable prefix (`x{"ssn":1}`, `note: {...}`) | plain text: detect ALLOW (passes); a downstream reader that searches for the first `{` recovers it |
//! | zero-width or bidi code point in a key | `UNSAFE_KEY why=IGNORABLE` (refused in every mode) |
//! | fullwidth key `ｓｓｎ` | folded: blocked |
//! | keys that differ only by Unicode normalization (`café` NFC and NFD side by side) | no NFC: both kept, not `AMBIGUOUS_KEY`: ALLOW (passes) |
//! | array of pairs `[["ssn", "..."]]` | `ssn` is a value, not a key: detect ALLOW (passes); strict `UNLABELLED_FIELD` |
//! | very deep (> 32) or very wide (> 16,384 nodes) document | `TAINT_LIMIT` (refused, never truncated) |
//! | label carrier omitted by the author (a foreign record with no `tenant_id`) | detect: ALLOW (passes); only name rules apply |
//! | label word the policy does not know | `UNKNOWN_LABEL` (refused) |
//! | free text that names another tenant (`TENANT-ID: b` in a value; MCP review shapes 1 and 2) | text is never read: detect ALLOW (passes); strict: `UNLABELLED_FIELD` unless the name is covered |
//! | ASCII case, `_`, `-`, White_Space, `ſ`, Kelvin sign and fullwidth variants of a covered key | normalized to the policy name: a covert channel of a few bits per key (not refused) |
//!
//! This module checks LABELS and NAMES, not the content of values. It trusts the policy author for the rules and
//! the document author for the carriers it contains: an omitted carrier is not detected, and a wrong `tenant_id`
//! written by the document's author is believed.
//!
//! # 8. The MCP proxy review's nine leaking shapes, translated (rows r1 to r9 of case `table`)
//!
//! r1, r2 free text in a value: ALLOW in detect mode (limit above), `UNLABELLED_FIELD` in strict mode with the name
//! uncovered; r3 nested JSON with a trailing comma: `OPAQUE_JSON error=BAD_KEY`; r4 nested duplicate `tenantId`:
//! `OPAQUE_JSON error=DUPLICATE_KEY` (and `tenantId` + `tenant_id`: `AMBIGUOUS_KEY`); r5 `_` key with trailing
//! text: `OPAQUE_JSON error=TRAILING_BYTES` (without the text: `TAINT_EGRESS_BLOCKED label=TENANT`); r6 form feed
//! before nested JSON: `OPAQUE_JSON error=BAD_VALUE`; r7 a record inside a key: `UNSAFE_KEY why=JSON_LIKE`; r8 plain
//! text in a key: `UNSAFE_KEY why=CARRIER_NAME`; r9 depth 70 nested JSON: `OPAQUE_JSON error=TOO_DEEP` (depth 40:
//! `TAINT_LIMIT why=TOO_DEEP`; depth 31: blocked by the label). Goal 20's top-level-only `tenant_id` read: a nested
//! `tenant_id` of another tenant is blocked at its object (row t33).
use crate::json::{self, J};
use crate::pin::Sha256;
use crate::prim::{refusal, wire_value, Cas, Decision, Now, OpSpec, Policies, Primitive, Record, Refusal, Request};
use crate::store::canonical_id;
use std::collections::{BTreeMap, BTreeSet, HashMap, HashSet};
use std::rc::Rc;

/// The deepest node of the expanded document (the root is at depth 0). Deeper: `TAINT_LIMIT why=TOO_DEEP`.
pub const MAX_DEPTH: usize = 32;
/// The most nodes of the expanded document. More: `TAINT_LIMIT why=TOO_MANY_NODES`.
pub const MAX_NODES: usize = 16384;
/// The most levels of JSON in strings. A JSON-like string at level MAX_NESTED: `TAINT_LIMIT why=NESTED_TOO_DEEP`.
pub const MAX_NESTED: usize = 4;
/// The longest object key, in UTF-8 bytes. Longer: `UNSAFE_KEY why=TOO_LONG`.
pub const MAX_KEY_BYTES: usize = 256;
pub const MAX_RULES: usize = 256;
pub const MAX_DESTINATIONS: usize = 64;
pub const MAX_NAME: usize = 64;
const FIXED: [&str; 3] = ["PHI", "PII", "SECRET_KEY"];
const ANY_TENANT: &str = "TENANT:*";

pub struct Taint;

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum Mode {
    Detect,
    Strict,
}

#[derive(Clone, PartialEq, Eq, Debug)]
enum RSeg {
    Name(String),
    AnyIndex,
}
#[derive(Clone, PartialEq, Eq, Debug)]
enum LSeg {
    Name(String),
    Index,
}
struct Rule {
    anchored: bool,
    segs: Vec<RSeg>,
    labels: BTreeSet<String>,
}
struct Dest {
    labels: BTreeSet<String>,
    any_tenant: bool,
}

pub struct Policy {
    mode: Mode,
    custom: BTreeSet<String>,
    rules: Vec<Rule>,
    dests: BTreeMap<String, Dest>,
    /// Normalized names that a refusal may echo: every name of a rule path, `value` and `tenantid`.
    names: BTreeSet<String>,
}

#[derive(Default)]
pub struct State;

// ---- names, keys, labels ------------------------------------------------------------------------------------------

/// Unicode Default_Ignorable_Code_Point (DerivedCoreProperties): zero-width, joiners, bidi controls, variation
/// selectors, tags, fillers. A key that holds one is refused (`UNSAFE_KEY why=IGNORABLE`).
pub fn ignorable(c: char) -> bool {
    matches!(c as u32, 0xAD | 0x34F | 0x61C | 0x115F..=0x1160 | 0x17B4..=0x17B5 | 0x180B..=0x180F | 0x200B..=0x200F
        | 0x202A..=0x202E | 0x2060..=0x206F | 0x3164 | 0xFE00..=0xFE0F | 0xFEFF | 0xFFA0 | 0xFFF0..=0xFFF8
        | 0x1BCA0..=0x1BCA3 | 0x1D173..=0x1D17A | 0xE0000..=0xE0FFF)
}

/// Key normalization for name rules, on the DECODED key (the parser has already decoded every `\u` escape):
/// fullwidth ASCII U+FF01..U+FF5E becomes ASCII (minus 0xFEE0), U+017F becomes `s`, U+212A becomes `k`; then `_`,
/// `-` and every White_Space code point are dropped; then ASCII A-Z become a-z. Nothing else changes (no full
/// Unicode case folding, no NFC/NFKC, no homoglyph map).
pub fn normalize(k: &str) -> String {
    let mut o = String::with_capacity(k.len());
    for c in k.chars() {
        let c = match c as u32 {
            u @ 0xFF01..=0xFF5E => char::from_u32(u - 0xFEE0).unwrap_or(c),
            0x17F => 's',
            0x212A => 'k',
            _ => c,
        };
        if c == '_' || c == '-' || c.is_whitespace() { continue }
        o.push(c.to_ascii_lowercase());
    }
    o
}

/// A string "looks like JSON" when, after leading Unicode White_Space, ignorable code points and C0/C1 controls
/// (`char::is_control`: U+0000..U+001F, U+007F..U+009F), it starts with `{`, `[` or `"`, or with the fullwidth
/// `｛` U+FF5B, `［` U+FF3B or `＂` U+FF02 (a lenient reader may strip or fold them; fail closed: OPAQUE_JSON).
pub fn json_like(s: &str) -> bool {
    let t = s.trim_start_matches(|c: char| c.is_whitespace() || ignorable(c) || c.is_control());
    t.starts_with(['{', '[', '"', '\u{FF5B}', '\u{FF3B}', '\u{FF02}'])
}

/// Why a key is unsafe (first reason in this order), or None.
fn key_fault(k: &str, n: &str) -> Option<&'static str> {
    if k.len() > MAX_KEY_BYTES { return Some("TOO_LONG") }
    if k.chars().any(|c| (c as u32) < 0x20 || (0x7F..=0x9F).contains(&(c as u32))) { return Some("CONTROL") }
    if k.chars().any(ignorable) { return Some("IGNORABLE") }
    if json_like(k) { return Some("JSON_LIKE") }
    if n != "tenantid" && n != "$taint" && (n.contains("tenantid") || n.contains("$taint")) { return Some("CARRIER_NAME") }
    None
}

fn upper_word(s: &str) -> bool {
    let b = s.as_bytes();
    (2..=32).contains(&b.len()) && b[0].is_ascii_uppercase() && b.iter().all(|c| c.is_ascii_uppercase() || c.is_ascii_digit() || *c == b'_')
}
fn tenant_of(label: &str) -> Option<&str> {
    label.strip_prefix("TENANT:").filter(|t| canonical_id(t))
}
fn known_label(custom: &BTreeSet<String>, s: &str) -> bool {
    FIXED.contains(&s) || custom.contains(s) || tenant_of(s).is_some()
}
/// The label as a refusal shows it: a tenant label without its id (the id is document data).
fn shown(label: &str) -> String {
    if label.starts_with("TENANT:") { "TENANT".into() } else { label.to_string() }
}

// ---- policy -------------------------------------------------------------------------------------------------------

fn strs(v: &J, what: &str) -> Result<Vec<String>, String> {
    let J::Arr(a) = v else { return Err(format!("NOT_ARRAY {what}")) };
    a.iter().map(|x| match x { J::Str(s) => Ok(s.clone()), _ => Err(format!("NOT_STRING {what}")) }).collect()
}

fn parse_path(s: &str) -> Result<(bool, Vec<RSeg>), String> {
    let bad = || format!("BAD_PATH {}", wire_value(s));
    let (anchored, mut rest) = match s.strip_prefix('$') { Some(r) => (true, r), None => (false, s) };
    let mut segs = Vec::new();
    let mut first = !anchored;
    while !rest.is_empty() || first {
        if let Some(r) = rest.strip_prefix("[]") {
            if first { return Err(bad()) }
            segs.push(RSeg::AnyIndex);
            rest = r;
            continue;
        }
        let r = if first { rest } else { rest.strip_prefix('.').ok_or_else(bad)? };
        let end = r.find(['.', '[']).unwrap_or(r.len());
        let name = &r[..end];
        if !(1..=MAX_NAME).contains(&name.len()) || !name.bytes().all(|b| b.is_ascii_alphanumeric() || b == b'_' || b == b'-') { return Err(bad()) }
        let n = normalize(name);
        if n.is_empty() { return Err(bad()) }
        segs.push(RSeg::Name(n));
        rest = &r[end..];
        first = false;
    }
    Ok((anchored, segs))
}

fn parse_policy_doc(doc: &J) -> Result<Policy, String> {
    let J::Obj(f) = doc else { return Err("NOT_OBJECT".into()) };
    for (k, _) in f {
        if !["primitive", "version", "name", "mode", "labels", "fields", "destinations"].contains(&k.as_str()) {
            return Err(format!("UNKNOWN_KEY {}", wire_value(k)));
        }
    }
    let get = |k: &str| doc.get(k).ok_or_else(|| format!("MISSING {k}"));
    let mode = match get("mode")? {
        J::Str(s) if s == "detect" => Mode::Detect,
        J::Str(s) if s == "strict" => Mode::Strict,
        _ => return Err("MODE detect|strict".into()),
    };
    let mut custom = BTreeSet::new();
    for l in strs(get("labels")?, "labels")? {
        if !upper_word(&l) || FIXED.contains(&l.as_str()) || l == "TENANT" { return Err(format!("BAD_LABEL {}", wire_value(&l))) }
        if !custom.insert(l.clone()) { return Err(format!("DUPLICATE_LABEL {}", wire_value(&l))) }
    }
    let J::Arr(fields) = get("fields")? else { return Err("NOT_ARRAY fields".into()) };
    if fields.len() > MAX_RULES { return Err(format!("TOO_MANY_RULES max={MAX_RULES}")) }
    let (mut rules, mut names) = (Vec::<Rule>::new(), BTreeSet::new());
    for r in fields {
        let J::Obj(rf) = r else { return Err("NOT_OBJECT fields".into()) };
        if rf.len() != 2 || r.get("path").is_none() || r.get("labels").is_none() { return Err("RULE_KEYS path,labels".into()) }
        let J::Str(path) = r.get("path").unwrap_or(&J::Null) else { return Err("NOT_STRING path".into()) };
        let (anchored, segs) = parse_path(path)?;
        let mut labels = BTreeSet::new();
        for l in strs(r.get("labels").unwrap_or(&J::Null), "labels")? {
            if !known_label(&custom, &l) { return Err(format!("UNKNOWN_LABEL {}", wire_value(&l))) }
            if !labels.insert(l.clone()) { return Err(format!("DUPLICATE_LABEL {}", wire_value(&l))) }
        }
        if rules.iter().any(|x| x.anchored == anchored && x.segs == segs) { return Err(format!("DUPLICATE_RULE {}", wire_value(path))) }
        for s in &segs {
            if let RSeg::Name(n) = s { names.insert(n.clone()); }
        }
        rules.push(Rule { anchored, segs, labels });
    }
    names.insert("value".into());
    names.insert("tenantid".into());
    let J::Obj(df) = get("destinations")? else { return Err("NOT_OBJECT destinations".into()) };
    if df.is_empty() || df.len() > MAX_DESTINATIONS { return Err(format!("DESTINATIONS 1..{MAX_DESTINATIONS}")) }
    let mut dests = BTreeMap::new();
    for (name, v) in df {
        let tenant_dest = name == ANY_TENANT;
        if !tenant_dest && (!upper_word(name) || name == "TENANT") { return Err(format!("BAD_DESTINATION {}", wire_value(name))) }
        let mut d = Dest { labels: BTreeSet::new(), any_tenant: false };
        for l in strs(v, "destinations")? {
            let fresh = if l == ANY_TENANT {
                if tenant_dest { return Err("ANY_TENANT_IN_TENANT_DESTINATION".into()) }
                !std::mem::replace(&mut d.any_tenant, true)
            } else {
                if !known_label(&custom, &l) { return Err(format!("UNKNOWN_LABEL {}", wire_value(&l))) }
                if tenant_dest && tenant_of(&l).is_some() { return Err("TENANT_LABEL_IN_TENANT_DESTINATION".into()) }
                d.labels.insert(l.clone())
            };
            if !fresh { return Err(format!("DUPLICATE_LABEL {}", wire_value(&l))) }
        }
        dests.insert(name.clone(), d);
    }
    Ok(Policy { mode, custom, rules, dests, names })
}

// ---- the check ----------------------------------------------------------------------------------------------------

fn seg_eq(r: &RSeg, l: &LSeg) -> bool {
    match (r, l) {
        (RSeg::Name(a), LSeg::Name(b)) => a == b,
        (RSeg::AnyIndex, LSeg::Index) => true,
        _ => false,
    }
}
fn rule_matches(r: &Rule, l: &[LSeg]) -> bool {
    if r.anchored {
        r.segs.len() == l.len() && r.segs.iter().zip(l).all(|(a, b)| seg_eq(a, b))
    } else {
        r.segs.len() <= l.len() && r.segs.iter().zip(&l[l.len() - r.segs.len()..]).all(|(a, b)| seg_eq(a, b))
    }
}
/// An anchored rule that names a strict descendant of `l`.
fn rule_extends(r: &Rule, l: &[LSeg]) -> bool {
    r.anchored && r.segs.len() > l.len() && r.segs.iter().zip(l).all(|(a, b)| seg_eq(a, b))
}

fn allowed(d: &Dest, dest_tenant: Option<&str>, label: &str) -> bool {
    match (tenant_of(label), dest_tenant) {
        (Some(t), Some(a)) => t == a,
        (Some(_), None) => d.any_tenant || d.labels.contains(label),
        (None, _) => d.labels.contains(label),
    }
}

fn addr(j: &J) -> usize {
    j as *const J as usize
}

/// The document with every JSON-like string value replaced by its strict parse (to MAX_NESTED levels).
struct Expanded {
    units: Vec<Box<J>>,
    /// address of a JSON-like string -> Ok(unit) or Err(the strict parser's error word)
    map: HashMap<usize, Result<usize, &'static str>>,
    nodes: usize,
    max_depth: usize,
    nested_over: bool,
}

fn expand(root: J) -> Expanded {
    let mut ex = Expanded { units: vec![Box::new(root)], map: HashMap::new(), nodes: 0, max_depth: 0, nested_over: false };
    let mut meta: Vec<(usize, usize)> = vec![(0, 0)]; // (depth of the unit root, level)
    let mut u = 0;
    while u < ex.units.len() {
        let (base, level) = meta[u];
        let mut found: Vec<(usize, J, usize)> = Vec::new();
        {
            let mut stack: Vec<(&J, usize)> = vec![(&*ex.units[u], base)];
            while let Some((n, d)) = stack.pop() {
                ex.nodes += 1;
                if ex.nodes > MAX_NODES { return ex }
                ex.max_depth = ex.max_depth.max(d);
                match n {
                    J::Arr(a) => stack.extend(a.iter().map(|c| (c, d + 1))),
                    J::Obj(f) => stack.extend(f.iter().map(|(_, c)| (c, d + 1))),
                    J::Str(s) if json_like(s) => {
                        if level + 1 > MAX_NESTED {
                            ex.nested_over = true;
                        } else {
                            match json::parse(s) {
                                Ok(j) => found.push((addr(n), j, d)),
                                Err(e) => { ex.map.insert(addr(n), Err(e)); }
                            }
                        }
                    }
                    _ => {}
                }
            }
        }
        for (a, j, d) in found {
            ex.map.insert(a, Ok(ex.units.len()));
            ex.units.push(Box::new(j));
            meta.push((d, level + 1));
        }
        u += 1;
    }
    ex
}

#[derive(Clone)]
enum SSeg {
    Root,
    Name(String),
    Hidden(usize),
    Index(usize),
    Nested,
}
fn render(p: &[SSeg]) -> String {
    let mut o = String::new();
    for s in p {
        match s {
            SSeg::Root => o.push('$'),
            SSeg::Name(n) => { o.push('.'); o.push_str(n) }
            SSeg::Hidden(i) => o.push_str(&format!(".~{i}")),
            SSeg::Index(i) => o.push_str(&format!("[{i}]")),
            SSeg::Nested => o.push('@'),
        }
    }
    o
}

struct Frame<'a> {
    node: &'a J,
    sdepth: usize,
    sseg: SSeg,
    ldepth: usize,
    lseg: Option<LSeg>,
    inh: Rc<BTreeSet<String>>,
    covered: bool,
    suppressed: bool,
    key_fault: Option<&'static str>,
}

#[derive(Default)]
struct Class {
    first: Option<Refusal>,
    count: usize,
}
impl Class {
    fn add(&mut self, code: &'static str, path: &[SSeg], extra: Vec<(&'static str, String)>, detail: &str) {
        self.count += 1;
        if self.first.is_none() {
            let mut f = vec![("json_path", render(path))];
            f.extend(extra);
            self.first = Some(refusal(code, f, detail));
        }
    }
    fn result(self) -> Option<Refusal> {
        let more = self.count.saturating_sub(1);
        self.first.map(|mut r| {
            r.repair.push(("more", more.to_string()));
            r
        })
    }
}

/// Resolves a node through the expansion map: (the node, the number of `@` hops, the opaque parse error if any).
fn resolve<'a>(ex: &'a Expanded, mut n: &'a J) -> (&'a J, usize, Option<&'static str>) {
    let mut hops = 0;
    loop {
        if let J::Str(_) = n {
            match ex.map.get(&addr(n)) {
                Some(Ok(v)) => {
                    n = &ex.units[*v];
                    hops += 1;
                    continue;
                }
                Some(Err(e)) => return (n, hops, Some(e)),
                None => {}
            }
        }
        return (n, hops, None);
    }
}

enum CarrierFault {
    Bad(&'static str),
    Unknown,
}

/// A label carrier `{"$taint": [<label>...], "value": <any>}` (keys compared after normalization).
fn carrier<'a>(fs: &'a [(String, J)], norms: &[String], ex: &'a Expanded, p: &Policy) -> Result<(BTreeSet<String>, &'a J), CarrierFault> {
    if fs.len() != 2 { return Err(CarrierFault::Bad("SHAPE")) }
    let ti = norms.iter().position(|n| n == "$taint").ok_or(CarrierFault::Bad("SHAPE"))?;
    let vi = 1 - ti;
    if norms[vi] != "value" { return Err(CarrierFault::Bad("SHAPE")) }
    let (J::Arr(items), _, _) = resolve(ex, &fs[ti].1) else { return Err(CarrierFault::Bad("LABELS_NOT_ARRAY")) };
    let mut labels = BTreeSet::new();
    let mut unknown = false;
    for it in items {
        match resolve(ex, it) {
            (J::Str(s), 0, None) if known_label(&p.custom, s) => { labels.insert(s.clone()); }
            (J::Str(_), _, _) => unknown = true,
            _ => return Err(CarrierFault::Bad("LABEL_NOT_STRING")),
        }
    }
    if unknown { return Err(CarrierFault::Unknown) }
    Ok((labels, &fs[vi].1))
}

/// The walk. Ok(nodes) = ALLOW. Err = the refusal (without the clock fields).
fn check(p: &Policy, d: &Dest, dest_tenant: Option<&str>, root: J) -> Result<usize, Refusal> {
    let ex = expand(root);
    let limit = |why: &str, max: usize, detail: &str| refusal("TAINT_LIMIT", vec![("why", why.to_string()), ("max", max.to_string())], detail);
    if ex.nodes > MAX_NODES { return Err(limit("TOO_MANY_NODES", MAX_NODES, "the document has too many nodes; nothing was checked")) }
    if ex.max_depth > MAX_DEPTH { return Err(limit("TOO_DEEP", MAX_DEPTH, "the document is too deep; nothing was checked")) }
    if ex.nested_over { return Err(limit("NESTED_TOO_DEEP", MAX_NESTED, "too many levels of JSON in strings; nothing was checked")) }

    let (mut structure, mut blocked, mut unlabelled) = (Class::default(), Class::default(), Class::default());
    let mut spath: Vec<SSeg> = Vec::new();
    let mut lpath: Vec<LSeg> = Vec::new();
    let mut stack = vec![Frame {
        node: &*ex.units[0], sdepth: 0, sseg: SSeg::Root, ldepth: 0, lseg: None, inh: Rc::new(BTreeSet::new()),
        covered: false, suppressed: false, key_fault: None,
    }];
    while let Some(f) = stack.pop() {
        spath.truncate(f.sdepth);
        spath.push(f.sseg);
        lpath.truncate(f.ldepth);
        if let Some(l) = f.lseg { lpath.push(l) }
        if let Some(why) = f.key_fault {
            structure.add("UNSAFE_KEY", &spath, vec![("why", why.into())], "an object key is unsafe; the key is not shown");
        }
        let (node, hops, opaque) = resolve(&ex, f.node);
        for _ in 0..hops { spath.push(SSeg::Nested) }
        if let Some(e) = opaque {
            structure.add("OPAQUE_JSON", &spath, vec![("error", e.into())], "a string looks like JSON but is not strict JSON");
        }

        let mut own: BTreeSet<String> = BTreeSet::new();
        let mut matched = false;
        for r in &p.rules {
            if rule_matches(r, &lpath) {
                matched = true;
                own.extend(r.labels.iter().cloned());
            }
        }
        let mut norms: Vec<String> = Vec::new();
        let mut carrier_value: Option<&J> = None;
        if let J::Obj(fs) = node {
            norms = fs.iter().map(|(k, _)| normalize(k)).collect();
            let mut seen = HashSet::new();
            if !norms.iter().all(|n| seen.insert(n.as_str())) {
                structure.add("AMBIGUOUS_KEY", &spath, vec![], "two keys of one object are equal after normalization");
            }
            if norms.iter().any(|n| n == "$taint") {
                match carrier(fs, &norms, &ex, p) {
                    Ok((labels, v)) => {
                        own.extend(labels);
                        carrier_value = Some(v);
                    }
                    Err(CarrierFault::Unknown) => structure.add("UNKNOWN_LABEL", &spath, vec![], "a label carrier names a label that the policy does not know"),
                    Err(CarrierFault::Bad(why)) => structure.add("MALFORMED_CARRIER", &spath, vec![("why", why.into())], "a label carrier has a bad shape"),
                }
            }
            for (i, n) in norms.iter().enumerate() {
                if n != "tenantid" { continue }
                match resolve(&ex, &fs[i].1) {
                    (J::Str(s), 0, None) if canonical_id(s) => { own.insert(format!("TENANT:{s}")); }
                    _ => structure.add("MALFORMED_CARRIER", &spath, vec![("why", "TENANT_ID".into())], "a tenant_id member is not a canonical tenant id string"),
                }
            }
        }
        let fresh: Vec<&String> = own.iter().filter(|l| !f.inh.contains(*l)).collect();
        for l in &fresh {
            if !allowed(d, dest_tenant, l) {
                blocked.add("TAINT_EGRESS_BLOCKED", &spath, vec![("label", shown(l))], "a field carries a label that may not leave to this destination; the value is not shown");
            }
        }
        let inh = if fresh.is_empty() { f.inh.clone() } else { Rc::new(f.inh.iter().chain(own.iter()).cloned().collect()) };
        let covered = f.covered || matched;
        let container = matches!(node, J::Obj(_) | J::Arr(_));
        let mut suppressed = f.suppressed;
        if p.mode == Mode::Strict && !suppressed && !covered
            && !(container && (lpath.is_empty() || p.rules.iter().any(|r| rule_extends(r, &lpath))))
        {
            unlabelled.add("UNLABELLED_FIELD", &spath, vec![], "strict mode: no policy rule covers this field");
            suppressed = true;
        }

        let (sd, ld) = (spath.len(), lpath.len());
        match node {
            J::Arr(a) => {
                for (i, c) in a.iter().enumerate().rev() {
                    stack.push(Frame { node: c, sdepth: sd, sseg: SSeg::Index(i), ldepth: ld, lseg: Some(LSeg::Index), inh: inh.clone(), covered, suppressed, key_fault: None });
                }
            }
            J::Obj(fs) => {
                if let Some(v) = carrier_value {
                    stack.push(Frame { node: v, sdepth: sd, sseg: SSeg::Name("value".into()), ldepth: ld, lseg: None, inh: inh.clone(), covered, suppressed, key_fault: None });
                } else {
                    let mut order: Vec<usize> = (0..fs.len()).collect();
                    order.sort_by(|a, b| fs[*a].0.as_bytes().cmp(fs[*b].0.as_bytes()));
                    for (rank, &i) in order.iter().enumerate().rev() {
                        let n = &norms[i];
                        let fault = key_fault(&fs[i].0, n);
                        let sseg = if fault.is_none() && p.names.contains(n) { SSeg::Name(n.clone()) } else { SSeg::Hidden(rank) };
                        stack.push(Frame { node: &fs[i].1, sdepth: sd, sseg, ldepth: ld, lseg: Some(LSeg::Name(n.clone())), inh: inh.clone(), covered, suppressed, key_fault: fault });
                    }
                }
            }
            _ => {}
        }
    }
    if let Some(r) = structure.result() { return Err(r) }
    if let Some(r) = blocked.result() { return Err(r) }
    if let Some(r) = unlabelled.result() { return Err(r) }
    Ok(ex.nodes)
}

fn dest_ok(dest: &str) -> bool {
    (upper_word(dest) && dest != "TENANT") || tenant_of(dest).is_some()
}

impl Primitive for Taint {
    const NAME: &'static str = "taint_egress";
    const OPS: &'static [OpSpec] = &[OpSpec { op: "check", min_keys: 0, max_keys: 0, cas: Cas::Required }];
    type Policy = Policy;
    type State = State;

    fn parse_policy(doc: &J) -> Result<Policy, String> {
        parse_policy_doc(doc)
    }

    fn decide(req: &Request, _state: &State, policies: &Policies<Policy>, _now: &Now) -> Decision {
        let malformed = |why: &str| Decision::Refuse(refusal("MALFORMED_REQUEST", vec![("why", why.to_string())], "args: <policy> <destination> <json document>"));
        let Some((pname, rest)) = req.args.split_once(' ') else { return malformed("TAINT_ARGS") };
        let Some((dest, doc)) = rest.split_once(' ') else { return malformed("TAINT_ARGS") };
        if !canonical_id(pname) || !dest_ok(dest) || doc.is_empty() { return malformed("TAINT_ARGS") }
        let Some(p) = policies.get(pname) else {
            return Decision::Refuse(refusal("UNKNOWN_POLICY", vec![], "no taint_egress policy of that name is pinned in this store"));
        };
        let dest_tenant = tenant_of(dest);
        let Some(d) = p.dests.get(if dest_tenant.is_some() { ANY_TENANT } else { dest }) else {
            return Decision::Refuse(refusal("UNKNOWN_DESTINATION", vec![], "the policy names no such destination"));
        };
        let root = match json::parse(doc) {
            Ok(j) => j,
            Err(e) => return Decision::Refuse(refusal("MALFORMED_REQUEST", vec![("why", "BAD_JSON".into()), ("error", e.into())], "the document is not strict JSON")),
        };
        match check(p, d, dest_tenant, root) {
            Ok(nodes) => {
                let mut h = Sha256::new();
                h.update(doc.as_bytes());
                Decision::Answer("ALLOW", vec![
                    ("policy", pname.to_string()),
                    ("destination", dest.to_string()),
                    ("mode", if p.mode == Mode::Strict { "strict" } else { "detect" }.to_string()),
                    ("sha256", h.hex()),
                    ("bytes", doc.len().to_string()),
                    ("nodes", nodes.to_string()),
                ], String::new())
            }
            Err(r) => Decision::Refuse(r),
        }
    }

    fn fold(_state: &mut State, _rec: &Record, _policies: &Policies<Policy>) -> Result<(), String> {
        Err("STATELESS taint_egress writes no record".into())
    }

    fn describe(_state: &State, _key: &str, _policies: &Policies<Policy>, _now: &Now) -> Option<Vec<(&'static str, String)>> {
        None
    }
}
