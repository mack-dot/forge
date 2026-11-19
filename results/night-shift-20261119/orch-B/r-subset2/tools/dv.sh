#!/bin/bash
# Usage: dv.sh NAME RUNNO [verify|translate|build|audit]. Light tier (90 s). Layout as impl/Refund.dfy. Work copy removed after.
set -u
R=<REPO>; E=$R/results/night-shift-20261119/orch-B/r-subset2
N=$1; K=$2; MODE=${3:-verify}
W=$E/work/$N; rm -rf $W; mkdir -p $W/impl $W/spec/refund $W/gate/refund
cp $R/spec/refund/RefundSpec.dfy $W/spec/refund/; cp $R/gate/refund/Bindings.dfy $W/gate/refund/
cp $E/subs/$N.dfy $W/impl/Refund.dfy
Z3=$R/.toolchain/dafny-4.11.0/dafny/z3/bin/z3-4.12.1
case $MODE in
  verify) ARGS="verify impl/Refund.dfy gate/refund/Bindings.dfy --solver-path $Z3 --resource-limit 1000000 --verification-time-limit 0 --cores 1 --verify-included-files --track-print-effects";;
  build) ARGS="build --target js impl/Refund.dfy --no-verify --output $W/model";;
  audit) ARGS="audit impl/Refund.dfy";;
  *) ARGS="translate js impl/Refund.dfy --no-verify --output $W/model";;
esac
sh $R/results/night-shift-20261119/orch-B/tools/dafny_locked.sh r-subset2 $W $E/logs/$N.$MODE.$K.log 90 $ARGS
[ -f $W/model.js ] && cp $W/model.js $E/js/$N.js
rm -rf $W
echo "$N $MODE exit $(tail -1 $E/logs/$N.$MODE.$K.log)"
