#!/bin/bash
O=/Users/mackianni/forge/results/night-shift-20261119/orch-B
D=$O/b-integrate; Z3=/Users/mackianni/forge/.toolchain/dafny-4.11.0/dafny/z3/bin/z3-4.12.1
run(){ m=$1; f=$2; L=$D/logs/$m-$f
  $O/tools/dafny_locked.sh b-integrate $D/controls/$m $L.log 90 verify --solver-path $Z3 --resource-limit 1000000 --verification-time-limit 0 --cores 1 --verify-included-files --track-print-effects "--log-format" "csv;LogFileName=$L.csv" $f.dfy >/dev/null 2>&1
  echo "$m $f: $(grep finished $L.log) $(tail -1 $L.log)"; }
run M1-reject-all SliceSafetyV3
run M2-commit-all SinkCoreV3
run M3-no-chargeid-check SliceSafetyV3
run M3-no-chargeid-check MultiCharge
run M4-no-reqid-check SinkCoreV3
run M5-drop-H1-L2 SliceSafetyV3
run M6-drop-A2-L2 SliceSafetyV3
