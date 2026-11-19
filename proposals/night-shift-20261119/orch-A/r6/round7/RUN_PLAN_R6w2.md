# RUN PLAN R6w round 7 (worker A33). NOT RUN.

Exploration first:
```
cd /Users/USER/forge/results/m1b-routeA-20261119/attempt-0001
cp /Users/USER/forge/results/night-shift-20261119/orch-A/r6/round7/R6wx-0002.sml R6wx-0002.sml
shasum -a 256 R6wx-0002.sml deps-R6w.txt   # 81a02ff0...f2a115 and 0a63eb75...f2b5
./nightshift-run.sh R6wx-0002 3600 deps-R6w.txt
```
Read: `^TRY_HELPER_CLOSED|^TRY_HELPER_FAILED` (all 17 lemmas now tried in order: real prerequisites),
`^EXPLORE_HEAD_CLOSED|^STEP_STUCK|^STEP_FAILED`.

Proof only if every REQUIRED lemma has `TRY_HELPER_CLOSED` (that is the same replay as the proof):
```
cp /Users/USER/forge/results/night-shift-20261119/orch-A/r6/round7/R6w-0002.sml R6w-0002.sml
shasum -a 256 R6w-0002.sml deps-R6w.txt    # 8b86aa91...a3d9 and 0a63eb75...f2b5
./nightshift-run.sh R6w-0002 3600 deps-R6w.txt
```
