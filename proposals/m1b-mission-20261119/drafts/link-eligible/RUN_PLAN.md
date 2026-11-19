# M1-B step I.1b — run plan for the eligibility link (DRAFT, NOT RUN)

Worker W2. Every exit code below is an EXPECTED value. None has been
observed. Record the actual codes separately.

Rules: one HOL process at a time (the runner's guard refuses to start when
another HOL child runs, memory free is under 25 %, or disk free is under
3 GiB). Use pinned Node only if a Node step is added (none here). No network.
Do not write under `clearing/`. The run folder name below is a suggestion.

```
F=<HOME>/forge
W2=<session scratch folder>/m1b/W2
RUN=$F/results/m1b-eligible-link-20261119/attempt-0001
B=origin/backup/forge-local-2026-11-11
P=proposals/refund-executable-feasibility
TC=$F/.toolchain/experiments/refund-cakeml-20261104
D=$TC/cakeml/compiler/dafny
DAFNY=$F/.toolchain/dafny-4.11.0/dafny/dafny
Z3=$F/.toolchain/dafny-4.11.0/dafny/z3/bin/z3-4.12.1
```

## 0. Inputs (read-only on the repository; copies go to $RUN)

```
mkdir -p $RUN/inputs $RUN/dafny/impl $RUN/dafny/spec/refund
git -C $F show $B:$P/source-model-binding-20261104/records/hol-0004/input.sexp > $RUN/inputs/FlatCore.sexp
git -C $F show $B:$P/source-export-feasibility-20261104/records/FlatCore-original.dfy > $RUN/dafny/FlatCore.dfy
cp $F/impl/Refund.dfy $RUN/dafny/impl/Refund.dfy
cp $F/spec/refund/RefundSpec.dfy $RUN/dafny/spec/refund/RefundSpec.dfy
cp $W2/EligibleFlat.dfy $RUN/dafny/EligibleFlat.dfy
shasum -a 256 $RUN/inputs/FlatCore.sexp $RUN/dafny/FlatCore.dfy $RUN/dafny/impl/Refund.dfy $RUN/dafny/spec/refund/RefundSpec.dfy
```

Expected SHA-256 values: `58154ddffc3b54d875c51bcd9dd2f36a93334c5cc302c899987aec0d7333dd0d`
(export, 3,621 bytes, no final newline),
`a89484e354914ca293286abfdb97376805d4e417a270342db15df4b784a51f4d` (FlatCore),
`0416882492de095b59f3547a8df788193ec41952cf2d30a65df80b8ecd52a700` (impl),
`90a21c71ae3a7e1cdb7c74d393ae8ed6f312548710bdf0ae71c62255c7ccfe57` (spec).
Stop if one differs.

## 1. Dafny side (no HOL slot needed; can run while HOL runs)

| ID | Command (cwd `$RUN/dafny`) | Expected | Time class |
| --- | --- | --- | --- |
| D1 | `$DAFNY verify EligibleFlat.dfy --solver-path $Z3 --resource-limit 1000000 --verification-time-limit 0 --cores 1 --verify-included-files --log-format "csv;LogFileName=verification.csv"` | exit 0; E1–E5, `Witnesses`, `FlatCore.AssessFlat` and `Refund.Assess` all verified | under 1 min (U295 run: 29 s) |
| D2 | `$DAFNY audit EligibleFlat.dfy` with the same options and empty-report comparison as the Stage 8 audit row in `ROADMAP.md` (line 1450) | exit 0; zero findings | under 1 min |
| D3 (optional, U1–U2) | Copy the U295 tree `git show $B:$P/byte-boundary-20261104/records/dafny-repeat/inputs/…` (all files listed by `git ls-tree -r $B -- $P/byte-boundary-20261104/records/dafny-repeat/inputs`, except `verification.csv`) to `$RUN/dafny-utf8/`; add `EligibleFlat.dfy` as `transport/EligibleFlat.dfy` and `EligibleFlatUtf8.dfy` at the root; check `transport/FlatCore.dfy`, `transport/impl/Refund.dfy`, `transport/spec/refund/RefundSpec.dfy` against the hashes above; then `$DAFNY verify EligibleFlatUtf8.dfy` with the D1 options | exit 0 | about 1 min |

Dafny negative controls (each a separate copy of `$RUN/dafny`; one edit each;
the D1 command must give exit 4 and name the listed obligation):

