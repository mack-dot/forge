# Acceptance against the directive (h-gate, 2026-11-19). Proposal only: NOTHING applied to gate/.

Proposal = diff (i) e-subset2/diff/refund-scope-minimal.diff (cited, unchanged; folded into (ii)) + diff (ii)
diff/refund-jsbound-combined.diff (against 985f5eaf: scope relaxations, `@` and `abstract` by the expect-rule
lexer, the `expect` rule and process supervision of e-expect/p3, and a new refusal tier `js_bound` that runs
gate/refund/js_bound_check.cjs on the compiled JavaScript). (iii) No piece of rule 3 is needed. gate/ is a
protected path: the new file gate/refund/js_bound_check.cjs is a protected-path ADDITION (owner approval).

## Criterion 1: "All seven known unsafe gate submissions are rejected."
| file | source scope (proposed) | JS check (proposed) | tier that refuses | evidence |
|---|---|---|---|---|
| E06-stack-overflow-keyed | PASS | RECURSION (DeepM, 64 unfoldings) | js_bound (both tiers) | results/check-none.jsonl |
| E07-oom-keyed | PASS | LOOP (Seq.Create length) | js_bound | same |
| E08-time-keyed | PASS | LOOP (4096 unfoldings) | js_bound | same |
| H01b-such-that-modulus-hang | PASS | STATEMENT (for...of search) | js_bound | same |
| H02-exponential-recursion-hang | PASS | RECURSION (Slow) | js_bound | same |
| H03-seq-comprehension-alloc | PASS | LOOP (Seq.Create length) | js_bound | same |
| H04-seq-length-2pow32-throws | PASS | LOOP (Seq.Create length) | js_bound | same |
| Z24 (4 variants) | `expect` rule | HALT (`throw`) on Z24-1000 | source rule; js_bound as second line | logs/scope_new.out |
Status: MACHINE-CHECKED for the checker and the scope rules separately (light single runs, actual outputs in the
files named). The gate copy as a whole (Dafny verify + build + checker + tests) is NOT RUN: heavy run prepared
(heavy/gate_jsbound.sh, TIER=critical and TIER=hostile-tests). Wiring of the two new gate functions: TESTED with a
stubbed Dafny (tools/wiring_test.py: E08 and Z24 refused in the critical path; P03, E06, A01 refused and C1-table
accepted in the hostile path).

## Criterion 2: "The observed false rejections are explained and resolved, or explicitly documented as unresolved."
See FALSE_REJECTIONS.md (one row per file, clause and line, category, status) and VERDICTS.md (per-file checker
verdicts and mutants). Totals are in the final section of FALSE_REJECTIONS.md (generated, not hand-counted).
"RESOLVED" there means: the proposed source-scope rules PASS (MACHINE, tools/scope_check.py on the proposed gate
text) AND the JS checker ACCEPTS the translation (MACHINE). It does NOT mean that the full gate accepted the file:
that needs the heavy run (NOT RUN). "PENDING" = no translation yet (heavy/translate_all.sh covers it).

## Safety preserved (hard constraint)
- No file of the hostile set with JavaScript is admitted unless its run is bounded by the stated caps; the three
  admitted review files (A04, A05b, A06: rule-2 bypasses) ran in 4-29 ms each under the 2 s / 200 MB limit
  (logs/drive_bounded.out, TESTED); A01 (2x40) is refused and is killed at 2 s when run (same log).
- Controls: a reject-all checker would fail: the checker accepts the repo implementation, the gate build
  (build/refund-generated/model.js), every rule-3-refused correct file with a translation, and the accepted sample.
- Mutants (5): see VERDICTS.md "mutant ... admits unsafe". Each of no-loop, no-recursion, no-load, no-shape admits
  named unsafe files; no-cost admits HV06/Y06 only if their translations exist (see VERDICTS.md).
- Red-team items (orch-C via orchestrator): C-GATE-02: no in-process recognizer remains; the source lexer is one
  linear pass with fail-closed caps (256 KiB, bracket nesting 64); control tools/regress_hgate.sh: exit 0 on the
  proposal (D-brace-nest-5000/10000/20000 and C30 refused in 0.08-0.15 s), exit 1 on pristine 985f5eaf (C30
  PASS) (logs/regress_hgate.out). The JS checker runs in a child with a 120 s bound; timeout or crash = refusal;
  it refuses modules over 1 MiB or nesting over 200 (synthetic 20,000-paren file refused). C-GATE-03: main()
  reads impl/Refund.dfy ONCE; prepare(code), identity(tier, code) and the snapshot check use these bytes
  (INPUT_CHANGED otherwise); the hostile tier checks the exact module bytes it runs. OPEN: Dafny verify,
  translate and build re-read the file; a swap that is restored before the final snapshot is not detected.
  C-GATE-04: G01, G02, G03, G08, G09 are rows of FALSE_REJECTIONS.md (all RESOLVED: scope PASS, JS ACCEPT).
- C-GATE-05 (bodiless ghost axioms A01, A02, A13-A17): scope PASS and the JS tier cannot see ghost code, so
  their refusal is owned by Dafny verify (non-zero exit by default) and both audit steps (red-team MACHINE logs:
  A01 verify exit 2, audit exit 2; A02 verify exit 2) and by the build: my `dafny translate js` of all seven
  exits non-zero (6 x exit 3 "warnings were found", A14 exit 2 resolution error; logs/A*.translate.7.log). The diff marks this as
  LOAD-BEARING in prove(): no warning-relaxing option, no relaxed audit. No token rule decides "has a body".
- C-GATE-06 (G11 `1_000_000`): scope PASS; JS verdict: see FALSE_REJECTIONS.md row G11.
- Out of scope of a cost bound: orch-C B01 (verbatim string with CR, runtime differs from the verifier) is
  ADMITTED by the JS checker (bounded, 245 steps). It is a compiler-correctness question (assumption J2); only
  the test tier or a differential oracle can refuse it.
- Per-change tables on the full sets: PER_CHANGE.md (V0 pristine, V1 scope-minimal, V2 source rules, V3 + JS).
- Termination by construction (B-7) evaluation: TERMINATION_TIER.md.

## What remains an argument
The cost claim of the checker (JS_CHECK_DESIGN.md: assumptions J1-J5) is an ARGUMENT, not a proof. The runtime
primitive cost table is read from source, not proved. The checker is unverified code of about 700 lines.
