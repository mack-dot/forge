# RUN PLAN R6w (R6 write side; worker A33). NOT RUN.

Nothing in this folder ran. Every tactic is UNCHECKED. Run the exploration first. Run the proof only after the
exploration shows `EXPLORE_HEAD_CLOSED` for every REQUIRED lemma.

## Inputs (round6, read by `use` from ONE directory, named once as a quoted string ending in "/")
| file | SHA-256 |
|---|---|
| `r6w_common.sml` | `0c2104df4c6909d5d09efc26c6b7317a15faf49a374c0e287acf1cd63719f626` |
| `r6w_steps.sml` | `347461733d8428169dfa2002c4f6e9b403a00f1606e20f4c4631b6a830d90142` |
| `r6w_explore_calls.sml` | `13878554a1477f161196750ccda79b90a10aa80f01bd8035d2611d9df4218624` |
| `r6w_prove.sml` | `1c44544118bf8876361704bfda7d7dad70a872db8012088bfdcee31a5812b5c8` |
| `R6wx-0001.sml` (exploration main) | `42506e55486d10fad88667cc2a266511f6ec7b412ab3bfc1352f051a07d461b8` |
| `R6w-0001.sml` (proof main) | `5be5d82a641298c4fc17a53119afff998e1127c4f6258893cecbc2766e833c96` |
| `deps-R6w.txt` = `deps-R6ffi.txt` (135 lines) + 2 lines `R6ffi-0002/forge_refundR6FfiTheory.{sig,sml}` | `0a63eb752e32ad4ea56a24a1161e79aee6694395a12538fe82da0606262ef2b5` |

The two new deps lines use the same path pattern as the R6base lines (the objects are in `R6ffi-0002/.hol/objs/`).

## Command 1: exploration (orchestrator only, single HOL slot)
```
cd /Users/mackianni/forge/results/m1b-routeA-20261119/attempt-0001
cp /Users/mackianni/forge/results/night-shift-20261119/orch-A/r6/round6/R6wx-0001.sml R6wx-0001.sml
cp /Users/mackianni/forge/results/night-shift-20261119/orch-A/r6/round6/deps-R6w.txt deps-R6w.txt
shasum -a 256 R6wx-0001.sml deps-R6w.txt   # 42506e55...61b8 and 0a63eb75...f2b5
./nightshift-run.sh R6wx-0001 3600 deps-R6w.txt
```
Run success = exit 0 and marker `EXPLORE_COMPLETE` (says nothing about the lemmas).
Read: `grep -n "^PART_\|^DEFINITION\|^STATEMENT\|^TRY_HELPER\|^FRAME_THM\|^EXPLORE_\|^STEP \|^STEP_FAILED\|^ALT_\|^STEP_STUCK" stdout.log`.
- `STATEMENT <name>` blocks print the full statements (print depth unlimited).
- `TRY_HELPER_CLOSED` for the 10 helpers; `FRAME_THM_REGISTERED IOFS_V_HPROP_INJ` (needed by the CF steps).
- Per lemma `EXPLORE_HEAD_CLOSED <name>` or `STEP_STUCK <name> <i> <label>` with the goal before the step.

## Command 2: proof (only after command 1 shows all REQUIRED lemmas closed)
```
cd /Users/mackianni/forge/results/m1b-routeA-20261119/attempt-0001
cp /Users/mackianni/forge/results/night-shift-20261119/orch-A/r6/round6/R6w-0001.sml R6w-0001.sml
shasum -a 256 R6w-0001.sml deps-R6w.txt    # 5be5d82a...3c96 and 0a63eb75...f2b5
./nightshift-run.sh R6w-0001 3600 deps-R6w.txt
```
Pass = exit 0, `EXACT_COMPLETE`, `FAILED_LIST` empty, 4 `CLOSURE_AXIOM` lines (bool), `CONTROL_OK` for
forge_refundR6Ffi, forge_refundRouteA2c, TextIOProof, `theorems = stored list, 1 definition`, `print_spec_refund stored`.
`OPTIONAL_FAILED` lists optional lemmas that failed (not fatal). If an optional lemma is STEP_STUCK in the
exploration, set its flag to required=false (already false) and accept it in OPTIONAL_FAILED, or delete its line
from `R6W_LEMMAS` (new hashes then).

Expected cost (guess, NOT measured): R6ffi-0002 took 171 s / 4.3 GB RSS for 4 lemmas; here 17 lemmas, 6 of them CF
proofs; 10-30 min if no candidate times out (240 s per candidate).
