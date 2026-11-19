# RUN PLAN R6rx-0001 / R6r-0001 (R6 read side, descriptor 0; worker A35). NOT RUN.

Nothing in this folder ran. Every tactic is UNCHECKED. No expected exit code below is an actual one.

## Files (directory `/Users/mackianni/forge/results/night-shift-20261119/orch-A/r6/round10/`)
| file | SHA-256 | role |
|---|---|---|
| `R6rx-0001.sml` | `0317b23620aaf60e4fd2e656515f3bc5f2a66b1631e5c726b3183465346725cf` | EXPLORATION main (= round9/R6wx-0004.sml; header, scratch theory, dir, names changed) |
| `R6r-0001.sml` | `d43aa62c68561f77665e3371e054283f4d6c90450ace59fd25301b30571d893d` | PROOF main, theory `forge_refundR6Read` (= round9/R6w-0004.sml; theory, dir, counts, controls changed) |
| `r6r_common.sml` | `34d55f95ba773be9016539715c4d2f5ec7f2d7d2b73415e8e60c567b23d0ab21` | grammar fix (round9, byte-identical), 4 definitions, shortcuts, TH table, replay, statements |
| `r6r_steps.sml` | `06df5823f5698c61541baa29211985eeec5eb5d37b17eff4cb05d94722165c28` | the ONE shared file of step lists |
| `r6r_explore_calls.sml` | `0e702d4e0bbc0d12a47ffe094d091472ae1dd8c8fa949786a20ec72c34ce3af1` | exploration calls (round9 + exploration-only split walks) |
| `r6r_prove.sml` | `3518908225b687733fad1f297a879edaaa51494d920920f7423133c29361551c` | proof replay + save (round9, list names changed) |
| `deps-R6r.txt` | `37017fc87d46d9216ff959b3492b888de1a20e95ce7cbf3c69b7954d408cf279` | `deps-R6w.txt` (137 lines, unchanged) + `R6w-0004/forge_refundR6WriteTheory.{sig,sml}` |

The main files read the `r6r_*.sml` files with `use` from `R6RDIR` (quoted string ending in "/"), so the
wrapper hashes them before and after the run. Do not move them.

## Commands (orchestrator only, single HOL slot; one at a time)
```
cd /Users/mackianni/forge/results/m1b-routeA-20261119/attempt-0001
cp /Users/mackianni/forge/results/night-shift-20261119/orch-A/r6/round10/R6rx-0001.sml R6rx-0001.sml
cp /Users/mackianni/forge/results/night-shift-20261119/orch-A/r6/round10/R6r-0001.sml R6r-0001.sml
cp /Users/mackianni/forge/results/night-shift-20261119/orch-A/r6/round10/deps-R6r.txt deps-R6r.txt
shasum -a 256 R6rx-0001.sml R6r-0001.sml deps-R6r.txt
./nightshift-run.sh R6rx-0001 3600 deps-R6r.txt        # 1. exploration
./nightshift-run.sh R6r-0001 3600 deps-R6r.txt         # 2. proof, ONLY if 1. shows TRY_HELPER_CLOSED for every required lemma
```
Success of 1 = `actual_exit 0` and marker `EXPLORE_COMPLETE` (says nothing about the lemmas).
Success of 2 = `actual_exit 0`, marker `EXACT_COMPLETE`, `FAILED_LIST` empty, `CONTROL_OK ... 4 definitions`.

## What to read in `R6rx-0001/stdout.log`
1. `grep -n "^DEFINITION\|DEFINITION_FAILED\|STATEMENT_PARSE_FAILED\|^FRAME_THM\|PART_FAILED" stdout.log`
   (4 definitions; 9 statements; FRAME_THM_PRESENT or FRAME_THM_EXPORTED for IOFS_V_HPROP_INJ, STDIO_V_HPROP_INJ).
2. `grep -n "^TRY_HELPER_\|^STEP_USED\|^STEP_CANDIDATE_FAILED\|^DIAG_" stdout.log` - the real proof attempts in order.
   Required: read_event_ok_read_into, read_event_ok_refund, STD_streams_fd0, INSTREAM_STRP_V_F_F, read_into_spec_R,
   refillBuffer_with_read_spec_V. Optional: INSTREAM_BUFFERED_FD_V_IMP, INSTREAM_STR_V_IMP, refillBuffer_with_read_spec_STR_V.
3. `grep -n "^EXPLORE_\|^STEP \|^STEP_FAILED\|^ALT_\|^  GOAL_\|^    ASM\|^    CONCL" stdout.log` - goals per step.
   `EXPLORE_EXTRA refillBuffer_with_read_spec_V__split`: goal count after "B1 read_into_spec_R call only (2761)".
   If it is not 1, the head-goal cut differs from the original chain; the PROOF list keeps call + tail in ONE step.
4. Note: a lemma explored with an ASSUMEd prerequisite (because the prerequisite did not close) fails at
   xlet_auto_spec/xapp_spec with "Could not find the hypothesis"; that is an artifact, read the prerequisite first.
