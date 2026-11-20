//! Unit tests of `policy.rs` (worker TESTS, round 2). Ported from the round 1 test root of worker POLICY
//! (47 cases; every case kept). FINITE TEST of a NATIVE CHECK; nothing here is proved.
//! Only the `pub` / `pub(crate)` surface of `policy.rs` is used.
use crate::json::{self, J};
use crate::policy::{self, load, load_from_text, Kind, Policy};

const POL: &str = r#"{"version": 1,
 "tools": {
   "issue_payout":      {"kind": "mutating", "rules": [{"arg": "amount", "max": "500.00"}, {"arg": "currency", "one_of": ["USD", "EUR"]}]},
   "update_dosage":     {"kind": "mutating", "subcaps": [{"arg": "mg", "max_fact": "max_mg/{patient_id}/{medication}"}]},
   "refund":            {"kind": "mutating", "rules": [{"arg": "amount", "min": "-100", "max": 100}]},
   "get_patient_chart": {"kind": "sensitive_read", "scope": ["clinic_id"]},
   "list_invoices":     {"kind": "sensitive_read", "scope": ["org_id"]},
   "ping":              {"kind": "passthrough"}},
 "clearing": {"anything": [1, 2, {"x": null}]}}"#;

const FACTS: &str = r#"{"max_mg/P-1001/Warfarin": "50", "max_mg/P-1002/Warfarin": 7.5, "max_mg/1001/Warfarin": "50"}"#;

