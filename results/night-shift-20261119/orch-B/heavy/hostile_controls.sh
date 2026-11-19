#!/bin/bash
# e-expect HEAVY controls. NOT RUN by e-expect. For the orchestrator, under heavy.lock, after HOL ends
# (no hol.lock, no `pgrep -f bin/hol`, swap free >= 1 GB, AC power). One submission at a time.
# Purpose: E06 (keyed stack overflow), E07 (keyed OOM), E08 (keyed 10^18-step loop) and H01/H02/H03 through the
# PATCHED gate (refund-expect-and-supervision.diff) in a disposable worktree. The gate itself runs Dafny and node
# (not via dafny_locked.sh), so this script holds dafny.lock itself for the whole gate run.
# Expected (NOT a result): each gives exit 1 with "RESOURCE_LIMIT: hostile ..." (bound or signal) or
# HOSTILE_REJECTED / TEST_COVERAGE; none gives ACCEPTED; none hangs past STEP_SECONDS['hostile'] (+ kill time).
# The 2^63-3 / 61 / 1000 / 123456789 keys are NOT among the hostile seeds, so for keyed submissions the
# EXPECTED outcome is ACCEPTED (the harness never reaches the key): that is the point of the control — a
# timeout bounds the gate run, not the admitted program on rare inputs. Record the actual result either way.
set -u
R=<REPO>
E=$R/results/night-shift-20261119/orch-B/e-expect
L=$R/results/night-shift-20261119/locks
W=${HEAVY_WT:-<SCRATCH>/orchB-hostile-heavy}
PY=/usr/local/bin/python3.10            # pinned 3.10.11; the gate checks its digest
SUBS="$R/proposals/m1b-mission-20261119/drafts/expect-rule/subs/E06-stack-overflow-keyed.dfy
$R/proposals/m1b-mission-20261119/drafts/expect-rule/subs/E07-oom-keyed.dfy
$R/proposals/m1b-mission-20261119/drafts/expect-rule/subs/E08-time-keyed.dfy
$E/p2/subs/H01b-such-that-modulus-hang.dfy
$E/p2/subs/H04-seq-length-2pow32-throws.dfy
$E/p2/subs/H02-exponential-recursion-hang.dfy
$E/p2/subs/H03-seq-comprehension-alloc.dfy"
# 0. (Orchestrator B's copy) heavy.lock is held by run_window.sh, which checked HOL, power and swap.
# dafny.lock: take a FIFO ticket, then wait for the lock (workers use the same queue).
Q=$L/dafny.queue; mkdir -p $Q; TK=$Q/$(date +%s)-$$-heavy; echo $$ > $TK
until mkdir $L/dafny.lock 2>/dev/null; do sleep 3; done
echo orchB-heavy-hostile > $L/dafny.lock/owner; echo $$ > $L/dafny.lock/pid
trap 'rm -rf $L/dafny.lock; rm -f $TK' EXIT
OUTD=$R/results/night-shift-20261119/orch-B/heavy/hostile; mkdir -p $OUTD
rm -rf $W
# 1. Disposable export of 985f5eaf (git archive: no worktree metadata); toolchain and node_modules symlinked.
mkdir -p $W && git -C $R archive 985f5eaf | tar -x -C $W
ln -s $R/.toolchain $W/.toolchain; ln -s $R/node_modules $W/node_modules
( cd $W && git apply $E/p3/refund-expect-and-supervision.diff )   # into the EXPORT only
# Shorter hostile bound for the control (production value 1800 s):
sed -i '' "s/'hostile': 1800/'hostile': 300/" $W/gate/refund.py
for S in $SUBS; do
  n=$(basename $S .dfy); cp $S $W/impl/Refund.dfy
  ( cd $W && env -i PATH=/opt/homebrew/bin:/usr/bin:/bin HOME=$W LANG=C \
      /usr/bin/time -l $PY gate/refund.py --tier hostile-tests --evidence build/heavy-$n.json ) \
      > $OUTD/heavy-$n.log 2>&1
  rc=$?; echo "exit $rc" >> $OUTD/heavy-$n.log; echo "$n exit $rc $(date -u +%FT%TZ)" | tee -a $OUTD/summary.txt; cp $W/build/heavy-$n.json $OUTD/ 2>/dev/null
  git -C $R show 985f5eaf:impl/Refund.dfy > $W/impl/Refund.dfy; rm -f $W/build/refund-gate.lock
done
# 2. Cleanup: remove the export (it holds no result; logs are in $E/p3).
rm -rf $W
