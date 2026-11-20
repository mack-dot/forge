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

// ---------------- round 3 repairs (REPAIR-POLICY; REVIEW-B findings 1, 2, 3) ----------------
// Each `r3_` case fails on the policy.rs of commit 65ccdc55 (shown in the round 3 report; `filters_result` added
// there as a shim with the old behaviour). The filter cases use POL, so they fail on the old code for the filter
// reason, not for a load error. The `limit_` cases pin a STATED limit of policy.rs ("Known limits") and the
// `keep_` case a legitimate result; both pass on both versions.

/// The shipped healthcare policy (examples/archia_mcp_showcase/policies/healthcare.policy.json), copied.
const HC_POL: &str = r#"{"version": 1, "tools": {
  "update_dosage": {"kind": "mutating",
    "bind": [{"fact": "clinic/{patient_id}", "session": "clinic_id"}],
    "args": "closed",
    "subcaps": [{"arg": "mg", "max_fact": "max_mg/{patient_id}/{medication}"}],
    "scope": ["clinic_id"], "labels": "optional"},
  "get_patient_chart": {"kind": "sensitive_read", "scope": ["clinic_id"]}}}"#;
/// A part of the shipped facts, plus two odd facts for the type checks.
const HC_FACTS: &str = r#"{"clinic/PT-A-001": {"id": "Clinic_Alpha"}, "clinic/PT-B-001": {"id": "Clinic_Beta"},
  "max_mg/PT-A-001/metoprolol": "50", "max_mg/PT-B-001/warfarin": "10", "max_mg/PT-B-001/metoprolol": "50",
  "clinic/PT-A-777": "5", "max_mg/PT-A-001/idcap": {"id": "50"}, "clinic/PT-A-002": {"id": "Clinic_Alpha"}}"#;

