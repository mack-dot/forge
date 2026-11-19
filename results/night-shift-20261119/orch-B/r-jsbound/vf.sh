#!/bin/bash
# Usage: vf.sh SRC.dfy [RUNNO]. Gate verify options, gate layout.
set -u
R=<REPO>; E=$R/results/night-shift-20261119/orch-B/r-jsbound
SRC=$1; K=${2:-1}; N=$(basename $SRC .dfy)
W=$E/work/v-$N; rm -rf $W; mkdir -p $W/impl $W/spec/refund
cp $R/spec/refund/RefundSpec.dfy $W/spec/refund/; cp $SRC $W/impl/Refund.dfy
sh $R/results/night-shift-20261119/orch-B/tools/dafny_locked.sh r-jsbound $W $E/logs/$N.verify.$K.log 90 verify --solver-path $R/.toolchain/dafny-4.11.0/dafny/z3/bin/z3-4.12.1 --resource-limit 1000000 --verification-time-limit 0 --cores 1 --verify-included-files --track-print-effects impl/Refund.dfy
rm -rf $W
echo "$N verify $(tail -1 $E/logs/$N.verify.$K.log)"
