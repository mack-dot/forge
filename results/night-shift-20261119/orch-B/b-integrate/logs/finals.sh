#!/bin/bash
O=/Users/mackianni/forge/results/night-shift-20261119/orch-B
D=$O/b-integrate; Z3=/Users/mackianni/forge/.toolchain/dafny-4.11.0/dafny/z3/bin/z3-4.12.1
for f in SinkCoreV3 SliceSafetyV3 MultiCharge MultiChargeLayered; do
  $O/tools/dafny_locked.sh b-integrate $D $D/logs/final-$f-01.log 90 verify --solver-path $Z3 --resource-limit 1000000 --verification-time-limit 0 --cores 1 --verify-included-files --track-print-effects "--log-format" "csv;LogFileName=$D/logs/final-$f-01.csv" $f.dfy >/dev/null 2>&1
  echo "$f: $(grep finished $D/logs/final-$f-01.log) $(tail -1 $D/logs/final-$f-01.log)"
done
