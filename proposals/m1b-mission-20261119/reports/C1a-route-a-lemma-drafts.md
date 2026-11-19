# Step C1a: Route A lemmas as HOL script drafts (X7, Opus; NOTHING was run; nothing is proved)

Worker report, saved verbatim by the orchestrator from the worker's transcript (home and scratch paths replaced). It is model output. It is not evidence by itself: the orchestrator's checks are in `TRACKER.md`.

---

X7 (route-a-lemmas), step C1 preparation. Nothing is proved: no HOL run took place. I changed no repository file and ran no state-changing git command. All files are in `<session scratch folder>/m1b/X7/`.

**L1 as written in the script** (`refund_ffi_contract_on_totalises`; this is the owner's `refund_ffi_contract_at_totalise`):
```
!b dm Vok f. refund_ffi_contract_on b dm Vok f ==> refund_ffi_contract_at b dm (refund_ffi_tot Vok f)
```
- `refund_ffi_contract_on` is built in the script from the stored `refund_ffi_contract_at_def` term. It keeps the same 7 binders and the same 4 conclusions, and adds one hypothesis, `Vok index new_bytes ms2`. A structural control checks this. A literal text check also runs; a mismatch prints but does not stop the run.
- `refund_ffi_tot Vok f k x = if Vok (FST x) (FST (SND x)) (SND (SND x)) then f k x else refund_abs_ffi k x`.
- The variable is named `Vok`, not `V`, to avoid a possible clash with a constant `V`.

**Constants used, by owning theory:**
- `forge_refundSlideProfileA`: `refund_ffi_contract_at(_def)`, `refund_env_ok_sl(_def)`, `refund_abs_ffi_contract_at`, `refund_ffi_contract_at_link_base_is_the_old_contract`, `refund_profile_a_sl` (L2 only).
- `forge_refundEnvModel`: `refund_abs_ffi(_def)`, `refund_bad_return_ffi(_def)`, `refund_ffi_witness_state(_def)`, `refund_ffi_contract`, `refund_ffi_contract_at_witness`.
- `forge_refundStartupBridge`: `refund_mc_def`. `forge_refundStartupClause`: `arm8_fix_def`. `forge_refundCmlMainStep`: `arm8_run` (these three in L2 only).
- Pinned CakeML: `targetSem` (`evaluate_def`, `machine_sem_def`, `apply_oracle_def`, `machine_config_component_equality`, `interference_ok`), `misc` (`shift_seq_def`, `read_bytearray_def`), `asmProps` (`target_state_rel_def`), `arm8_target` (`arm8_target_def`, `arm8_config_def`, `arm8_ok_def`), `ffi`, `basis_ffi`. HOL `words`: `word_msb`.
- All stored names were checked against the `.sig` files.
- New constants: `refund_ffi_contract_on`, `refund_ffi_tot`, `refund_close_call_valid`, `refund_close_abort_model_ffi` (theory `forge_refundRouteA1`), and `ffi_calls_ok` (theory `forge_refundRouteA2`).

**Status of each part:**
- DRAFT (`routeA-L1.sml`, 16 theorems, 4 definitions):
  - L1 and its corollary for `refund_env_ok_sl`.
  - Sanity: with `Vok = λ_ _ _. T` the on-form is exactly the stored contract.
  - Helper lemmas, including `shift_seq n (refund_ffi_tot Vok f) = refund_ffi_tot Vok (shift_seq n f)`, which L2 needs.
  - N1 (proved negation): without totalisation the implication is false. Witness: `λ_ _ _. F` and `refund_bad_return_ffi`, by the stored witness tactic.
  - N2: `refund_close_call_valid` (x1 = 8w, x3 ≠ 0w, not `word_msb` x3) rejects the U393 state. The stored contract demands a return to x30 at that state. A stand-in effect that jumps to 0x1000252A4w meets the on-form and fails the stored contract (proved negation). U394 `zero_alen_reaches_assert_block` is cited in a comment only; I did not re-prove native steps.
- DRAFT: `routeA-L1-imp.sml`, an import check in the imp4 style (9 exact statements, 2 controls).
- DRAFT, higher risk: `routeA-L2.sml`.
  - `ffi_calls_ok`: a copy of the `evaluate` recursion that checks `Vok` at every ExtCall `FFI_return`. It is F at SharedMem calls.
  - L2: under `mc2 = mc1 with ffi_interfer := refund_ffi_tot Vok mc1.ffi_interfer` and `ffi_calls_ok Vok mc2 ffi k ms`, `evaluate mc1 ffi k ms = evaluate mc2 ffi k ms`. Induction on the clock, case splits in the style of `evaluate_add_clock`.
  - L2S: the same for `machine_sem`.
  - L2R `refund_profile_a_sl_reach`: the stored premises with `refund_env_ok_sl` replaced by three premises. The conclusion is checked term-identical (`aconv`) to the stored `refund_profile_a_sl`.
- NOT ATTEMPTED (statements only, in `routeA-L3.md`): every L3 part, L-EXIT and L-OUT.
  - write: U400 is quoted. It covers successful write events only. The missing statement is `refund_run_write_events_all_succeed`.
  - read: the smallest first theorem is `successful_read_call_state_has_valid_arguments`.
  - close: no unreachability is needed for the abort layer. The oracle returns only when clen = 8 and alen ≥ 1 (stored `ffi_close_accepts_only_valid_lengths`). The signed bound needs a new premise, heap end ≤ 2^63.
  - open_in: needs unreachability.
  - `refund_semantics` fixes only `extract_fs`. That equation cannot exclude failed close or open_in events, or an open/close pair. Unreachability therefore needs a source-level argument, for example a C-faithful oracle and a CF re-proof.
  - All stored call-site facts are at slide 0.

**Main risk that L1 does not run as written:** `Cases_on `Vok index new_bytes ms2`` in L1. I rely on it to give the assumptions `Vok …` and `¬Vok …`, positive case first, so that `MATCH_MP refund_ffi_tot_valid` and `MATCH_MP refund_ffi_tot_invalid` find them. A second, smaller risk: the N2b hypotheses at index 2 are closed by `EVAL_TAC`, a copy of the stored index-0 witness tactic. For L2, the risk is the shape of the goal after the double unfolding and the record normal forms.

**Run command** (full plan in `RUN_PLAN.md`):
1. Check memory, swap, disk and that no HOL process runs.
2. `mkdir -p <HOME>/forge/results/m1b-routeA-20261119/attempt-0001`.
3. Copy `run_case.py` and `deps-imp4.txt` (as `deps-L1.txt`) from `results/round4-m1-replay-20261118/slide-s3-copy/attempt-0001/`. Copy the drafts and the helpers into the new folder.
4. `cd` to that folder and run `FORGE_CPU_SECONDS=600 ./go-routeA.sh L1-0001 L1-0001.sml deps-L1.txt`.

CPU estimate is 150 s, so the limit is 600 s (4×); L2 has a 1600 s limit. The run uses the pinned hol and the `cake_compile_heap`. Pass criteria, the five-attempt rule and the meaning of each failure are in the plan. `hash_parents.py` gives SHA-256 of the `.sig`, `.sml` and `.dat` of every parent theory, the produced objects, the hol binary and the heap, plus the CHECKED statements and markers. I tested it read-only on the stored e4-0001: exit 0, 61 parents, 0 missing, and the hashes match `command.json`.

**Files:** `routeA-L1.sml`, `routeA-L1-imp.sml`, `routeA-L2.sml`, `routeA-L2.md`, `routeA-L3.md`, `RUN_PLAN.md`, `STATEMENTS.md`, `hash_parents.py`, `go-routeA.sh`, `test-e4.hashes.json` (the helper self-test), all in the folder above.
- SHA-256 of `routeA-L1.sml`: `9ddf6746…8830`.
- SHA-256 of `routeA-L2.sml`: `03036c1c…3b09`.

**Not determined by reading:**
- the exact case-split behaviour of `Cases_on` on a non-variable boolean term;
- whether `srw_ss` record normal forms coincide in the L2 leaves;
- whether `Define` accepts the `evaluate` copy without a termination proof;
- whether `V` is a constant in the heap (I avoided it);
- the x0 values at halt (L-EXIT);
- the cost of a CF re-proof under a stricter FFI part.

The STATEMENTS.md paragraph says: Route A is "verified machine-model behaviour under a reachable-call FFI premise that a faithful model of the C code could satisfy". It is NOT verified native execution. The FFI simulation relation stays a conditional premise.

| step | status | evidence or blocker |
|---|---|---|
| C1-prep L1 script and import check | REPORTED | `routeA-L1.sml`, `routeA-L1-imp.sml` (DRAFT, not run) |
| C1-prep L2 | REPORTED | `routeA-L2.sml` (DRAFT, higher risk), `routeA-L2.md` |
| C1-prep L3 / L-EXIT / L-OUT | REPORTED | `routeA-L3.md` (NOT ATTEMPTED; gaps named) |
| C1-prep run plan and hashes | REPORTED | `RUN_PLAN.md`, `hash_parents.py` (self-test exit 0), `go-routeA.sh` |
| C1 run of L1 | BLOCKED | needs the single HOL slot; to be run by the orchestrator |
