#!/bin/bash
# c13-gate-js. Usage: dv.sh SRC.dfy TAG [verify|translate] [gate|alone]. One single-file Dafny run (60 s) via orch-B/tools/dafny_locked.sh.
# gate: layout as the gate (impl/Refund.dfy + spec/refund/RefundSpec.dfy from 4af09308 + gate/refund/Bindings.dfy), options = gate dafny.OPTIONS.
# alone: the file by itself (probe). Work copy removed after; model.js kept in js/.
set -u
R=/Users/mackianni/forge; E=$R/results/night-shift-20261119/orch-C/c13-gate-js
SRC=$1; K=$2; MODE=${3:-verify}; LAY=${4:-gate}; N=$(basename $SRC .dfy)
W=$E/work/$N; rm -rf $W; mkdir -p $W/impl $W/spec/refund $W/gate/refund $E/js $E/logs
Z3=$R/.toolchain/dafny-4.11.0/dafny/z3/bin/z3-4.12.1
OPTS="--solver-path $Z3 --resource-limit 1000000 --verification-time-limit 0 --cores 1 --verify-included-files --track-print-effects"
if [ $LAY = gate ]; then
  git -C $R show 4af09308:spec/refund/RefundSpec.dfy > $W/spec/refund/RefundSpec.dfy
  git -C $R show 4af09308:gate/refund/Bindings.dfy > $W/gate/refund/Bindings.dfy
  cp $SRC $W/impl/Refund.dfy; F=impl/Refund.dfy; EXTRA=gate/refund/Bindings.dfy
else
  cp $SRC $W/Probe.dfy; F=Probe.dfy; EXTRA=
fi
case $MODE in
  verify) ARGS="verify $F $EXTRA $OPTS";;
  *) ARGS="translate js $F --no-verify --output $W/model";;
esac
bash $R/results/night-shift-20261119/orch-B/tools/dafny_locked.sh orchC-c13 $W $E/logs/$N.$MODE.$K.log 60 $ARGS
code=$?
[ -f $W/model.js ] && cp $W/model.js $E/js/$N.js
rm -rf $W
echo "$N $MODE exit $code"
exit $code
