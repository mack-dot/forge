# RUN PLAN R6rx-0002 / R6r-0002 (round 12, worker A37). NOT RUN.

Nothing in this folder ran. Every tactic is UNCHECKED. No expected exit code below is an actual one.
This file replaces the round10 plan in this copy (round10/RUN_PLAN_R6r.md is unchanged).

## SHA-256 (at writing time; this file itself not listed)
```
16aa8183dd5c28ff0956c408d536ed0180a275171b1ecc08b0f400c258af0052  R6rx-0002.sml
516e8e5ec850650dda2cbb458de5f2178e7f07ba82b6cdbe0dcf03c13fb8bc15  R6r-0002.sml
34d55f95ba773be9016539715c4d2f5ec7f2d7d2b73415e8e60c567b23d0ab21  r6r_common.sml
b2302a4567f566572cf868862d95ca5e16e05d19ed481ea1b4566c395c1968ad  r6r_steps.sml
3e9d3e6f5ec4d81d38b3c9a3e2287b15f83de77ebdcaf9ac7b01d9b6354ed7bd  r6r_explore_calls.sml
3518908225b687733fad1f297a879edaaa51494d920920f7423133c29361551c  r6r_prove.sml
37017fc87d46d9216ff959b3492b888de1a20e95ce7cbf3c69b7954d408cf279  deps-R6r.txt
d304390a3f90eea76a5e9a052a544883f019f0b0e29b6329245ae426067dd08c  CHANGES.txt
```

## Commands (orchestrator only, single HOL slot; one at a time; wait until R6rx-0001 has ended)
```
cd /Users/mackianni/forge/results/m1b-routeA-20261119/attempt-0001
cp /Users/mackianni/forge/results/night-shift-20261119/orch-A/r6/round12/R6rx-0002.sml R6rx-0002.sml
cp /Users/mackianni/forge/results/night-shift-20261119/orch-A/r6/round12/R6r-0002.sml R6r-0002.sml
shasum -a 256 R6rx-0002.sml R6r-0002.sml deps-R6r.txt   # deps-R6r.txt unchanged: 37017fc8...cf279
./nightshift-run.sh R6rx-0002 3600 deps-R6r.txt        # 1. exploration
./nightshift-run.sh R6r-0002 3600 deps-R6r.txt         # 2. proof, ONLY if 1. shows TRY_HELPER_CLOSED for every required lemma
```
Success of 1 = actual_exit 0 and EXPLORE_COMPLETE (says nothing about the lemmas). A step can outlast its 240 s limit
(R6rx-0001), so 1. may also end by the 3600 s runner limit; the walks are ordered so that the most useful ones print first.
Success of 2 = actual_exit 0, EXACT_COMPLETE, FAILED_LIST empty, CONTROL_OK lines.

## What to read in R6rx-0002/stdout.log
1. grep -n "^TRY_HELPER_\|^STEP_USED\|^STEP_CANDIDATE_FAILED\|^DIAG_\|^CLOSED_NAMES" stdout.log
2. grep -n "^EXPLORE_EXTRA\|^STEP \|^STEP_FAILED\|^ALT_\|^STEP_STUCK\|TIMEOUT" stdout.log
   - refillBuffer_with_read_spec_STR_V__closedassume: goals after xapp_spec / EX_INV / irule_at (V not needed).
   - refillBuffer_with_read_spec_V__split: which of "B1 eof fact / xmatch / open / xpull" is slow or fails; goal count
     after "B1 read_into_spec_R call only (2761)". If not 1, the PROOF list keeps call + tail as ONE step (as now).
