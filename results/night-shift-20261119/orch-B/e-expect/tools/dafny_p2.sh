#!/bin/bash
# Usage: dafny_p2.sh NAME MODE(verify|audit) RUNNO. Light tier (60 s). Workdir = e-expect/p2/work/NAME.
set -u
R=<REPO>; E=$R/results/night-shift-20261119/orch-B/e-expect
N=$1; MODE=$2; K=$3
W=$E/p2/work/$N; mkdir -p $W/impl $W/spec/refund $W/gate/refund $W/.toolchain
cp $R/spec/refund/RefundSpec.dfy $W/spec/refund/; cp $R/gate/refund/Bindings.dfy $W/gate/refund/
cp $E/p2/subs/$N.dfy $W/impl/Refund.dfy
Z3=$R/.toolchain/dafny-4.11.0/dafny/z3/bin/z3-4.12.1
if [ "$MODE" = verify ]; then
  sh $R/results/night-shift-20261119/orch-B/tools/dafny_locked.sh e-expect $W $E/p2/logs/$N.verify.$K.log 60 \
    verify impl/Refund.dfy gate/refund/Bindings.dfy --solver-path $Z3 --resource-limit 1000000 --verification-time-limit 0 \
    --cores 1 --verify-included-files --track-print-effects
else
  cp $R/gate/expected-audit.md $W/audit.md
  sh $R/results/night-shift-20261119/orch-B/tools/dafny_locked.sh e-expect $W $E/p2/logs/$N.audit.$K.log 60 \
    audit impl/Refund.dfy gate/refund/Bindings.dfy --report-format md --report-file $W/audit.md --compare-report
fi
echo "$N $MODE exit $?"
