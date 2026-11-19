# Step I.1b: draft of the first link theorem for the eligibility predicate (W2, Opus; nothing was run)

Worker report, saved verbatim by the orchestrator from the worker's transcript (home and scratch paths replaced). It is model output. It is not evidence by itself: the orchestrator's checks are in `TRACKER.md`.

---

W2 (link-draft), step I.1b: REPORTED. I ran no tool on the drafts. Nothing here is proved.

**Route chosen: (a′), which is route (a) on the flat exported source plus a bridge checked by Dafny.**
- The approved text cannot be exported as it is.
  - The AST and the patched exporter have no datatypes and no field select (`dafny_astScript.sml:11-17,127-131`; `Bake.proposed.cs:50-53,491-503`).
  - They have no set display or `in` (`Bake.proposed.cs:81,579-597`), and no `|s|` (unary operators: only `Not`, `:573-577`).
  - They have no `>`. String `==`/`!=`, `&&`/`||`/`<==>`, `<=` (chained comparisons are resolved to `&&`), and functions are supported.
- The real export already exists in git: the U294 export of `FlatCore.dfy`, 3,621 bytes, SHA-256 `58154ddf…dd0d`, on the backup branch at `…/source-model-binding-20261104/records/hol-0004/input.sexp`. U294 already parsed it in HOL with exit 0. So no frontend rebuild is needed. That rebuild would need the network, and its build folder is no longer on disk.
- Not chosen: (b) the VCG adds nothing for straight-line code and cannot reach the approved datatypes. A hand-written copy of RefundSpec in HOL would be one more reading claim.

**First theorem, L3 `eligible_link_guard_value`:** for all heaps `h`, all `env`, all byte strings `c q r`, all integers `o m a` and all booleans `e p k`:
`evaluate_exp (eligible_link_initial h c q o m e p k a r) env eligible_link_guard = (same state, Rval (BoolV (eligible c q o m e p k a r)))`.
Here `eligible_link_guard` is the right-hand side of the first ensures clause of the exported, kernel-parsed AST.

The other HOL theorems:
- **L1:** the exact bytes parse completely to the stored program.
- **L2:** that guard is both the contract guard and the first assignment in the body.
- **L4:** the guard equals the constructed `refund_guard` that the compiled method is built from.
- **L5:** string `Eq`/`Neq` in the model is equality of byte lists.

The Dafny lemmas, in a concrete module that imports the concrete `Refund`:
- **E1/E2:** the approved `Eligible` equals `EligibleFlat`, for every approved pair and for every flat tuple.
- **E3:** all six non-candidate responses are ineligible.
- **E4:** `FlatRefund.AssessFlat`'s `authorized` equals `EligibleFlat`, which equals `Eligible`.
- **U1 (optional):** `Eligible` equals `EligibleFlat` over the UTF-8 bytes `Encoded(·)` of the strings, using the U262 lemmas `EncodedEmpty` and `SameReasons`.

The chain U1 → T1/T2 → L3 → T3/T4 is two kernel-checked halves joined by trust items. It is not one kernel theorem. It would replace the author's reading for matrix rows 5–9 (eligibility part) and narrow row 16.

**Files I wrote** (all in `<session scratch folder>/m1b/W2/`):
- `<session scratch folder>/m1b/W2/EligibleFlat.dfy`
- `<session scratch folder>/m1b/W2/EligibleFlatUtf8.dfy` (optional U1/U2)
- `<session scratch folder>/m1b/W2/forge_refundEligibleLinkScript.sml` (a `hol run` script in the style of U294 `proof-0004.sml`, not a Holmake script)
- `<session scratch folder>/m1b/W2/STATEMENTS.md`
- `<session scratch folder>/m1b/W2/RUN_PLAN.md` (commands, expected exits, 5 Dafny and 7 HOL negative controls, extension to the tuple, R1–R5 and the output encoding)

**Still trusted after this step:**
- **T1:** the patched Dafny exporter fork (it declares 4.10.1; the pinned verifier is 4.11.0).
- **T2:** that Dafny and the CakeML Dafny semantics give the same meaning to the operators used.
- **T3:** Dafny Unicode string ↔ `mlstring` of UTF-8 bytes. The step across kernels is not checked (matrix row 3).
- **T4:** int and bool identification across kernels.
- **T5/T6:** the Dafny/Z3 and HOL/Poly/heap toolchains.
- **T7:** SHA-256 binding of the inputs.
- **T8:** the downstream Profile A theorems, unchanged.

**Not covered:**
- Non-UTF-8 byte inputs: L3 holds for them, but the approved contract says nothing about them.
- Ill-typed inputs.
- The tuple, R1–R5 and the output encoding (later steps).
- Unicode normalization.
- A swap of `chargeId`/`requestId` inside the guard. The guard is symmetric in them, so control PC1 is expected to pass. The tuple step must catch the swap.

**Main risks:**
1. Environment. `load "forge_refundTheory"` and `load "sexp_to_dafnyTheory"` have not run from the `forge_refund_call_experiment` cwd since the U413 rebuild, and its Holmakefile has no INCLUDES.
2. Tactic. L3 uses `EVAL_TAC >> rpt (IF_CASES_TAC >> fs [] >> EVAL_TAC)`. The same tactic closed U294 `source_full_result` on the same guard, so the risk is low.
3. L2's `simp` on a large concrete equality. The fallback is `REWRITE_TAC`.

**Smallest experiment:** RUN_PLAN H0 is a 3-line probe that does the two `load`s. Then H1 runs this script on the exported bytes (expected 1–5 min; U294 took 166 s). D1 is the Dafny verify (under 1 min, no HOL slot needed). H0 tells whether the environment works; H1 with NH1/NH2 tells whether the route works.

**What I could not determine by reading:**
- The `loadPath` behaviour on the rebuilt toolchain.
- Real run time and memory.
- Whether `dafny audit` reports zero findings on `EligibleFlat.dfy`.
- Whether the fork's 4.10.1 resolver handles chained comparisons the same way as 4.11.0.
- Whether the frontend can be rebuilt offline. I think not.

The repository was not changed by me. `git status` shows `proposals/m1-owner-review-20261119/REVIEW_PACKET.md` modified; that is not my change.

| step | status | evidence or blocker |
| --- | --- | --- |
| I.1b link-draft | REPORTED | 5 draft files in the W2 scratch folder; route (a′) on the U294 export `58154ddf…`; first theorem L3 above; nothing run (HOL slot reserved); next: RUN_PLAN H0 → H1 + NH1/NH2, D1 |
