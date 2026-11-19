#!/bin/bash
O=<REPO>/results/night-shift-20261119/orch-B
D=$O/r-integrate; S=$D/src; Z3=<REPO>/.toolchain/dafny-4.11.0/dafny/z3/bin/z3-4.12.1
for f in SinkCoreV3 SliceSafetyV3 MultiCharge MultiChargeLayered; do
  $O/tools/dafny_locked.sh r-integrate $S $D/logs/final-$f-01.log 90 verify --solver-path $Z3 --resource-limit 1000000 --verification-time-limit 0 --cores 1 --verify-included-files --track-print-effects "--log-format" "csv;LogFileName=$D/logs/final-$f-01.csv" $f.dfy >/dev/null 2>&1
  echo "$f: $(grep finished $D/logs/final-$f-01.log) $(tail -1 $D/logs/final-$f-01.log)"
done
for f in SinkCoreV3 SliceSafetyV3 MultiCharge MultiChargeLayered; do
  $O/tools/dafny_locked.sh r-integrate $S $D/logs/audit-$f.log 90 audit --report-format md --report-file $D/logs/audit-$f.md $f.dfy >/dev/null 2>&1
  echo "audit $f: $(tail -1 $D/logs/audit-$f.log); rows: $(grep -c '^|' $D/logs/audit-$f.md 2>/dev/null)"
done
for f in SinkCoreV3 SliceSafetyV3; do
  $O/tools/dafny_locked.sh r-integrate $S $D/logs/translate-$f-01.log 90 translate cs --solver-path $Z3 --resource-limit 1000000 --verification-time-limit 0 --cores 1 --verify-included-files --track-print-effects --output $D/work/translate-out/$f "--log-format" "csv;LogFileName=$D/logs/translate-$f-01.csv" $f.dfy >/dev/null 2>&1
  echo "translate $f: $(grep finished $D/logs/translate-$f-01.log) $(tail -1 $D/logs/translate-$f-01.log)"
done
