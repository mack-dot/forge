# Orchestrator A (proof track): FINAL record of the night shift 2026-11-19

## 1. Header

- Written by worker W-final. Data read 2026-11-19T17:12:03Z to 17:21Z (`date -u`). File assembled at 2026-11-19T17:23:01Z.
- Stage line: **M1-B OPEN. `end_to_end=false`. No stage promoted.** This file does not propose to set `end_to_end`.
- What this file is: a record of results, by reading of the stored files and by hashing them. W-final ran no HOL, no
  Dafny, no git, no test, no network. W-final edited no existing file and the graph file is unchanged.
- Appendix: `FINAL_STATEMENTS.txt` (same folder). It holds every printed statement of every stored theorem, copied by
  script (`gen.py` in W-final's scratch folder) from the case `stdout.log`. Nothing in it is retyped.
- Classes: MACHINE-CHECKED / ASSUMPTION / TESTED-UNPROVED / MISSING. Exit codes are ACTUAL (`command.json`
  `actual_exit`; each `.go.log` last line `go exit N` is quoted next to it). NOT RUN stays NOT RUN. An exploration (case
  prefix with an x: `LOx`, `EEx`, `EFx`, `L2dx`, `R6x`, `R6wx`, `R6rx`, `R6tx`, `TRx`, `NVx`) stores nothing and is never a theorem.
- Applies to EVERY HOL result below: **same machine, stored older parent theories, not a clean replay, not an
  independent-machine replay.** Every theorem is a statement about the MODEL (CakeML/HOL machine semantics), never about
  the real process.
- Run folders: `results/m1b-routeA-20261119/attempt-0001/` (route A cases; wrapper `nightshift-run.sh <case> <cpu> <deps>`,
  which calls `go-routeA.sh`, which calls `run_case.py`) and `results/night-shift-20261119/orch-A/link/run/attempt-0001/`
  (link cases; `bash go.sh <ID>`). Toolchain (FIELDS_FOR_B.md): HOL4 9783a499…, CakeML cd915569…, Poly/ML 5.9.2,
  `hol` binary sha256 cd6a5b30…, heap `cake_compile_heap` sha256 2f5dbb71….

Case counts (route A folder, from `command.json`): proof or control cases with actual exit 0: 29; exit 1: 18; exit −24: 1.
Explorations: exit 0: 20; exit 1: 3; exit −15: 2. Source files with no run (NOT RUN): 20. Link folder: 10 cases exit 0
(H0, R1, R2, R3, I1, H1, H2, H4, E0, PC1); 12 negative controls exit 1 as required; 5 first tries exit 1 (setup errors).

## 2. HOL theorems (stored main theorems)

Each block: case, theory, actual exit, command, sha256 of the theory `.sig`, `.sml`, `.dat` (hashed by W-final; compared
with the `command.json` record), main theorem rows with an anchor into `FINAL_STATEMENTS.txt` (exact statement and the
premise list split by script), other theorems by name, the review verdict and its limits, and the reproduction status.
"Theorem row" count in this section: 74.

### 2.1 Reproduction from the branch (read 17:20:48Z)

- `orch-A/repro/RESULT.json` sha256 `fe2513822639b9317a0e3f6271eb06adc36aef9dcfc5b474084ab486e2e4aee6` (mtime 17:19Z
  local 12:19): branch head `dae1b93e…`; kind "same-machine reproduction from committed sources on stored older parents;
  NOT a clean or independent-machine replay". 18 of 18 cases REPRODUCED-FROM-BRANCH (exit 0 both sides, objects equal):
  L1-0001, L2-0003, L2b-0003, L2c-0001, PF-0004, PX-0001, LO-0006, LE-0004, contract-0001 (link H1), MF-0002, MG-0001,
  L2d-0001, E1-0003, EF-0001, EE-0001, R6base-0001, R6ffi-0002, R6w-0004. Two failed attempts kept as rows:
  MG-0001.fail-1 (repro exit 1, "Run out of store" during parent load) and R6ffi-0002.fail-1 (repro exit −15, watchdog
  kill after a system sleep 15:16:31Z–15:24:22Z). W-final re-hashed the reproduced `.sig/.sml/.dat` of all 16 route-A
  cases, contract-0001 and R6w-0004 on disk: equal to the original run objects.
- `repro/run/repro-driver.log` last line: "2026-11-19T17:19:38Z R6w-0004 ended: go exit 0; STOP (wind-down; no further
  case)". R6w-0004 started 17:11:10Z, after the wind-down order (section 8).
- Not in the reproduction set: L1imp-0001, E1r-0001, L2r-0001 (themselves re-runs), LE-0003, MF-0001, MT-0001, R6r-0004,
  R6t-0004, NV-0003, TR1-0001, TR2-0001, NN-0002, and every link case except contract-0001.

### L1 (FFI contract totalisation) — case `L1-0001`

- Theory `forge_refundRouteA1`; stored theorems 16, definitions 4 (from the .sig).
- Actual exit **0** (`command.json`); markers ['EXACT_COMPLETE']; wall 74.891 s; go.log last line `go exit 0`; `inputs_unchanged_after` True.
- Command: `./nightshift-run.sh L1-0001 600 deps-L1.txt` in `results/m1b-routeA-20261119/attempt-0001` (cpu from `command.json` `cpu_seconds_limit`; deps: parent list equal to deps-L1.txt (also equal to deps-LO.txt); the reproduction driver used deps-L1.txt).
- sha256 `forge_refundRouteA1Theory.sig` = `b3bbd85776b43a9ffeac13d7e2a3089718c3c89bd836bba03baa85395d7186ed` (equal to command.json record)
- sha256 `forge_refundRouteA1Theory.sml` = `732e806946306bef325c37ab884e14ea108bb41e641d0a2076c8946c426bd893` (equal to command.json record)
- sha256 `forge_refundRouteA1Theory.dat` = `f1e68d49914cbf2a1465946f37747d7418ef2195fc8383d5d6b7d12c8f958fae` (equal to command.json record)
- **Theorem row:** `forge_refundRouteA1.refund_ffi_contract_on_totalises` — exact statement and premise list: `FINAL_STATEMENTS.txt` anchor `[L1-0001/refund_ffi_contract_on_totalises]` (premises: 1).
- **Theorem row:** `forge_refundRouteA1.refund_env_ok_sl_of_contract_on` — exact statement and premise list: `FINAL_STATEMENTS.txt` anchor `[L1-0001/refund_env_ok_sl_of_contract_on]` (premises: 2).
- **Theorem row:** `forge_refundRouteA1.contract_on_without_totalisation_is_not_the_stored_contract` — exact statement and premise list: `FINAL_STATEMENTS.txt` anchor `[L1-0001/contract_on_without_totalisation_is_not_the_stored_contract]` (premises: none at top level).
- **Theorem row:** `forge_refundRouteA1.close_abort_model_totalised_meets_stored_contract` — exact statement and premise list: `FINAL_STATEMENTS.txt` anchor `[L1-0001/close_abort_model_totalised_meets_stored_contract]` (premises: none at top level).
- Other stored theorems (12), by name only (statements in FINAL_STATEMENTS.txt where printed; all in the .dat): `bad_return_ffi_totalised_with_empty_predicate_meets_contract`, `close_abort_model_fails_stored_contract`, `close_abort_model_satisfies_contract_on`, `refund_close_call_valid_excludes_zero_alen`, `refund_close_call_valid_rejects_u393_witness`, `refund_env_with_ffi_interfer_fields`, `refund_ffi_contract_on_all_valid_is_the_stored_contract`, `refund_ffi_tot_all_valid_is_identity`, `refund_ffi_tot_invalid`, `refund_ffi_tot_shift_seq`, `refund_ffi_tot_valid`, `stored_contract_demands_return_at_u393_close_state`.
- Review: A7: HOLDS; 16 theorems MACHINE-CHECKED (model). L1 holds for every `Vok` (also `Vok = F`). L1 with L2 REPLACES the false all-states FFI premise by two unproved premises (native `refund_ffi_contract_on`; `ffi_calls_ok`); it does not remove it.
- Reproduction: REPRODUCED-FROM-BRANCH with identical .sig/.sml/.dat (orch-A/repro/RESULT.json; W-final re-hashed the reproduced objects: equal). Same machine, stored older parents; not a clean replay.

### L1 import check — case `L1imp-0001`

- Theory `(no theory exported)`; stored theorems 0, definitions 0 (from the .sig).
- Actual exit **0** (`command.json`); markers ['EXACT_COMPLETE']; wall 61.177 s; go.log last line `go exit 0`; `inputs_unchanged_after` True.
- Command: `./nightshift-run.sh L1imp-0001 600 deps-L1imp.txt` in `results/m1b-routeA-20261119/attempt-0001` (cpu from `command.json` `cpu_seconds_limit`; deps: parent list equal to deps-L1imp.txt, deps-L2.txt and deps-L2b.txt (identical content); file name UNCONFIRMED by name).
- No theory exported (no .sig/.sml/.dat).
- Review: A7: `IMPORTED_COUNT 9 MISMATCH_COUNT 0` (9 of 16 statements re-matched by `aconv`); its two controls are weak (not-aconv against one mutant). Stores nothing.
- Reproduction: not in the reproduction set (single same-machine run).

### L2 (totalised machine agrees; restated machine theorem) — case `L2-0003`

- Theory `forge_refundRouteA2`; stored theorems 9, definitions 1 (from the .sig).
- Actual exit **0** (`command.json`); markers ['EXACT_COMPLETE']; wall 97.861 s; go.log last line `go exit 0`; `inputs_unchanged_after` True.
- Command: `./nightshift-run.sh L2-0003 1600 deps-L2.txt` in `results/m1b-routeA-20261119/attempt-0001` (cpu from `command.json` `cpu_seconds_limit`; deps: the reproduction driver used deps-L2.txt; identical content to deps-L1imp.txt, deps-L2b.txt).
- sha256 `forge_refundRouteA2Theory.sig` = `297119d72a40c62ed8c4d2f86c6582728bfc75dfa60252a2b3665b79df96d539` (equal to command.json record)
- sha256 `forge_refundRouteA2Theory.sml` = `41d7e3835847e4a3b4d18a3357a6a1a1238342196ed59f45d2da404c3b55d000` (equal to command.json record)
- sha256 `forge_refundRouteA2Theory.dat` = `8058ee0e53ad4c574ce7e301a478330bd9d853f8180da533882dacee02dc2586` (equal to command.json record)
- **Theorem row:** `forge_refundRouteA2.refund_profile_a_sl_reach` — exact statement and premise list: `FINAL_STATEMENTS.txt` anchor `[L2-0003/refund_profile_a_sl_reach]` (premises: 13).
- **Theorem row:** `forge_refundRouteA2.refund_ffi_tot_evaluate_agree` — exact statement and premise list: `FINAL_STATEMENTS.txt` anchor `[L2-0003/refund_ffi_tot_evaluate_agree]` (premises: 2).
- **Theorem row:** `forge_refundRouteA2.refund_ffi_tot_machine_sem_agree` — exact statement and premise list: `FINAL_STATEMENTS.txt` anchor `[L2-0003/refund_ffi_tot_machine_sem_agree]` (premises: 1).
- Other stored theorems (6), by name only (statements in FINAL_STATEMENTS.txt where printed; all in the .dat): `ffi_calls_ok_compute`, `ffi_calls_ok_false_at_a_returning_call`, `read_ffi_bytearray_ffi_interfer_update`, `read_ffi_bytearrays_ffi_interfer_update`, `refund_mc_totalised_record`, `refund_mc_totalised_record_fields`.
- Review: A12: MACHINE-CHECKED (model). Conclusion of `refund_profile_a_sl_reach` is `aconv` to the stored one and speaks about `refund_mc B envmc`. "More realistic premise" NOT established: no `Vok` is shown for which all premises hold (non-vacuity MISSING).
- Reproduction: REPRODUCED-FROM-BRANCH with identical .sig/.sml/.dat (orch-A/repro/RESULT.json; W-final re-hashed the reproduced objects: equal). Same machine, stored older parents; not a clean replay.

### L2 confirmation re-run inside the swap rule — case `L2r-0001`

- Theory `forge_refundRouteA2`; stored theorems 9, definitions 1 (from the .sig).
- Actual exit **0** (`command.json`); markers ['EXACT_COMPLETE']; wall 101.417 s; go.log last line `go exit 0`; `inputs_unchanged_after` True.
- Command: `./nightshift-run.sh L2r-0001 1600 deps-L2.txt` in `results/m1b-routeA-20261119/attempt-0001` (cpu from `command.json` `cpu_seconds_limit`; deps: parent list equal to deps-L1imp.txt, deps-L2.txt, deps-L2b.txt; file name UNCONFIRMED by name).
- sha256 `forge_refundRouteA2Theory.sig` = `297119d72a40c62ed8c4d2f86c6582728bfc75dfa60252a2b3665b79df96d539` (equal to command.json record)
- sha256 `forge_refundRouteA2Theory.sml` = `41d7e3835847e4a3b4d18a3357a6a1a1238342196ed59f45d2da404c3b55d000` (equal to command.json record)
- sha256 `forge_refundRouteA2Theory.dat` = `8058ee0e53ad4c574ce7e301a478330bd9d853f8180da533882dacee02dc2586` (equal to command.json record)
- Statements: identical (by script) to `L2-0003`; no separate theorem rows.
- Review: Confirmation run for owner item A-1: objects byte-equal to L2-0003.
- Reproduction: not in the reproduction set (single same-machine run).

### L2b (ffi_calls_ok for close from the oracle) — case `L2b-0003`

- Theory `forge_refundRouteA2b`; stored theorems 28, definitions 0 (from the .sig).
- Actual exit **0** (`command.json`); markers ['EXACT_COMPLETE']; wall 179.048 s; go.log last line `go exit 0`; `inputs_unchanged_after` True.
- Command: `./nightshift-run.sh L2b-0003 1500 deps-L2b2.txt` in `results/m1b-routeA-20261119/attempt-0001` (cpu from `command.json` `cpu_seconds_limit`; deps: unique content match; reproduction used deps-L2b2.txt).
- sha256 `forge_refundRouteA2bTheory.sig` = `1e3ee9f9ee25c8f5d5d0fbdcb811c4731ffc5205b081d9b9a3c628fc7318a0b0` (equal to command.json record)
- sha256 `forge_refundRouteA2bTheory.sml` = `7b528d0b991b2ddf5320cc119546d5d0b5cae57c8efc4b8fc1bcd95aac62a93b` (equal to command.json record)
- sha256 `forge_refundRouteA2bTheory.dat` = `ae199111722c7b23de262468c95003b357f5b18ffc0042c4e14960bfac90b143` (equal to command.json record)
- **Theorem row:** `forge_refundRouteA2b.refund_l2r_third_premise_close` — exact statement and premise list: `FINAL_STATEMENTS.txt` anchor `[L2b-0003/refund_l2r_third_premise_close]` (premises: 1).
- **Theorem row:** `forge_refundRouteA2b.ffi_calls_ok_of_valid_events` — exact statement and premise list: `FINAL_STATEMENTS.txt` anchor `[L2b-0003/ffi_calls_ok_of_valid_events]` (premises: 3).
- **Theorem row:** `forge_refundRouteA2b.ffi_calls_ok_of_returning_calls` — exact statement and premise list: `FINAL_STATEMENTS.txt` anchor `[L2b-0003/ffi_calls_ok_of_returning_calls]` (premises: 2).
- Other stored theorems (25), by name only (statements in FINAL_STATEMENTS.txt where printed; all in the .dat): `basis_close_call_returns_at_a_concrete_state`, `basis_close_return_lengths`, `call_FFI_return_appends_its_event`, `call_FFI_return_keeps_oracle`, `close_instance_needs_the_basis_oracle`, `close_predicate_fails_for_a_returning_zero_length_call`, `close_predicate_rejects_zero_alen`, `close_returning_calls_have_valid_lengths`, `evaluate_clock_zero`, `ffi_calls_ok_conj`, `ffi_calls_ok_mono`, `ffi_close_return_lengths`, `refund_close_premises_hold`, `refund_ffi_calls_ok_close`, `refund_ffi_calls_ok_close_totalised`, `refund_l2r_third_premise_close_and_rest`, `refund_mc_close_fields`, `refund_names_are_ExtCall`, `returning_call_premise_is_needed`, `returning_call_with_valid_event_gives_P`, `rfb2_ffi_interfer_update`, `rfb2_install_interfer_update`, `rfb2_next_interfer_update`, `three_names_are_ExtCall`, `y3_event_predicate_admits_a_two_byte_read_array`.
- Review: A18: MACHINE-CHECKED. With `Vok = closeP`, premise 2 (`refund_ffi_contract_on … closeP …`) is FALSE for the real C (read with configuration length 0: the C aborts, the model returns an error byte).
- Reproduction: REPRODUCED-FROM-BRANCH with identical .sig/.sml/.dat (orch-A/repro/RESULT.json; W-final re-hashed the reproduced objects: equal). Same machine, stored older parents; not a clean replay.

