# A13 adversarial review of PF-0004 (condensed by Orchestrator A)
Verdict: no defect. The strict-prefix lemmas are MACHINE-CHECKED at MODEL level for the REAL HOL renderer.
- Integrity HOLDS (128 inputs re-hashed, 0 mismatches). Harness HOLDS: a theorem with hypotheses is never saved; the tag
  check covers all theorems and definitions of the theory before export; FAILED_LIST and DIAG_OK_UNDER_LIST are empty.
- No statement or definition changed from PF-0001 to PF-0004; 5 lemmas were added (`stmt_diff.py`, exit 0).
- `refund_render_fields` is the constant of `forge_refundWireProgScript.sml:10-14`, the one translated into the program and
  named by the stored theorem `refund_profile_a_sl` (e4-0001 stdout 238-264). Fields: (ok, amount, reason, charge, request, count).
- `refund_strict_parse` (defined in the script): parse, empty rest, field decode, re-render equality. Accepts exactly renders.
- Consumer link: `frame.strict_parse` returns a value only if its own `render_fields` output equals the input. So the link is
  "Python `render_fields` = HOL `refund_render_fields`": TESTED-UNPROVED (`consumer_attack.py` exit 0: 25 targeted inputs and
  304,326 random prefixes and edits; 0 wrong acceptances).
- MISSING tonight: a stored theorem for over-long output (`render f ++ junk`, junk ≠ ""): one step from the definition; add it.
- Scope: MODEL only. Real stdout = model output needs X9 (L-OUT) and X8 (NATIVE), A-FD1-WRITE, A-LOADER; stdout must start empty.