| ID | Single edit | Must fail |
| --- | --- | --- |
| ND1 | in `EligibleFlat`: `0 <= amount <= remaining` → `0 <= amount < remaining` | E1, E2, E4 |
| ND2 | in `EligibleFlat`: `"returned_item"` → `"returned_items"` | E1, E2, E4 |
| ND3 | in `FlatResponse`: `else R.Missing` → `else R.Candidate(amount, reason)` | E2 (and E4's second ensures) |
| ND4 | in `EligibleFlat`: delete `requestOpen && ` | E1, E2, E4 |
| ND5 | in the copied `FlatCore.dfy` only: delete `requestOpen && ` in BOTH the first ensures and the body (new SHA-256; not the export input) | E4 |

## 2. HOL side (one process at a time)

Runner: copy the recorded runner
`$F/results/refund-profile-a-local-20261117/attempt-0001/run_case.py` to
`$RUN/run_case.py`. Make exactly two edits and record them:
1. `CWD = .../compiler/dafny/forge_refund_call_experiment` (the recorded cwd of
   U294 `proof-0004.sml`, exit 0 on 2026-11-04).
2. Add `'ELIGIBLE_LINK_COMPLETE'` to `MARKERS`.
Copy `$W2/forge_refundEligibleLinkScript.sml` to `$RUN/`.

| ID | Command | Expected | Time class |
| --- | --- | --- | --- |
| H0 (probe) | a 3-line file `probe.sml`: `load "sexp_to_dafnyTheory"; load "forge_refundTheory"; print "EXACT_COMPLETE\n";` run as `cd $RUN && FORGE_HEAP=cakeml/misc/cakeml-heap FORGE_CPU_SECONDS=300 python3 -I -B run_case.py probe-0001 probe.sml` | exit 0, marker present | under 1 min |
| H0′ (only if H0 fails on `load`) | same, with theory paths as extra arguments: `… run_case.py probe-0002 probe.sml $D/sexp_to_dafnyTheory $D/forge_refund_experiment/forge_refundTheory` | exit 0 | under 1 min |
| H1 | `cd $RUN && FORGE_HEAP=cakeml/misc/cakeml-heap FORGE_CPU_SECONDS=900 FORGE_ELIGIBLE_SEXP=$RUN/inputs/FlatCore.sexp python3 -I -B run_case.py link-0001 forge_refundEligibleLinkScript.sml` (add the H0′ extra arguments if H0′ was needed) | exit 0; marker `ELIGIBLE_LINK_COMPLETE`; five `FORGE_THEOREM` lines; `FORGE_HYPOTHESES 0` and empty `FORGE_AXIOMS` each; objects `.hol/objs/forge_refundEligibleLinkTheory.{dat,sig,sml}` | short: 1–5 min (U294 `proof-0004`, which evaluated the whole method twice, took 166.5 s) |
| H2 | repeat H1 as `link-repeat` | exit 0; the same `FORGE_STATEMENT` lines byte for byte | same |
| H3 | fresh import: `import.sml` = `load "<RUN>/link-0001/forge_refundEligibleLinkTheory"`-style load (as U294 `import-0001/audit.sml`), then print `Parse.thm_to_string` of the five theorems and their tags | exit 0; statements equal H1 | under 1 min |

Read `FORGE_STATEMENT eligible_link_guard_value` in the H1 log and compare it
with section 2 of `STATEMENTS.md` by eye before anything else is claimed.

HOL negative controls. Each control uses a mutated copy of the export (a new
file, a new SHA-256), the same script, and a new case name. Expected: exit 1
(nonzero), no `ELIGIBLE_LINK_COMPLETE`, and the named theorem is the failure.

| ID | Edit to the export copy (use exact string replacement) | Must fail |
| --- | --- | --- |
| NH1 | both occurrences of `(BinOp (Le) (Var "amount") (Var "remaining"))` → `(BinOp (Lt) (Var "amount") (Var "remaining"))` | L3 (residual goal) |
| NH2 | only the FIRST occurrence (the ensures clause) of the NH1 text changed | L2 (contract guard ≠ body guard) |
| NH3 | both occurrences of `"returned_item"` → `"returned_itex"` (same length) | L3 |
| NH4 | both occurrences of `(BinOp (Le) (Var "remaining") (Var "original"))` → `(BinOp (Le) (Var "original") (Var "remaining"))` | L3 |
| NH5 | both occurrences of `(Var "requestOpen"))` inside the guard → `(Lit (BoolL True)))` | L3 |
| NH6 | append ` (Extra)` after the last byte | ML refusal `Trailing export bytes` before L1 |
| NH7 | statement control: in a copy of the script, change the right side of L3 to `eligible charge request original remaining enabled opened candidate (amount + 1) reason` (export unchanged) | L3 |
| PC1 (expected PASS) | both occurrences of `(Var "chargeId") (Lit (StrL ""))` ↔ `(Var "requestId") (Lit (StrL ""))` swapped | L1–L5 PASS. This is expected: the guard is symmetric in the two IDs. Record it as a known limit, not as a failure of the controls. The swap must be caught at the tuple step |

If NH2 passes, L2 is too weak; stop and report. If any NH passes, the
positive result does not count.

## 3. Main risks in the draft (from reading only)

1. Environment (highest). `load "forge_refundTheory"` and
   `load "sexp_to_dafnyTheory"` from the `forge_refund_call_experiment` cwd
   have not run since the toolchain rebuild (U413, 2026-11-18). The
   Holmakefiles there have no `INCLUDES`. H0/H0′ test this first.
2. Tactic of L3: `EVAL_TAC >> rpt (IF_CASES_TAC >> fs [] >> EVAL_TAC)`. With
   symbolic inputs EVAL leaves `case (if … then Done … else …) of …` terms;
   the loop must split all twelve conditions. The same tactic closed U294
   `source_full_result` on the same guard and `refund_guard_value` on the
   constructed guard, so the risk is low but not zero.
3. L2 uses `simp` on a large concrete equality after explicit witnesses. If
   `simp` normalises the two sides differently, replace it by
   `REWRITE_TAC [eligible_link_program_def, eligible_link_guard_def]`.
4. Overloaded names (`Var`, `Eq`) in the heap: the draft writes
   `dafny_ast$Var` and `dafny_ast$Eq` where it matters.
5. Dafny: `import R = Refund` plus the include of `FlatCore.dfy` in one
   program (same pattern as U262 `Transport.dfy`, which verified). Risk low.

## 4. Extension of the same method

### 4a. Six-field decision tuple and R1–R5

HOL: U294 already proved, for this exact export, `source_full_result` (all six
outputs equal the `refund_fields` conditionals), `source_postconditions`, and
`CompiledInputBinding.source_compiled_fields` (the outputs equal
`refund_fields`). Re-run those three scripts (backup branch,
`$P/source-model-binding-20261104/records/{proof-0004,relation,bridge}.sml`)
on the rebuilt toolchain with the same runner, one at a time. Add a
`swapped-fields` control (exists: `records/fixtures/swapped-fields.dfy` and its
export) that must fail.

Dafny: add to `RefundEligibleLink` (draft text, not checked):

```dafny
  method TupleLink(context: R.Context, response: R.ModelResponse)
    modifies {}
  {
    var ok, amount, reason, charge, request, count :=
      F.AssessFlat(context.chargeId, context.requestId, context.original,
        context.remaining, context.refundEnabled, context.requestOpen,
        response.Candidate?, FlatAmount(response), FlatReason(response));
    var decision, plan := R.Assess(context, response);
    EligibleFlatMatchesApproved(context, response);
    assert ok <==> decision.Authorized?;
    assert ok ==> decision == R.Authorized(amount, reason);
    assert ok ==> plan == [R.Intent(charge, request, amount, reason)];
    assert !ok ==> decision == R.Rejected && plan == [] &&
      amount == 0 && reason == "" && charge == "" && request == "" ;
    assert count == |plan|;
  }
```

R1–R5 then hold for the tuple through `R.Assess`'s own verified ensures; no
new HOL work is needed for them. The UTF-8 form of the tuple is U295
`RefundByteBoundary.Boundary` (already verified 2026-11-04; re-run D3-style).

### 4b. Output encoding

The approved contract has no wire format. HOL already has
`refund_response_roundtrip`, `refund_response_parse` (`forge_refund_io`) and
U295 `byte_wire_outputs`. What is missing is an APPROVED statement of the
output format; without it there is nothing on the Dafny side to be equivalent
to. Propose it to the owner as a new specification item; do not invent it.

### 4c. Route 1b (cleaner, needs a frontend rebuild)

Put `EligibleFlat` alone in a module file (`module FlatEligible { predicate
EligibleFlat(…) {…} }`), export it with the rebuilt U294 patched frontend
(commit `6eb1ed63…` + patch `df88831b…`; needs the .NET SDK and NuGet, so the
network, so the owner's word), and prove in HOL
`0 < st.clock ⇒ evaluate_exp st (mk_env P) (FunCall «EligibleFlat» [Var … ×9]) = … BoolV (eligible …)`.
Then the Dafny lemma is about the very predicate that was exported, and E4
(the method detour) is not needed. Trust items stay the same.