### L2c (Route A reduced to native contract at VokY3 + R6) — case `L2c-0001`

- Theory `forge_refundRouteA2c`; stored theorems 29, definitions 2 (from the .sig).
- Actual exit **0** (`command.json`); markers ['EXACT_COMPLETE']; wall 277.409 s; go.log last line `go exit 0`; `inputs_unchanged_after` True.
- Command: `./nightshift-run.sh L2c-0001 1500 deps-L2c.txt` in `results/m1b-routeA-20261119/attempt-0001` (cpu from `command.json` `cpu_seconds_limit`; deps: unique content match; reproduction used deps-L2c.txt).
- sha256 `forge_refundRouteA2cTheory.sig` = `3f30ece9f9b233ff40995a53cd413d669b09828da8a974a6dfc574b048efbfe7` (equal to command.json record)
- sha256 `forge_refundRouteA2cTheory.sml` = `864c99ff2037fb5e653321d88fd0a5abdf2a71f80a33a8a8a8a6de812d3a86a8` (equal to command.json record)
- sha256 `forge_refundRouteA2cTheory.dat` = `8e280ce39967ad5dce7731858f2687fe41e36c804ef7cc72fa23e1c1f6524e46` (equal to command.json record)
- **Theorem row:** `forge_refundRouteA2c.refund_profile_a_sl_events` — exact statement and premise list: `FINAL_STATEMENTS.txt` anchor `[L2c-0001/refund_profile_a_sl_events]` (premises: 13).
- **Theorem row:** `forge_refundRouteA2c.refund_valid_event_gives_VokY3` — exact statement and premise list: `FINAL_STATEMENTS.txt` anchor `[L2c-0001/refund_valid_event_gives_VokY3]` (premises: 10).
- Other stored theorems (27), by name only (statements in FINAL_STATEMENTS.txt where printed; all in the .dat): `R4_L2b_literal`, `VokY3_is_the_L2b_lambda`, `VokY3_rejects_close_and_open_in`, `call_FFI_return_keeps_length`, `close_event_is_not_valid`, `first_two_elements_are_take_two`, `open_in_event_is_not_valid`, `read_bytearray_EL`, `read_bytearray_EL_domain`, `refund_calls_premise_VokY3`, `refund_events_premise_gives_l2r_third_premise`, `refund_ffi_names_distinct`, `refund_mc_pointer_fields`, `refund_names_are_nonempty_ExtCall`, `refund_record_bytearrays`, `refund_valid_event_is_the_L2b_EVc_lambda`, `valid_event_accepts_a_read_event`, `valid_event_accepts_a_write_event`, `valid_event_index_and_shape`, `valid_event_rejects_a_close_event`, `valid_event_rejects_the_N4_short_read_event`, `valid_read_event_gives_VokY3`, `valid_read_event_shape`, `valid_write_event_gives_VokY3`, `valid_write_event_shape`, `word_add_n2w_suc`, `zip_equal_lengths_injective`.
- Review: A26: MACHINE-CHECKED (model). = `refund_profile_a_sl_reach` at `VokY3` with premise 3 replaced by R6 (pairwise `aconv`). R6 PLAUSIBLE, NOT proved. Native contract at VokY3-valid calls: TESTED-UNPROVED.
- Reproduction: REPRODUCED-FROM-BRANCH with identical .sig/.sml/.dat (orch-A/repro/RESULT.json; W-final re-hashed the reproduced objects: equal). Same machine, stored older parents; not a clean replay.

### L2d (shape predicate; program-behaviour premise from the oracle) — case `L2d-0001`

- Theory `forge_refundRouteA2d`; stored theorems 29, definitions 0 (from the .sig).
- Actual exit **0** (`command.json`); markers ['EXACT_COMPLETE']; wall 81.94 s; go.log last line `go exit 0`; `inputs_unchanged_after` True.
- Command: `./nightshift-run.sh L2d-0001 1500 deps-MG.txt` in `results/m1b-routeA-20261119/attempt-0001` (cpu from `command.json` `cpu_seconds_limit`; deps: unique content match; reproduction used deps-MG.txt).
- sha256 `forge_refundRouteA2dTheory.sig` = `c46427349c5f5a791f03674c794bf1534f39813a3b8cbb47d49946b628c699bb` (equal to command.json record)
- sha256 `forge_refundRouteA2dTheory.sml` = `ee63d8624f120cd1bf3a82f6a05607dcd74d163aa385f8d93aa78607c8d363be` (equal to command.json record)
- sha256 `forge_refundRouteA2dTheory.dat` = `24538952fe3fac0fbe34f4f68bf8ef7a25eb1c7e601f7282e0dd39f065a5ecb2` (equal to command.json record)
- **Theorem row:** `forge_refundRouteA2d.refund_profile_a_sl_shape` — exact statement and premise list: `FINAL_STATEMENTS.txt` anchor `[L2d-0001/refund_profile_a_sl_shape]` (premises: 12).
- **Theorem row:** `forge_refundRouteA2d.refund_model_frame_decision_shape` — exact statement and premise list: `FINAL_STATEMENTS.txt` anchor `[L2d-0001/refund_model_frame_decision_shape]` (premises: 12).
- **Theorem row:** `forge_refundRouteA2d.refund_ffi_calls_ok_shape_totalised` — exact statement and premise list: `FINAL_STATEMENTS.txt` anchor `[L2d-0001/refund_ffi_calls_ok_shape_totalised]` (premises: none at top level).
- **Theorem row:** `forge_refundRouteA2d.remaining_premise_met_by_the_abstract_effect` — exact statement and premise list: `FINAL_STATEMENTS.txt` anchor `[L2d-0001/remaining_premise_met_by_the_abstract_effect]` (premises: none at top level).
- Other stored theorems (25), by name only (statements in FINAL_STATEMENTS.txt where printed; all in the .dat): `arm8_ffi_bytearrays_lengths`, `basis_open_in_return_length`, `basis_oracle_fails_at_zero_length_read_and_u393_close`, `basis_read_call_returns_at_a_concrete_state`, `basis_read_call_with_conf_length_0_returns`, `basis_read_return_length`, `basis_returning_call_has_valid_shape`, `basis_returning_calls_have_valid_shapes`, `basis_write_call_returns_at_a_concrete_state`, `basis_write_return_length`, `ffi_open_in_one_byte_array_returns_error_byte`, `ffi_open_in_return_length`, `ffi_read_conf_length_0_returns_error_byte`, `ffi_read_return_length`, `ffi_read_short_array_returns_error_byte`, `ffi_write_conf_length_0_returns_error_byte`, `ffi_write_return_length`, `l2d_frame_contract_upgrade`, `l2d_model_frame_contract_of_reach`, `refund_ffi_calls_ok_shape`, `refund_l2r_third_premise_shape`, `shape_predicate_holds_at_the_concrete_read_call`, `shape_predicate_holds_at_the_concrete_write_call`, `shape_predicate_needs_the_basis_oracle`, `shape_predicate_rejects_u393_and_zero_length_states`.
- Review: A27: MACHINE-CHECKED (model). One FFI premise left (contract at shape-valid calls). No `envmc` that describes the original C meets it (the premise covers all stub states). `refund_model_frame_decision_shape` is an OPTIONAL lemma of the script: its CHECKED line is the evidence. "Shape ⇒ returns" only by reading.
- Reproduction: REPRODUCED-FROM-BRANCH with identical .sig/.sml/.dat (orch-A/repro/RESULT.json; W-final re-hashed the reproduced objects: equal). Same machine, stored older parents; not a clean replay.

### E1 (processor-bit erasure, single functions) — case `E1-0003`

- Theory `forge_m1bErasureV2`; stored theorems 18, definitions 6 (from the .sig).
- Actual exit **0** (`command.json`); markers ['EXACT_COMPLETE']; wall 76.555 s; go.log last line `go exit 0`; `inputs_unchanged_after` True.
- Command: `./nightshift-run.sh E1-0003 600 deps-L1.txt` in `results/m1b-routeA-20261119/attempt-0001` (cpu from `command.json` `cpu_seconds_limit`; deps: reproduction used deps-L1.txt; identical content to deps-LO.txt).
- sha256 `forge_m1bErasureV2Theory.sig` = `a00181034f8d732c634e7ea7d98329c5bed89c65f3ae3d10509b04a43a9fb1d8` (equal to command.json record)
- sha256 `forge_m1bErasureV2Theory.sml` = `b8ccbd128f5df1f28eb346a28fcef9813071fcdbe503f1162294499ca0338c93` (equal to command.json record)
- sha256 `forge_m1bErasureV2Theory.dat` = `cf4c757a1036d3fbab7526f65035ab205172f0799cd129a5d4267dbc2fe6165e` (equal to command.json record)
- **Theorem row:** `forge_m1bErasureV2.BranchTo_erase_untagged` — exact statement and premise list: `FINAL_STATEMENTS.txt` anchor `[E1-0003/BranchTo_erase_untagged]` (premises: 2).
- **Theorem row:** `forge_m1bErasureV2.CheckSPAlignment_erase` — exact statement and premise list: `FINAL_STATEMENTS.txt` anchor `[E1-0003/CheckSPAlignment_erase]` (premises: 2).
- **Theorem row:** `forge_m1bErasureV2.arm8_ok_erase` — exact statement and premise list: `FINAL_STATEMENTS.txt` anchor `[E1-0003/arm8_ok_erase]` (premises: none at top level).
- **Theorem row:** `forge_m1bErasureV2.N1a_tagged_branch_breaks` — exact statement and premise list: `FINAL_STATEMENTS.txt` anchor `[E1-0003/N1a_tagged_branch_breaks]` (premises: 2).
- Other stored theorems (14), by name only (statements in FINAL_STATEMENTS.txt where printed; all in the .dat): `BranchTo_EL0_pc`, `CheckSPAlignment_erase_fault`, `N1b_bit55_branch_breaks`, `N2_misaligned_sp_breaks`, `N3_e0e_not_erasable`, `N4_slide_ok_admits_tagged_code`, `N5_lo55_holds_at_slide_zero_and_fails_at_N4_slide`, `P1_bit55_without_TBI1_is_fine`, `erase_fields`, `erase_restore`, `restore_erase`, `tbi_pc_erased`, `tbi_pc_untagged`, `untagged_bits`.
- Review: A10: no false theorem; 18 MACHINE-CHECKED. Premises are TRADED, not removed. No lift to a `NextStateARM8` step or to `evaluate`; `arm8_target_real` bridge MISSING. Mutant E1neg-0001: actual exit 1, as required.
- Reproduction: REPRODUCED-FROM-BRANCH with identical .sig/.sml/.dat (orch-A/repro/RESULT.json; W-final re-hashed the reproduced objects: equal). Same machine, stored older parents; not a clean replay.

### E1 confirmation re-run inside the swap rule — case `E1r-0001`

- Theory `forge_m1bErasureV2`; stored theorems 18, definitions 6 (from the .sig).
- Actual exit **0** (`command.json`); markers ['EXACT_COMPLETE']; wall 79.643 s; go.log last line `go exit 0`; `inputs_unchanged_after` True.
- Command: `./nightshift-run.sh E1r-0001 600 deps-L1.txt` in `results/m1b-routeA-20261119/attempt-0001` (cpu from `command.json` `cpu_seconds_limit`; deps: parent list equal to deps-L1.txt and deps-LO.txt; file name UNCONFIRMED by name).
- sha256 `forge_m1bErasureV2Theory.sig` = `a00181034f8d732c634e7ea7d98329c5bed89c65f3ae3d10509b04a43a9fb1d8` (equal to command.json record)
- sha256 `forge_m1bErasureV2Theory.sml` = `b8ccbd128f5df1f28eb346a28fcef9813071fcdbe503f1162294499ca0338c93` (equal to command.json record)
- sha256 `forge_m1bErasureV2Theory.dat` = `cf4c757a1036d3fbab7526f65035ab205172f0799cd129a5d4267dbc2fe6165e` (equal to command.json record)
- Statements: identical (by script) to `E1-0003`; no separate theorem rows.
- Review: Confirmation run for owner item A-1: objects byte-equal to E1-0003.
- Reproduction: not in the reproduction set (single same-machine run).

### EF (one step keeps TCR_EL1, SCTLR_EL1, EL) — case `EF-0001`

