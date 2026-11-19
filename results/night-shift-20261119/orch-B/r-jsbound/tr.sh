#!/bin/bash
# Usage: tr.sh SRC.dfy [RUNNO]. Same as h-gate/tools/tr.sh (translate js --no-verify, gate layout), output r-jsbound/js/NAME.js
set -u
R=<REPO>; E=$R/results/night-shift-20261119/orch-B/r-jsbound
SRC=$1; K=${2:-1}; N=$(basename $SRC .dfy)
W=$E/work/$N; rm -rf $W; mkdir -p $W/impl $W/spec/refund
cp $R/spec/refund/RefundSpec.dfy $W/spec/refund/; cp $SRC $W/impl/Refund.dfy
sh $R/results/night-shift-20261119/orch-B/tools/dafny_locked.sh r-jsbound $W $E/logs/$N.translate.$K.log 90 translate js impl/Refund.dfy --no-verify --output $W/model
[ -f $W/model.js ] && cp $W/model.js $E/js/$N.js
rm -rf $W
echo "$N translate $(tail -1 $E/logs/$N.translate.$K.log)"
