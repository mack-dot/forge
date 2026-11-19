#!/bin/bash
# Usage: dv.sh SRC.dfy TAG [verify|translate]. One single-file Dafny run (60 s) through orch-B/tools/dafny_locked.sh.
# Layout as the gate: impl/Refund.dfy + spec/refund/RefundSpec.dfy (+ gate/refund/Bindings.dfy). Work copy removed after.
set -u
R=/Users/mackianni/forge; E=$R/results/night-shift-20261119/orch-C/c5-gate
SRC=$1; K=$2; MODE=${3:-verify}; N=$(basename $SRC .dfy)
W=$E/work/$N; rm -rf $W; mkdir -p $W/impl $W/spec/refund $W/gate/refund $E/js
git -C $R show 4af09308:spec/refund/RefundSpec.dfy > $W/spec/refund/RefundSpec.dfy
git -C $R show 4af09308:gate/refund/Bindings.dfy > $W/gate/refund/Bindings.dfy
cp $SRC $W/impl/Refund.dfy
Z3=$R/.toolchain/dafny-4.11.0/dafny/z3/bin/z3-4.12.1
case $MODE in
  verify) ARGS="verify impl/Refund.dfy gate/refund/Bindings.dfy --solver-path $Z3 --resource-limit 1000000 --verification-time-limit 0 --cores 1 --verify-included-files --track-print-effects";;
  *) ARGS="translate js impl/Refund.dfy --no-verify --output $W/model";;
esac
bash $R/results/night-shift-20261119/orch-B/tools/dafny_locked.sh orchC-c5 $W $E/logs/$N.$MODE.$K.log 60 $ARGS
code=$?
[ -f $W/model.js ] && cp $W/model.js $E/js/$N.js
rm -rf $W
echo "$N $MODE exit $code"
exit $code
