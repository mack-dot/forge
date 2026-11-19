#!/bin/bash
# d-v5sink: HEAVY differential TEST (not a proof) for the orchestrator. Copy of d-v3sink2/heavy_v4.sh, changed (cb-v5).
# NOT RUN by d-v5sink (only ONE 5-sequence plain smoke). It does NOT take heavy.lock (the orchestrator's wrapper does).
# It REFUSES to run (exit 75) while hol.lock exists or a HOL process runs. Usage: heavy_v5.sh [OUTDIR] [ONLY]
#   (default d-v5sink/heavy-1; ONLY=smoke: one plain run, n=5)
# Pairs (core:sink) and the EXPECTED exit per run (an expectation, NOT a result):
#   sinkcore-v3.cjs:cb-v5          0  (v3 compiled core vs v5 draft: no divergence) in modes plain, fault-1, fault-2.
#        In mode interleave a second v5 sink OPENS the file: its start-up AuditV5 refuses a store that holds a
#        committed SIGNED-BUT-UNAUTHORIZED token (generator kind forged-post(key), or s0.refundEnabled = false), and
#        the first sink's re-audit HALTS after such a commit by the other sink. That is by design (AuditV5 re-checks
#        F.Authorizes); expect divergences or a harness error there. Record the kinds; do not count them as a pass.
#   sinkcore-v3.cjs:cb-v3          0  (reference: the d-v3sink pair)
#   sinkcore-v3.cjs:hand-v3        0
#   sinkcore-v3.cjs:real           3  (control: only foreign-charge-*, reqid-mismatch)
#   sinkcore-reqid.cjs:cb-v5       3  (control: only foreign-charge-*)
# Exit codes of diff.ts: 0 none; 3 divergences all of allowed kinds; 1 a divergence of a kind not allowed; other = harness error.
# A control run that ends with exit 0 is a FAILED control.
set -u
R=<REPO>; W=$R/results/night-shift-20261119/orch-B/d-v5sink; LOCKS=$R/results/night-shift-20261119/locks
H=${1:-$W/heavy-1}; ONLY=${2:-}
if [ "$ONLY" != smoke ] && { [ -e $LOCKS/hol.lock ] || pgrep -f 'bin/hol' >/dev/null; }; then echo "refused: hol.lock exists or a HOL process runs"; exit 75; fi
$W/setup_v5.sh $H || { echo "setup failed"; exit 2; }
export PATH=/opt/homebrew/bin:/usr/bin:/bin
[ "$(node --version)" = "v24.3.0" ] || { echo "not the pinned Node"; exit 2; }
NEW=foreign-charge-intent,foreign-charge-post
cd $R
PAIRS=("sinkcore-v3.cjs:cb-v5:" "sinkcore-v3.cjs:cb-v3:" "sinkcore-v3.cjs:hand-v3:" "sinkcore-v3.cjs:real:$NEW,reqid-mismatch" "sinkcore-reqid.cjs:cb-v5:$NEW")
MODES=(plain fault-1 fault-2 interleave)
[ "$ONLY" = smoke ] && { PAIRS=("sinkcore-v3.cjs:cb-v5:"); MODES=(plain); }
for pair in "${PAIRS[@]}"; do
  IFS=: read core sink allowed <<< "$pair"
  for mode in "${MODES[@]}"; do
    if [ "$ONLY" != smoke ] && { [ -e $LOCKS/hol.lock ] || pgrep -f 'bin/hol' >/dev/null; }; then echo "stopped: hol.lock or HOL appeared" | tee -a $H/summary.txt; exit 75; fi
    n=500; [ $mode = plain ] && n=2000; [ "$ONLY" = smoke ] && n=5
    s=$(date -u +%FT%TZ)
    env -i PATH=$PATH HOME=$H NODE_PATH=$R/node_modules Z4_SEED=20261119 Z4_CORE=$core Z4_ALLOWED_KINDS=$allowed \
      node --import tsx $H/diff.ts $sink $mode $n > $H/results/$core-$sink-$mode.stdout 2>&1
    rc=$?
    echo "$core $sink $mode n=$n allowed=$allowed start=$s end=$(date -u +%FT%TZ) exit $rc" | tee -a $H/summary.txt
  done
done