- Theory `forge_m1bErasureFrame`; stored theorems 69, definitions 0 (from the .sig).
- Actual exit **0** (`command.json`); markers ['EXACT_COMPLETE']; wall 86.299 s; go.log last line `go exit 0`; `inputs_unchanged_after` True.
- Command: `./nightshift-run.sh EF-0001 600 deps-ES.txt` in `results/m1b-routeA-20261119/attempt-0001` (cpu from `command.json` `cpu_seconds_limit`; deps: unique content match; reproduction used deps-ES.txt).
- sha256 `forge_m1bErasureFrameTheory.sig` = `379bf0b81432875556299dff6b86bd559050e72bb7a61c17f4e130291b9a3620` (equal to command.json record)
- sha256 `forge_m1bErasureFrameTheory.sml` = `2d359f31649f72bf45985baaacd3e26988963a8327a7efc5f5e9fec2badbb495` (equal to command.json record)
- sha256 `forge_m1bErasureFrameTheory.dat` = `662d7cd2336d50b1e6737850f0c52a141033d4ed113d71b800b1b515d9391206` (equal to command.json record)
- **Theorem row:** `forge_m1bErasureFrame.Next_frame` — exact statement and premise list: `FINAL_STATEMENTS.txt` anchor `[EF-0001/Next_frame]` (premises: none at top level).
- **Theorem row:** `forge_m1bErasureFrame.NextStateARM8_frame` — exact statement and premise list: `FINAL_STATEMENTS.txt` anchor `[EF-0001/NextStateARM8_frame]` (premises: 1).
- **Theorem row:** `forge_m1bErasureFrame.W_nonvacuous` — exact statement and premise list: `FINAL_STATEMENTS.txt` anchor `[EF-0001/W_nonvacuous]` (premises: none at top level).
- Other stored theorems (66), by name only (statements in FINAL_STATEMENTS.txt where printed; all in the .dat): `FOR_proj`, `FOR_snd_const`, `Mem_state`, `Next_frame_all`, `frame_BranchTo`, `frame_CheckAlignment`, `frame_CheckSPAlignment`, `frame_Fetch`, `frame_Hint_Branch`, `frame_LoadStoreSingle`, `frame_Mem`, `frame_Run`, `frame_SetTheFlags`, `frame_dfn_AddSubCarry`, `frame_dfn_AddSubExtendRegister`, `frame_dfn_AddSubImmediate`, `frame_dfn_AddSubShiftedRegister`, `frame_dfn_Address`, `frame_dfn_BitfieldMove`, `frame_dfn_BranchConditional`, `frame_dfn_BranchImmediate`, `frame_dfn_BranchRegister`, `frame_dfn_Breakpoint`, `frame_dfn_CRC`, `frame_dfn_ClearExclusive`, `frame_dfn_CompareAndBranch`, `frame_dfn_ConditionalCompareImmediate`, `frame_dfn_ConditionalCompareRegister`, `frame_dfn_ConditionalSelect`, `frame_dfn_CountLeading`, `frame_dfn_DebugRestore`, `frame_dfn_DebugSwitch`, `frame_dfn_Division`, `frame_dfn_ExceptionReturn`, `frame_dfn_ExtractRegister`, `frame_dfn_Halt`, `frame_dfn_Hint`, `frame_dfn_HypervisorCall`, `frame_dfn_LoadLiteral`, `frame_dfn_LoadStoreAcquire`, `frame_dfn_LoadStoreAcquirePair`, `frame_dfn_LoadStoreImmediate`, `frame_dfn_LoadStorePair`, `frame_dfn_LoadStoreRegister`, `frame_dfn_LogicalImmediate`, `frame_dfn_LogicalShiftedRegister`, `frame_dfn_MemoryBarrier`, `frame_dfn_MoveImmediateProcState`, `frame_dfn_MoveSystemRegister`, `frame_dfn_MoveWide`, `frame_dfn_MultiplyAddSub`, `frame_dfn_MultiplyAddSubLong`, `frame_dfn_MultiplyHigh`, `frame_dfn_Reserved`, `frame_dfn_Reverse`, `frame_dfn_SecureMonitorCall`, `frame_dfn_Shift`, `frame_dfn_SupervisorCall`, `frame_dfn_SystemInstruction`, `frame_dfn_TestBitAndBranch`, `frame_dfn_Unallocated`, `frame_raise_exception`, `frame_write_Mem`, `frame_write_SP`, `frame_write_X`, `word2_cases`.
- Review: A26: holds (model). For the stored target the usable form is `NextStateARM8_frame`, plus a separate no-fault fact.
- Reproduction: REPRODUCED-FROM-BRANCH with identical .sig/.sml/.dat (orch-A/repro/RESULT.json; W-final re-hashed the reproduced objects: equal). Same machine, stored older parents; not a clean replay.

### EE (erasure for one NextStateARM8 step) — case `EE-0001`

- Theory `forge_m1bEraseStep`; stored theorems 101, definitions 1 (from the .sig).
- Actual exit **0** (`command.json`); markers ['EXACT_COMPLETE']; wall 105.622 s; go.log last line `go exit 0`; `inputs_unchanged_after` True.
- Command: `./nightshift-run.sh EE-0001 1500 deps-EE.txt` in `results/m1b-routeA-20261119/attempt-0001` (cpu from `command.json` `cpu_seconds_limit`; deps: unique content match; reproduction used deps-EE.txt).
- sha256 `forge_m1bEraseStepTheory.sig` = `cc7a95cd2d3546afd3ea9cce8ed6088e3dda9a5ff71a7ac7c7f7013a71a77dc5` (equal to command.json record)
- sha256 `forge_m1bEraseStepTheory.sml` = `a1e693a490c4c52bd5df98da0e48466204d09be117a5d89a9b57e2af897f1b38` (equal to command.json record)
- sha256 `forge_m1bEraseStepTheory.dat` = `e6c3a68afb091d6eede8bf2587d94bc45c4e10d90ccf11ddd5ad51a62c52c1fa` (equal to command.json record)
- **Theorem row:** `forge_m1bEraseStep.NextStateARM8_erase` — exact statement and premise list: `FINAL_STATEMENTS.txt` anchor `[EE-0001/NextStateARM8_erase]` (premises: 4).
- **Theorem row:** `forge_m1bEraseStep.Next_erase_sp` — exact statement and premise list: `FINAL_STATEMENTS.txt` anchor `[EE-0001/Next_erase_sp]` (premises: 5).
- Other stored theorems (99), by name only (statements in FINAL_STATEMENTS.txt where printed; all in the .dat): `B1_dfn_BranchConditional`, `B1_dfn_BranchImmediate`, `B1_dfn_BranchRegister`, `B1_dfn_CompareAndBranch`, `B1_dfn_TestBitAndBranch`, `B2_dfn_BranchConditional`, `B2_dfn_BranchImmediate`, `B2_dfn_BranchRegister`, `B2_dfn_CompareAndBranch`, `B2_dfn_TestBitAndBranch`, `BranchImmediate_erase_untagged`, `BranchRegister_erase_untagged`, `FOR_erase`, `FOR_pair_erase`, `FOR_proj`, `FOR_snd_const`, `Fetch_keep`, `Mem_state`, `NX_erase`, `NX_pc`, `Next_alt`, `Next_erase_exception`, `Next_erase_pc`, `Next_erase_same_pc`, `Next_pc`, `Run_erase_pc`, `Run_pc`, `SCTLR_reads`, `U1_untagged_iff`, `U2_code_dm_untagged`, `U3_mem_dm_untagged`, `U4_next_pc_from_code_invariant`, `U5_erase_identity`, `U6_refund_end_state_erase_identity`, `W_nonvacuous`, `erase_BigEndian`, `erase_CheckAlignment`, `erase_ConditionHolds`, `erase_ExtendReg`, `erase_Fetch`, `erase_Hint_Branch`, `erase_LoadStoreSingle`, `erase_Mem`, `erase_SP`, `erase_SetTheFlags`, `erase_ShiftReg`, `erase_TranslationRegime`, `erase_X`, `erase_dfn_AddSubCarry`, `erase_dfn_AddSubExtendRegister`, `erase_dfn_AddSubImmediate`, `erase_dfn_AddSubShiftedRegister`, `erase_dfn_Address`, `erase_dfn_BitfieldMove`, `erase_dfn_Breakpoint`, `erase_dfn_CRC`, `erase_dfn_ClearExclusive`, `erase_dfn_ConditionalCompareImmediate`, `erase_dfn_ConditionalCompareRegister`, `erase_dfn_ConditionalSelect`, `erase_dfn_CountLeading`, `erase_dfn_DebugRestore`, `erase_dfn_DebugSwitch`, `erase_dfn_Division`, `erase_dfn_ExceptionReturn`, `erase_dfn_ExtractRegister`, `erase_dfn_Halt`, `erase_dfn_Hint`, `erase_dfn_HypervisorCall`, `erase_dfn_LoadLiteral`, `erase_dfn_LoadStoreAcquire`, `erase_dfn_LoadStoreAcquirePair`, `erase_dfn_LoadStoreImmediate`, `erase_dfn_LoadStorePair`, `erase_dfn_LoadStoreRegister`, `erase_dfn_LogicalImmediate`, `erase_dfn_LogicalShiftedRegister`, `erase_dfn_MemoryBarrier`, `erase_dfn_MoveImmediateProcState`, `erase_dfn_MoveSystemRegister`, `erase_dfn_MoveWide`, `erase_dfn_MultiplyAddSub`, `erase_dfn_MultiplyAddSubLong`, `erase_dfn_MultiplyHigh`, `erase_dfn_Reserved`, `erase_dfn_Reverse`, `erase_dfn_SecureMonitorCall`, `erase_dfn_Shift`, `erase_dfn_SupervisorCall`, `erase_dfn_SystemInstruction`, `erase_dfn_Unallocated`, `erase_raise_exception`, `erase_reads`, `erase_upds`, `erase_write_Mem`, `erase_write_SP`, `erase_write_X`, `fupd_PC_id`, `writeX_PC`.
- Review: A31: HOLDS. `NextStateARM8_erase` is the E1-0003 text. MISSING: non-vacuity with TBI0 or SA0 set and a non-fault step; the run lift needs "the erased run never faults", EL0, PC in code, SP aligned; native facts N1–N5.
- Reproduction: REPRODUCED-FROM-BRANCH with identical .sig/.sml/.dat (orch-A/repro/RESULT.json; W-final re-hashed the reproduced objects: equal). Same machine, stored older parents; not a clean replay.

### PF (strict-prefix lemmas for the HOL renderer) — case `PF-0004`

- Theory `forge_refundPrefixFree`; stored theorems 26, definitions 3 (from the .sig).
- Actual exit **0** (`command.json`); markers ['EXACT_COMPLETE']; wall 82.052 s; go.log last line `go exit 0`; `inputs_unchanged_after` True.
- Command: `./nightshift-run.sh PF-0004 600 deps-L1.txt` in `results/m1b-routeA-20261119/attempt-0001` (cpu from `command.json` `cpu_seconds_limit`; deps: reproduction used deps-L1.txt; identical content to deps-LO.txt).
- sha256 `forge_refundPrefixFreeTheory.sig` = `c99effd18c12a15653e467980571ae534bb8d46ba3ae097dbc6068386dc245d7` (equal to command.json record)
- sha256 `forge_refundPrefixFreeTheory.sml` = `fcf9f05632617d30e0f6662f76abc46e96f44f1c7eda1c79f8e81a2150642fb4` (equal to command.json record)
- sha256 `forge_refundPrefixFreeTheory.dat` = `bddae16a86019059a5f550508a28de770ba49ec7d41bde3493539694595cdce7` (equal to command.json record)
- **Theorem row:** `forge_refundPrefixFree.refund_strict_parse_no_strict_prefix` — exact statement and premise list: `FINAL_STATEMENTS.txt` anchor `[PF-0004/refund_strict_parse_no_strict_prefix]` (premises: 2).
- **Theorem row:** `forge_refundPrefixFree.refund_strict_parse_complete` — exact statement and premise list: `FINAL_STATEMENTS.txt` anchor `[PF-0004/refund_strict_parse_complete]` (premises: none at top level).
- **Theorem row:** `forge_refundPrefixFree.refund_render_fields_prefix_free` — exact statement and premise list: `FINAL_STATEMENTS.txt` anchor `[PF-0004/refund_render_fields_prefix_free]` (premises: 2).
- Other stored theorems (23), by name only (statements in FINAL_STATEMENTS.txt where printed; all in the .dat): `N1_trailing_newline_breaks`, `N2_atom_breaks`, `N3_depth0_breaks`, `atom_prefix_ISL`, `char_escaped_strict_prefix`, `every_isPREFIX`, `lexP_Atom`, `lexP_Expr`, `lexP_all`, `lexPs_cons`, `lexPs_cons_in_v`, `lexPs_cons_space`, `lexPs_cons_split`, `lexPs_nil`, `lex_aux_prefix_ISL`, `parse_ISL_of_lex`, `prefix_append_strict`, `read_string_aux_char_escaped`, `read_string_aux_strict_prefix`, `read_symbol_safe_nil`, `refund_render_fields_prefix_code`, `sexp_print_eqs`, `sexp_to_string_Expr_prefix_free`.
- Review: A13: no defect; MACHINE-CHECKED at model level for the real HOL renderer. `refund_strict_parse` is defined in the script. Python `frame.strict_parse` = HOL: TESTED-UNPROVED only.
- Reproduction: REPRODUCED-FROM-BRANCH with identical .sig/.sml/.dat (orch-A/repro/RESULT.json; W-final re-hashed the reproduced objects: equal). Same machine, stored older parents; not a clean replay.

### PX (exact acceptance set of the strict parser) — case `PX-0001`

- Theory `forge_refundPrefixExact`; stored theorems 9, definitions 0 (from the .sig).
- Actual exit **0** (`command.json`); markers ['EXACT_COMPLETE']; wall 74.631 s; go.log last line `go exit 0`; `inputs_unchanged_after` True.
- Command: `./nightshift-run.sh PX-0001 600 deps-PX.txt` in `results/m1b-routeA-20261119/attempt-0001` (cpu from `command.json` `cpu_seconds_limit`; deps: unique content match; reproduction used deps-PX.txt).
- sha256 `forge_refundPrefixExactTheory.sig` = `1b94aa1614fbd28abfb76de7077a7e926d427e1e5fff5c065d7a8ce013b7e7e3` (equal to command.json record)
- sha256 `forge_refundPrefixExactTheory.sml` = `d142d8311d390e8dd29247b387e67c94f39af01ba937b504280cd0ddb7f8378c` (equal to command.json record)
- sha256 `forge_refundPrefixExactTheory.dat` = `f521b6563120561463656376e2e1378ee570b841dd3e083a5a5f3abca890429b` (equal to command.json record)
- **Theorem row:** `forge_refundPrefixExact.refund_strict_parse_exact` — exact statement and premise list: `FINAL_STATEMENTS.txt` anchor `[PX-0001/refund_strict_parse_exact]` (premises: none at top level).
- **Theorem row:** `forge_refundPrefixExact.refund_frame_decision` — exact statement and premise list: `FINAL_STATEMENTS.txt` anchor `[PX-0001/refund_frame_decision]` (premises: 2).
- Other stored theorems (7), by name only (statements in FINAL_STATEMENTS.txt where printed; all in the .dat): `refund_frame_decision_needs_prefix`, `refund_strict_parse_SOME_render`, `refund_strict_parse_accepts_only_one_frame`, `refund_strict_parse_extension_needs_nonempty`, `refund_strict_parse_not_reject_all`, `refund_strict_parse_rejects_extension`, `refund_strict_parse_witness`.
- Review: A18: MACHINE-CHECKED; all items HOLD. Not covered: Python parser = HOL parser (TESTED-UNPROVED); real stdout ≼ model render (X8/X9); A-LOADER.
- Reproduction: REPRODUCED-FROM-BRANCH with identical .sig/.sml/.dat (orch-A/repro/RESULT.json; W-final re-hashed the reproduced objects: equal). Same machine, stored older parents; not a clean replay.

### L-OUT (model I/O events to descriptor-1 bytes) — case `LO-0006`

