# Run plan: Route A L2 (v2) and the processor erasure lemmas (v2). Worker A5. NOTHING HERE HAS RUN.

Every command below is PLANNED. No exit code in this file is an actual exit code. Pattern: `drafts/route-a/RUN_PLAN.md`.
Run one HOL process at a time, in the single HOL slot, only when no other HOL job runs.

E = `<HOME>/forge/results/night-shift-20261119/orch-A/ffi-erasure` (this folder; sources)
S = `<HOME>/forge/results/round4-m1-replay-20261118/slide-s3-copy/attempt-0001` (READ ONLY; runner and deps origin)
A = `<HOME>/forge/results/m1b-routeA-20261119/attempt-0001` (the Route A attempt folder of `drafts/route-a/RUN_PLAN.md`)
R = `<HOME>/forge/proposals/m1b-mission-20261119/drafts/route-a`

Input digests (SHA-256, measured by A5 with `shasum -a 256`, exit 0):
- `S/run_case.py` 9c1064bd…823c3b; `S/deps-imp4.txt` 76bcd490…2c9cc90 (125 lines)
- `R/go-routeA.sh` 8b6bf896…2c7289; `R/hash_parents.py` 39be0107…ff5644
- `E/routeA-L2_v2.sml` and `E/erasure_v2.sml`: see `E/REPORT.md` (files table).

## 0. Order

| # | Case | Source | Deps | CPU estimate (guess) | CPU limit | Precondition |
|---|---|---|---|---|---|---|
| 1 | `L1-0001` | `R/routeA-L1.sml` | `deps-L1.txt` | as R/RUN_PLAN.md | 600 | none (orchestrator plan) |
| 2 | `L1imp-0001` | `R/routeA-L1-imp.sml` | `deps-L1imp.txt` | as R/RUN_PLAN.md | 600 | 1 exit 0 |
| 3 | `L2-0001` | `E/routeA-L2_v2.sml` (NOT the original routeA-L2.sml; see REPORT A, defect A-D1) | `deps-L2.txt` = `deps-L1imp.txt` | 400–900 s (load ~110 s; `Define` of the copy of `evaluate`; up to two tactic attempts for L2) | 1600 | 1 and 2 exit 0 |
| 4 | `E1-0001` | `E/erasure_v2.sml` | none (no Forge parent) | 120–300 s (heap load ~100 s; small lemmas) | 600 | independent of 1–3; may run first |
| 5 (optional) | `E1neg-0001` | mutation of `E/erasure_v2.sml` (section 5 below) | none | as 4 | 600 | 4 exit 0 |
| 6 (optional) | `L2neg-0001` | mutation of `E/routeA-L2_v2.sml` (section 5 below) | `deps-L2.txt` | as 3 | 1600 | 3 exit 0 |

Case 4 needs no Forge theory. It loads only `arm8Theory`, `arm8_stepTheory`, `targetSemTheory`, `arm8_targetTheory`,
`alignmentTheory` from the pinned heap `cakeml/cv_translator/cake_compile_heap` (run_case.py default). It is the
cheapest first real HOL run of this packet.

## 1. Before each run (resource check, memory first)

```zsh
memory_pressure | tail -1            # need >= 25 % free (run_case.py refuses below 25 %)
sysctl vm.swapusage                  # record
df -h /System/Volumes/Data           # need >= 3 GiB free
pgrep -fl 'cake_compile_heap|arm8-heap|cakeml-heap|poly' || echo "no HOL process"
```
If any HOL process runs: stop. `run_case.py` refuses with exit 3 (`resource_guard_refused`); that is not an attempt.

## 2. Setup (once; A is the folder of the Route A plan)

```zsh
E=<HOME>/forge/results/night-shift-20261119/orch-A/ffi-erasure
S=<HOME>/forge/results/round4-m1-replay-20261118/slide-s3-copy/attempt-0001
A=<HOME>/forge/results/m1b-routeA-20261119/attempt-0001
mkdir -p $A                                   # if the Route A plan has not made it yet
cp -n $S/run_case.py $A/run_case.py           # unchanged copy; it sits next to the case sources (OUT = its folder)
shasum -a 256 $S/run_case.py $A/run_case.py   # must be equal: 9c1064bd…823c3b
cp $E/routeA-L2_v2.sml $A/L2-0001.sml
cp $E/erasure_v2.sml   $A/E1-0001.sml
shasum -a 256 $E/routeA-L2_v2.sml $A/L2-0001.sml $E/erasure_v2.sml $A/E1-0001.sml
```

