#!/bin/bash
O=<REPO>/results/night-shift-20261119/orch-B
D=$O/r-integrate; Z3=<REPO>/.toolchain/dafny-4.11.0/dafny/z3/bin/z3-4.12.1
run(){ m=$1; f=$2; L=$D/logs/mut-$m-$f
  $O/tools/dafny_locked.sh r-integrate $D/mut/$m $L.log 90 verify --solver-path $Z3 --resource-limit 1000000 --verification-time-limit 0 --cores 1 --verify-included-files --track-print-effects "--log-format" "csv;LogFileName=$L.csv" $f.dfy >/dev/null 2>&1
  echo "$m $f: $(grep finished $L.log) $(tail -1 $L.log)"; }
run M1-reject-all SinkCoreV3
run M2-commit-all SinkCoreV3
run MA-chargeok-pre-only SinkCoreV3
run MA-chargeok-pre-only MultiCharge
run MA2-chargeok-no-post SinkCoreV3
run MB-reqid-skip-zero SinkCoreV3
run MC-auditstart-true SinkCoreV3
