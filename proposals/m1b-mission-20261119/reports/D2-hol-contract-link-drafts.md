# Step D2: the HOL half of the contract link: comparison of the contracts, the full draft theorem and its controls (Y2, Opus; drafts only; nothing ran in HOL)

Worker report, saved verbatim by the orchestrator from the worker's transcript (home and scratch paths replaced). It is model output. It is not evidence by itself: the orchestrator's checks are in `TRACKER.md`.

---

## Y2 report (graph links S5, S6). Drafts only. Nothing ran in HOL. M1-B stays OPEN.

### Findings
1. **Same contract at the source-text level.** I measured this, I did not prove it. `LinkedRefund` reaches `FlatRefund.AssessFlat` only through `inputs/transport/FlatCore.dfy`. That file has SHA-256 `a89484e3…`, the same bytes as the U294 exporter input (`export-0003/input.dfy`). The 34 included files contain only this one `module FlatRefund`. A clause-by-clause read of the export (`58154ddf…`, 3,621 bytes) against `FlatCore.dfy` finds no mismatch. The export keeps the same 9 inputs and 6 outputs, with the same names, types and order. It has no requires, reads or modifies. The three ensures map to `Eq`, `Imp` and `Imp(Not)`. The `And` chains nest to the left (HOL `eligible` nests to the right), and the values are equal.
   - The other differences are not mismatches; each one is a named assumption:
     - **Strings:** a Dafny char is Unicode, a HOL char is 8 bits. The contract is used only on `Encoded(·)` (every char below 256) and on `""`.
     - **Names:** HOL binds the inputs by position.
     - **Integers:** unbounded on both sides.
     - **Operator meanings:** this is S7.
   - **Swaps that the guard cannot see:** the guard is symmetric in `enabled`/`opened` and in `chargeId`/`requestId`. The id swap is caught by ensures 2. The enabled/opened swap is caught by nothing, but it does no harm: both are plain conjuncts on both sides.
2. **New gap (D5):** `proofs/linked-refund/run_check.py` pins the three approved copies but not `transport/FlatCore.dfy`. If that copy changes, the Dafny half still passes but no longer speaks of the exported contract. One pin line (`a89484e3…`) fixes this.
3. **The stored U294 theories match the present tool tree by hash.** Their parent hashes are `forge_refund` `aafcbc1d…`, `sexp_to_dafny` `7bd0f755…` and `forge_refundCertifiedProg` `439e5c15…`. The SHA-1 of each rebuilt parent `.dat` (2026-11-18) is the same. The stored objects and the three scripts match their recorded SHA-256 values.
4. **Three blockers stop an unedited replay of U294:**
   - The U294 runners assert heap `36f7c254…`, but the present heap is `66b1654b…`.
   - `results/refund-source-binding-2026-11-04/` is not on disk.
   - Loading a theory by name may fail. `forge_refund_call_experiment` has no `INCLUDES`, and `forge_refundProg_experiment` is an empty folder made on 2026-11-18. Reading cannot settle this; probe H0 does.
5. **The vcg theories and `dafny_eval_rel` are not built.** So `conditions_hold` and `eval_true` cannot be used. The statement uses `evaluate_exps … = Rval [BoolV T;BoolV T;BoolV T]`, the same form as U294 `source_postconditions`.
6. **Pre-flight of the eligibility draft (W2):** every name and type exists in the stored `.sig` files, including `explode_11` and `refund_guard_value`. Its tactics are the ones U294 used successfully. The highest risk is the load path (P6). Do not replace `simp` by `REWRITE_TAC` in L2: the parser output and the `«…»` syntax may write the same string in two forms.

