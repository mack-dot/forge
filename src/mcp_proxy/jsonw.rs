//! Small JSON writer for the messages that the proxy itself creates (refusals, dropped reads, the state answer).
//! NATIVE CHECK and FINITE TEST, not proved. Standard library only.
//! The proxy never re-serializes a message that it forwards: forwarded lines keep their original bytes.
use crate::json::J;
use std::fmt::Write;

/// Append `s` as a JSON string literal (RFC 8259): quote, backslash and every control byte below 0x20 are escaped.
/// Every other character is written as UTF-8.
pub fn push_str(out: &mut String, s: &str) {
    out.push('"');
    for c in s.chars() {
        match c {
            '"' => out.push_str("\\\""),
            '\\' => out.push_str("\\\\"),
            '\n' => out.push_str("\\n"),
            '\r' => out.push_str("\\r"),
            '\t' => out.push_str("\\t"),
            '\u{8}' => out.push_str("\\b"),
            '\u{c}' => out.push_str("\\f"),
            c if (c as u32) < 0x20 => {
                let _ = write!(out, "\\u{:04x}", c as u32);
            }
            c => out.push(c),
        }
    }
    out.push('"');
}

/// A JSON string literal for `s`.
pub fn string(s: &str) -> String {
    let mut o = String::with_capacity(s.len() + 2);
    push_str(&mut o, s);
    o
}

/// The JSON text that echoes a request id: a number keeps its exact source text, a string is re-escaped (same
/// value). Any other value gives None (the caller answers with `"id": null`).
pub fn id_text(id: &J) -> Option<String> {
    match id {
        J::Num(t) => Some(t.clone()),
        J::Str(s) => Some(string(s)),
        _ => None,
    }
}

/// A JSON-RPC error that the proxy creates. `id` is JSON text (`null` allowed). `verdict` is a fixed word.
pub fn error(id: &str, code: i32, message: &str, verdict: &str, detail: &str, epoch: u64, state_hex: &str) -> String {
    let mut o = String::with_capacity(160 + detail.len());
    o.push_str("{\"jsonrpc\":\"2.0\",\"id\":");
    o.push_str(id);
    let _ = write!(o, ",\"error\":{{\"code\":{code},\"message\":");
    push_str(&mut o, message);
    o.push_str(",\"data\":{\"verdict\":");
    push_str(&mut o, verdict);
    o.push_str(",\"detail\":");
    push_str(&mut o, detail);
    let _ = write!(o, ",\"epoch\":{epoch},\"state\":");
    push_str(&mut o, state_hex);
    o.push_str("}}}");
    o
}

/// The answer to a dropped sensitive read: a valid MCP `CallToolResult` with an empty content set and
/// `isError: true`. `reason` is a short fixed word; no byte of the upstream response is copied.
pub fn dropped_read(id: &str, reason: &str) -> String {
    let mut o = String::with_capacity(200);
    o.push_str("{\"jsonrpc\":\"2.0\",\"id\":");
    o.push_str(id);
    o.push_str(",\"result\":{\"content\":[],\"isError\":true,\"_meta\":{\"forge-airlock/verdict\":\"READ_DROPPED\",\"forge-airlock/reason\":");
    push_str(&mut o, reason);
    o.push_str("}}}");
    o
}

/// The answer to the extension method `forge-airlock/state`.
pub fn state_result(id: &str, epoch: u64, state_hex: &str) -> String {
    let mut o = String::with_capacity(100);
    o.push_str("{\"jsonrpc\":\"2.0\",\"id\":");
    o.push_str(id);
    let _ = write!(o, ",\"result\":{{\"epoch\":{epoch},\"state\":");
    push_str(&mut o, state_hex);
    o.push_str("}}");
    o
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::json;

    #[test]
    fn escape_round_trip() {
        let samples = ["", "a", "\"q\"", "back\\slash", "nl\nret\rtab\t", "\u{0}\u{1}\u{1f}\u{8}\u{c}", "é€😀", "\u{7f}", "</script>"];
        for s in samples {
            let t = string(s);
            assert!(!t.bytes().any(|b| b < 0x20), "raw control byte in {t:?}");
            assert_eq!(json::parse(&t), Ok(J::Str(s.to_string())), "round trip of {s:?}");
        }
    }

    #[test]
    fn id_echo() {
        for (src, want) in [("7", "7"), ("-12", "-12"), ("1.50e3", "1.50e3"), ("\"abc\"", "\"abc\""), ("\"a\\u0041\"", "\"aA\"")] {
            let j = json::parse(src).unwrap();
            assert_eq!(id_text(&j).as_deref(), Some(want));
        }
        assert_eq!(id_text(&J::Null), None);
        assert_eq!(id_text(&J::Bool(true)), None);
    }

    #[test]
    fn shapes_parse() {
        let e = error("\"x\\n\"", -32001, "Airlock Invariant Breach", "BLOCKED_CAS", "pre \"bad\"\n", 3, "00ff");
        let v = json::parse(&e).unwrap();
        assert_eq!(v.get("id"), Some(&J::Str("x\n".into())));
        let err = v.get("error").unwrap();
        assert_eq!(err.get("code"), Some(&J::Num("-32001".into())));
        assert_eq!(err.get("data").unwrap().get("epoch"), Some(&J::Num("3".into())));
        let d = json::parse(&dropped_read("5", "SCOPE")).unwrap();
        let r = d.get("result").unwrap();
        assert_eq!(r.get("content"), Some(&J::Arr(vec![])));
        assert_eq!(r.get("isError"), Some(&J::Bool(true)));
        let s = json::parse(&state_result("null", 0, "ab")).unwrap();
        assert_eq!(s.get("result").unwrap().get("epoch"), Some(&J::Num("0".into())));
    }
}
