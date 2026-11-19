#!/bin/bash
# Usage: dv3.sh SRC.dfy RUNNO [verify|translate]. Light tier (90 s) through dafny_locked.sh. Layout as impl/Refund.dfy.
# Copy of r-subset2/tools/dv.sh with a source path. The work copy is removed after the run.
set -u
R=<REPO>; E=$R/results/night-shift-20261119/orch-B/e-subset3
SRC=$1; K=$2; MODE=${3:-verify}; N=$(basename $SRC .dfy)
W=$E/work/$N; rm -rf $W; mkdir -p $W/impl $W/spec/refund $W/gate/refund
cp $R/spec/refund/RefundSpec.dfy $W/spec/refund/; cp $R/gate/refund/Bindings.dfy $W/gate/refund/
cp $SRC $W/impl/Refund.dfy
Z3=$R/.toolchain/dafny-4.11.0/dafny/z3/bin/z3-4.12.1
case $MODE in
  verify) ARGS="verify impl/Refund.dfy gate/refund/Bindings.dfy --solver-path $Z3 --resource-limit 1000000 --verification-time-limit 0 --cores 1 --verify-included-files --track-print-effects";;
  *) ARGS="translate js impl/Refund.dfy --no-verify --output $W/model";;
esac
sh $R/results/night-shift-20261119/orch-B/tools/dafny_locked.sh e-subset3 $W $E/logs/$N.$MODE.$K.log 90 $ARGS
[ -f $W/model.js ] && cp $W/model.js $E/js/$N.js
rm -rf $W
echo "$N $MODE $(tail -1 $E/logs/$N.$MODE.$K.log)"
