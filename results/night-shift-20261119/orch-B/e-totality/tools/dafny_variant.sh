#!/bin/bash
# Usage: dafny_variant.sh SUBDIR NAME MODE(verify|translate) RUNNO. Light tier (60 s). Layout as impl/Refund.dfy.
set -u
R=/Users/mackianni/forge; E=$R/results/night-shift-20261119/orch-B/e-totality
D=$1; N=$2; MODE=$3; K=$4
W=$E/work/$N; mkdir -p $W/impl $W/spec/refund $W/gate/refund
cp $R/spec/refund/RefundSpec.dfy $W/spec/refund/; cp $R/gate/refund/Bindings.dfy $W/gate/refund/
cp $E/subs/$D/$N.dfy $W/impl/Refund.dfy
Z3=$R/.toolchain/dafny-4.11.0/dafny/z3/bin/z3-4.12.1
if [ "$MODE" = verify ]; then
  sh $R/results/night-shift-20261119/orch-B/tools/dafny_locked.sh e-totality $W $E/logs/$N.verify.$K.log 60 \
    verify impl/Refund.dfy gate/refund/Bindings.dfy --solver-path $Z3 --resource-limit 1000000 --verification-time-limit 0 \
    --cores 1 --verify-included-files --track-print-effects
else
  sh $R/results/night-shift-20261119/orch-B/tools/dafny_locked.sh e-totality $W $E/logs/$N.translate.$K.log 60 \
    translate js impl/Refund.dfy --output $W/out/model --solver-path $Z3 --resource-limit 1000000 \
    --verification-time-limit 0 --cores 1
fi
code=$?
echo "$N $MODE exit $code"
