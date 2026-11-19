# Run plan: Route A L2b (`ffi_calls_ok_of_returning_calls` and the close instance). Worker A8. NOTHING HERE HAS RUN.

Every command below is PLANNED. No exit code in this file is an actual exit code. Pattern: `ffi-erasure/RUN_PLAN_ffi_erasure.md`.
Run one HOL process at a time, in the single HOL slot, only when no other HOL job runs.

F = `<HOME>/forge/results/night-shift-20261119/orch-A/ffi-calls-ok` (this folder; sources)
A = `<HOME>/forge/results/m1b-routeA-20261119/attempt-0001` (Route A attempt folder; `run_case.py`, `go-routeA.sh`, deps)

## 0. State of the parent (ACTUAL, read from records)

- `A/L2-0001`: `actual_exit 1`, wall 92.1 s, CPU 104.9 s, RSS 3558 MiB (`A/L2-0001.go.log`). `LEMMA_FAILED` for
  `refund_ffi_tot_evaluate_agree`, `refund_ffi_tot_machine_sem_agree`, `refund_profile_a_sl_reach`
  (`A/L2-0001/stdout.log` 211-249). `DEFINITION` of `ffi_calls_ok` printed (line 9); `CHECKED` only for
  `read_ffi_bytearray_ffi_interfer_update`, `read_ffi_bytearrays_ffi_interfer_update`,
  `ffi_calls_ok_false_at_a_returning_call`. No export: theory `forge_refundRouteA2` does NOT exist.
- Therefore `routeA-L2b.sml` has two modes, printed as `D3_SOURCE`:
  - `local`: defines `ffi_calls_ok` with the verbatim text of `A/L2-0001.sml` lines 74-113 (diff checked by A8: identical).
  - `imported`: uses `forge_refundRouteA2.ffi_calls_ok_def` when that theory is loaded (only after an L2 retry exports it).

## 1. Order

| # | Case | Source | Deps | CPU estimate (guess) | CPU limit | Precondition |
|---|---|---|---|---|---|---|
| 1 | `L2b-0001` | `F/routeA-L2b.sml` | `deps-L2b.txt` = `deps-L2.txt` (127 lines; L1 theory lines included; no L2 lines) | 150-450 s (load ~90 s as L2-0001; three inductions over the 41-line definition; EVAL of two concrete arm8 calls) | 1200 | `L1-0001` exit 0 (true: records) |
| 1' | `L2b-000N` (later) | same file | `deps-L2.txt` + `A/L2-000M/forge_refundRouteA2Theory.sig` + `.sml` | as 1 | 1200 | an L2 retry `L2-000M` with exit 0 and export |
| 2 (optional) | `L2bnegA-0001` | mutant A (section 5) | as 1 | as 1 | 1200 | 1 exit 0 |
| 3 (optional) | `L2bnegB-0001` | mutant B (section 5) | as 1 | as 1 | 1200 | 1 exit 0 |

Case 1 proves the lemma about the local constant `forge_refundRouteA2b$ffi_calls_ok`. That is NOT the constant of a future
`forge_refundRouteA2`; case 1' is needed before composition with L2/L2R.

## 2. Before each run (memory first)

```zsh
memory_pressure | tail -1            # need >= 25 % free (run_case.py refuses below 25 %)
sysctl vm.swapusage
df -h /System/Volumes/Data           # need >= 3 GiB free
pgrep -fl 'cake_compile_heap|arm8-heap|cakeml-heap|poly' || echo "no HOL process"
```
If any HOL process runs: stop. `run_case.py` refuses with exit 3 (`resource_guard_refused`); that is not an attempt.

## 3. Setup and case 1

