#!/bin/bash
# judge.sh <tag> <sink.ts> <dispatcher.ts>: runs BOTH judges of cf242303 (fix-f08a21c1 tree), scrubbed env, cwd = tree.
# regress: tests/refund-finality/regress/run.ts <sink> <dispatcher>; spec: spec-conformance/run.ts <sink> seq 200 1 <model> <work> --dispatcher <d>
EV=<REPO>/results/night-shift-20261119/orch-C/c19-dispatch2; L=$EV/judges/logs; mkdir -p $L $EV/judges/work/$1
MODEL=<REPO>/results/night-shift-20261119/orch-B/p-adopt/build/pristine-core/model.cjs
TO=300 $EV/run.sh tests/refund-finality/regress/run.ts "$2" "$3" > $L/$1.regress.log 2>&1; echo "exit $?" >> $L/$1.regress.log
TO=300 $EV/run.sh tests/refund-finality/spec-conformance/run.ts "$2" seq 200 1 $MODEL $EV/judges/work/$1 --dispatcher "$3" > $L/$1.spec.log 2>&1; echo "exit $?" >> $L/$1.spec.log
rm -rf $EV/judges/work/$1