## 3. Case 3: L2 v2 (only after L1-0001 and L1imp-0001 have exit 0)

```zsh
cd $A
cp deps-L1imp.txt deps-L2.txt                 # = deps-imp4 (125 lines) + the two L1 theory lines
FORGE_CPU_SECONDS=1600 ./go-routeA.sh L2-0001 L2-0001.sml deps-L2.txt ; echo "go exit $?"
```
Pass criteria (ALL must hold; else the run is a finding):
- `command.json` `actual_exit` 0; marker `EXACT_COMPLETE`; `inputs_unchanged_after` true;
- no `LEMMA_FAILED`, no `UNEXPECTED_CONTROL_ACCEPTANCE`;
- `DEFINITION` line for `ffi_calls_ok` (one `Define`; record whether `ffi_calls_ok_ind` is also stored);
- `CHECKED` for the 8 named theorems: `read_ffi_bytearray_ffi_interfer_update`, `read_ffi_bytearrays_ffi_interfer_update`,
  `ffi_calls_ok_false_at_a_returning_call`, `refund_ffi_tot_evaluate_agree`, `refund_ffi_tot_machine_sem_agree`,
  `refund_mc_totalised_record`, `refund_mc_totalised_record_fields`, `refund_profile_a_sl_reach`;
- exactly one `TACTIC_USED refund_ffi_tot_evaluate_agree <n>`; record n (1 = repaired original, 2 = every_case_tac variant);
  every `TACTIC_ATTEMPT_FAILED` line before it is a finding about that tactic, not about the statement;
- `PREMISE_FOUND refund_env_ok_sl sl envmc`; `STATEMENT_L2 …` printed;
- five `CONTROL_OK` lines: C-NV; L2 literal statement; L2R conclusion term-identical to the stored `refund_profile_a_sl`;
  L2R premises without `refund_env_ok_sl` and `refund_ffi_contract_at`; L2R premise count = stored + 2;
- exactly four `CLOSURE_AXIOM` lines (`bool.SELECT_AX`, `bool.INFINITY_AX`, `bool.ETA_AX`, `bool.BOOL_CASES_AX`).
Expected weak points (my reading, UNCHECKED): the TOP_CASE_TAC leaves of tactic 1; the size of the every_case_tac split
of tactic 2 (the SharedMem branch of `evaluate` has nested cases; the premise is F there); the last lines of L2R.

## 4. Case 4: erasure v2 (no precondition)

```zsh
cd $A
FORGE_CPU_SECONDS=600 python3 -I -B run_case.py E1-0001 E1-0001.sml > E1-0001.run.json ; echo "exit $?"
python3 -c "import json;d=json.load(open('E1-0001/command.json'));print(d['actual_exit'],d['markers'],d['child_user_cpu_seconds'],d['inputs_unchanged_after'])"
grep -n "^CHECKED\|^TACTIC_\|^OPTIONAL_\|^CONTROL\|^UNEXPECTED\|^STATEMENT_TYPECHECKS\|^CLOSURE\|COMPLETE\|^LEMMA_FAILED\|^SHOW\|^  GOAL\|^STORED" E1-0001/stdout.log | cut -c1-260
```
(Do not use go-routeA.sh here: with an empty deps file it passes one empty argument to run_case.py.)
Pass criteria:
- `actual_exit` 0; `EXACT_COMPLETE`; `inputs_unchanged_after` true; no `LEMMA_FAILED`; no `UNEXPECTED_CONTROL_ACCEPTANCE`;
- six `DEFINITION` lines: `erase_def`, `bits_of_def`, `restore_def`, `untagged_def`, `tbi_pc_def`, `erase_e0e_def`;
  `STORED_DEFINITIONS 6`;