```zsh
F=<HOME>/forge/results/night-shift-20261119/orch-A/ffi-calls-ok
A=<HOME>/forge/results/m1b-routeA-20261119/attempt-0001
cd $A
cp $F/routeA-L2b.sml L2b-0001.sml
cp $F/deps-L2b.txt deps-L2b.txt
shasum -a 256 $F/routeA-L2b.sml L2b-0001.sml $F/deps-L2b.txt deps-L2b.txt deps-L2.txt   # see the digests in the final report
FORGE_CPU_SECONDS=1200 ./go-routeA.sh L2b-0001 L2b-0001.sml deps-L2b.txt ; echo "go exit $?"
grep -n "^D3_SOURCE\|^DEFINITION\|^CHECKED\|^TACTIC_\|^OPTIONAL_\|^CONTROL\|^UNEXPECTED\|^STATEMENT_\|^STATEMENTS_BAD\|^PREMISE\|^CLOSURE\|COMPLETE\|^LEMMA_FAILED\|^SHOW\|^  GOAL\|^STORED" L2b-0001/stdout.log | cut -c1-260
```

Pass criteria (ALL must hold; else the run is a finding):
- `command.json` `actual_exit` 0; marker `EXACT_COMPLETE`; `inputs_unchanged_after` true;
- no `LEMMA_FAILED`; no `UNEXPECTED_CONTROL_ACCEPTANCE`;
- `D3_SOURCE local ...` (case 1) or `D3_SOURCE imported ...` (case 1'); one `DEFINITION` line, text equal to line 9ff of
  `A/L2-0001/stdout.log`;
- `CHECKED` for the 19 required theorems: `rfb2_next_interfer_update`, `rfb2_install_interfer_update`,
  `rfb2_ffi_interfer_update`, `call_FFI_return_keeps_oracle`, `ffi_calls_ok_of_returning_calls`, `ffi_close_return_lengths`,
  `basis_close_return_lengths`, `close_returning_calls_have_valid_lengths`, `three_names_are_ExtCall`,
  `refund_names_are_ExtCall`, `refund_mc_close_fields`, `refund_ffi_calls_ok_close`, `refund_ffi_calls_ok_close_totalised`,
  `refund_close_premises_hold`, `basis_close_call_returns_at_a_concrete_state`,
  `close_predicate_fails_for_a_returning_zero_length_call`, `returning_call_premise_is_needed`,
  `close_instance_needs_the_basis_oracle`, `close_predicate_rejects_zero_alen`;
- one `TACTIC_USED <name> <n>` for each `thmA` theorem; record n. A `TACTIC_ATTEMPT_FAILED` before it is a finding about
  that tactic, not about the statement;
- five `CONTROL_OK` lines: G literal; G without the basis oracle; close instance literal and without `word_msb`;
  refund close instance has one premise; NV-B, N2, N1, N2' are negations;
- `PREMISE_FOUND refund_env_ok_sl sl envmc`; eight `STATEMENT_TYPECHECKS` lines (`R1_rw_returning_calls_oracle_only`,
  `R2_open_in_returning_calls_oracle_only`, `R3_signed_alen_from_domain_size`, `R4_valid_event_gives_Vok`,
  `R5_events_give_ffi_calls_ok`, `R6_refund_run_events_are_valid`, `R7_L3_target_for_VokY3`, `as_proposed_with_free_P`);
  `STATEMENTS_BAD 0`. These lines say only that a term parses with type bool. A non-zero `STATEMENTS_BAD` is a finding;
  it does not block the export;
- exactly four `CLOSURE_AXIOM` lines (`bool.SELECT_AX`, `bool.INFINITY_AX`, `bool.ETA_AX`, `bool.BOOL_CASES_AX`);
- `STORED_THEOREMS` = 19 + (number of optional `CHECKED`) + (1 if `Define` stored `ffi_calls_ok_ind`; local mode only);
  `STORED_DEFINITIONS` 1 (local) or 0 (imported).

Optional theorems (an `OPTIONAL_FAILED` line is a finding, not a failed run): `ffi_calls_ok_mono`, `ffi_calls_ok_conj`,
`evaluate_clock_zero`, `call_FFI_return_appends_its_event`, `ffi_calls_ok_of_valid_events` (the R5 bridge),
`y3_event_predicate_admits_a_two_byte_read_array` (N4: evidence for the Y3 event-predicate defect).

Expected weak points (my reading, UNCHECKED): `leafG` on the leaves of G (the forms are copied from the L2-0001 SHOW
output of the same unfolding, but the G leaves differ: no second machine); the `simp`/`EVAL_TAC` mix of the two concrete
controls with the basis oracle (`closeFD`, `w82n`, `UNIV`); `close_regs_tac` (register `n2w 1` versus `1w`).

What a pass gives: MACHINE-CHECKED (local, one machine): G; at every returning `close` call of ANY machine with the arm8
target, len regs 1/3, ExtCall names and the basis oracle, `x1 = 8w /\ x3 <> 0w`; the same for the refund record and its
totalised version, for every slide, clock and start state. It gives nothing about read/write/open_in, nothing about
`word_msb x3`, nothing about program behaviour, nothing native, and (case 1) nothing about the constant of a future L2.

## 4. Case 1' (only after an L2 retry exports `forge_refundRouteA2`)

```zsh
cd $A
{ cat deps-L2.txt; echo $A/L2-000M/forge_refundRouteA2Theory.sig; echo $A/L2-000M/forge_refundRouteA2Theory.sml; } > deps-L2b-imp.txt
cp $F/routeA-L2b.sml L2b-000N.sml
FORGE_CPU_SECONDS=1200 ./go-routeA.sh L2b-000N L2b-000N.sml deps-L2b-imp.txt ; echo "go exit $?"
```
Pass criteria: as section 3, with `D3_SOURCE imported` and `STORED_DEFINITIONS 0`.

## 5. Negative controls of the run (optional; each must FAIL in the stated way)

- Mutant A (`L2bnegA-0001`): delete the oracle premise of `close_returning_calls_have_valid_lengths` (line 217 only).
  ```zsh
  cd $A; sed '217s#EL 2 mc.ffi_names = ExtCall «close» /\\ ffi.oracle = basis_ffi_oracle ext ==>#EL 2 mc.ffi_names = ExtCall «close» ==>#' L2b-0001.sml > L2bnegA-0001.sml
  diff L2b-0001.sml L2bnegA-0001.sml     # A8 dry run on a scratch copy: exactly line 217 changes
  FORGE_CPU_SECONDS=1200 ./go-routeA.sh L2bnegA-0001 L2bnegA-0001.sml deps-L2b.txt ; echo "go exit $?"
  ```
  Expected: `LEMMA_FAILED close_returning_calls_have_valid_lengths` (the statement is false: N2'), then `Fail` before
  export, `actual_exit` not 0, no `EXACT_COMPLETE`. A pass is a defect in the harness or in my reading.
- Mutant B (`L2bnegB-0001`): delete premise 1 of G (line 148 only: `(!i. i < LENGTH mc.ffi_entry_pcs ==> ...) /\`).
  ```zsh
  cd $A; sed '148d' L2b-0001.sml > L2bnegB-0001.sml; diff L2b-0001.sml L2bnegB-0001.sml
  ```
  Expected: `LEMMA_FAILED ffi_calls_ok_of_returning_calls` (false: a SharedMem entry gives `F`), `actual_exit` not 0.

## 6. What to record

Per case: actual exit, wall and CPU seconds, max RSS, markers; `D3_SOURCE`; every `CHECKED` statement as printed; every
`TACTIC_USED` / `TACTIC_ATTEMPT_FAILED` / `OPTIONAL_FAILED`; the `STATEMENT_TYPECHECKS` terms; the `CLOSURE_AXIOM` lines;
`command.json` `source_sha256` against the digest of `F/routeA-L2b.sml`; `hash_parents.py` output (`L2b-0001.hashes.json`).

## 7. Failure handling

At most five attempts per proof; each attempt a new case name and a new source copy. Tactic-only changes are allowed and
must be marked. A statement change needs old text, new text and why. Never add `cheat`, `mk_thm`, `new_axiom` or an oracle.
A `LEMMA_FAILED` is a finding about my tactic, not evidence that the statement is false (except in the section 5 mutants).
