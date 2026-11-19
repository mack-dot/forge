#!/bin/bash
# Usage: vt.sh SRC.dfy [RUNNO]. ONE Dafny run (light, 60 s) through orch-B/tools/dafny_locked.sh:
# `dafny translate js` WITH verification (gate verifier options), layout as the gate (impl/Refund.dfy + spec).
# Exit 0 = verified AND translated. Output js/NAME.js (modules only, as tr.sh of B). Work copy removed.
set -u
R=/Users/mackianni/forge; E=$R/results/night-shift-20261119/orch-C/c23-jsgate
SRC=$1; K=${2:-1}; N=$(basename $SRC .dfy)
W=$E/work/$N; rm -rf $W; mkdir -p $W/impl $W/spec/refund
cp $R/spec/refund/RefundSpec.dfy $W/spec/refund/; cp $SRC $W/impl/Refund.dfy
Z3=$R/.toolchain/dafny-4.11.0/dafny/z3/bin/z3-4.12.1
sh $R/results/night-shift-20261119/orch-B/tools/dafny_locked.sh c23-jsgate $W $E/logs/$N.vt.$K.log 60 translate js impl/Refund.dfy \
  --solver-path $Z3 --resource-limit 1000000 --verification-time-limit 0 --cores 1 --verify-included-files --track-print-effects --output $W/model
rc=$?
[ $rc -eq 0 ] && [ -f $W/model.js ] && cp $W/model.js $E/js/$N.js
rm -rf $W
echo "$N vt rc=$rc $(grep -E 'verified|error|Error' $E/logs/$N.vt.$K.log | head -3 | tr '\n' ' ')"
exit $rc
