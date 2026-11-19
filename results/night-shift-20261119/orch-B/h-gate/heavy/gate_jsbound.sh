#!/bin/bash
# Orchestrator B, h-gate (copy of e-subset3/heavy/gate_subset3.sh, NOT RUN): DIFF, LIST, OUT parameters; default = JS-bound combined diff.
# subset rule) in a scratch export of 985f5eaf, over correct and hostile submissions. HEAVY (Dafny + Node per file).
# The ORCHESTRATOR holds heavy.lock (PHASE2 rule): this script does not take it. It takes dafny.lock (FIFO ticket). Nothing in the repository is changed.
set -u
R=/Users/mackianni/forge; NS=$R/results/night-shift-20261119; B=$NS/orch-B; L=$NS/locks
OUT=${OUT:-$B/h-gate/heavy/gate-jsbound}; W=/private/tmp/claude-501/-Users-mackianni-forge/90d187ef-57dc-4fa3-a5b8-7a6708d00cf2/scratchpad/orchB-gate-jsbound; DIFF=${DIFF:-$B/h-gate/diff/refund-jsbound-combined.diff}; LIST=${LIST:-$B/h-gate/heavy/list_jsbound.txt}
PY=/usr/local/bin/python3.10
[ -e $L/hol.lock ] && { echo "refused: hol.lock exists"; exit 75; }
pgrep -f 'bin/hol' >/dev/null && { echo "refused: a HOL process runs"; exit 75; }
case "$(pmset -g batt | head -1)" in *"AC Power"*) ;; *) echo "refused: battery"; exit 75;; esac
sw=$(sysctl -n vm.swapusage | sed -E 's/.*free = ([0-9]+)\..*/\1/'); mf=$(memory_pressure | sed -n 's/.*free percentage: \([0-9]*\)%.*/\1/p')
if [ "$sw" -lt 512 ] || { [ "$sw" -lt 1024 ] && [ "${mf:-0}" -lt 40 ]; }; then echo "refused: swap $sw MiB, memory free $mf %"; exit 75; fi
Q=$L/dafny.queue; mkdir -p $Q; TK=$Q/$(date +%s)-$$-heavy; echo $$ > $TK
trap '[ -e $L/dafny.lock/mine-$$ ] && rm -rf $L/dafny.lock; rm -f $TK' EXIT
until mkdir $L/dafny.lock 2>/dev/null; do sleep 3; done
touch $L/dafny.lock/mine-$$; echo orchB-gate-jsbound > $L/dafny.lock/owner; echo $$ > $L/dafny.lock/pid
echo "# start $(date -u +%FT%TZ) swap free $sw MiB memory free $mf %"
rm -rf $W; mkdir -p $W && git -C $R archive 985f5eaf | tar -x -C $W
ln -s $R/.toolchain $W/.toolchain; ln -s $R/node_modules $W/node_modules
( cd $W && git apply $DIFF ) || { echo "diff did not apply"; exit 2; }
sed -i '' "s/'hostile': 1800/'hostile': 300/" $W/gate/refund.py
mkdir -p $OUT/logs; : > $OUT/summary.txt
while read cls S; do
  [ -e $L/hol.lock ] && { echo "stopped: hol.lock appeared" | tee -a $OUT/summary.txt; break; }
  n=$(basename $S .dfy); cp $S $W/impl/Refund.dfy
  ( cd $W && env -i PATH=/opt/homebrew/bin:/usr/bin:/bin HOME=$W LANG=C PYTHONUSERBASE=/Users/mackianni/Library/Python/3.10 \
      $PY gate/refund.py --tier ${TIER:-hostile-tests} --evidence build/gs-$n.json ) > $OUT/logs/$n.log 2>&1
  rc=$?; echo "exit $rc" >> $OUT/logs/$n.log
  v=$(grep -h 'ACCEPTED\|REJECTED\|RESOURCE_LIMIT\|SUBSET\|EXPECT\|SCOPE\|ERROR\|JS_BOUND' $OUT/logs/$n.log | tail -1 | cut -c1-140)
  echo "$cls $n exit $rc :: $v" | tee -a $OUT/summary.txt
  git -C $R show 985f5eaf:impl/Refund.dfy > $W/impl/Refund.dfy; rm -f $W/build/refund-gate.lock
done < $LIST
rm -rf $W
echo "# end $(date -u +%FT%TZ)"
