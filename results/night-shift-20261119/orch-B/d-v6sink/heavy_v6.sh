#!/bin/bash
# d-v6sink: HEAVY differential TEST (not a proof) for the orchestrator. Copy of d-v5sink/heavy_v5.sh, changed (cb-v6,
# V6 core adapter). NOT RUN by d-v6sink (only ONE 5-sequence plain smoke). It does NOT take heavy.lock (the
# orchestrator's wrapper does). It REFUSES to run (exit 75) while hol.lock exists or a HOL process runs.
# Usage: heavy_v6.sh [OUTDIR] [ONLY]   (default d-v6sink/heavy-1; ONLY=smoke: one plain run, n=5)
# Pairs (core:sink) and the EXPECTED exit per run (an expectation, NOT a result):
#   sinkcore-v6.cjs:cb-v6     0  (compiled V6 core vs v6 draft: no divergence) in plain, fault-1, fault-2, interleave.
#   sinkcore-v3.cjs:cb-v6     3  (CONTROL: divergences ONLY on unauthorized-token kinds: signed-unauthorized,
#                                 forged-post(key), the directed forged-post / valid-signed (refund disabled), and the
#                                 committing kinds on a refund-disabled s0 (suffix @disabled)). exit 0 = FAILED control.
#   sinkcore-v6.cjs:cb-v3     3  (CONTROL, reverse: the v3 draft commits the unauthorized kinds; same allowed list).
#   sinkcore-v3.cjs:cb-v3     0  (reference: the d-v3sink pair, unchanged harness semantics for V3 core)
# Exit codes of diff.ts: 0 none; 3 divergences all of allowed kinds; 1 a divergence of a kind not allowed; other = harness error.
set -u
R=<REPO>; W=$R/results/night-shift-20261119/orch-B/d-v6sink; LOCKS=$R/results/night-shift-20261119/locks
H=${1:-$W/heavy-1}; ONLY=${2:-}
if [ "$ONLY" != smoke ] && { [ -e $LOCKS/hol.lock ] || pgrep -f 'bin/hol' >/dev/null; }; then echo "refused: hol.lock exists or a HOL process runs"; exit 75; fi
$W/setup_v6.sh $H || { echo "setup failed"; exit 2; }
export PATH=/opt/homebrew/bin:/usr/bin:/bin
[ "$(node --version)" = "v24.3.0" ] || { echo "not the pinned Node"; exit 2; }
UN=signed-unauthorized,forged-post\(key\),forged-post,valid-signed,valid@disabled,zero@disabled,stale-or-current@disabled,forged-post\(key\)@disabled,signed-unauthorized@disabled
cd $R
PAIRS=("sinkcore-v6.cjs:cb-v6:" "sinkcore-v3.cjs:cb-v6:$UN" "sinkcore-v6.cjs:cb-v3:$UN" "sinkcore-v3.cjs:cb-v3:")
MODES=(plain fault-1 fault-2 interleave)
[ "$ONLY" = smoke ] && { PAIRS=("sinkcore-v6.cjs:cb-v6:"); MODES=(plain); }
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