### Draft theorem (not run)
The draft is in `forge_refundExportedContractScript.sml`. It parses the export again inside the kernel and splits it into `exported_ens1..3`. The steps are C1 decode, C2 shape (exactly three clauses), C3–C5 the value of each clause for all six outputs, and C6 the value of the whole list. Then:
- **C7 `exported_contract_on_refund_fields`:** `refund_fields … = (ok,a,r,c,q,n) ⇒ evaluate_exps (exported_contract_state h … ok a r c q n) env exported_ensures = (…, Rval [BoolV T;BoolV T;BoolV T])`. It holds for all `h`, `env`, `int`, `bool` and `mlstring` inputs.
- **C8 `exported_contract_exact`:** the three clauses hold if and only if the tuple is the result of `refund_fields`.
- **C9:** two witnesses (the Dafny ones).
- **H4 `exported_contract_on_rendered_output`:** the six fields read back from the complete rendered text satisfy the contract.

The theorems do not read the method body. The positive control PC1 (a change to the body only) must pass for that reason.

There are 11 negative controls, made and counted by `make_controls.py`. NC1 (Le→Lt in the contract only), NC2 (ids swapped in the contract), NC3, NC4 (clause 3 dropped), NC5, NC6 (trailing bytes), NS1 (amount+1), NS2 (ids swapped in the statement), NS3 and NR1 must fail.

### Assumptions that stay after C7 and C8
- A1 (S4) the exporter. Smallest shrink: a short printer from the S-expression back to Dafny clauses, plus a Dafny proof that each printed clause `<==>` the `FlatCore.dfy` clause.
- A2 the meaning of 8 Dafny operators. Shrink: an 8-row table as one owner-approved assumption; C3–C5 already reduce the HOL side to plain HOL logic.
- A3 strings as bytes. Shrink: state the bridge on code lists only.
- A4 `int`/`bool` identity across the two provers.
- A5 the state shape. Shrink: generalise to every state with those locals.
- A6–A8 are outside this link: S8, the HOL kernel and theory identity, and the Dafny half.

### Files (all in `<session scratch folder>/m1b/Y2/`)
`STATEMENTS.md`, `RUN_PLAN.md`, `PREFLIGHT_ELIGIBLE.md`, `forge_refundExportedContractScript.sml` (`89fee9c3…`), `forge_refundExportedRenderScript.sml`, `preload-render.sml`, `loadpath.sml`, `probe.sml`, `make_controls.py`, `controls/` (11 inputs plus `CONTROLS.json`), `u294/` (copies extracted from the backup branch).

### What I ran
- `git show`, `git ls-tree`, `shasum` and `grep`: exit 0.
- `make_controls.py`: first run exit 1 (an encoding bug in my own script); after the fix, two runs, each exit 0.
- `diff`: exit 1, which is expected because the files differ.
- No HOL, no Dafny, no build.

### What I could not determine
- Whether `load` by name works today.
- Whether the tactics of C3–C8 close their goals (risk low to medium, by analogy with U294).
- How long the CertifiedProg load takes.

| step | status | evidence or blocker |
| --- | --- | --- |
| 1 locate artifacts / loadability | DONE (by reading) | the parent hashes match; three replay blockers listed |
| 2 contract comparison | DONE | same bytes `a89484e3…`; D1–D6; gap D5 |
| 3 pre-flight of the eligibility draft | DONE | `PREFLIGHT_ELIGIBLE.md`; P6 is the main risk |
| 4 full draft and controls | DRAFT | the script and 11 controls; NOT RUN |
| 5 run plan | DRAFT | `RUN_PLAN.md` (H0, R1–R3, I1, H1–H4) |
| 6 residual assumptions | DONE | `STATEMENTS.md` section 4 |

| link id | proposed class | evidence |
| --- | --- | --- |
| S3 | MACHINE-CHECKED (unchanged) | add the FlatCore pin (D5) |
| S4 | ASSUMPTION (not approved) | unchanged; shrink by the round-trip check |
| S5 | MACHINE-CHECKED on 2026-11-04 ONLY | the parent hashes match today; replay R1–R3 not run |
| S6 | MISSING | draft C7/C8 only; a draft does not upgrade a link |
| S7 | ASSUMPTION (not approved) | reduced to an 8-operator table and a code-list bridge (proposal) |