- Theory `forge_refundLOut`; stored theorems 43, definitions 6 (from the .sig).
- Actual exit **0** (`command.json`); markers ['EXACT_COMPLETE']; wall 82.771 s; go.log last line `go exit 0`; `inputs_unchanged_after` True.
- Command: `./nightshift-run.sh LO-0006 900 deps-L1.txt` in `results/m1b-routeA-20261119/attempt-0001` (cpu from `command.json` `cpu_seconds_limit`; deps: parent list equal to deps-L1.txt and deps-LO.txt; the reproduction used deps-L1.txt; original file name UNCONFIRMED by name).
- sha256 `forge_refundLOutTheory.sig` = `37c9a04ba7f577eb8048cc3d75674ce5c413eb17df1d9f2f91f16eaf106dc9c3` (equal to command.json record)
- sha256 `forge_refundLOutTheory.sml` = `7b3ddca11b563905b473a1754b2a2698d47ce2a7c9e070bb2c844620ba3c66ef` (equal to command.json record)
- sha256 `forge_refundLOutTheory.dat` = `c77cfc0b05a58a668d86e8f2ac3194c75f6d2808a9f7f6f225ae3e7d626965a4` (equal to command.json record)
- **Theorem row:** `forge_refundLOut.refund_L_OUT` — exact statement and premise list: `FINAL_STATEMENTS.txt` anchor `[LO-0006/refund_L_OUT]` (premises: 2).
- **Theorem row:** `forge_refundLOut.refund_L_OUT_prefix` — exact statement and premise list: `FINAL_STATEMENTS.txt` anchor `[LO-0006/refund_L_OUT_prefix]` (premises: 3).
- **Theorem row:** `forge_refundLOut.refund_profile_a_sl_fd1` — exact statement and premise list: `FINAL_STATEMENTS.txt` anchor `[LO-0006/refund_profile_a_sl_fd1]` (premises: 11).
- Other stored theorems (40), by name only (statements in FINAL_STATEMENTS.txt where printed; all in the .dat): `ALOOKUP_fs_ffi_part`, `N_O1_free_ext_breaks`, `N_O2_failed_write_counted_without_success_test`, `N_O3_fd2_write_counted_without_fd_test`, `P_O4_partial_write_counts_nw`, `STD_streams_ADELKEY_File`, `STD_streams_File_fd`, `STD_streams_facts`, `STD_streams_fs0`, `closeFD_stdout`, `extract_fs_inode_tbl`, `extract_no_ext_ExtCall`, `extract_no_ext_stdout`, `extract_no_ext_stdout_cons`, `extract_no_ext_stdout_nil`, `extract_no_ext_stdout_step`, `extract_no_ext_stdout_step_ExtCall`, `extract_no_ext_stdout_step_SharedMem`, `extract_no_ext_stdout_step_basis_other`, `extract_no_ext_stdout_step_event`, `extract_no_ext_stdout_step_fs_ffi_part`, `fd1_written_APPEND`, `fd1_written_def`, `fd1_written_ind`, `fd1_written_prefix`, `ffi_close_stdout_step`, `ffi_open_in_stdout_step`, `ffi_open_out_stdout_step`, `ffi_read_stdout_step`, `ffi_write_cases`, `ffi_write_stdout_step`, `fs_ffi_part_stdout_step`, `openFile_stdout`, `openFile_truncate_stdout`, `read_stdout`, `refund_profile_a_sl_fd1_Resource_limit_hit`, `refund_profile_a_sl_fd1_Success`, `w22n_lt`, `w22n_n2w2_bytes`, `write_stdout`.
- Review: A22: no false statement; MACHINE-CHECKED within scope (model, `no_ext`, stored premises incl. `refund_env_ok_sl`, which is false for the real C). Orchestrator A's own written stop was BENT (owner item A-2). 43 stored = 41 CHECKED + `fd1_written_def` + `fd1_written_ind`.
- Reproduction: REPRODUCED-FROM-BRANCH with identical .sig/.sml/.dat (orch-A/repro/RESULT.json; W-final re-hashed the reproduced objects: equal). Same machine, stored older parents; not a clean replay.

### L-EXIT generic — case `LE-0003`

- Theory `forge_refundLExitGen`; stored theorems 6, definitions 2 (from the .sig).
- Actual exit **0** (`command.json`); markers ['EXACT_COMPLETE']; wall 78.068 s; go.log last line `go exit 0`; `inputs_unchanged_after` True.
- Command: `./nightshift-run.sh LE-0003 1200 deps-L1.txt` in `results/m1b-routeA-20261119/attempt-0001` (cpu from `command.json` `cpu_seconds_limit`; deps: parent list equal to deps-L1.txt and deps-LO.txt; file name UNCONFIRMED by name).
- sha256 `forge_refundLExitGenTheory.sig` = `b4e08579c17baf24a0cf6c70f9674e7c1cf826fc255321e51e475d6a564ea455` (equal to command.json record)
- sha256 `forge_refundLExitGenTheory.sml` = `795f8273c7ff36bf7164e4c9a165f9a6cd4b14c0c34104b77292976842f0c09e` (equal to command.json record)
- sha256 `forge_refundLExitGenTheory.dat` = `c75e87c3237317add452fc596eccd6a9d8eb78cf85b107d33b9714dc804afbf3` (equal to command.json record)
- **Theorem row:** `forge_refundLExitGen.evaluate_Halt_reg` — exact statement and premise list: `FINAL_STATEMENTS.txt` anchor `[LE-0003/evaluate_Halt_reg]` (premises: 1).
- Other stored theorems (5), by name only (statements in FINAL_STATEMENTS.txt where printed; all in the .dat): `N_E1_status_collision`, `N_E2_silent_stop`, `N_E3_success_with_zero_register`, `machine_sem_of_evaluate_Halt`, `refund_halt_address`.
- Review: A26: holds (generic `evaluate_Halt_reg`). Superseded for the refund instance by LE-0004 (same 6 statements, by script).
- Reproduction: not in the reproduction set (single same-machine run).

### L-EXIT (model halt to register value) — case `LE-0004`

- Theory `forge_refundLExit`; stored theorems 7, definitions 2 (from the .sig).
- Actual exit **0** (`command.json`); markers ['EXACT_COMPLETE']; wall 84.894 s; go.log last line `go exit 0`; `inputs_unchanged_after` True.
- Command: `./nightshift-run.sh LE-0004 1200 deps-LE.txt` in `results/m1b-routeA-20261119/attempt-0001` (cpu from `command.json` `cpu_seconds_limit`; deps: unique content match; reproduction used deps-LE.txt).
- sha256 `forge_refundLExitTheory.sig` = `3d655ac63d5b623fd035f300c23f45fda0efcd94e8c671e67d6cc16d940d0835` (equal to command.json record)
- sha256 `forge_refundLExitTheory.sml` = `533615b1a93e76c43533cb5993cd40e1a02d3ec9bb41a4d743c89bb06a4c3f2a` (equal to command.json record)
- sha256 `forge_refundLExitTheory.dat` = `ae68ccd38fac46d165c787caab1e6ba32c2eb60ad60494c11c1ed7a042aee45c` (equal to command.json record)
- **Theorem row:** `forge_refundLExit.refund_profile_a_sl_halt` — exact statement and premise list: `FINAL_STATEMENTS.txt` anchor `[LE-0004/refund_profile_a_sl_halt]` (premises: 11).
- **Theorem row:** `forge_refundLExit.evaluate_Halt_reg` — exact statement and premise list: `FINAL_STATEMENTS.txt` anchor `[LE-0004/evaluate_Halt_reg]` (premises: 1).
- Other stored theorems (5), by name only (statements in FINAL_STATEMENTS.txt where printed; all in the .dat): `N_E1_status_collision`, `N_E2_silent_stop`, `N_E3_success_with_zero_register`, `machine_sem_of_evaluate_Halt`, `refund_halt_address`.
- Review: A26: holds; uses the CmlMainSlide `arm8_run`; vacuous if no clock halts (existence is elsewhere). Halt-value range and the real exit path (32-bit test, 8-bit status) stay open. Owner item A-2 covers it.
- Reproduction: REPRODUCED-FROM-BRANCH with identical .sig/.sml/.dat (orch-A/repro/RESULT.json; W-final re-hashed the reproduced objects: equal). Same machine, stored older parents; not a clean replay.

### MF first run (superseded by MF-0002) — case `MF-0001`

- Theory `forge_refundModelFrame`; stored theorems 11, definitions 0 (from the .sig).
- Actual exit **0** (`command.json`); markers ['EXACT_COMPLETE']; wall 76.603 s; go.log last line `go exit 0`; `inputs_unchanged_after` True.
- Command: `./nightshift-run.sh MF-0001 900 deps-MF.txt` in `results/m1b-routeA-20261119/attempt-0001` (cpu from `command.json` `cpu_seconds_limit`; deps: unique content match).
- sha256 `forge_refundModelFrameTheory.sig` = `e6973e3137d3b1993cede52b17c3d62dfa7ffdb644750ce1c2650212534d123a` (equal to command.json record)
- sha256 `forge_refundModelFrameTheory.sml` = `592210b61c76bcb7ad918ca1bdbc46fe376a7d6632f539eccfad4de845e3d305` (equal to command.json record)
- sha256 `forge_refundModelFrameTheory.dat` = `29a28cb997e6ae13a9268063fceca3ea633046ccd1502f8e657882432d254abe` (equal to command.json record)
- **Theorem row:** `forge_refundModelFrame.refund_model_frame_decision` — exact statement and premise list: `FINAL_STATEMENTS.txt` anchor `[MF-0001/refund_model_frame_decision]` (premises: 11).
- Other stored theorems (10), by name only (statements in FINAL_STATEMENTS.txt where printed; all in the .dat): `extend_with_resource_limit_single_success`, `refund_fd1_frame_of_run`, `refund_frame_accept_of_outcome`, `refund_frame_accept_of_prefix`, `refund_model_frame_decision_reach`, `refund_model_success_gives_frame`, `refund_outcome_prefix`, `refund_strict_parse_common_prefix_rejected`, `refund_strict_parse_empty_rejected`, `refund_success_accept`.
- Review: A26 reviewed MF-0001 with MF-0002. Same theory name as MF-0002; its 11 statements are identical by script to MF-0002's; MF-0002 adds 2. MF-0002 is the parent of later cases.
- Reproduction: not in the reproduction set (single same-machine run).

### M3 (machine model to exported contract, one theorem) — case `MF-0002`

- Theory `forge_refundModelFrame`; stored theorems 13, definitions 0 (from the .sig).
- Actual exit **0** (`command.json`); markers ['EXACT_COMPLETE']; wall 79.607 s; go.log last line `go exit 0`; `inputs_unchanged_after` True.
- Command: `./nightshift-run.sh MF-0002 900 deps-MF2.txt` in `results/m1b-routeA-20261119/attempt-0001` (cpu from `command.json` `cpu_seconds_limit`; deps: unique content match; reproduction used deps-MF2.txt).
- sha256 `forge_refundModelFrameTheory.sig` = `0807d8cafb615d4261baeb85db30c9c62b6707bab538b4a95009a3f231179fe0` (equal to command.json record)
- sha256 `forge_refundModelFrameTheory.sml` = `6c1600c7376cffaf4737c5b5e91ff43e8393cbddc49717af0225ed26213374c5` (equal to command.json record)
- sha256 `forge_refundModelFrameTheory.dat` = `25852aa9600444cd42a0035df3d5a18635f26c0c4f315bba309b8d25f0794963` (equal to command.json record)
- **Theorem row:** `forge_refundModelFrame.refund_model_frame_meets_exported_contract` — exact statement and premise list: `FINAL_STATEMENTS.txt` anchor `[MF-0002/refund_model_frame_meets_exported_contract]` (premises: 11).
- **Theorem row:** `forge_refundModelFrame.refund_model_frame_decision` — exact statement and premise list: `FINAL_STATEMENTS.txt` anchor `[MF-0002/refund_model_frame_decision]` (premises: 11).
- Other stored theorems (11), by name only (statements in FINAL_STATEMENTS.txt where printed; all in the .dat): `extend_with_resource_limit_single_success`, `refund_fd1_frame_of_run`, `refund_frame_accept_of_outcome`, `refund_frame_accept_of_prefix`, `refund_frame_contract_key`, `refund_model_frame_decision_reach`, `refund_model_success_gives_frame`, `refund_outcome_prefix`, `refund_strict_parse_common_prefix_rejected`, `refund_strict_parse_empty_rejected`, `refund_success_accept`.
- Review: A26: MACHINE-CHECKED (model). Constants are the link theory's own. Its premise `refund_env_ok_sl` is FALSE for the real C (U393). 13 named assumptions stand between M3 and "the real consumer accepts the real stdout ⇒ approved R1–R5".
- Reproduction: REPRODUCED-FROM-BRANCH with identical .sig/.sml/.dat (orch-A/repro/RESULT.json; W-final re-hashed the reproduced objects: equal). Same machine, stored older parents; not a clean replay.

### MG (M3 from the reduced premises: native contract at VokY3 + R6) — case `MG-0001`

- Theory `forge_refundModelFrameEvents`; stored theorems 5, definitions 0 (from the .sig).
- Actual exit **0** (`command.json`); markers ['EXACT_COMPLETE']; wall 72.379 s; go.log last line `go exit 0`; `inputs_unchanged_after` True.
- Command: `./nightshift-run.sh MG-0001 900 deps-MG.txt` in `results/m1b-routeA-20261119/attempt-0001` (cpu from `command.json` `cpu_seconds_limit`; deps: unique content match; reproduction used deps-MG.txt).
- sha256 `forge_refundModelFrameEventsTheory.sig` = `ebb925aef88d057e0b6befd39619cdc581d18f906be06602509a43ead6ba5866` (equal to command.json record)
- sha256 `forge_refundModelFrameEventsTheory.sml` = `9e94b86240490c8aefbe0b5f95fbc2a5575b8061c7974a98ac11967d28cf6b98` (equal to command.json record)
- sha256 `forge_refundModelFrameEventsTheory.dat` = `af248759e08ab151dcad67ed805720dcb12596719581f3d2306d97aeb72f1af4` (equal to command.json record)
- **Theorem row:** `forge_refundModelFrameEvents.refund_model_frame_decision_events` — exact statement and premise list: `FINAL_STATEMENTS.txt` anchor `[MG-0001/refund_model_frame_decision_events]` (premises: 13).
- **Theorem row:** `forge_refundModelFrameEvents.refund_model_success_gives_frame_events` — exact statement and premise list: `FINAL_STATEMENTS.txt` anchor `[MG-0001/refund_model_success_gives_frame_events]` (premises: 13).
- Other stored theorems (3), by name only (statements in FINAL_STATEMENTS.txt where printed; all in the .dat): `refund_frame_contract_upgrade`, `refund_model_frame_contract_of_reach`, `refund_success_accept_of_run`.
- Review: A27: G1, G2 hold; visibly conditional on R6 (MISSING) and the contract at VokY3-valid calls (native).
- Reproduction: REPRODUCED-FROM-BRANCH with identical .sig/.sml/.dat (orch-A/repro/RESULT.json; W-final re-hashed the reproduced objects: equal). Same machine, stored older parents; not a clean replay. First reproduction try: actual exit 1 ("Run out of store" in parent load), kept as MG-0001.fail-1.

### MT (composed theorem for the totalised machine) — case `MT-0001`

- Theory `forge_refundModelFrameTot`; stored theorems 6, definitions 0 (from the .sig).
- Actual exit **0** (`command.json`); markers ['EXACT_COMPLETE']; wall 114.711 s; go.log last line `go exit 0`; `inputs_unchanged_after` True.
- Command: `./nightshift-run.sh MT-0001 900 deps-MG.txt` in `results/m1b-routeA-20261119/attempt-0001` (cpu from `command.json` `cpu_seconds_limit`; deps: STATE.md and content match).
- sha256 `forge_refundModelFrameTotTheory.sig` = `87c854a3cba78fe2d0b225d6961a1b9b60026b865859a826d7e39c40521cae82` (equal to command.json record)
- sha256 `forge_refundModelFrameTotTheory.sml` = `f21ab5aa0d36639636c6b9eee9f9c54ff32e46b9f050865987098d4dd7b1f747` (equal to command.json record)
- sha256 `forge_refundModelFrameTotTheory.dat` = `ee292cf1f55cee49e48ff5fe8ece2ccd7fb6c8b1ce9a3f9644842c1fa02847d3` (equal to command.json record)
- **Theorem row:** `forge_refundModelFrameTot.refund_model_frame_totalised` — exact statement and premise list: `FINAL_STATEMENTS.txt` anchor `[MT-0001/refund_model_frame_totalised]` (premises: 12).
- **Theorem row:** `forge_refundModelFrameTot.refund_model_success_totalised` — exact statement and premise list: `FINAL_STATEMENTS.txt` anchor `[MT-0001/refund_model_success_totalised]` (premises: 12).
- Other stored theorems (4), by name only (statements in FINAL_STATEMENTS.txt where printed; all in the .dat): `refund_ffi_contract_on_empty_predicate`, `refund_ffi_tot_classification_ignores_counter`, `refund_ffi_tot_empty_predicate_is_abstract`, `refund_ffi_tot_observed_set`.
- Review: HOLDS WITH LIMITS (review-MT): model level only; 12 premises; `interference_ok` and `contract_on` for a constructed environment NOT proved; MT2 only for Terminate Success; non-vacuity of MT1 premises not stored; two self-referential controls.
- Reproduction: not in the reproduction set (single same-machine run).