- `CHECKED` for the 18 required theorems: `erase_fields`, `restore_erase`, `erase_restore`, `arm8_ok_erase`, `untagged_bits`,
  `BranchTo_EL0_pc`, `tbi_pc_erased`, `tbi_pc_untagged`, `BranchTo_erase_untagged`, `CheckSPAlignment_erase`,
  `CheckSPAlignment_erase_fault`, `N1a_tagged_branch_breaks`, `N1b_bit55_branch_breaks`, `N2_misaligned_sp_breaks`,
  `N3_e0e_not_erasable`, `N4_slide_ok_admits_tagged_code`, `P1_bit55_without_TBI1_is_fine`,
  `N5_lo55_holds_at_slide_zero_and_fails_at_N4_slide`; `STORED_THEOREMS` 18, or 19 when the optional `BranchTo_erase_iff`
  is `CHECKED` (an `OPTIONAL_FAILED BranchTo_erase_iff` line is a finding, not a failed run);
- six `CONTROL_OK` lines (N1a, N1b, N3 negatives; N2; N4; BranchTo_erase_untagged literal statement);
- seven `STATEMENT_TYPECHECKS` lines (Next_frame, Next_erase_fault_mono, Next_erase, NextStateARM8_erase,
  NextStateARM8_erase_or_fault, arm8_target_real, lo55). These lines say only that the term parses with type bool;
- four `CLOSURE_AXIOM` lines.
What a pass gives: the five lemmas of G2's "first lemma to run" set (BranchTo_erase_untagged with N1a, N1b, P1, and the
SP lemmas) are MACHINE-CHECKED about the L3 model. It gives nothing about real hardware, nothing about `Next` as a whole
(the frame and simulation lemmas stay MISSING), and nothing about the refund run.

## 5. Negative controls of the runs (optional; each must FAIL in the stated way)

- `E1neg-0001`: copy `E1-0001.sml`; delete the premise `/\ untagged t` from the goal of `BranchTo_erase_untagged` (the goal
  term only, both lines that contain it: the `thmA` goal and the `aconv` literal). Expected: `LEMMA_FAILED BranchTo_erase_untagged`
  (the statement is false: N1a is a counterexample), then `Fail` before export, `actual_exit` ≠ 0, no `EXACT_COMPLETE`.
  A pass of this mutant is a defect in the harness or in my reading.
  ```zsh
  cd $A; sed 's#s.PSTATE.EL = 0w /\\ untagged t ==>#s.PSTATE.EL = 0w ==>#' E1-0001.sml > E1neg-0001.sml
  grep -c 'untagged t ==>' E1-0001.sml E1neg-0001.sml     # expect 4 and 2 (A5 dry run of this sed on a scratch copy: 4 and 2, diff = the two intended lines 129 and 259)
  FORGE_CPU_SECONDS=600 python3 -I -B run_case.py E1neg-0001 E1neg-0001.sml > E1neg-0001.run.json ; echo "exit $?"
  ```
- `L2neg-0001`: copy `L2-0001.sml`; in `L2_goal` delete ` /\ ffi_calls_ok Vok mc2 ffi k ms`. Expected:
  `LEMMA_FAILED refund_ffi_tot_evaluate_agree` (the statement without the premise is false for an effect that differs from
  `refund_abs_ffi` at a returning invalid call), `actual_exit` ≠ 0. A pass is a defect.

## 6. What to record (for the orchestrator; ROADMAP.md and TRACKER.md are the orchestrator's files)

Per case: actual exit (`command.json` `actual_exit`), wall and CPU seconds, max RSS, markers; every `CHECKED` statement as
printed; every `DEFINITION`; every `TACTIC_USED` / `TACTIC_ATTEMPT_FAILED` / `OPTIONAL_FAILED`; the `CLOSURE_AXIOM` lines;
the source SHA-256 (`command.json` `source_sha256`) against the digest in REPORT.md; for case 3 also
`hash_parents.py` output (`L2-0001.hashes.json`).

## 7. Failure handling

- At most five attempts per proof (project rule); each attempt a new case name and a new source copy (run_case.py refuses an
  existing case folder). Record the diff between attempts.
- Tactic-only changes are allowed and must be marked. A statement or definition change needs old text, new text and why.
- Never add `cheat`, `mk_thm`, `new_axiom` or an oracle.
- A `LEMMA_FAILED` is a finding about my tactic, not evidence that the statement is false (except in the section 5 mutants).
