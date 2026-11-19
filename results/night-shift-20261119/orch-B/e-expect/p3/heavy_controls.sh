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
W=${HEAVY_WT:-<SCRATCH>/e-expect-heavy}
PY=/usr/local/bin/python3.10            # pinned 3.10.11; the gate checks its digest
SUBS="$R/proposals/m1b-mission-20261119/drafts/expect-rule/subs/E06-stack-overflow-keyed.dfy
$R/proposals/m1b-mission-20261119/drafts/expect-rule/subs/E07-oom-keyed.dfy
$R/proposals/m1b-mission-20261119/drafts/expect-rule/subs/E08-time-keyed.dfy
$E/p2/subs/H01b-such-that-modulus-hang.dfy
$E/p2/subs/H04-seq-length-2pow32-throws.dfy
$E/p2/subs/H02-exponential-recursion-hang.dfy
$E/p2/subs/H03-seq-comprehension-alloc.dfy"
# 0. Preconditions (refuse, do not wait).
[ -e $L/hol.lock ] && { echo "refused: hol.lock exists"; exit 75; }
pgrep -f 'bin/hol' >/dev/null && { echo "refused: HOL running"; exit 75; }
sw=$(sysctl -n vm.swapusage | sed -E 's/.*free = ([0-9]+)\..*/\1/'); [ "$sw" -lt 1024 ] && { echo "refused: swap $sw"; exit 75; }
mkdir $L/heavy.lock || { echo "heavy.lock held"; exit 76; }
mkdir $L/dafny.lock || { rmdir $L/heavy.lock; echo "dafny.lock held"; exit 76; }
echo e-expect-heavy > $L/dafny.lock/owner; echo e-expect-heavy > $L/heavy.lock/owner
trap 'rm -rf $L/dafny.lock $L/heavy.lock' EXIT
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
      > $E/p3/heavy-$n.log 2>&1
  echo "exit $?" >> $E/p3/heavy-$n.log
  git -C $R show 985f5eaf:impl/Refund.dfy > $W/impl/Refund.dfy; rm -f $W/build/refund-gate.lock
done
# 2. Cleanup: remove the export (it holds no result; logs are in $E/p3).
rm -rf $W
