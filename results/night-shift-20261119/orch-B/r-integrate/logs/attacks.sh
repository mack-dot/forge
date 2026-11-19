#!/bin/bash
O=<REPO>/results/night-shift-20261119/orch-B
D=$O/r-integrate; W=$D/work; Z3=<REPO>/.toolchain/dafny-4.11.0/dafny/z3/bin/z3-4.12.1
G="--solver-path $Z3 --resource-limit 1000000 --verification-time-limit 0 --cores 1 --verify-included-files --track-print-effects"
N=${1:-01}
for f in AttackCore AttackMulti AttackTrace; do
  $O/tools/dafny_locked.sh r-integrate $W $D/logs/$f-$N.log 90 verify $G "--log-format" "csv;LogFileName=$D/logs/$f-$N.csv" $f.dfy >/dev/null 2>&1
  echo "$f: $(grep -E 'finished' $D/logs/$f-$N.log) $(tail -1 $D/logs/$f-$N.log)"
done
$O/tools/dafny_locked.sh r-integrate $W $D/logs/translate-js-AuditCompile-$N.log 90 translate js $G --output $W/js-out/AuditCompile AuditCompile.dfy >/dev/null 2>&1
echo "translate js AuditCompile: $(grep finished $D/logs/translate-js-AuditCompile-$N.log) $(tail -1 $D/logs/translate-js-AuditCompile-$N.log)"