### NV (joint witness for the shape antecedent) — case `NV-0003`

- Theory `forge_refundShapeSat`; stored theorems 6, definitions 0 (from the .sig).
- Actual exit **0** (`command.json`); markers ['EXACT_COMPLETE']; wall 159.146 s; go.log last line `go exit 0`; `inputs_unchanged_after` True.
- Command: `./nightshift-run.sh NV-0003 900 deps-NV.txt` in `results/m1b-routeA-20261119/attempt-0001` (cpu from `command.json` `cpu_seconds_limit`; deps: unique content match; STATE.md).
- sha256 `forge_refundShapeSatTheory.sig` = `89aae432c0a3522d98c447bd71d94a1d369265c5d59b99d7720de7b64846b91b` (equal to command.json record)
- sha256 `forge_refundShapeSatTheory.sml` = `a0f8e0c139756710059d9e30b48f6a93e8103a04fab6772e3c84a95a62a17576` (equal to command.json record)
- sha256 `forge_refundShapeSatTheory.dat` = `146210e7952478d30c60552b0dcc6efe69c62ad7d47e119d896afe4582edf293` (equal to command.json record)
- **Theorem row:** `forge_refundShapeSat.refund_shape_premises_satisfiable_for_every_request` — exact statement and premise list: `FINAL_STATEMENTS.txt` anchor `[NV-0003/refund_shape_premises_satisfiable_for_every_request]` (premises: none at top level).
- **Theorem row:** `forge_refundShapeSat.refund_shape_premises_hold_at_a_constructed_state` — exact statement and premise list: `FINAL_STATEMENTS.txt` anchor `[NV-0003/refund_shape_premises_hold_at_a_constructed_state]` (premises: none at top level).
- Other stored theorems (4), by name only (statements in FINAL_STATEMENTS.txt where printed; all in the .dat): `refund_abs_env_fields`, `refund_ffi_contract_at_imp_on`, `refund_shape_premises_satisfiable`, `refund_shape_run_is_accepted`.
- Review: HOLDS WITH LIMITS (review-NV): MODEL-only witness at the abstract environment; NV2 weak; no stored witness for MT1 or MG-0001; no witness that a run ends in Success with a strict frame.
- Reproduction: not in the reproduction set (single same-machine run).

### NN (non-negative amount and count; T14 part b) — case `NN-0002`

- Theory `forge_refundNonNeg`; stored theorems 9, definitions 0 (from the .sig).
- Actual exit **0** (`command.json`); markers ['EXACT_COMPLETE']; wall 288.783 s; go.log last line `go exit 0`; `inputs_unchanged_after` True.
- Command: `./nightshift-run.sh NN-0002 900 deps-MG.txt` in `results/m1b-routeA-20261119/attempt-0001` (cpu from `command.json` `cpu_seconds_limit`; deps: unique content match; STATE.md).
- sha256 `forge_refundNonNegTheory.sig` = `fd3e5b77be13963e87381648aefe9ef59e72357abd3d956a2f8f488d09c036ac` (equal to command.json record)
- sha256 `forge_refundNonNegTheory.sml` = `a93c71ed7f8603dc548ee7d45a2fba9d4e0f6509b6f71498ff090897c3953dde` (equal to command.json record)
- sha256 `forge_refundNonNegTheory.dat` = `ecd5c4bb0206fa7749ba863c870d4a1c5b975d67a3887661da96a8dd45873495` (equal to command.json record)
- **Theorem row:** `forge_refundNonNeg.refund_run_wire_output_nonneg` — exact statement and premise list: `FINAL_STATEMENTS.txt` anchor `[NN-0002/refund_run_wire_output_nonneg]` (premises: 1).
- **Theorem row:** `forge_refundNonNeg.refund_frame_decision_nonneg` — exact statement and premise list: `FINAL_STATEMENTS.txt` anchor `[NN-0002/refund_frame_decision_nonneg]` (premises: 2).
- **Theorem row:** `forge_refundNonNeg.refund_model_frame_decision_nonneg` — exact statement and premise list: `FINAL_STATEMENTS.txt` anchor `[NN-0002/refund_model_frame_decision_nonneg]` (premises: 11).
- Other stored theorems (6), by name only (statements in FINAL_STATEMENTS.txt where printed; all in the .dat): `refund_fields_ints_bounded`, `refund_fields_ints_bounded_proj`, `refund_fields_negative_amount_rejected`, `refund_fields_positive_witness`, `refund_model_frame_decision_reach_nonneg`, `refund_strict_parse_accepts_negative_frame`.
- Review: HOLDS WITH LIMITS (review-NN): about the HOL parser only; "the two parsers agree" is an OVERCLAIM; O1 inherits `refund_env_ok_sl` (may be vacuous).
- Reproduction: not in the reproduction set (single same-machine run).

### R6 base (replay shortcut refuted) — case `R6base-0001`

- Theory `forge_refundR6Base`; stored theorems 11, definitions 0 (from the .sig).
- Actual exit **0** (`command.json`); markers ['EXACT_COMPLETE']; wall 78.107 s; go.log last line `go exit 0`; `inputs_unchanged_after` True.
- Command: `./nightshift-run.sh R6base-0001 900 deps-R6x.txt` in `results/m1b-routeA-20261119/attempt-0001` (cpu from `command.json` `cpu_seconds_limit`; deps: unique content match; reproduction used deps-R6x.txt).
- sha256 `forge_refundR6BaseTheory.sig` = `334bfef3209e8cd2349afa7d9220b044f209a39396b687567bcce06f7d024569` (equal to command.json record)
- sha256 `forge_refundR6BaseTheory.sml` = `8e1a9bb0f0c9e88df862a24d2a4c82c45ce710f624fff199125fbdc34d92c751` (equal to command.json record)
- sha256 `forge_refundR6BaseTheory.dat` = `0fd1bb32b5f18c9330c0a120b5cb954e60adeea8913193eadbdd3663c34fc57e` (equal to command.json record)
- **Theorem row:** `forge_refundR6Base.replay_cannot_exclude_error_return_events` — exact statement and premise list: `FINAL_STATEMENTS.txt` anchor `[R6base-0001/replay_cannot_exclude_error_return_events]` (premises: none at top level).
- **Theorem row:** `forge_refundR6Base.every_clock_events` — exact statement and premise list: `FINAL_STATEMENTS.txt` anchor `[R6base-0001/every_clock_events]` (premises: 2).
- Other stored theorems (9), by name only (statements in FINAL_STATEMENTS.txt where printed; all in the .dat): `bad_read_event_is_not_valid`, `bad_read_event_is_not_valid_w`, `bad_read_event_replays_to_the_same_state`, `clock_prefix_of_terminate`, `every_of_three_parts`, `every_prefix`, `extract_fs_ignores_bad_read_event`, `ffi_has_index_in_APPEND`, `refund_valid_event_implies_weak`.
- Review: A31: HOLDS with limits: `replay_cannot_exclude_error_return_events` refutes exactly the replay shortcut; its bad event has an EMPTY configuration; a stronger bad event is UNCHECKED.
- Reproduction: REPRODUCED-FROM-BRANCH with identical .sig/.sml/.dat (orch-A/repro/RESULT.json; W-final re-hashed the reproduced objects: equal). Same machine, stored older parents; not a clean replay.

### R6 FFI-level specifications with an event invariant — case `R6ffi-0002`

- Theory `forge_refundR6Ffi`; stored theorems 4, definitions 3 (from the .sig).
- Actual exit **0** (`command.json`); markers ['EXACT_COMPLETE']; wall 170.745 s; go.log last line `go exit 0`; `inputs_unchanged_after` True.
- Command: `./nightshift-run.sh R6ffi-0002 3600 deps-R6ffi.txt` in `results/m1b-routeA-20261119/attempt-0001` (cpu from `command.json` `cpu_seconds_limit`; deps: unique content match; STATE.md; reproduction used deps-R6ffi.txt).
- sha256 `forge_refundR6FfiTheory.sig` = `ab3b7581bc47a155eda9c19697cadbaa25bf23e826265b546dd29667bf91d38a` (equal to command.json record)
- sha256 `forge_refundR6FfiTheory.sml` = `56a4f132c5d5effa26b47ac1a0b110fd3acf199ac235464990749c3c072800ae` (equal to command.json record)
- sha256 `forge_refundR6FfiTheory.dat` = `9bd6e4d295206830a7de112119f3e9d7bca831fc5e1b468cf80f249bd46e8294` (equal to command.json record)
- **Theorem row:** `forge_refundR6Ffi.read_into_spec_V` — exact statement and premise list: `FINAL_STATEMENTS.txt` anchor `[R6ffi-0002/read_into_spec_V]` (premises: 1; printed statement ELIDED).
- **Theorem row:** `forge_refundR6Ffi.writei_spec_V` — exact statement and premise list: `FINAL_STATEMENTS.txt` anchor `[R6ffi-0002/writei_spec_V]` (premises: 1; printed statement ELIDED).
- **Theorem row:** `forge_refundR6Ffi.IOxV_IMP_IOx` — exact statement and premise list: `FINAL_STATEMENTS.txt` anchor `[R6ffi-0002/IOxV_IMP_IOx]` (premises: none at top level).
- Other stored theorems (1), by name only (statements in FINAL_STATEMENTS.txt where printed; all in the .dat): `IOFS_V_FFI_part_hprop`.
- Review: A32: 4 theorems, 3 definitions MACHINE-CHECKED. Record gap: the `use`d files were not bound in the run record (fixed for later runs). Statements ELIDED in stdout. H_inv discharge at the program's calls: by hand only. The .sml header still names R6ffi-0001.
- Reproduction: REPRODUCED-FROM-BRANCH with identical .sig/.sml/.dat (orch-A/repro/RESULT.json; W-final re-hashed the reproduced objects: equal). Same machine, stored older parents; not a clean replay. RESULT.json sha256 fe251382… (read 17:20:48Z). First reproduction try: actual exit -15 (watchdog after a system sleep), kept as R6ffi-0002.fail-1; the source differs only in the r6 directory string.

### R6 write side — case `R6w-0004`

- Theory `forge_refundR6Write`; stored theorems 16, definitions 1 (from the .sig).
- Actual exit **0** (`command.json`); markers ['EXACT_COMPLETE']; wall 153.144 s; go.log last line `go exit 0`; `inputs_unchanged_after` True.
- Command: `./nightshift-run.sh R6w-0004 3600 deps-R6w.txt` in `results/m1b-routeA-20261119/attempt-0001` (cpu from `command.json` `cpu_seconds_limit`; deps: unique content match; STATE.md).
- sha256 `forge_refundR6WriteTheory.sig` = `afa7c1e3952247019a43891a9d323eb10197e541faad530e8988aa362d0be46b` (equal to command.json record)
- sha256 `forge_refundR6WriteTheory.sml` = `04eb1904049bbf51a923be4027d1570423ba0156868811ee59fb1a2e604e7c7b` (equal to command.json record)
- sha256 `forge_refundR6WriteTheory.dat` = `832ae0b79545441e8ca49926d05049e7cf848698d8c5fca322c6660ccc767e8e` (equal to command.json record)
- **Theorem row:** `forge_refundR6Write.print_spec_refund` — exact statement and premise list: `FINAL_STATEMENTS.txt` anchor `[R6w-0004/print_spec_refund]` (premises: 1).
- **Theorem row:** `forge_refundR6Write.write_spec_V` — exact statement and premise list: `FINAL_STATEMENTS.txt` anchor `[R6w-0004/write_spec_V]` (premises: 1; printed statement ELIDED).
- **Theorem row:** `forge_refundR6Write.write_event_ok_refund` — exact statement and premise list: `FINAL_STATEMENTS.txt` anchor `[R6w-0004/write_event_ok_refund]` (premises: none at top level).
- Other stored theorems (13), by name only (statements in FINAL_STATEMENTS.txt where printed; all in the .dat): `IOFS_V_HPROP_INJ`, `IOxV_FFI_part_IN`, `SEG_APPEND3_W`, `STDIO_V_HPROP_INJ`, `STDIO_V_numchars`, `UNIQUE_IOFS_V`, `UNIQUE_STDIO_V`, `output_STDIO_spec_V`, `output_aux_spec_V`, `output_spec_V`, `print_spec_V`, `write_event_ok_writei`, `writei_spec_W`.
- Review: A34: no defect; 16 theorems, 1 definition MACHINE-CHECKED at the heap-predicate level, conditional on `STDIO_V`; does not reach the semantic event list; open items (a)–(e). The .sml header still names R6w-0003.
- Reproduction: REPRODUCED-FROM-BRANCH with identical .sig/.sml/.dat (orch-A/repro/RESULT.json; W-final re-hashed the reproduced objects: equal). Same machine, stored older parents; not a clean replay. Started 17:11:10Z, AFTER the wind-down order reached A (see section 8); ended 17:19:38Z, go exit 0.

### R6 read side, bottom layer — case `R6r-0004`

- Theory `forge_refundR6Read`; stored theorems 9, definitions 4 (from the .sig).
- Actual exit **0** (`command.json`); markers ['EXACT_COMPLETE']; wall 248.049 s; go.log last line `go exit 0`; `inputs_unchanged_after` True.
- Command: `./nightshift-run.sh R6r-0004 3600 deps-R6r.txt` in `results/m1b-routeA-20261119/attempt-0001` (cpu from `command.json` `cpu_seconds_limit`; deps: STATE.md (q42); identical content to deps-R6t.txt).
- sha256 `forge_refundR6ReadTheory.sig` = `6e103506d6821cb25dd5035bc7ea61c38a5379d8c1099859eecb7fdbde419fbf` (equal to command.json record)
- sha256 `forge_refundR6ReadTheory.sml` = `756fa28b89bc156da005430165f958ed371d734cd07069dc4cfe26a81481d739` (equal to command.json record)
- sha256 `forge_refundR6ReadTheory.dat` = `8821d180073c3968132b589da308def0d454278a142847724db500fbbdcd3209` (equal to command.json record)
- **Theorem row:** `forge_refundR6Read.refillBuffer_with_read_spec_V` — exact statement and premise list: `FINAL_STATEMENTS.txt` anchor `[R6r-0004/refillBuffer_with_read_spec_V]` (premises: 2; printed statement ELIDED).
- **Theorem row:** `forge_refundR6Read.read_event_ok_refund` — exact statement and premise list: `FINAL_STATEMENTS.txt` anchor `[R6r-0004/read_event_ok_refund]` (premises: none at top level).
- Other stored theorems (7), by name only (statements in FINAL_STATEMENTS.txt where printed; all in the .dat): `INSTREAM_BUFFERED_FD_V_IMP`, `INSTREAM_STRP_V_F_F`, `INSTREAM_STR_V_IMP`, `STD_streams_fd0`, `read_event_ok_read_into`, `read_into_spec_R`, `refillBuffer_with_read_spec_STR_V`.
- Review: HOLDS WITH LIMITS (review-R6r): only `refillBuffer_with_read` and its STR wrapper; no link to `io_events`; side conditions remain. Header names R6r-0003 (record defect).
- Reproduction: not in the reproduction set (single same-machine run).