fn hc() -> Policy {
    load_from_text(HC_POL, Some(HC_FACTS), &sess()).expect("healthcare policy loads")
}
fn hdose(args: &str) -> Result<(), policy::Deny> {
    hc().check_mutation("update_dosage", &j(args))
}
fn hread(tool: &str, result: &str) -> &'static str {
    code(hc().check_read_result(tool, &j(result)))
}
/// The read filter of `get_patient_chart` under POL (the policy that also loads on the old policy.rs).
fn cread(result: &str) -> &'static str {
    code(read(result))
}
/// A chart text item with one extra member `note` (any JSON value text).
fn chart_with(extra: &str) -> String {
    text_item(&format!(r#"{{"clinic_id":"Clinic_Alpha","patient_id":"PT-A-001",{extra}}}"#))
}

// Finding 1 (FAIL-OPEN): cross-clinic write.
#[test]
fn r3_bind_foreign_patient_refused() {
    let e = hdose(r#"{"patient_id":"PT-B-001","medication":"warfarin","mg":10}"#).unwrap_err();
    assert_eq!(e.code, "SCOPE_BIND");
    assert!(!e.subcap);
}
#[test]
fn r3_bind_own_patient_then_subcap() {
    assert_eq!(code(hdose(r#"{"patient_id":"PT-A-001","medication":"metoprolol","mg":50}"#)), "OK");
    assert_eq!(code(hdose(r#"{"patient_id":"PT-A-001","medication":"metoprolol","mg":50.01}"#)), "SUBCAP");
    assert_eq!(code(hdose(r#"{"patient_id":"PT-A-001","medication":"insulin","mg":1}"#)), "SUBCAP");
}
#[test]
fn r3_bind_missing_fact_refused() {
    // PT-A-002 has a bind fact and no cap; PT-Z-009 has no fact at all.
    assert_eq!(code(hdose(r#"{"patient_id":"PT-Z-009","medication":"warfarin","mg":1}"#)), "SCOPE_BIND");
    let nofacts = load_from_text(HC_POL, None, &sess()).unwrap();
    assert_eq!(code(nofacts.check_mutation("update_dosage", &j(r#"{"patient_id":"PT-A-001","medication":"metoprolol","mg":1}"#))), "SCOPE_BIND");
}
#[test]
fn r3_bind_fact_types() {
    // A decimal fact never satisfies a bind; an id fact never satisfies a sub-cap.
    assert_eq!(code(hdose(r#"{"patient_id":"PT-A-777","medication":"metoprolol","mg":1}"#)), "SCOPE_BIND");
    assert_eq!(code(hdose(r#"{"patient_id":"PT-A-001","medication":"idcap","mg":1}"#)), "SUBCAP");
}
#[test]
fn r3_bind_bad_template_argument() {
    for a in [
        r#"{"medication":"metoprolol","mg":1}"#,
        r#"{"patient_id":"PT-A-001/x","medication":"metoprolol","mg":1}"#,
        r#"{"patient_id":["PT-A-001"],"medication":"metoprolol","mg":1}"#,
        r#"{"patient_id":"PT-A-001 ","medication":"metoprolol","mg":1}"#,
    ] {
        assert_eq!(code(hdose(a)), "SCOPE_BIND", "{a}");
    }
}
#[test]
fn r3_bind_session_missing_or_other() {
    let none = load_from_text(HC_POL, Some(HC_FACTS), &[]).unwrap();
    assert_eq!(code(none.check_mutation("update_dosage", &j(r#"{"patient_id":"PT-A-001","medication":"metoprolol","mg":1}"#))), "SCOPE_BIND");
    let beta = load_from_text(HC_POL, Some(HC_FACTS), &[("clinic_id".into(), "Clinic_Beta".into())]).unwrap();
    assert_eq!(code(beta.check_mutation("update_dosage", &j(r#"{"patient_id":"PT-A-001","medication":"metoprolol","mg":1}"#))), "SCOPE_BIND");
    assert_eq!(code(beta.check_mutation("update_dosage", &j(r#"{"patient_id":"PT-B-001","medication":"warfarin","mg":10}"#))), "OK");
}

// Finding 3 (oracle): the code of a foreign call does not depend on its facts or its dose.
#[test]
fn r3_foreign_code_independent_of_facts_and_dose() {
    for a in [
        r#"{"patient_id":"PT-B-001","medication":"warfarin","mg":1}"#,      // fact exists, under the cap
        r#"{"patient_id":"PT-B-001","medication":"warfarin","mg":99999}"#,  // fact exists, over the cap
        r#"{"patient_id":"PT-B-001","medication":"insulin","mg":1}"#,       // no cap fact
        r#"{"patient_id":"PT-B-001","medication":"warfarin"}"#,             // dose missing
        r#"{"patient_id":"PT-B-001","medication":"warfarin","mg":1,"x":1}"#, // extra argument (args closed)
        r#"{"patient_id":"PT-B-404","medication":"warfarin","mg":1}"#,      // no bind fact
    ] {
        let e = hdose(a).unwrap_err();
        assert_eq!((e.code, e.subcap), ("SCOPE_BIND", false), "{a}");
    }
}
#[test]
fn r3_own_subcap_one_code_missing_or_exceeded() {
    let over = hdose(r#"{"patient_id":"PT-A-001","medication":"metoprolol","mg":51}"#).unwrap_err();
    let missing = hdose(r#"{"patient_id":"PT-A-002","medication":"metoprolol","mg":1}"#).unwrap_err();
    assert_eq!((over.code, over.subcap), ("SUBCAP", true));
    assert_eq!((missing.code, missing.subcap), ("SUBCAP", true));
    assert!(over.detail != missing.detail); // the precise reason stays in `detail` (stderr only)
}

// New rule: "args": "closed".
#[test]
fn r3_args_closed() {
    let e = hdose(r#"{"patient_id":"PT-A-001","medication":"metoprolol","mg":1,"note":"x"}"#).unwrap_err();
    assert_eq!((e.code, e.subcap), ("ARGS", false));
    // Without "closed" (POL, the default "open") an unnamed argument passes with any value.
    assert_eq!(code(dose(r#"{"patient_id":"P-1001","medication":"Warfarin","mg":1,"note":{"x":[1]}}"#)), "OK");
}

// New rules: load errors of bind, args, scope on mutating, labels, id facts.
#[test]
fn r3_load_new_key_errors() {
    let m = |extra: &str| format!(r#"{{"version":1,"tools":{{"a":{{"kind":"mutating"{extra}}}}}}}"#);
    for extra in [
        r#","bind":[]"#,
        r#","bind":{}"#,
        r#","bind":[{"fact":"clinic/{p}"}]"#,
        r#","bind":[{"session":"clinic_id"}]"#,
        r#","bind":[{"fact":"clinic/{p}","session":"clinic-id"}]"#,
        r#","bind":[{"fact":"clinic/{","session":"clinic_id"}]"#,
        r#","bind":[{"fact":"clinic/{p}","session":"clinic_id","x":1}]"#,
        r#","args":"shut""#,
        r#","args":true"#,
        r#","labels":"optional""#,
        r#","scope":["clinic_id"],"labels":"maybe""#,
        r#","scope":[]"#,
        r#","scope":["clinic_id"]"#, // a mutating scope needs an explicit "labels"
        r#","scope":["clinic_id","clinicId"]"#,
    ] {
        load_err(&m(extra));
    }
    load_err(r#"{"version":1,"tools":{"r":{"kind":"sensitive_read","scope":["clinic_id"],"labels":"optional"}}}"#);
    assert!(load_from_text(&m(r#","bind":[{"fact":"clinic/{p}","session":"clinic_id"}],"args":"closed","scope":["clinic_id"],"labels":"required""#), None, &[]).is_ok());
}
#[test]
fn r3_id_fact_syntax() {
    let ok = r#"{"version":1,"tools":{}}"#;
    assert!(load_from_text(ok, Some(r#"{"clinic/P":{"id":"Clinic_Alpha"},"cap":"5"}"#), &[]).is_ok());
    for bad in [r#"{"c":{"id":""}}"#, r#"{"c":{"id":1}}"#, r#"{"c":{"id":"A","x":1}}"#, r#"{"c":{}}"#, r#"{"c":{"id":"A\nB"}}"#, r#"{"c":"Clinic_Alpha"}"#] {
        assert!(load_from_text(ok, Some(bad), &[]).is_err(), "{bad}");
    }
    let long = format!(r#"{{"c":{{"id":"{}"}}}}"#, "a".repeat(257));
    assert!(load_from_text(ok, Some(&long), &[]).is_err());
}

// New interface: filters_result and the result filter of a mutating tool.
#[test]
fn r3_filters_result() {
    let p = hc();
    assert!(p.filters_result("update_dosage"));
    assert!(p.filters_result("get_patient_chart"));
    let q = pol();
    assert!(q.filters_result("get_patient_chart") && q.filters_result("list_invoices"));
    assert!(!q.filters_result("issue_payout")); // mutating, no scope
    assert!(!q.filters_result("ping"));
    assert!(!q.filters_result("nope"));
}
#[test]
fn r3_mutating_result_filter() {
    // The real server's update result (no clinic_id): passes with "labels": "optional".
    let ack = r#"{"max_safe_mg":50,"medication":"metoprolol","mg":25,"patient_id":"PT-A-001","previous_mg":"12.5","status":"applied"}"#;
    let both = format!(r#"{{"content":[{{"type":"text","text":{}}}],"structuredContent":{ack},"isError":false}}"#, json_str(ack));
    assert_eq!(hread("update_dosage", &both), "OK");
    // A hostile upstream that returns a foreign record, or a scope name in text, is refused.
    assert_eq!(hread("update_dosage", &text_item(r#"{"status":"applied","clinic_id":"Clinic_Beta","previous_mg":5}"#)), "SCOPE");
    assert_eq!(hread("update_dosage", &text_item(r#"{"status":"applied","note":"clinicId Clinic_Beta"}"#)), "SCOPE_IN_TEXT");
    assert_eq!(hread("update_dosage", &format!(r#"{{"content":[{{"type":"text","text":{}}}],"isError":true}}"#, json_str(ack))), "UPSTREAM_ERROR");
    // With required labels, the same acknowledgement is UNLABELLED.
    let req = HC_POL.replace(r#""labels": "optional""#, r#""labels": "required""#);
    let p = load_from_text(&req, Some(HC_FACTS), &sess()).unwrap();
    assert_eq!(code(p.check_read_result("update_dosage", &j(&both))), "UNLABELLED");
}

// Finding 2 (HIGH): the nine shapes of REVIEW-B a1 (rows 5 to 13), each with the payload of a1/payloads.py.
#[test]
fn r3_a1_row05_text_label_upper_hyphen() {
    assert_eq!(cread(&chart_with(r#""note":"CLINIC-ID: Clinic_Beta BETA_PHI_MARK""#)), "SCOPE_IN_TEXT");
}
#[test]
fn r3_a1_row06_text_label_camel_case() {
    assert_eq!(cread(&chart_with(r#""note":"clinicId: Clinic_Beta BETA_PHI_MARK""#)), "SCOPE_IN_TEXT");
}
#[test]
fn r3_a1_row07_nested_trailing_comma() {
    let note = json_str(r#"{"clinicId":"Clinic_Beta","name":"Synthetic Patient Beta-One","MARK":"BETA_PHI_MARK",}"#);
    assert_eq!(cread(&chart_with(&format!(r#""note":{note}"#))), "SCOPE_IN_TEXT");
}
#[test]
fn r3_a1_row08_nested_duplicate_keys() {
    let note = json_str(r#"{"clinicId":"Clinic_Alpha","clinicId":"Clinic_Beta","MARK":"BETA_PHI_MARK"}"#);
    assert_eq!(cread(&chart_with(&format!(r#""note":{note}"#))), "SCOPE_IN_TEXT");
}
#[test]
fn r3_a1_row09_escaped_key_trailing_text() {
    // The key holds a literal backslash-u escape of `_` (one JSON escape level inside the note text).
    let note = json_str(&format!(r#"{{"clinic{}u005fid":"Clinic_Beta","MARK":"BETA_PHI_MARK"}} end"#, '\\'));
    assert_eq!(cread(&chart_with(&format!(r#""note":{note}"#))), "SCOPE_IN_TEXT");
}
#[test]
fn r3_a1_row10_json_after_form_feed() {
    let note = format!(r#""\f{}""#, &json_str(r#"{"clinicId":"Clinic_Beta","MARK":"BETA_PHI_MARK"}"#)[1..].trim_end_matches('"'));
    assert_eq!(cread(&chart_with(&format!(r#""note":{note}"#))), "SCOPE_IN_TEXT");
}
#[test]
fn r3_a1_row11_foreign_record_in_object_key() {
    let key = json_str(r#"{"clinic_id": "Clinic_Beta", "name": "Synthetic Patient Beta-One", "MARK": "BETA_PHI_MARK"}"#);
    assert_eq!(cread(&chart_with(&format!(r#"{key}:"Clinic_Alpha""#))), "SCOPE");
}
#[test]
fn r3_a1_row12_plain_text_in_object_key() {
    assert_eq!(cread(&chart_with(r#""x":{"clinic_id=Clinic_Beta BETA_PHI_MARK":"Clinic_Alpha"}"#)), "SCOPE_IN_TEXT");
}
#[test]
fn r3_a1_row13_nested_json_deeper_than_parser() {
    let inner = format!("{}{}{}", "[".repeat(70), r#"{"clinicId":"Clinic_Beta","MARK":"BETA_PHI_MARK"}"#, "]".repeat(70));
    assert_eq!(cread(&chart_with(&format!(r#""note":{}"#, json_str(&inner)))), "SCOPE_IN_TEXT");
}

// Finding 2, the new rules in general form (no scope key name involved, or a key as the carrier).
#[test]
fn r3_json_like_text_that_is_not_strict_json_refused() {
    for s in ["[draft] note", r#"{"name":"B",}"#, r#"{"a":1,"a":2}"#, r#""quoted" words"#, "\u{a0}{\"name\":\"B\"}"] {
        assert_eq!(cread(&chart_with(&format!(r#""note":{}"#, json_str(s)))), "NESTED_NOT_JSON", "{s}");
    }
    let deep = format!("{}{}", "[".repeat(70), "]".repeat(70)); // deeper than the parser's 64 levels
    assert_eq!(cread(&chart_with(&format!(r#""note":{}"#, json_str(&deep)))), "NESTED_NOT_JSON");
}
#[test]
fn r3_json_like_object_key_not_strict_refused() {
    let key = json_str(r#"{"name":"Synthetic Patient Beta-One",}"#);
    assert_eq!(cread(&chart_with(&format!(r#"{key}:1"#))), "NESTED_NOT_JSON");
}
#[test]
fn r3_text_check_after_u_decoding() {
    // Literal backslash-u sequences in plain text (not JSON-like): one round, two rounds.
    assert_eq!(cread(&chart_with(r#""note":"see clinic\\u005fid=Clinic_Beta""#)), "SCOPE_IN_TEXT");
    assert_eq!(cread(&chart_with(r#""note":"see clinic\\u005cu005fid=Clinic_Beta""#)), "SCOPE_IN_TEXT");
    assert_eq!(cread(&chart_with(r#""note":"see \\u0063linic\\u0049D""#)), "SCOPE_IN_TEXT");
    // The same in an object key.
    assert_eq!(cread(&chart_with(r#""clinic\\u005fid":"Clinic_Beta""#)), "SCOPE_IN_TEXT");
    // Still escaped after 4 rounds: refused.
    let mut s = String::from("\\u005f");
    for _ in 0..4 {
        s = s.replacen('\\', "\\u005c", 1);
    }
    assert_eq!(cread(&chart_with(&format!(r#""note":{}"#, json_str(&s)))), "ESCAPED_TEXT");
}
#[test]
fn r3_variant_key_must_end_with_scope_key() {
    assert_eq!(cread(&chart_with(r#""clinic_id_Clinic_Beta":"Clinic_Alpha""#)), "SCOPE_IN_TEXT");
    assert_eq!(cread(&chart_with(r#""clinic_id: Beta":"Clinic_Alpha""#)), "SCOPE_IN_TEXT");
    assert_eq!(cread(&chart_with(r#""referring clinic-id":"Clinic_Alpha""#)), "OK");
}
#[test]
fn keep_own_chart_of_the_real_server_passes() {
    // The real server's chart of PT-A-003 (both parts): no false refusal of the repaired rules.
    let c = r#"{"birth_year":1958,"clinic_id":"Clinic_Alpha","medications":[{"max_safe_mg":80,"medication":"atorvastatin","mg":20},{"max_safe_mg":50,"medication":"metoprolol","mg":"12.5"}],"name":"Synthetic Patient Alpha-Three","patient_id":"PT-A-003"}"#;
    let both = format!(r#"{{"content":[{{"type":"text","text":{}}}],"structuredContent":{c},"isError":false}}"#, json_str(c));
    assert_eq!(cread(&both), "OK");
}

// Stated limits ("Known limits" in policy.rs): these still PASS. Each is the a1 payload or the doc example.
#[test]
fn limit_unlabelled_foreign_record_next_to_label_passes() {
    assert_eq!(cread(&chart_with(r#""rows":[{"name":"Synthetic Patient Beta-One","MARK":"BETA_PHI_MARK"}]"#)), "OK");
}
#[test]
fn limit_other_label_word_and_lookalike_pass() {
    assert_eq!(cread(&chart_with(r#""rows":[{"clinic":"Clinic_Beta"}]"#)), "OK");
    assert_eq!(cread(&chart_with(r#""rows":[{"clinіc_id":"Clinic_Beta"}]"#)), "OK"); // Cyrillic і
}
#[test]
fn limit_words_before_scope_name_in_variant_key_pass() {
    assert_eq!(cread(&chart_with(r#""Clinic_Beta_Beta_One_clinic_id":"Clinic_Alpha""#)), "OK");
}
#[test]
fn limit_other_encodings_pass() {
    assert_eq!(cread(&chart_with(r#""note":"clinic%5Fid=Clinic_Beta""#)), "OK"); // URL encoding
    assert_eq!(cread(&chart_with(r#""note":"Y2xpbmljX2lkPUNsaW5pY19CZXRh""#)), "OK"); // base64
}
