# RUN PLAN EEx-0001 (erase side of one ARM8 step, EXPLORATION). Worker A20. NOTHING HERE HAS RUN.

All commands and exit codes below are PLANNED. Run only in the single HOL slot, by the orchestrator.

V = `/Users/mackianni/forge/results/night-shift-20261119/orch-A/erasure-step/v3`
A = `/Users/mackianni/forge/results/m1b-routeA-20261119/attempt-0001`

## Inputs
| File | SHA-256 |
|---|---|
| `V/EEx-0001.sml` (764 lines) | `e47689d82b65429ccfa73aed632f7bf474799cdb9b31ea767cc1661b920c5458` |
| `A/deps-ES.txt` (127 lines) | `7b46255aac314b9d3da4f7d0a7b85a20337583ae8248f896fd3390d23865d3d4` |
| `A/ES-0002.sml` (source of the COPY blocks) | `7c0c3c512561709394eb9d55d03e89a571e61ea58585aacac3c10b69aa02a7e5` |
| EF-0001 objects (`A/EF-0001.run.json`) | `.sig 379bf0b8…3620`, `.sml 2d359f31…b495`, `.dat 662d7cd2…1206` |

## Deps recipe (once)
```zsh
cd /Users/mackianni/forge/results/m1b-routeA-20261119/attempt-0001
cp deps-ES.txt deps-EE.txt
print -r -- "$PWD/EF-0001/forge_m1bErasureFrameTheory.sig" >> deps-EE.txt
print -r -- "$PWD/EF-0001/forge_m1bErasureFrameTheory.sml" >> deps-EE.txt
wc -l deps-EE.txt      # expected 129
```
(The runner maps `<dir>/<name>` to `<dir>/.hol/objs/<name>`, run_case.py:50-51, as for the E1-0003 lines.)

## Run (CPU 1500 s; the script stops proofs at 1250 s script CPU and explorations at 1050 s)
```zsh
cp /Users/mackianni/forge/results/night-shift-20261119/orch-A/erasure-step/v3/EEx-0001.sml EEx-0001.sml
shasum -a 256 EEx-0001.sml   # must be e47689d8...5458
./nightshift-run.sh EEx-0001 1500 deps-EE.txt ; echo "go exit $?"
```
Run success = actual exit 0 and `EXPLORE_COMPLETE`. It proves and stores nothing (one scratch definition NX_def).

## What the run should show (expectations, not results)
```zsh
grep -n "^EXPLORE_\|^STEP_FAILED\|^STEP_STUCK\|^ALT_WORKS\|^VALIDATION\|^PROVED_NOT_STORED\|^DIAG_OK_UNDER\|^LEMMA_FAILED\|^LEFT_GOALS\|^STATEMENT\|^WOULD_FAIL_LIST\|^FRAME_LEMMAS_FROM\|^RULE_COUNTS\|^TACTIC_USED erase_\|^TACTIC_USED Run\|^TACTIC_USED B" EEx-0001/stdout.log | cut -c1-300
```
- `FRAME_LEMMAS_FROM_EF_0001 61`.
- Every erase lemma that passed in ES-0002 shows `PROVED_NOT_STORED` again (regression check).
- D1: `erase_write_SP` closes by tactic 3 (EL split) or 4 (push-in); X1 plans print the ARB goals otherwise.
- `probe_CSA_discharge/*`: closes = the SP premise is discharged from the assumption (H4 refuted); open = H4 holds.
- X2-X7 (SP class): one closed plan per lemma, or the first blocking goal (`STEP_STUCK`, `GOAL_BEGIN`).
- `Run_erase_pc`, `Run_pc`: `PROVED_NOT_STORED` (then the Next chain and `NextStateARM8_erase` follow without
  hypotheses), or the leaf goals left after `leaf_try` (the instruction cases that still block).
- `STATEMENT` lines: NextStateARM8_erase (E1-0003 text), Next_erase (E1-0003 text, not derived), Next_erase_sp,
  U0..U6 untagged premises; `STATEMENT_RESULT NextStateARM8_erase hyps 0 concl_literal true` is the goal.
- `WOULD_FAIL_LIST` empty = a proof version (EE-0001) is expected to pass as written (still UNCHECKED).