### R6 top glue (source-semantics io_events) — case `R6t-0004`

- Theory `forge_refundR6Top`; stored theorems 18, definitions 0 (from the .sig).
- Actual exit **0** (`command.json`); markers ['EXACT_COMPLETE']; wall 503.378 s; go.log last line `go exit 0`; `inputs_unchanged_after` True.
- Command: `./nightshift-run.sh R6t-0004 1800 deps-R6t.txt` in `results/m1b-routeA-20261119/attempt-0001` (cpu from `command.json` `cpu_seconds_limit`; deps: STATE.md; identical content to deps-R6r.txt).
- sha256 `forge_refundR6TopTheory.sig` = `1d18da0f1ed9e538ee3c7ab7e07e338ea98f21c4db1f38f63a4ca4b310a5657c` (equal to command.json record)
- sha256 `forge_refundR6TopTheory.sml` = `a3b35263643a275b0a53b54e439dd3b7de34e598c580059b7bd670e91ba78ca5` (equal to command.json record)
- sha256 `forge_refundR6TopTheory.dat` = `3ed285382c3f84ddb72f3b64c0fc5be514e846564666225b74b8dce11afb45b0` (equal to command.json record)
- **Theorem row:** `forge_refundR6Top.whole_prog_spec_V_events` — exact statement and premise list: `FINAL_STATEMENTS.txt` anchor `[R6t-0004/whole_prog_spec_V_events]` (premises: 7).
- **Theorem row:** `forge_refundR6Top.sem_satisfies_imp_V` — exact statement and premise list: `FINAL_STATEMENTS.txt` anchor `[R6t-0004/sem_satisfies_imp_V]` (premises: 1).
- **Theorem row:** `forge_refundR6Top.IOFS_V_init` — exact statement and premise list: `FINAL_STATEMENTS.txt` anchor `[R6t-0004/IOFS_V_init]` (premises: 3).
- Other stored theorems (15), by name only (statements in FINAL_STATEMENTS.txt where printed; all in the .dat): `FFI_part_IN_st2heap_FILTER`, `IOxV_events_IN`, `STDIO_V_FFI_part_hprop`, `STDIO_V_events`, `STDIO_V_of_IOFS_V`, `basis_proj2_names`, `every_basis_events`, `final_heap_events`, `init_cl_part_IN`, `init_fs_part_IN`, `init_heap_V`, `init_iobuff_IN`, `init_rt_part_IN`, `parts_ok_basis_ffi`, `whole_prog_spec_V_init`.
- Review: HOLDS WITH LIMITS (review-TR): reaches the source-semantics `io_events` (Terminate Success io, EVERY Inv io); hypotheses left: main V-spec, declaration lookup, state facts, `wfFS`, `STD_streams`. No machine-level fact.
- Reproduction: not in the reproduction set (single same-machine run).

### TR1 (generic trace theory, X8 model side) — case `TR1-0001`

- Theory `forge_machineTrace`; stored theorems 71, definitions 17 (from the .sig).
- Actual exit **0** (`command.json`); markers ['EXACT_COMPLETE']; wall 204.284 s; go.log last line `go exit 0`; `inputs_unchanged_after` True.
- Command: `./nightshift-run.sh TR1-0001 1200 deps-TR.txt` in `results/m1b-routeA-20261119/attempt-0001` (cpu from `command.json` `cpu_seconds_limit`; deps: unique content match; STATE.md).
- sha256 `forge_machineTraceTheory.sig` = `d8fd6750a2f1c244fe437951e6d2680a1a75b9129e0c6a689d62b048e0bb80c5` (equal to command.json record)
- sha256 `forge_machineTraceTheory.sml` = `df8ad427c3c042f43be31283482adf9aaf26cee3ddaee703f9a1f17bcaa846f7` (equal to command.json record)
- sha256 `forge_machineTraceTheory.dat` = `b48745a44b275789cf322916641ded296ac495a85ec63c0f1a1225e456915271` (equal to command.json record)
- **Theorem row:** `forge_machineTrace.evaluate_follows_trace` — exact statement and premise list: `FINAL_STATEMENTS.txt` anchor `[TR1-0001/evaluate_follows_trace]` (premises: 1).
- **Theorem row:** `forge_machineTrace.trace_io` — exact statement and premise list: `FINAL_STATEMENTS.txt` anchor `[TR1-0001/trace_io]` (premises: 1).
- Other stored theorems (69), by name only (statements in FINAL_STATEMENTS.txt where printed; all in the .dat): `add_clock_swap`, `call_FFI_return_io`, `datatype_trace_event`, `div_after`, `evaluate_cong`, `evaluate_one_ffi_event`, `evaluate_one_step_event`, `evaluate_zero`, `fail_after`, `ffi_event_ok_upd`, `ffi_post_st_io`, `ffi_post_st_upd`, `fst_error`, `nffis_def`, `nffis_ind`, `prefix_of_halt`, `shift_seq_0`, `shift_seq_1_pred`, `shift_seq_shift_seq`, `step_event_ok_upd`, `term_after`, `toy_bad_rejected`, `toy_encoded`, `toy_target_fields`, `toy_trace_events`, `toy_trace_ok`, `trace_eventMAP_ind`, `trace_eventMAP_thm`, `trace_eventSET_ind`, `trace_eventSET_thm`, `trace_event_11`, `trace_event_Axiom`, `trace_event_MAP_CONG`, `trace_event_MAP_ID`, `trace_event_MAP_IMAGE`, `trace_event_MAP_O`, `trace_event_bnd`, `trace_event_case_cong`, `trace_event_case_eq`, `trace_event_distinct`, `trace_event_induction`, `trace_event_inh`, `trace_event_nchotomy`, `trace_event_size_MAP`, `trace_event_wit`, `trace_events_def`, `trace_events_ind`, `trace_ffi_interfer_def`, `trace_ffi_interfer_guard`, `trace_ffi_interfer_ind`, `trace_ffi_interfer_nil`, `trace_ffi_interfer_off`, `trace_ffi_interfer_shift`, `trace_ffi_interfer_step`, `trace_gen`, `trace_last_def`, `trace_last_ind`, `trace_next_interfer_def`, `trace_next_interfer_ffi`, `trace_next_interfer_ind`, `trace_next_interfer_ok`, `trace_next_interfer_proj`, `trace_next_interfer_shift`, `trace_ok_def`, `trace_ok_ind`, `trace_ok_upd`, `trace_st_def`, `trace_st_ind`, `trace_st_upd`.
- Review: HOLDS WITH LIMITS (review-TR): GENERIC (no arm8 or refund content); `trace_ok` demands agreement under the projection P only; Install, SharedMem, FFI_final are excluded by `trace_ok` conjuncts (obligations). That a real trace meets `trace_ok` (ML-11) is MISSING.
- Reproduction: not in the reproduction set (single same-machine run).

### TR2 (generic trace prefix lemmas) — case `TR2-0001`

- Theory `forge_machineTracePrefix`; stored theorems 4, definitions 0 (from the .sig).
- Actual exit **0** (`command.json`); markers ['EXACT_COMPLETE']; wall 215.649 s; go.log last line `go exit 0`; `inputs_unchanged_after` True.
- Command: `./nightshift-run.sh TR2-0001 1200 deps-TR2.txt` in `results/m1b-routeA-20261119/attempt-0001` (cpu from `command.json` `cpu_seconds_limit`; deps: unique content match; STATE.md).
- sha256 `forge_machineTracePrefixTheory.sig` = `3d2b7a7158871fa90448092555dd520a1c7a0009f652007651a399a0a0794bc9` (equal to command.json record)
- sha256 `forge_machineTracePrefixTheory.sml` = `a2975bc9680560f3330903208ce19bbf242d01e860396930984c80fa5b123a83` (equal to command.json record)
- sha256 `forge_machineTracePrefixTheory.dat` = `f4be385243b3ae4a1045522054ed17fc8253fcb931ce3b4fd549c8c6bd2a9575` (equal to command.json record)
- **Theorem row:** `forge_machineTracePrefix.trace_terminate` — exact statement and premise list: `FINAL_STATEMENTS.txt` anchor `[TR2-0001/trace_terminate]` (premises: 2).
- **Theorem row:** `forge_machineTracePrefix.trace_fail` — exact statement and premise list: `FINAL_STATEMENTS.txt` anchor `[TR2-0001/trace_fail]` (premises: 2).
- **Theorem row:** `forge_machineTracePrefix.trace_diverge` — exact statement and premise list: `FINAL_STATEMENTS.txt` anchor `[TR2-0001/trace_diverge]` (premises: 2).
- Other stored theorems (1), by name only (statements in FINAL_STATEMENTS.txt where printed; all in the .dat): `toy_bad_not_followed`.
- Review: HOLDS WITH LIMITS (review-TR): `trace_terminate` has the only premise `trace_ok`; a toy control shows the premise cannot be dropped. Generic.
- Reproduction: not in the reproduction set (single same-machine run).

### Link H1 (S6: exported contract on refund_fields) — case `contract-0001`

- Theory `forge_refundExportedContract`; stored theorems 9, definitions 7 (from the .sig).
- Actual exit **0** (`command.json`); markers ['EXPORTED_CONTRACT_COMPLETE']; wall 23.803 s; go.log last line `go exit 0`; `inputs_unchanged_after` True.
- Command: `bash go.sh H1` in `results/night-shift-20261119/orch-A/link/run/attempt-0001` (go.log `H1.go.log`; runner line `run_case.py contract-0001`).
- sha256 `forge_refundExportedContractTheory.sig` = `878cf3b845efb3c49a57b0d564a93bdd85b4b0cfb01286b4877039a5bded8721` (equal to command.json record)
- sha256 `forge_refundExportedContractTheory.sml` = `f5580a0b0d9af5a3129fd0f551374cc73001900c00cfae9f4a23854c90228c6d` (equal to command.json record)
- sha256 `forge_refundExportedContractTheory.dat` = `f54513268a6a641f568de47836a612d3cf5decd8530f0c32da6b7864a29d8174` (equal to command.json record)
- **Theorem row:** `forge_refundExportedContract.exported_contract_on_refund_fields` — exact statement and premise list: `FINAL_STATEMENTS.txt` anchor `[contract-0001/exported_contract_on_refund_fields]` (premises: 1).
- **Theorem row:** `forge_refundExportedContract.exported_contract_exact` — exact statement and premise list: `FINAL_STATEMENTS.txt` anchor `[contract-0001/exported_contract_exact]` (premises: none at top level).
- Other stored theorems (7), by name only (statements in FINAL_STATEMENTS.txt where printed; all in the .dat): `exported_contract_decode`, `exported_contract_shape`, `exported_contract_value`, `exported_contract_witnesses`, `exported_ens1_value`, `exported_ens2_value`, `exported_ens3_value`.
- Review: A17: MACHINE-CHECKED in HOL (run plus repeat H2); every control fails for the intended reason (stderr read by the reviewer). Defects A, B in `check.py` (verdicts honest only after the manual stderr check). Export digest not in the theorem. Charge/request symmetry not controlled on the input side. Not end to end to Dafny R1–R5.
- Reproduction: REPRODUCED-FROM-BRANCH (RESULT.json case `contract-0001`: .sig/.sml/.dat equal; W-final hashed the reproduced objects: equal).

### Link H2 (repeat of H1) — case `contract-repeat`

- Theory `forge_refundExportedContract`; stored theorems 9, definitions 7 (from the .sig).
- Actual exit **0** (`command.json`); markers ['EXPORTED_CONTRACT_COMPLETE']; wall 24.133 s; go.log last line `go exit 0`; `inputs_unchanged_after` True.
- Command: `bash go.sh H2` in `results/night-shift-20261119/orch-A/link/run/attempt-0001` (go.log `H2.go.log`; runner line `run_case.py contract-repeat`).
- sha256 `forge_refundExportedContractTheory.sig` = `878cf3b845efb3c49a57b0d564a93bdd85b4b0cfb01286b4877039a5bded8721` (equal to command.json record)
- sha256 `forge_refundExportedContractTheory.sml` = `f5580a0b0d9af5a3129fd0f551374cc73001900c00cfae9f4a23854c90228c6d` (equal to command.json record)
- sha256 `forge_refundExportedContractTheory.dat` = `f54513268a6a641f568de47836a612d3cf5decd8530f0c32da6b7864a29d8174` (equal to command.json record)
- Statements: identical (by script) to `contract-0001`; no separate theorem rows.
- Review: A17: .sig/.sml/.dat equal to H1 (W-final hashes: equal).
- Reproduction: not in the reproduction set (single same-machine run).

### Link H4 (contract on rendered output) — case `render-0002`

- Theory `forge_refundExportedRender`; stored theorems 1, definitions 0 (from the .sig).
- Actual exit **0** (`command.json`); markers ['EXPORTED_RENDER_COMPLETE']; wall 13.184 s; go.log last line `go exit 0`; `inputs_unchanged_after` True.
- Command: `bash go.sh H4` in `results/night-shift-20261119/orch-A/link/run/attempt-0001` (go.log `H4.go.log`; runner line `run_case.py render-0002`); first try render-0001: setup error, kept as H4.setup-error-1.go.log.
- sha256 `forge_refundExportedRenderTheory.sig` = `94a05b737d509d817d987c2526a771c1ef5b1014207101d9439a1237226bff00` (equal to command.json record)
- sha256 `forge_refundExportedRenderTheory.sml` = `504bd6e8623460dae163309dcc03fb62d08c0eedf7f15d42d7bc1fce33e12eed` (equal to command.json record)
- sha256 `forge_refundExportedRenderTheory.dat` = `75a94a812a6ab126385f1e269506ef1a89210c2a82234eb4908ab331ee909a35` (equal to command.json record)
- **Theorem row:** `forge_refundExportedRender.exported_contract_on_rendered_output` — exact statement and premise list: `FINAL_STATEMENTS.txt` anchor `[render-0002/exported_contract_on_rendered_output]` (premises: 3).
- Review: A17 names ctl-NR1-2 as a real proof failure at the render theorem; no separate verdict line for H4 in review-link: UNCONFIRMED.
- Reproduction: not in the reproduction set (single same-machine run).

### Link E0 (eligible guard link, optional) — case `eligible-link-0001`

