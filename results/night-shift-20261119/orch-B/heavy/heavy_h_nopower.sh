#!/bin/bash
# h-sink: HEAVY steps for the orchestrator. PREPARED, NOT RUN by the worker. Does NOT take heavy.lock (the orchestrator's
# wrapper does). Refuses (75) while hol.lock exists or a HOL process runs, or not on AC power.
# Usage: heavy_h.sh [OUTDIR] [PART]   PART = diff | storm | perf | all (default all)
# (A) diff: the d-v6sink differential harness (setup_v6.sh, read-only reuse) with one more sink wrapper, sinks/cb-h1.ts
#     (the hardened tree's sink; the wrapper defers construction to init(s0) and, for an existing file, takes the anchor
#     from meta.initial_state, a TEST convenience as in cb-v6). Pairs and EXPECTED exits (expectations, NOT results):
#       sinkcore-v6.cjs:cb-h1  plain, fault-1, fault-2, interleave: 0 (no divergence), EXCEPT: runs whose s0 has refunds
#                              disabled (kind suffix @disabled): the hardened sink refuses to START (S7), so the harness may
#                              report those as divergences or as a harness error: allowed list = the @disabled kinds; then
#                              expected exit 3 (divergences only of allowed kinds). Any kind outside the list: NOT predicted.
#       sinkcore-v3.cjs:cb-h1  plain: 3 (CONTROL: the unauthorized kinds diverge, as for cb-v6). exit 0 = FAILED control.
# (B) storm: 200 x (fresh file; child constructs the hardened sink without init; SIGKILL after a random 0-600 ms; then an
#     honest open + init + zero-amount commit must print "ok"). EXPECTED: 200 ok, 0 refused (red team C-ATT-02).
# (C) perf: tests/perf20k.ts at N=20000 (start-up audit time, commit median/p90 at 20,000 rows vs a small store, one
#     foreign append + commit). EXPECTED: commit median at 20,000 rows within 2x of the small store; start audit O(n).
set -u
R=<REPO>; O=$R/results/night-shift-20261119/orch-B; H=$O/h-sink; LOCKS=$R/results/night-shift-20261119/locks
OUT=${1:-$H/heavy-1}; PART=${2:-all}
guard() { if [ -e $LOCKS/hol.lock ] || pgrep -f 'bin/hol' >/dev/null; then echo "refused: hol.lock exists or a HOL process runs" | tee -a $OUT/summary.txt; exit 75; fi
  pmset -g batt | head -1 | grep -q "Power" || { echo "refused: not on AC power" | tee -a $OUT/summary.txt; exit 75; }; }
mkdir -p $OUT; guard
export PATH=/opt/homebrew/bin:/usr/bin:/bin; [ "$(node --version)" = "v24.3.0" ] || { echo "not the pinned Node"; exit 2; }
ENV=(env -i PATH=$PATH HOME=$H/home LANG=C NODE_PATH=$R/node_modules)
if [ $PART = all ] || [ $PART = diff ]; then
  D=$OUT/diff; $O/d-v6sink/setup_v6.sh $D || { echo "setup failed"; exit 2; }
  sed "s#<REPO>/results/night-shift-20261119/orch-B/d-v6sink/sink_core_backed_v6#$H/tree/ts/refund-finality/sink#; s#SELECT v FROM meta WHERE k = 'initial_state'#SELECT initial_state AS v FROM meta#; s#^// d-v6sink.*#// h-sink: cb-h1 = cb-v6 pointed at the hardened sink (meta.initial_state column).#" $D/sinks/cb-v6.ts > $D/sinks/cb-h1.ts
  grep -q '"cb-h1"' $D/lib.ts || sed -i '' 's#^  "cb-v6": Z + "/sinks/cb-v6.ts",#&\n  "cb-h1": Z + "/sinks/cb-h1.ts",#' $D/lib.ts   # orchestrator B: the worker's script did not register the wrapper (window 9 setup error)
  grep -q "h-sink/tree/ts/refund-finality/sink" $D/sinks/cb-h1.ts || { echo "wrapper edit failed"; exit 2; }
  shasum -a 256 $D/sinks/cb-h1.ts $H/tree/ts/refund-finality/sink.ts $H/tree/ts/refund-finality/core/store.ts >> $D/inputs-sha256.txt
  DIS=valid@disabled,zero@disabled,stale-or-current@disabled,forged-post\(key\)@disabled,signed-unauthorized@disabled
  UN=signed-unauthorized,forged-post\(key\),forged-post,valid-signed,$DIS
  cd $R
  for pair in "sinkcore-v6.cjs:cb-h1:$DIS" "sinkcore-v3.cjs:cb-h1:$UN"; do
    IFS=: read core sink allowed <<< "$pair"
    MODES=(plain fault-1 fault-2 interleave); [ $core = sinkcore-v3.cjs ] && MODES=(plain)
    for mode in "${MODES[@]}"; do
      guard; n=500; [ $mode = plain ] && n=2000; s=$(date -u +%FT%TZ)
      "${ENV[@]}" HOME=$D Z4_SEED=20261119 Z4_CORE=$core Z4_ALLOWED_KINDS=$allowed node --import tsx $D/diff.ts $sink $mode $n > $D/results/$core-$sink-$mode.stdout 2>&1; rc=$?
      echo "diff $core $sink $mode n=$n start=$s end=$(date -u +%FT%TZ) exit $rc" | tee -a $OUT/summary.txt
    done
  done
fi
if [ $PART = all ] || [ $PART = storm ]; then
  S=$OUT/storm; mkdir -p $S; ok=0; bad=0
  for i in $(seq 1 200); do
    guard; f=$S/s$i.sqlite; rm -f $f $f-journal
    "${ENV[@]}" node --import tsx $H/tests/ddl_child.ts $H/tree $f 0 noinit > /dev/null 2>&1 & pid=$!
    sleep 0.$(printf '%03d' $((RANDOM % 600))); kill -9 $pid 2>/dev/null; wait $pid 2>/dev/null
    r=$(cd $H/tree && "${ENV[@]}" node --import tsx $H/tests/ddl_open_check.ts $H/tree $f 2>/dev/null | tail -1)
    if [ "$r" = ok ]; then ok=$((ok+1)); else bad=$((bad+1)); echo "storm $i: $r" >> $S/failures.txt; fi; rm -f $f $f-journal
  done
  echo "storm ok=$ok refused=$bad (expected 200 / 0)" | tee -a $OUT/summary.txt
fi
if [ $PART = all ] || [ $PART = perf ]; then
  guard; (cd $H/tree && /usr/bin/time -p "${ENV[@]}" timeout 900 node --import tsx $H/tests/perf20k.ts $H/tree $OUT/perf 20000 > $OUT/perf20k.out 2>&1); rc=$?
  echo "perf20k exit $rc (see perf20k.out)" | tee -a $OUT/summary.txt; rm -rf $OUT/perf
fi
