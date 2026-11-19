# Pre-flight of `drafts/link-eligible/forge_refundEligibleLinkScript.sml` (W2). By reading only

Checked against the stored `.sig` and `Script.sml` files of the present tree
(`.toolchain/experiments/refund-cakeml-20261104/cakeml/...`). Nothing ran.

| # | Item | Finding | Risk |
| --- | --- | --- | --- |
| P1 | Names | `forge_refundTheory.sig` exports `eligible_def`, `refund_guard_def`, `refund_initial_def`, `refund_guard_value`, `refund_full_result` (all used names exist). `mlstringTheory.explode_11` exists: `∀s1 s2. explode s1 = explode s2 ⇔ s1 = s2` (`basis/pure/mlstringScript.sml:111`). `dafny_ast$Eq`, `dafny_ast$Var`, `init_state` exist | low |
| P2 | Types | `eligible` takes `(original:int) (remaining:int) … (amount:int)`; the state uses `IntV`; consistent. `refund_guard_value` is stated for free `h env`, so L4 with `h' env'` matches | low |
| P3 | L3 tactic | `EVAL_TAC >> rpt (IF_CASES_TAC >> fs [] >> EVAL_TAC)` is the U294 `source_full_result` tactic on the SAME exported guard (exit 0 on 2026-11-04) and close to `refund_guard_value`. The exported guard is left-nested and has no trailing `Lit (BoolL T)`; the constructed `refund_guard` is right-nested with trailing literals. Values agree by evaluation only | low to medium |
| P4 | L2 tactic | `simp` on a literal equality after `EXISTS_TAC`; the same pattern closed U294 `source_signature`. Do NOT replace it by `REWRITE_TAC`: the parser output and the `«…»` syntax may give different but equal `mlstring` forms (the U294 `.dat` string table contains `implode`) | low |
| P5 | L5 | `simp [do_bop_def, explode_11]`: `do_bop Eq` gives `BoolV (StrV s = StrV t)`; `value_same_type_def` is `[simp]`. Equivalent to U294 `mapped_operators` (`s = t` form) | low |
| P6 | Load by name (RUN_PLAN H0) | cwd `forge_refund_call_experiment`: its `Holmakefile` has no `INCLUDES`; the folder `forge_refundProg_experiment` is EMPTY since 2026-11-18. The 2026-11-04 success does not show that the name lookup works today. Add explicit `loadPath` lines (as in Y2's script) or keep H0′ | **medium (highest)** |
| P7 | Runner | `run_case.py` of 2026-11-17 exists; its fixed inputs exist (`bridge-0005/command.json`, the native image). Its guard refuses while another HOL child runs (today: the replay, PID seen at 2026-11-19), exit 3. `FORGE_HEAP=cakeml/misc/cakeml-heap` is right (U294 heap path); the heap SHA-256 is now `66b1654b…`, not U294's `36f7c254…` | known |
| P8 | Step 0 inputs | `git show …/hol-0004/input.sexp` gives `58154ddf…` (measured); `…/source-export-feasibility-20261104/records/FlatCore-original.dfy` gives `a89484e3…` (measured) | none |
| P9 | Scope | L1 to L5 say nothing about the five other outputs. PC1 (ids swapped in the guard) passes by design. Y2's C7 with NC2/NS2 covers the outputs and the swap | gap closed by C7 (draft) |
| P10 | Order of failure | NH2 (contract-only edit) fails at L2 because L2 runs before L3: as the plan states | none |

Verdict (by reading): runnable as a first probe after P6 is handled. Its
L3 is implied in substance by Y2's C3 (`exported_ens1_value`): if C3 passes,
L3 adds the link to `refund_guard` (L4) only.