- Theory `forge_refundEligibleLink`; stored theorems 5, definitions 4 (from the .sig).
- Actual exit **0** (`command.json`); markers []; wall 15.613 s; go.log last line `go exit 0`; `inputs_unchanged_after` True.
- Command: `bash go.sh E0` in `results/night-shift-20261119/orch-A/link/run/attempt-0001` (go.log `E0.go.log`; runner line `run_case.py eligible-link-0001`).
- sha256 `forge_refundEligibleLinkTheory.sig` = `034d057d864225034685456ebe88924f73deb150c7b20fbaf886450ceceb1825` (equal to command.json record)
- sha256 `forge_refundEligibleLinkTheory.sml` = `9dd1eabad95ba50e424b7c0dc8adcdf903a0eb4050b00aa3a2d1d5d71da7bef3` (equal to command.json record)
- sha256 `forge_refundEligibleLinkTheory.dat` = `5d5e96d68a989ec56c1dee96185ef7613c632695ad093063f1cf95fc7bfb19f0` (equal to command.json record)
- **Theorem row:** `forge_refundEligibleLink.eligible_link_guard_value` — exact statement and premise list: `FINAL_STATEMENTS.txt` anchor `[eligible-link-0001/eligible_link_guard_value]` (premises: none at top level).
- Other stored theorems (4), by name only (statements in FINAL_STATEMENTS.txt where printed; all in the .dat): `eligible_link_decode`, `eligible_link_matches_compiled_guard`, `eligible_link_operators`, `eligible_link_shape`.
- Review: No separate verdict line in review-link: UNCONFIRMED. Marker `ELIGIBLE_LINK_COMPLETE` is in stdout, not in `markers`.
- Reproduction: not in the reproduction set (single same-machine run).

### Link R1 (S5: U294 source binding replay) — case `u294-hol`

- Theory `forge_refundSourceBinding`; stored theorems 5, definitions 5 (from the .sig).
- Actual exit **0** (`command.json`); markers ['SOURCE_BINDING_COMPLETE']; wall 166.446 s; go.log last line `go exit 0`; `inputs_unchanged_after` True.
- Command: `bash go.sh R1` in `results/night-shift-20261119/orch-A/link/run/attempt-0001` (go.log `R1.go.log`; runner line `run_case.py u294-hol`).
- sha256 `forge_refundSourceBindingTheory.sig` = `eccb0dd42fae6c33c76ff1040c03e2f7b33e695892ec73ba4c212148c2dbc1a8` (equal to command.json record)
- sha256 `forge_refundSourceBindingTheory.sml` = `b6f406a647f55fcf5a08d927628452f4d1a395dc82d2782816b8b53454f629e9` (equal to command.json record)
- sha256 `forge_refundSourceBindingTheory.dat` = `6f30ff5d62bf416b9c837eb2184bdd3ee1b1cac30e34e5fc9f8b72b667d812f3` (equal to command.json record)
- **Theorem row:** `forge_refundSourceBinding.source_full_result` — exact statement and premise list: `FINAL_STATEMENTS.txt` anchor `[u294-hol/source_full_result]` (premises: none at top level).
- **Theorem row:** `forge_refundSourceBinding.source_postconditions` — exact statement and premise list: `FINAL_STATEMENTS.txt` anchor `[u294-hol/source_postconditions]` (premises: none at top level).
- Other stored theorems (3), by name only (statements in FINAL_STATEMENTS.txt where printed; all in the .dat): `mapped_operators`, `source_decode`, `source_signature`.
- Review: A17: S5 MACHINE-CHECKED (same machine); R1 stdout byte-equal to the recorded hol-0004.
- Reproduction: not in the reproduction set (single same-machine run).

### Link R2 (U294 source relation replay) — case `u294-rel-2`

- Theory `forge_refundSourceRelation`; stored theorems 1, definitions 0 (from the .sig).
- Actual exit **0** (`command.json`); markers ['SOURCE_RELATION_COMPLETE']; wall 2.601 s; go.log last line `go exit 0`; `inputs_unchanged_after` True.
- Command: `bash go.sh R2` in `results/night-shift-20261119/orch-A/link/run/attempt-0001` (go.log `R2.go.log`; runner line `run_case.py u294-rel-2`); first try u294-rel: setup error, R2.setup-error-1.go.log.
- sha256 `forge_refundSourceRelationTheory.sig` = `98a27beb595105a5b8def75c52ee16b08007bd45b73c5e49f8064dfb2de2b735` (equal to command.json record)
- sha256 `forge_refundSourceRelationTheory.sml` = `798117388eb984b3ab4d0d66f56abb63522060662782d496ad21c3422e1d719c` (equal to command.json record)
- sha256 `forge_refundSourceRelationTheory.dat` = `19cd87a38e5fdca3bc6055225a3d878524337fc4f3ece864a0d5814d9f2f54dd` (equal to command.json record)
- **Theorem row:** `forge_refundSourceRelation.source_model_result` — exact statement and premise list: `FINAL_STATEMENTS.txt` anchor `[u294-rel-2/source_model_result]` (premises: none at top level).
- Review: A17: holds; differs from the record only in a timing line.
- Reproduction: not in the reproduction set (single same-machine run).

### Link R3 (U294 compiled-fields bridge replay) — case `u294-bridge-2`

- Theory `forge_refundCompiledInputBinding`; stored theorems 1, definitions 0 (from the .sig).
- Actual exit **0** (`command.json`); markers ['SOURCE_BRIDGE_COMPLETE']; wall 7.381 s; go.log last line `go exit 0`; `inputs_unchanged_after` True.
- Command: `bash go.sh R3` in `results/night-shift-20261119/orch-A/link/run/attempt-0001` (go.log `R3.go.log`; runner line `run_case.py u294-bridge-2`); first try u294-bridge: setup error, R3.setup-error-1.go.log.
- sha256 `forge_refundCompiledInputBindingTheory.sig` = `c68a2c027826a7b3b6be2290fa31e68938858613ef9ccefba2357c1e1b4c7ac1` (equal to command.json record)
- sha256 `forge_refundCompiledInputBindingTheory.sml` = `71b0b16e0c2607626c014924a93f99fa2aad0dedc482793c8270e44d628fd571` (equal to command.json record)
- sha256 `forge_refundCompiledInputBindingTheory.dat` = `937d10bbb0aa62379be980788114847c7efd90c13b2baa1e9fa90271c0472519` (equal to command.json record)
- **Theorem row:** `forge_refundCompiledInputBinding.source_compiled_fields` — exact statement and premise list: `FINAL_STATEMENTS.txt` anchor `[u294-bridge-2/source_compiled_fields]` (premises: 1).
- Review: A17: holds; differs from the record only in a timing line.
- Reproduction: not in the reproduction set (single same-machine run).


## 3. Failed and superseded attempts kept (nothing deleted)

Route A folder, every case with a non-zero or negative actual exit (exits copied by script from `command.json`; the
`go.log` of a signal stop shows `go exit 1` because `run_case.py` maps a signal to 1):

| Case | Actual exit (`command.json`) | go.log last line | Reason (source: ATTEMPT_COUNTS.md, STATE.md, MORNING.md, reviews) |
|---|---|---|---|
| `E1-0001` | 1 | `go exit 1` | no theory loaded (setup); STATE.md |
| `E1-0002` | 1 | `go exit 1` | ML static error (`wordsTheory` line 31); E1-0003 differs only there (review A10) |
| `E1neg-0001` | 1 | `go exit 1` | MUTANT control (premise `untagged t` deleted): `LEMMA_FAILED BranchTo_erase_untagged`, no export: REQUIRED failure |
| `ES-0001` | 1 | `go exit 1` | ML error; many frame/erase lemmas open (STATE.md); step lift open |
| `ES-0002` | 1 | `go exit 1` | ML error; step lift open (FIELDS_FOR_B 09:38Z) |
| `L2-0001` | 1 | `go exit 1` | PROOF failure: tactic gap at the ExtCall leaves (`refund_ffi_tot_evaluate_agree` try 1) |
| `L2-0002` | 1 | `go exit 1` | ML static/type error; no proof tried |
| `L2b-0001` | 1 | `go exit 1` | PROOF failure of `ffi_calls_ok_of_returning_calls` (try 1); used a LOCAL copy of `ffi_calls_ok` (review A12) |
| `L2b-0002` | 1 | `go exit 1` | every lemma proved; a control comparison in the script was wrong; no export |
| `LE-0002` | 1 | `go exit 1` | ML parse error |
| `LO-0001` | -24 | `go exit 1` | CPU limit (signal; actual exit -24): a non-terminating tactic for `STD_streams_File_fd` |
| `LO-0002` | 1 | `go exit 1` | ML static error; no proof tried |
| `LO-0003` | 1 | `go exit 1` | PROOF failure: first failure `read_stdout`; 24 lemmas CHECKED |
| `LO-0004` | 1 | `go exit 1` | PROOF failure: `refund_profile_a_sl_fd1`, `extract_no_ext_stdout` open; 27 lemmas CHECKED |
| `LO-0005` | 1 | `go exit 1` | PROOF failure `extract_no_ext_stdout_step` (HOL_ERR in FIRST_ASSUM), then ML parse error at proof.sml:492; A's own stop was then bent (owner item A-2) |
| `PF-0001` | 1 | `go exit 1` | PROOF failure `lexPs_cons` (try 1) |
| `PF-0002` | 1 | `go exit 1` | PROOF failure `lexPs_cons` (try 2) |
| `PF-0003` | 1 | `go exit 1` | PROOF failure `lexPs_cons` (try 3) |
| `NN-0001` | 1 | `go exit 1` | ML static error: header comment closed early at "[0-9]*)"; no proof step ran; superseded by NN-0002 (comment text only) |
| `TRx-0001` | 1 | `go exit 1` | EXPLORATION; ML static error (`Thread` structure names); no step ran |
| `TRx-0002` | 1 | `go exit 1` | EXPLORATION; `toy_target_def` "Nullary definition failed"; 0 lemma steps ran |
| `NVx-0002` | 1 | `go exit 1` | EXPLORATION; statement construction ACC_FFI failed (find_term); no lemma step ran |
| `R6rx-0001` | -15 | `go exit 1` | EXPLORATION; one step hung (time limit did not interrupt); A sent SIGTERM after 39 min (actual exit -15) |
| `R6tx-0001` | -15 | `go exit 1` | EXPLORATION; hung at `parts_ok_basis_ffi` step 2; A sent SIGTERM (actual exit -15) |

Link folder (`results/night-shift-20261119/orch-A/link/run/attempt-0001`), failed or control cases:

| Case | Actual exit | Note |
|---|---|---|
| `render-0001` | 1 | H4 first try: setup error (H4.setup-error-1.go.log) |
| `u294-rel` | 1 | R2 first try: setup error |
| `u294-bridge` | 1 | R3 first try: setup error |
| `u294-import` | 1 | I1 first try: setup error |
| `ctl-NR1` | 1 | NR1 first try: "No such file or directory" (path error); check.py still printed PASS (defect A) |
| `ctl-NC1` | 1 | control, REQUIRED failure: exported_ens1_value |
| `ctl-NC2` | 1 | control: exported_ens2_value |
| `ctl-NC3` | 1 | control: exported_ens3_value |
| `ctl-NC4` | 1 | control: "Expected exactly three ensures clauses" |
| `ctl-NC5` | 1 | control: exported_ens1_value |
| `ctl-NC6` | 1 | control: "Trailing export bytes" |
| `ctl-NS1` | 1 | control: exported_contract_on_refund_fields |
| `ctl-NS2` | 1 | control: exported_contract_on_refund_fields |
| `ctl-NS3` | 1 | control: exported_contract_on_refund_fields |
| `ctl-NR1-2` | 1 | control (NR1 second run): exported_contract_on_rendered_output |
| `ctl-NB1` | 1 | control (input binding ids swapped): exported_ens2_value; check.py has no rule for NB1 ("unknown case id") |
| `ctl-PC1` | 0 | POSITIVE control, expected exit 0: 9 FORGE_STATEMENT records equal to contract-0001 |

Per-lemma attempt counts and the bent stop of L-OUT: `results/m1b-routeA-20261119/attempt-0001/ATTEMPT_COUNTS.md`
(`lexPs_cons` 3 failed tries then PF-0004; `refund_ffi_tot_evaluate_agree` 1 failed try then L2-0003; L-OUT: LO-0001 to
LO-0005 failed, exploration LOx-0001, then LO-0006; owner item A-2).

Superseded runs with exit 0 (kept, not separate results): E1r-0001 and L2r-0001 (confirmation re-runs; objects
byte-equal to E1-0003 and L2-0003); MF-0001 (superseded by MF-0002); LE-0003 (generic; superseded for the refund
instance by LE-0004); link H2 (repeat of H1, objects equal).

Explorations (store nothing; prove nothing; never a theorem): actual exit 0 with `EXPLORE_COMPLETE`: LOx-0001,
EFx-0001, EEx-0001, EEx-0002, L2dx-0001, R6x-0001 to R6x-0005, R6wx-0001 to R6wx-0004, R6rx-0004, R6tx-0003,
R6tx-0004, TRx-0003, TRx-0004, NVx-0003. Explorations with exit 1 or −15: see the table (TRx-0001, TRx-0002, NVx-0002,
R6rx-0001, R6tx-0001). Explorations record that steps closed; their lemmas count only where a later proof run stored them.

NOT RUN (source staged in the run folder, no `command.json`): LE-0001 (draft v3; superseded by LE-0002 to LE-0004);
R6ffi-0001 (superseded by R6ffi-0002, which keeps the R6ffi-0001 header text); R6w-0001, R6w-0002, R6w-0003 (superseded
by R6w-0004); R6r-0001, R6r-0002, R6r-0003, R6rx-0002, R6rx-0003 (superseded by R6rx-0004 / R6r-0004); R6t-0001,
R6t-0002, R6t-0003, R6tx-0002 (superseded by R6tx-0004 / R6t-0004); TR-0001, TR-0002, TR-0003 (replaced by TR1-0001
and TR2-0001); NV-0001, NV-0002, NVx-0001 (superseded by NVx-0003 / NV-0003). The watchdog copies (R6rx-0003,
R6r-0003, R6tx-0002, R6t-0002, NVx-0001, NV-0001, TR-0001) carry the `Thread` structure error and were replaced by
ML-only copies (ATTEMPT_COUNTS.md 15:53Z).

NOT RUN, outside the run folder: `orch-A/x8glue/` (worker W-x8glue): an INCOMPLETE static draft of the X8 model-side
glue (`STATEMENTS.txt`, `xg_common.sml`, `xg_steps.sml`, `deps-XG.txt`, `deps-XG2.txt`, `CHANGES.txt`). Drivers
XGx-0001/XG-0001 NOT written; no syntax check; nothing run; every lemma UNPROVED. Also NOT RUN: the conditional space
theorem P9a draft (`resource-native/`), the T6 perturbation differential, AC3-j, AC3-k, C's native launch-path attack
(C-1), a clean replay and an independent-machine replay.

Replay debt (`orch-A/replay-debt/REPORT.md`, `STATE.md`): of the 158 recorded cases, 152 AS_RECORDED on the first run;
005, 130, 142 stopped first with Poly/ML "Run out of store" (infrastructure, inconclusive) and were AS_RECORDED on a
second run; 094, 097, 098 UNAVAILABLE (no source with the recorded SHA-256 in 13,542 git blobs and 22,854 files).

## 4. Assurance graph status for links X1–X16, S4–S7, V4–V5 (PROPOSED table; the graph file is not edited)

"Old class" = `proposals/m1b-mission-20261119/TOP_LEVEL_GRAPH.md` section 2, with sections 7 and 8 where they changed the
row. "Row class" = the class of the link as written, which is the class of its weakest part. A machine-checked SUB-PART is
named in its own column; it does not raise the row. Every MC entry below: model level, same machine, stored parents.