fn sess() -> Vec<(String, String)> {
    vec![("clinic_id".into(), "Clinic_Alpha".into())]
}
fn pol() -> Policy {
    load_from_text(POL, Some(FACTS), &sess()).expect("policy loads")
}
fn j(s: &str) -> J {
    json::parse(s).expect("test JSON")
}
fn load_err(p: &str) -> String {
    match load_from_text(p, None, &[]) {
        Ok(_) => panic!("expected a load error for {p}"),
        Err(e) => e,
    }
}
fn pay(amount: &str) -> Result<(), policy::Deny> {
    pol().check_mutation("issue_payout", &j(&format!(r#"{{"amount": {amount}, "currency": "USD"}}"#)))
}
fn dose(args: &str) -> Result<(), policy::Deny> {
    pol().check_mutation("update_dosage", &j(args))
}
fn read(result: &str) -> Result<(), policy::Deny> {
    pol().check_read_result("get_patient_chart", &j(result))
}
fn text_item(inner: &str) -> String {
    // Wrap one JSON text as an MCP text content item.
    let esc = inner.replace('\\', "\\\\").replace('"', "\\\"");
    format!(r#"{{"content":[{{"type":"text","text":"{esc}"}}]}}"#)
}
fn code(r: Result<(), policy::Deny>) -> &'static str {
    match r {
        Ok(()) => "OK",
        Err(d) => d.code,
    }
}

// ---------------- load ----------------
#[test]
fn load_ok_and_kinds() {
    let p = pol();
    assert_eq!(p.kind("issue_payout"), Some(Kind::Mutating));
    assert_eq!(p.kind("get_patient_chart"), Some(Kind::SensitiveRead));
    assert_eq!(p.kind("ping"), Some(Kind::Passthrough));
    assert_eq!(p.kind("delete_everything"), None);
}
#[test]
fn load_unknown_top_key() {
    assert!(load_err(r#"{"version":1,"tools":{},"extra":1}"#).contains("unknown key"));
}
#[test]
fn load_clearing_must_be_object() {
    load_err(r#"{"version":1,"tools":{},"clearing":[1]}"#);
}
#[test]
fn load_bad_version() {
    load_err(r#"{"version":2,"tools":{}}"#);
    load_err(r#"{"version":"1","tools":{}}"#);
    load_err(r#"{"version":1.0,"tools":{}}"#);
    load_err(r#"{"tools":{}}"#);
}
#[test]
fn load_tools_missing_or_wrong_type() {
    load_err(r#"{"version":1}"#);
    load_err(r#"{"version":1,"tools":[]}"#);
}
#[test]
fn load_empty_tool_name() {
    load_err(r#"{"version":1,"tools":{"":{"kind":"passthrough"}}}"#);
}
#[test]
fn load_tool_without_kind() {
    assert!(load_err(r#"{"version":1,"tools":{"a":{}}}"#).contains("kind"));
}
#[test]
fn load_bad_kind() {
    load_err(r#"{"version":1,"tools":{"a":{"kind":"admin"}}}"#);
    load_err(r#"{"version":1,"tools":{"a":{"kind":1}}}"#);
}
#[test]
fn load_unknown_tool_key() {
    load_err(r#"{"version":1,"tools":{"a":{"kind":"passthrough","rules":[]}}}"#);
    load_err(r#"{"version":1,"tools":{"a":{"kind":"mutating","scope":["x"]}}}"#);
    load_err(r#"{"version":1,"tools":{"a":{"kind":"mutating","rules":[{"arg":"x","max":1,"maxx":2}]}}}"#);
}
#[test]
fn load_rule_errors() {
    load_err(r#"{"version":1,"tools":{"a":{"kind":"mutating","rules":[{"arg":"x"}]}}}"#); // no constraint
    load_err(r#"{"version":1,"tools":{"a":{"kind":"mutating","rules":[{"max":1}]}}}"#); // no arg
    load_err(r#"{"version":1,"tools":{"a":{"kind":"mutating","rules":[{"arg":"","max":1}]}}}"#);
    load_err(r#"{"version":1,"tools":{"a":{"kind":"mutating","rules":[{"arg":"x","max":"5e"}]}}}"#);
    load_err(r#"{"version":1,"tools":{"a":{"kind":"mutating","rules":[{"arg":"x","max":"0500"}]}}}"#);
    load_err(r#"{"version":1,"tools":{"a":{"kind":"mutating","rules":[{"arg":"x","max":true}]}}}"#);
    load_err(r#"{"version":1,"tools":{"a":{"kind":"mutating","rules":[{"arg":"x","min":5,"max":4}]}}}"#);
    load_err(r#"{"version":1,"tools":{"a":{"kind":"mutating","rules":[{"arg":"x","max":1,"equals":"a"}]}}}"#);
    load_err(r#"{"version":1,"tools":{"a":{"kind":"mutating","rules":[{"arg":"x","one_of":[]}]}}}"#);
    load_err(r#"{"version":1,"tools":{"a":{"kind":"mutating","rules":{}}}}"#);
}
#[test]
fn load_subcap_template_errors() {
    for t in ["", "max_mg/{", "max_mg/{}", "max_mg/{a-b}", "max_mg/}x", "max_mg/{a}{", "a{b}c}"] {
        let p = format!(r#"{{"version":1,"tools":{{"a":{{"kind":"mutating","subcaps":[{{"arg":"mg","max_fact":"{t}"}}]}}}}}}"#);
        load_err(&p);
    }
    load_err(r#"{"version":1,"tools":{"a":{"kind":"mutating","subcaps":[{"arg":"mg"}]}}}"#);
}
#[test]
fn load_scope_errors() {
    load_err(r#"{"version":1,"tools":{"r":{"kind":"sensitive_read"}}}"#);
    load_err(r#"{"version":1,"tools":{"r":{"kind":"sensitive_read","scope":[]}}}"#);
    load_err(r#"{"version":1,"tools":{"r":{"kind":"sensitive_read","scope":["clinic-id"]}}}"#);
    load_err(r#"{"version":1,"tools":{"r":{"kind":"sensitive_read","scope":["___"]}}}"#);
    load_err(r#"{"version":1,"tools":{"r":{"kind":"sensitive_read","scope":["clinic_id","clinicid"]}}}"#);
    load_err(r#"{"version":1,"tools":{"r":{"kind":"sensitive_read","scope":[1]}}}"#);
}
#[test]
fn load_duplicate_tool_refused_by_parser() {
    load_err(r#"{"version":1,"tools":{"a":{"kind":"passthrough"},"a":{"kind":"passthrough"}}}"#);
}
#[test]
fn load_facts_errors() {
    let ok = r#"{"version":1,"tools":{}}"#;
    assert!(load_from_text(ok, Some(r#"{"a":"1","a":"2"}"#), &[]).is_err()); // duplicate
    assert!(load_from_text(ok, Some(r#"{"a":"1.5x"}"#), &[]).is_err());
    assert!(load_from_text(ok, Some(r#"{"a":"0500"}"#), &[]).is_err());
    assert!(load_from_text(ok, Some(r#"{"a":null}"#), &[]).is_err());
    assert!(load_from_text(ok, Some(r#"{"a":{"b":1}}"#), &[]).is_err()); // not flat
    assert!(load_from_text(ok, Some(r#"[1]"#), &[]).is_err());
    assert!(load_from_text(ok, Some(r#"{"":1}"#), &[]).is_err());
    assert!(load_from_text(ok, Some(r#"{"a":1e2,"b":"-3.25"}"#), &[]).is_ok());
}
#[test]
fn load_session_errors() {
    let ok = r#"{"version":1,"tools":{}}"#;
    let s = |k: &str, v: &str| (k.to_string(), v.to_string());
    assert!(load_from_text(ok, None, &[s("clinic_id", "A"), s("clinic_id", "B")]).is_err());
    assert!(load_from_text(ok, None, &[s("", "A")]).is_err());
    assert!(load_from_text(ok, None, &[s("clinic_id", "")]).is_err());
    assert!(load_from_text(ok, None, &[s("clinic id", "A")]).is_err());
    assert!(load_from_text(ok, None, &[s("clinic_id", "A\nB")]).is_err());
}
#[test]
fn load_files_and_size_bound() {
    // A private folder under $MCP_TEST_TMP (or the system temporary folder), removed at the end.
    let base = std::env::var_os("MCP_TEST_TMP").map(std::path::PathBuf::from).unwrap_or_else(std::env::temp_dir);
    let dir = base.join(format!("mcp-policy-unit-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&dir);
    {
        use std::os::unix::fs::DirBuilderExt;
        std::fs::DirBuilder::new().recursive(true).mode(0o700).create(&dir).unwrap();
    }
    let p = dir.join("p.json");
    let f = dir.join("f.json");
    std::fs::write(&p, POL).unwrap();
    std::fs::write(&f, FACTS).unwrap();
    let pol = load(p.to_str().unwrap(), Some(f.to_str().unwrap()), &sess()).expect("files load");
    assert_eq!(pol.kind("ping"), Some(Kind::Passthrough));
    // over 1 MiB: refused before parsing
    let big = dir.join("big.json");
    let mut s = String::from(r#"{"version":1,"tools":{},"clearing":{"x":""#);
    s.push_str(&"a".repeat(1 << 20));
    s.push_str(r#""}}"#);
    std::fs::write(&big, s).unwrap();
    assert!(load(big.to_str().unwrap(), None, &[]).err().unwrap().contains("larger"));
    assert!(load(dir.join("missing.json").to_str().unwrap(), None, &[]).is_err());
    assert!(load(dir.to_str().unwrap(), None, &[]).is_err()); // a directory
    std::fs::remove_dir_all(&dir).unwrap();
}

// ---------------- rules: exact decimal bounds ----------------
#[test]
fn bound_exact_limit_forms_allowed() {
    for a in ["500.00", "500.0", "500", "5e2", "5.00E+2", "50000e-2", "\"500.00\"", "\"5e2\""] {
        assert_eq!(code(pay(a)), "OK", "amount {a}");
    }
}
#[test]
fn bound_just_over_refused() {
    for a in ["500.01", "500.0000000000000000000000000001", "5.0001e2", "501", "1e3", "\"500.01\""] {
        assert_eq!(code(pay(a)), "RULE", "amount {a}");
    }
}
#[test]
fn bound_bad_text_refused() {
    // JSON numbers like 0500 never parse; as strings they are refused by the decimal grammar.
    for a in ["\"0500\"", "\"+500\"", "\".5\"", "\"5.\"", "\" 500\"", "\"500 \"", "\"NaN\"", "\"Infinity\"", "\"0x1F4\"", "\"\"", "\"5e1234567\"", "null", "true", "[500]"] {
        assert_eq!(code(pay(a)), "RULE", "amount {a}");
    }
}
#[test]
fn bound_negative_and_negative_zero() {
    // Default min is 0: a negative payout is refused; -0 is exactly zero and allowed.
    assert_eq!(code(pay("-1")), "RULE");
    assert_eq!(code(pay("-0.01")), "RULE");
    assert_eq!(code(pay("-0")), "OK");
    assert_eq!(code(pay("-0.0e5")), "OK");
    assert_eq!(code(pay("0")), "OK");
}
#[test]
fn bound_explicit_negative_min() {
    let p = pol();
    let r = |a: &str| code(p.check_mutation("refund", &j(&format!(r#"{{"amount": {a}}}"#))));
    assert_eq!(r("-100"), "OK");
    assert_eq!(r("-100.000"), "OK");
    assert_eq!(r("-100.001"), "RULE");
    assert_eq!(r("-1e3"), "RULE");
    assert_eq!(r("100"), "OK");
    assert_eq!(r("1.00e2"), "OK");
    assert_eq!(r("100.1"), "RULE");
}
#[test]
fn bound_tiny_and_huge_exponents_exact() {
    assert_eq!(code(pay("1e-999999")), "OK");
    assert_eq!(code(pay("1e999999")), "RULE");
    assert_eq!(code(pay("4.99999999999999999999999999999999999999e2")), "OK");
    assert_eq!(code(pay("1e1000000")), "RULE"); // exponent with 7 digits: refused, not rounded
}
#[test]
fn rule_missing_argument_and_string_rule() {
    let p = pol();
    assert_eq!(code(p.check_mutation("issue_payout", &j(r#"{"currency":"USD"}"#))), "RULE");
    assert_eq!(code(p.check_mutation("issue_payout", &j(r#"{"amount":1}"#))), "RULE");
    assert_eq!(code(p.check_mutation("issue_payout", &j(r#"{"amount":1,"currency":"GBP"}"#))), "RULE");
    assert_eq!(code(p.check_mutation("issue_payout", &j(r#"{"amount":1,"currency":"usd"}"#))), "RULE");
    assert_eq!(code(p.check_mutation("issue_payout", &j(r#"{"amount":1,"currency":1}"#))), "RULE");
    assert_eq!(code(p.check_mutation("issue_payout", &j(r#"{"amount":1,"currency":"EUR"}"#))), "OK");
}
#[test]
fn mutation_shape_and_unknown_tool() {
    let p = pol();
    assert_eq!(code(p.check_mutation("issue_payout", &j("[1]"))), "SHAPE");
    assert_eq!(code(p.check_mutation("issue_payout", &j("null"))), "SHAPE");
    assert_eq!(code(p.check_mutation("get_patient_chart", &j("{}"))), "SHAPE");
    assert_eq!(code(p.check_mutation("nope", &j("{}"))), "NOT_IN_POLICY");
}

// ---------------- dosage sub-cap ----------------
#[test]
fn subcap_allowed_at_and_below() {
    for mg in ["50", "50.0", "\"50.000\"", "5e1", "49.999", "0"] {
        let a = format!(r#"{{"patient_id":"P-1001","medication":"Warfarin","mg":{mg}}}"#);
        assert_eq!(code(dose(&a)), "OK", "mg {mg}");
    }
}
#[test]
fn subcap_over_refused_with_flag() {
    let e = dose(r#"{"patient_id":"P-1001","medication":"Warfarin","mg":500}"#).unwrap_err();
    assert!(e.subcap);
    assert_eq!(e.code, "SUBCAP");
    assert!(dose(r#"{"patient_id":"P-1001","medication":"Warfarin","mg":50.0000001}"#).unwrap_err().subcap);
}
#[test]
fn subcap_fact_as_json_number() {
    assert_eq!(code(dose(r#"{"patient_id":"P-1002","medication":"Warfarin","mg":"7.50"}"#)), "OK");
    assert_eq!(code(dose(r#"{"patient_id":"P-1002","medication":"Warfarin","mg":7.51}"#)), "SUBCAP");
}
#[test]
fn subcap_missing_fact_refused() {
    let e = dose(r#"{"patient_id":"P-9999","medication":"Warfarin","mg":1}"#).unwrap_err();
    assert!(e.subcap && e.detail.contains("missing"));
    let nofacts = load_from_text(POL, None, &sess()).unwrap();
    let e = nofacts.check_mutation("update_dosage", &j(r#"{"patient_id":"P-1001","medication":"Warfarin","mg":1}"#)).unwrap_err();
    assert!(e.subcap);
}
#[test]
fn subcap_missing_or_bad_arguments_refused() {
    for a in [
        r#"{"patient_id":"P-1001","medication":"Warfarin"}"#,
        r#"{"patient_id":"P-1001","mg":1}"#,
        r#"{"medication":"Warfarin","mg":1}"#,
        r#"{"patient_id":"P-1001","medication":"Warfarin","mg":"fifty"}"#,
        r#"{"patient_id":"P-1001","medication":"Warfarin","mg":null}"#,
        r#"{"patient_id":"P-1001","medication":"Warfarin","mg":-1}"#,
        r#"{"patient_id":["P-1001"],"medication":"Warfarin","mg":1}"#,
        r#"{"patient_id":true,"medication":"Warfarin","mg":1}"#,
    ] {
        let e = dose(a).unwrap_err();
        assert!(e.subcap, "{a}");
    }
}
#[test]
fn subcap_template_injection_refused() {
    // Each of these would build an existing fact name if the template values were not checked.
    for a in [
        r#"{"patient_id":"P-1001/Warfarin","medication":"","mg":40}"#,
        r#"{"patient_id":"P-1001","medication":"Warfarin/","mg":40}"#,
        r#"{"patient_id":"{patient_id}","medication":"Warfarin","mg":40}"#,
        r#"{"patient_id":"P-1001","medication":"","mg":40}"#,
        r#"{"patient_id":"P-1001\n","medication":"Warfarin","mg":40}"#,
        r#"{"patient_id":"P-1001","medication":"Warfarin\u0000","mg":40}"#,
        r#"{"patient_id":"Р-1001","medication":"Warfarin","mg":40}"#,
    ] {
        let e = dose(a).unwrap_err();
        assert!(e.subcap && e.detail.contains("safe"), "{a}: {}", e.detail);
    }
}
#[test]
fn subcap_number_template_value_keeps_text() {
    assert_eq!(code(dose(r#"{"patient_id":1001,"medication":"Warfarin","mg":50}"#)), "OK");
    // 1001.0 names another fact, which is missing: refused.
    assert_eq!(code(dose(r#"{"patient_id":1001.0,"medication":"Warfarin","mg":1}"#)), "SUBCAP");
}

// ---------------- scoped-read filter ----------------
const OWN: &str = r#"{"patient_id":"P-1001","clinic_id":"Clinic_Alpha","name":"A"}"#;
const FOREIGN: &str = r#"{"patient_id":"P-2001","clinic_id":"Clinic_Beta","name":"B"}"#;

#[test]
fn read_own_clinic_passes() {
    assert_eq!(code(read(&text_item(OWN))), "OK");
    let both = format!(r#"{{"content":[{{"type":"text","text":{}}}],"structuredContent":{OWN},"isError":false}}"#, json_str(OWN));
    assert_eq!(code(read(&both)), "OK");
}
fn json_str(s: &str) -> String {
    format!("\"{}\"", s.replace('\\', "\\\\").replace('"', "\\\""))
}
#[test]
fn read_other_clinic_refused() {
    assert_eq!(code(read(&text_item(FOREIGN))), "SCOPE");
    assert_eq!(code(read(&format!(r#"{{"content":[],"structuredContent":{FOREIGN}}}"#))), "SCOPE");
}
#[test]
fn read_mixed_list_one_foreign_refused() {
    let list = format!(r#"{{"records":[{OWN},{OWN},{FOREIGN},{OWN}]}}"#);
    assert_eq!(code(read(&text_item(&list))), "SCOPE");
    // Second content item foreign, first clean.
    let two = format!(r#"{{"content":[{{"type":"text","text":{}}},{{"type":"text","text":{}}}]}}"#, json_str(OWN), json_str(FOREIGN));
    assert_eq!(code(read(&two)), "SCOPE");
}
#[test]
fn read_foreign_deep_nested_refused() {
    let deep = r#"{"clinic_id":"Clinic_Alpha","a":{"b":[{"c":{"d":[[{"clinic_id":"Clinic_Beta"}]]}}]}}"#;
    assert_eq!(code(read(&text_item(deep))), "SCOPE");
}
#[test]
fn read_non_json_text_refused() {
    assert_eq!(code(read(r#"{"content":[{"type":"text","text":"Patient B, Clinic_Beta, DOB 1970"}]}"#)), "NOT_JSON");
    assert_eq!(code(read(r#"{"content":[{"type":"text","text":"{'clinic_id':'Clinic_Alpha'}"}]}"#)), "NOT_JSON");
}
#[test]
fn read_no_scope_key_refused() {
    assert_eq!(code(read(&text_item(r#"{"patient_id":"P-2001","name":"B"}"#))), "UNLABELLED");
    assert_eq!(code(read(&text_item("[]"))), "UNLABELLED");
    assert_eq!(code(read(r#"{"content":[]}"#)), "UNLABELLED");
    // one labelled part and one unlabelled part
    let two = format!(r#"{{"content":[{{"type":"text","text":{}}},{{"type":"text","text":"{{\"name\":\"B\"}}"}}]}}"#, json_str(OWN));
    assert_eq!(code(read(&two)), "UNLABELLED");
}
#[test]
fn read_is_error_refused() {
    assert_eq!(code(read(&format!(r#"{{"content":[{{"type":"text","text":{}}}],"isError":true}}"#, json_str(OWN)))), "UPSTREAM_ERROR");
    assert_eq!(code(read(r#"{"content":[],"isError":"no"}"#)), "SHAPE");
}
#[test]
fn read_non_text_items_refused() {
    assert_eq!(code(read(r#"{"content":[{"type":"image","data":"AAAA","mimeType":"image/png"}]}"#)), "NOT_TEXT");
    assert_eq!(code(read(r#"{"content":[{"type":"resource","resource":{"uri":"x","text":"y"}}]}"#)), "NOT_TEXT");
    let ann = format!(r#"{{"content":[{{"type":"text","text":{},"annotations":{{}}}}]}}"#, json_str(OWN));
    assert_eq!(code(read(&ann)), "NOT_TEXT");
    assert_eq!(code(read(r#"{"content":["x"]}"#)), "NOT_TEXT");
    assert_eq!(code(read(r#"{"content":[{"type":"text","text":5}]}"#)), "NOT_TEXT");
}
#[test]
fn read_shape_errors() {
    assert_eq!(code(read("[]")), "SHAPE");
    assert_eq!(code(read(r#"{"structuredContent":{}}"#)), "SHAPE"); // content missing
    assert_eq!(code(read(r#"{"content":{}}"#)), "SHAPE");
    assert_eq!(code(read(&format!(r#"{{"content":[],"structuredContent":[{OWN}]}}"#))), "SHAPE");
    assert_eq!(code(read(&format!(r#"{{"content":[],"structuredContent":{OWN},"_meta":{{}}}}"#))), "SHAPE");
}
#[test]
fn read_scope_value_types_refused() {
    assert_eq!(code(read(&text_item(r#"{"clinic_id":["Clinic_Alpha"]}"#))), "SCOPE");
    assert_eq!(code(read(&text_item(r#"{"clinic_id":null}"#))), "SCOPE");
    assert_eq!(code(read(&text_item(r#"{"clinic_id":1}"#))), "SCOPE");
    assert_eq!(code(read(&text_item(r#"{"clinic_id":"clinic_alpha"}"#))), "SCOPE"); // case differs
    assert_eq!(code(read(&text_item(r#"{"clinic_id":"Clinic_Alpha "}"#))), "SCOPE");
}
#[test]
fn read_spelling_variants_seen() {
    assert_eq!(code(read(&text_item(r#"{"clinic_id":"Clinic_Alpha","x":{"clinicId":"Clinic_Beta"}}"#))), "SCOPE");
    assert_eq!(code(read(&text_item(r#"{"clinic_id":"Clinic_Alpha","x":{"CLINIC-ID":"Clinic_Beta"}}"#))), "SCOPE");
    assert_eq!(code(read(&text_item(r#"{"clinic_id":"Clinic_Alpha","referring_clinic_id":"Clinic_Beta"}"#))), "SCOPE");
    // A variant spelling with the session value is not a label by itself.
    assert_eq!(code(read(&text_item(r#"{"referring_clinic_id":"Clinic_Alpha"}"#))), "UNLABELLED");
    assert_eq!(code(read(&text_item(r#"{"clinicId":"Clinic_Alpha"}"#))), "OK");
}
#[test]
fn read_nested_json_in_string() {
    let inner = json_str(r#"{"clinic_id":"Clinic_Beta","name":"B"}"#);
    let outer = format!(r#"{{"clinic_id":"Clinic_Alpha","blob":{inner}}}"#);
    assert_eq!(code(read(&text_item(&outer))), "SCOPE");
    // the text item itself is a JSON string that holds JSON
    let whole = json_str(OWN);
    assert_eq!(code(read(&text_item(&whole))), "OK");
    let whole_foreign = json_str(FOREIGN);
    assert_eq!(code(read(&text_item(&whole_foreign))), "SCOPE");
}
#[test]
fn read_nested_too_deep_refused() {
    let mut s = OWN.to_string();
    for _ in 0..6 {
        s = json_str(&s);
    }
    assert_eq!(code(read(&text_item(&s))), "NESTED_TOO_DEEP");
}
#[test]
fn read_scope_name_in_plain_text_refused() {
    let t = r#"{"clinic_id":"Clinic_Alpha","note":"see CLINIC_ID: Clinic_Beta"}"#;
    assert_eq!(code(read(&text_item(t))), "SCOPE_IN_TEXT");
    let trunc = r#"{"clinic_id":"Clinic_Alpha","note":"{\"clinic_id\":\"Clinic_Beta\""}"#;
    assert_eq!(code(read(&text_item(trunc))), "SCOPE_IN_TEXT");
}
#[test]
fn read_session_missing_and_other_tool() {
    let p = load_from_text(POL, None, &[]).unwrap();
    assert_eq!(code(p.check_read_result("get_patient_chart", &j(&text_item(OWN)))), "NO_SESSION");
    let p = pol();
    assert_eq!(code(p.check_read_result("list_invoices", &j(&text_item(r#"{"org_id":"O1"}"#)))), "NO_SESSION");
    assert_eq!(code(p.check_read_result("issue_payout", &j(&text_item(OWN)))), "SHAPE");
    assert_eq!(code(p.check_read_result("nope", &j(&text_item(OWN)))), "NOT_IN_POLICY");
}
#[test]
fn read_two_scope_keys() {
    let p = load_from_text(
        r#"{"version":1,"tools":{"r":{"kind":"sensitive_read","scope":["clinic_id","org_id"]}}}"#,
        None,
        &[("clinic_id".into(), "A".into()), ("org_id".into(), "O".into())],
    )
    .unwrap();
    assert_eq!(code(p.check_read_result("r", &j(&text_item(r#"{"clinic_id":"A","org_id":"O"}"#)))), "OK");
    assert_eq!(code(p.check_read_result("r", &j(&text_item(r#"{"clinic_id":"A"}"#)))), "UNLABELLED");
    assert_eq!(code(p.check_read_result("r", &j(&text_item(r#"{"clinic_id":"A","org_id":"X"}"#)))), "SCOPE");
}
