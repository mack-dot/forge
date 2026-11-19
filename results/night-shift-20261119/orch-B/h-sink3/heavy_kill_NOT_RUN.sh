#!/bin/bash
# HEAVY (kill runs). Prepared by h-sink3; NOT RUN by h-sink3. The orchestrator runs it in a heavy window.
# It refuses while results/night-shift-20261119/locks/hol.lock exists or a HOL process runs; it does not take heavy.lock.
# Runs: (1) s3_kill_commits.ts on the fixed tree (<= 30 rounds, <= 50 s); (2) the red team's x1_crash_journal.ts kill 20
# (adapted copy) on the unfixed and on the fixed tree. Logs: logs/heavy_*.log, each ending "exit N".
H=<REPO>/results/night-shift-20261119/orch-B/h-sink3
if [ -e <REPO>/results/night-shift-20261119/locks/hol.lock ] || pgrep -f 'bin/hol' >/dev/null; then echo "REFUSED: hol.lock exists or a HOL process runs"; exit 75; fi
df -g /System/Volumes/Data | awk 'NR==2 && $4 < 30 { print "REFUSED: < 30 GiB free"; exit 75 }' || exit 75
cd $H || exit 1
S3_HEAVY_OK=1 TMO=120 ./rt.sh heavy_s3_kill_commits_fixed $H/tree tests/refund-finality/regress/s3_kill_commits.ts $H/tree
S3_HEAVY_OK=1 TMO=120 ./rt.sh heavy_s3_kill_commits_unfixed $H/tree tests/refund-finality/regress/s3_kill_commits.ts $H/pristine
TMO=150 attacks/run.sh $H/pristine $H/attacks/c21/x1_crash_journal.ts $H/attacks/work/x1k kill 20 > logs/heavy_x1_kill_unfixed.log 2>&1; echo "exit $?" >> logs/heavy_x1_kill_unfixed.log
TMO=150 attacks/run.sh $H/tree $H/attacks/c21/x1_crash_journal.ts $H/attacks/work/x1k kill 20 > logs/heavy_x1_kill_fixed.log 2>&1; echo "exit $?" >> logs/heavy_x1_kill_fixed.log
rm -rf $H/attacks/work/x1k $H/tmp/forge-*
tail -n 1 logs/heavy_*.log