| Link | Old class | Machine-checked part after tonight (evidence) | Row class proposed | Still missing or assumed |
|---|---|---|---|---|
| X1 | MC | none new (earlier M1R-1 replay; not re-run tonight) | MC (unchanged) | clean and independent replay |
| X2 | MC | none new | MC (unchanged) | the same |
| X3 | MC (model, 11 premises) | restated forms: `refund_profile_a_sl_reach` (L2-0003), `_events` (L2c-0001), `_shape` (L2d-0001), MT1 (MT-0001) | MC (unchanged; model) | a resource bound; premises not met by the real C (X6) |
| X4 | MC for one state, ideal env | NV-0003: joint witness of the shape antecedent for every request, abstract environment | MC (unchanged scope: abstract env) | witness for MT1, MG-0001; a run that ends in Success with a strict frame; a real loader state |
| X5 | ASSUMPTION (wording must change, §7) | none for the entry state | ASSUMPTION | T10: ML-10 T-ENTRY27 MISSING; N16 ASSUMPTION |
| X6 | ASSUMPTION, probably false | L1-0001 (totalisation), L2d-0001 review: no `envmc` that describes the present C meets the shape contract | ASSUMPTION, FALSE as an all-states contract for the present C | owner item A-3 (C patch or R6) |
| X7 | MISSING | L1-0001, L2-0003, L2b-0003, L2c-0001, L2d-0001, MG-0001, MT-0001; R6 pieces R6base-0001, R6ffi-0002, R6w-0004, R6r-0004, R6t-0004 | MISSING | R6 (main V-spec, state facts, link to machine `io_events`, "no close/open_in"); native contract at valid calls (ASSUMPTION) |
| X8 | MISSING | generic trace core only: TR1-0001 (`evaluate_follows_trace`, `trace_io`), TR2-0001 (`trace_terminate`, `trace_fail`, `trace_diverge`); MT-0001 is the model target | MISSING | statement draft v3 by reading (`x8-x11/X8_statement_v3.txt`, with CORRECTIONS_v2 leads); ML-01..ML-15 none stored; no refund instance of `trace_ok`; x8glue draft NOT RUN; 23 native rows (17 ASSUMPTION, 6 enforced by prototype) |
| X9 | MISSING | LO-0006: `refund_L_OUT`, `refund_L_OUT_prefix`, `refund_profile_a_sl_fd1` — model I/O events at `no_ext` to `fd1_written`, under the stored premises incl. `refund_env_ok_sl` (false for the real C) | MISSING as a row (model part MC; owner A-2 pending) | real descriptor-1 bytes = model `fd1_written`: inside X8 (N12, N13, N22 ASSUMPTION) |
| X10 | MISSING | LE-0004: `refund_profile_a_sl_halt`, `evaluate_Halt_reg` (model halt to register value); same premises | MISSING as a row | halt-value range; real exit path (32-bit test, 8-bit status); exit status carries no proof meaning |
| X11 | ASSUMPTION (Q1) | X11e sub-results: E1-0003 (single functions), EF-0001 (`NextStateARM8_frame`), EE-0001 (`NextStateARM8_erase`, one step) | ASSUMPTION; X11e MISSING | run lift ML-08, ML-09; ML-05 L-GHOST; non-vacuity with TBI0/SA0 set; N02–N04 ASSUMPTION |
| X12 | TESTED-UNPROVED | none | TESTED-UNPROVED | X8 |
| X13 | TESTED-UNPROVED | PF-0004 (`refund_strict_parse_no_strict_prefix`, `_complete`), PX-0001 (`_exact`, `refund_frame_decision`), NN-0002 (non-negativity, T14b) — about the HOL function `refund_strict_parse` | TESTED-UNPROVED as a row | Python `frame.strict_parse` = HOL parser: TESTED-UNPROVED (T14a; residual R1–R3 of review-NN) |
| X14 | MC | none new | MC (unchanged) | — |
| X15 | MISSING | none (no proof) | MISSING (deployed path) | `launch/launcher_v2.py` prototype: TESTED-UNPROVED, NOT deployed, unverified Python; owner item A-5 |
| X16 | MISSING | none | MISSING | issuer calls the compiled Dafny checker, not M1 (B's track; B-6) |
| S4 | TESTED-UNPROVED (§7; was ASSUMPTION) | none new in HOL | TESTED-UNPROVED (export file); exporter fidelity ASSUMPTION (T4; build absent) | rebuild and byte-equal re-export |
| S5 | MC on 2026-11-04 only | link R1, R2, R3 replayed tonight (go exit 0; second tries for R2, R3, I1 after a path fix) | MC (replayed 2026-11-19, same machine) | clean and independent replay |
| S6 | MISSING | link H1, H2 (`exported_contract_on_refund_fields`, `exported_contract_exact`), H4, E0; controls NC1–NC6, NS1–NS3, NR1, NB1 exit 1 as required; PC1 exit 0; H1 reproduced from the branch | MC (model; same machine; run plus repeat) | check.py defects A, B; export digest not in the theorem; input-side symmetry control; T4i input encoding MISSING; output decoding MISSING |
| S7 | ASSUMPTION (narrowed, §7) | none | ASSUMPTION (BETA) | no artefact relates Dafny and HOL semantics |
| V4 | MISSING | none: `hash_parents.py` records parent `.dat` after the run; `inputs_unchanged_after` covers `.sig/.sml` only | MISSING | pinned definition closure |
| V5 | MISSING | the reproduction (section 2.1) is same machine, same agent family | MISSING | independent replay |

## 5. Unproven transitions to `end_to_end=true`

Source: `orch-A/END_TO_END_GAPS_v2.md` (sha256 read by W-final in section 8) with its two appended updates. Classes as
there (MC, AS = ASSUMPTION, TU, EP = enforced by an unverified prototype launcher, MI = MISSING). Updated rows are marked.

1. T2b — reader of the export bytes is right: AS (A-READER; Python reader TESTED-UNPROVED).
2. T3 — Dafny meaning of the 3 clauses = HOL `evaluate_exps` meaning: AS (BETA).
3. T4 — exporter fidelity (Dafny source to export bytes): AS (build folder absent).
4. T4i — input encoding (stdin bytes = `refund_request` of the intended nine values): MI.
5. T7 — compiler correctness to the exact code slices: MC in the earlier chain; its go.logs not seen tonight: UNCONFIRMED tonight.
6. T8 — model run to strict parse to exported clauses: MC under premises T9–T13 only (MF-0002, MG-0001, L2d-0001, MT-0001, LO-0006, LE-0004, PX-0001, PF-0004).
7. T8v — premises jointly satisfiable: MC for the shape antecedent only (NV-0003); none for MT1; no Success-with-frame witness.
8. T9 — FFI premise: MI (R6 open; native contract AS; owner A-3).
9. T10 — entry state at `cml_main`: MI (N16 AS; ML-10 MI).
10. T11 — processor bits TBI0, TBI1, SA0, EL0, E0E: MI (one-step erasure MC; run lift MI; N02–N04 AS).
11. T12 — descriptors fd 0, fd 1: MI (N09, N11, N20, N21 EP; ML-04 MI). Red-team lead: N11, N20 "ENFORCED" too strong (FINDINGS_FROM_C, 17:12Z).
12. T12k — kernel read/write results = model oracle: AS (no launcher can enforce it).
13. T13 — X8, the real process refines the totalised model: **MI — the smallest missing refinement boundary** (15 ML lemmas, none stored; 23 native rows; update: N05, N07, N08, N10, N23 are ASSUMPTIONS, no launcher can enforce them).
14. T14o — consumer reads the process's descriptor-1 bytes: AS (N22 read-to-EOF EP; no exit flush to fd 1 AS).
15. T14a — `frame.strict_parse` = `refund_strict_parse` (restricted): TU.
16. T14b — program prints non-negative amount and count only: UPDATED to MC at model level (NN-0002); about the HOL parser only.
17. T15 — launch environment (no injected loader code; fixed env; pinned image): AS (parts EP; launcher interpreter OPEN; owner A-5).
18. T16 — native result to issuer decision (X16): MI in the deployed path (B's claim).
19. T17 — issuer to token to sink to committed state: MI for deployed code (B's claim).
20. T18 — trust base; clean and independent replay: MI.

Smallest missing refinement boundary (one line): **X8 / T13 — "a real run of image b8ed5ec2…7bb8 that meets the native
rows is a run of the totalised machine model from `ms_27`"; its model part (ML-01..ML-15) has no stored lemma and its
native part cannot be closed by HOL.**

## 6. Launch-path attack classes (all TESTED-UNPROVED; prototype `launcher_v2.py`, not deployed)

| Class | State | Who ran which test | Open rows |
|---|---|---|---|
| AC-1 truncated or empty stdout with exit 0; closed or non-blocking descriptors | CLOSED-BY-ENFORCED-CONTROL (tested) for AC1-a..f, NEW-1 in-process | author: `old/test_ac1.py`, `test_v2_findings.py`, `test_mutants_v2.py` (exit 0); A re-ran (`recheck-A`, `recheck-A2`: logs end "0 not as expected"); C ran its 24 lifecycle conformance tests: v1 exit 1 (2 FAIL, SIGCHLD ignored, C-LAUNCH-01), v2 exit 0 twice, with a bash test child, not the refund program | AC1-a launcher's own EAGAIN path not exercised; NEW-1 caller-exec route NO-FAILING-SIDE; red-team lead: after a time-out v2 does not drain stdout; a late signal can give exit 4 or 1 AFTER an AUTHORIZED line, so **a consumer must accept only "AUTHORIZED line AND launcher exit 0"** |
| AC-2 code injected at load; launcher integrity (CE-3) | CLOSED-BY-ENFORCED-CONTROL for AC2-a, b, h–l, o; AC2-m by construction | author: `old/test_ac2.py`, `test_mutants_v2.py` (exit 0); A re-ran; C's real-program injection attack NOT RUN (C-1) | AC2-n2, AC2-n3 (forged decision line ACCEPTED via `DEVELOPER_DIR`), AC2-n4/n5 (consumer duty: `env -i … python3 -B -I`), NEW-12, T-2, T-3, T-4; AC2-g owner option (hardened runtime) |
| AC-3 hostile launch state; FFI misreport | CLOSED-BY-ENFORCED-CONTROL for AC3-a, AC3-d, NEW-8; AC3-i CLOSED; AC3-b, c, e EXCLUDED-BY-CONSTRUCTION; AC3-g NO-FAILING-SIDE | author: `old/test_ac3.py`, `test_v2_findings.py`, `test_mutants_v2.py` (exit 0); A re-ran | AC3-j (C misreport at unreached states; R6 / A-3; NOT RUN), AC3-k (same-uid kill; NOT RUN), NEW-11 (SIGKILL cleanup), DATA rlimit, umask |

Sources: `END_TO_END_GAPS_v2.md` §3, `launch/CONTROL_MATRIX_v2.md`, `launch/review_launcher.txt` (F-01..F-16),
`launch/FINDINGS_FROM_C.md` (incl. the static leads of 17:12Z, not checked by C or A).

## 7. Owner decisions waiting (`results/night-shift-20261119/OWNER_REQUIRED.md`)

- **A-1** swap rule: ten HOL cases started below 1 GB swap free; E1-0003 and L2-0003 were run again inside the rule
  (E1r-0001, L2r-0001; objects byte-equal). Keep or restate the rule. Affects rows E1-0003, L2-0003.
- **A-2** L-OUT: A's own written stop was bent (LO-0006 after LO-0005 and LOx-0001; the ROADMAP per-lemma rule held).
  Accept LO-0006 and LE-0004, or require a fresh single run. Affects X9, X10, T8, ML-14. (LO-0006 and LE-0004 were since
  reproduced from the branch, same machine; that does not answer A-2.)
- **A-3** FFI premise: prove R6 for the present executable (multi-day) or adopt the model-total C FFI patch
  (`ffi-hardening/basis_ffi_model_total.patch`, sha256 ea344ad0…f357; new image digest; records redone). Affects X6, X7,
  T9, AC3-j.
- **A-4** push permission: RESOLVED by the owner for commit 6903135a.
- **A-5** launch path: (1) adopt a launcher as the only launch path with the invocation rule
  `/usr/bin/env -i /usr/bin/python3 -B -I <path>/launcher.py`; (2) hardened runtime (re-sign; new pin); (3) C patch for
  AC3-j. Affects X15, T12, T14o, T15.
- **C-1** (red team): who runs the native launch-path attacks with the real program (injected code, FFI C). Until
  decided, every AC row has no independent attack run with the real program; only C's lifecycle conformance run exists.

## 8. Known weaknesses of this record

- Same machine for every HOL result; parents are stored older theories; no clean replay; no independent-machine replay.
  The reproduction (section 2.1) shows object identity on the same machine only (V5 stays MISSING).
- `inputs_unchanged_after` covers parent `.sig/.sml`, not parent `.dat`; `hash_parents.py` hashes `.dat` after the run.
- Reviewers, workers and orchestrators are the same model family; "independent" means separate workers only.
- The consolidated counts in `END_TO_END_GAPS_v2.md` (§2 row counts; ML and N counts) predate its two updates; section
  5 here applies the updates by row, not by recount.
- Statements of 9 stored theorems are ELIDED in `stdout.log` (R6ffi-0002: 2, R6w-0004: 4, R6r-0004: 2, R6t-0004: 1);
  their exact text is only in the `.dat`; W-final did not decode `.dat` files. Helper theorems of EE-0001, EF-0001 and
  datatype theorems of TR1-0001 have no printed statement.
- Premise lists in `FINAL_STATEMENTS.txt` come from a text split of the printed statement; the statement is binding.
- deps file NAME UNCONFIRMED (content confirmed by exact match of the parent list in `command.json`) for L1imp-0001,
  L2r-0001, E1r-0001, LE-0003, LO-0006 (identical-content deps files exist).
- Link H4 (render-0002) and E0 (eligible-link-0001) have no separate verdict line in `review-link/REPORT.md`: UNCONFIRMED.
- T7 (earlier compiler-correctness chain): its go.logs were not seen tonight: UNCONFIRMED tonight.
- Record defects found: the `.sml` headers of R6ffi-0002, R6w-0004, R6r-0004 name the earlier case; `check.py` has
  defects A, B and no rule for NB1; R6ffi-0002 ran before the wrapper hashed `use`d files.
- DISCLOSURE: the owner's wind-down said "start no new HOL case after the current one". The reproduction driver started
  its last queued case R6w-0004 at 17:11:10Z, after the order reached A (about 17:08Z) and 15 s before the worker stopped
  the driver (17:11:25Z). A let it finish (17:19:38Z, go exit 0). No HOL case started after it. `hol.lock` release at
  17:19:54Z is A's report; at about 17:22Z W-final saw only `dafny.queue` and `released` in `results/night-shift-20261119/locks/` (not touched).
- Digests of the sources W-final read: `orch-A/END_TO_END_GAPS_v2.md` 8f8ed1752353d3ce…; `orch-A/END_TO_END_GAPS.md` 56593f0803dc1ce1…; `orch-A/repro/RESULT.json` fe2513822639b931…; `orch-A/repro/run/repro-driver.log` a306a6a7f9cc2e6d…; `orch-A/STATE.md` 08f2aa7757971855…; `orch-A/launch/CONTROL_MATRIX_v2.md` 46a98a26285e2aac…; `orch-A/launch/FINDINGS_FROM_C.md` da092ca05df8eb45…; `orch-A/x8-x11/X8_statement_v3.txt` 9d1f9d5055d93709…; `orch-A/x8-x11/CORRECTIONS_v2.md` d4dea276ad4efedd…; `orch-A/replay-debt/REPORT.md` be8e25819c77dab0…; `OWNER_REQUIRED.md` 485ed7d5bb721e0d…; `TOP_LEVEL_GRAPH.md` d084bebf53caebf1…; `ATTEMPT_COUNTS.md` 84bf22dabb851fd0….
