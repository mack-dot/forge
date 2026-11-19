#!/bin/bash
# d-v3sink: HEAVY differential TEST (not a proof) for the orchestrator. NOT RUN by d-v3sink.
# It does NOT take heavy.lock (the orchestrator's wrapper does). It REFUSES to run (exit 75) while hol.lock exists
# or a HOL process runs. Usage: heavy_v3.sh [OUTDIR]   (default d-v3sink/heavy-1)
# Pairs (core:sink) and the EXPECTED exit per run (an expectation, NOT a result):
#   sinkcore-v3.cjs:cb-v3          0  (no divergence)
#   sinkcore-v3.cjs:hand-v3        0
#   sinkcore-v3.cjs:real           3  (controls: only kinds foreign-charge-*, reqid-mismatch; the unchanged sink lacks both checks)
#   sinkcore-v3.cjs:patched-reqid  3  (only foreign-charge-*)
#   sinkcore-reqid.cjs:cb-v3       3  (only foreign-charge-*)
# Exit codes of diff.ts: 0 none; 3 divergences all of allowed kinds; 1 a divergence of a kind not allowed; other = harness error.
# A control run that ends with exit 0 is a FAILED control (the new kinds did not diverge).
set -u
R=<REPO>; V=$R/results/night-shift-20261119/orch-B/d-v3sink; LOCKS=$R/results/night-shift-20261119/locks
H=${1:-$V/heavy-1}
if [ -e $LOCKS/hol.lock ] || pgrep -f 'bin/hol' >/dev/null; then echo "refused: hol.lock exists or a HOL process runs"; exit 75; fi
$V/setup_v3.sh $H || { echo "setup failed"; exit 2; }
export PATH=/opt/homebrew/bin:/usr/bin:/bin
[ "$(node --version)" = "v24.3.0" ] || { echo "not the pinned Node"; exit 2; }
NEW=foreign-charge-intent,foreign-charge-post
cd $R
for pair in "sinkcore-v3.cjs:cb-v3:" "sinkcore-v3.cjs:hand-v3:" "sinkcore-v3.cjs:real:$NEW,reqid-mismatch" \
            "sinkcore-v3.cjs:patched-reqid:$NEW" "sinkcore-reqid.cjs:cb-v3:$NEW"; do
  IFS=: read core sink allowed <<< "$pair"
  for mode in plain fault-1 fault-2 interleave; do
    if [ -e $LOCKS/hol.lock ] || pgrep -f 'bin/hol' >/dev/null; then echo "stopped: hol.lock or HOL appeared" | tee -a $H/summary.txt; exit 75; fi
    n=500; [ $mode = plain ] && n=2000
    s=$(date -u +%FT%TZ)
    env -i PATH=$PATH HOME=$H NODE_PATH=$R/node_modules Z4_SEED=20261119 Z4_CORE=$core Z4_ALLOWED_KINDS=$allowed \
      node --import tsx $H/diff.ts $sink $mode $n > $H/results/$core-$sink-$mode.stdout 2>&1
    rc=$?
    echo "$core $sink $mode n=$n allowed=$allowed start=$s end=$(date -u +%FT%TZ) exit $rc" | tee -a $H/summary.txt
  done
done
