#!/bin/bash
# Orchestrator B (copy by e-subset3 of e-subset2/heavy/gate_subset2.sh, NOT RUN): DIFF, LIST, OUT parameters; default = rule 3 combined-scope diff.
# subset rule) in a scratch export of 985f5eaf, over correct and hostile submissions. HEAVY (Dafny + Node per file).
# Takes heavy.lock and dafny.lock (FIFO ticket). Nothing in the repository is changed.
set -u
R=<REPO>; NS=$R/results/night-shift-20261119; B=$NS/orch-B; L=$NS/locks
OUT=${OUT:-$B/e-subset3/heavy/gate-subset3}; W=<SCRATCH>/orchB-gate-subset3; DIFF=${DIFF:-$B/e-subset3/diff/refund-subset3-combined-scope.diff}; LIST=${LIST:-$B/e-subset3/heavy/list3.txt}
PY=/usr/local/bin/python3.10
[ -e $L/hol.lock ] && { echo "refused: hol.lock exists"; exit 75; }
pgrep -f 'bin/hol' >/dev/null && { echo "refused: a HOL process runs"; exit 75; }
case "$(pmset -g batt | head -1)" in *"AC Power"*) ;; *) echo "refused: battery"; exit 75;; esac
sw=$(sysctl -n vm.swapusage | sed -E 's/.*free = ([0-9]+)\..*/\1/'); mf=$(memory_pressure | sed -n 's/.*free percentage: \([0-9]*\)%.*/\1/p')
if [ "$sw" -lt 512 ] || { [ "$sw" -lt 1024 ] && [ "${mf:-0}" -lt 40 ]; }; then echo "refused: swap $sw MiB, memory free $mf %"; exit 75; fi
mkdir $L/heavy.lock || { echo "heavy.lock held"; exit 76; }
echo orch-B > $L/heavy.lock/owner; echo $$ > $L/heavy.lock/pid; date -u +%FT%TZ > $L/heavy.lock/start
Q=$L/dafny.queue; mkdir -p $Q; TK=$Q/$(date +%s)-$$-heavy; echo $$ > $TK
trap 'rm -rf $L/heavy.lock; [ -e $L/dafny.lock/mine-$$ ] && rm -rf $L/dafny.lock; rm -f $TK' EXIT
until mkdir $L/dafny.lock 2>/dev/null; do sleep 3; done
touch $L/dafny.lock/mine-$$; echo orchB-gate-subset3 > $L/dafny.lock/owner; echo $$ > $L/dafny.lock/pid
echo "# start $(date -u +%FT%TZ) swap free $sw MiB memory free $mf %"
rm -rf $W; mkdir -p $W && git -C $R archive 985f5eaf | tar -x -C $W
ln -s $R/.toolchain $W/.toolchain; ln -s $R/node_modules $W/node_modules
( cd $W && git apply $DIFF ) || { echo "diff did not apply"; exit 2; }
sed -i '' "s/'hostile': 1800/'hostile': 300/" $W/gate/refund.py
mkdir -p $OUT/logs; : > $OUT/summary.txt
while read cls S; do
  [ -e $L/hol.lock ] && { echo "stopped: hol.lock appeared" | tee -a $OUT/summary.txt; break; }
  n=$(basename $S .dfy); cp $S $W/impl/Refund.dfy
  ( cd $W && env -i PATH=/opt/homebrew/bin:/usr/bin:/bin HOME=$W LANG=C PYTHONUSERBASE=<HOME>/Library/Python/3.10 \
      $PY gate/refund.py --tier hostile-tests --evidence build/gs-$n.json ) > $OUT/logs/$n.log 2>&1
  rc=$?; echo "exit $rc" >> $OUT/logs/$n.log
  v=$(grep -h 'ACCEPTED\|REJECTED\|RESOURCE_LIMIT\|SUBSET\|EXPECT\|SCOPE\|ERROR' $OUT/logs/$n.log | tail -1 | cut -c1-90)
  echo "$cls $n exit $rc :: $v" | tee -a $OUT/summary.txt
  git -C $R show 985f5eaf:impl/Refund.dfy > $W/impl/Refund.dfy; rm -f $W/build/refund-gate.lock
done < $LIST
rm -rf $W
echo "# end $(date -u +%FT%TZ)"
