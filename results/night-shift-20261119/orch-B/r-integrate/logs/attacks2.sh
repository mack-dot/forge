#!/bin/bash
O=/Users/mackianni/forge/results/night-shift-20261119/orch-B
D=$O/r-integrate; W=$D/work; Z3=/Users/mackianni/forge/.toolchain/dafny-4.11.0/dafny/z3/bin/z3-4.12.1
G="--solver-path $Z3 --resource-limit 1000000 --verification-time-limit 0 --cores 1 --verify-included-files --track-print-effects"
$O/tools/dafny_locked.sh r-integrate $W $D/logs/translate-js-AuditCompile-02.log 90 translate js $G --output $W/js-out/AuditCompile AuditCompile.dfy >/dev/null 2>&1
echo "translate js AuditCompile: $(grep finished $D/logs/translate-js-AuditCompile-02.log) $(tail -1 $D/logs/translate-js-AuditCompile-02.log)"
$O/tools/dafny_locked.sh r-integrate $W $D/logs/AttackBurn-01.log 90 verify $G "--log-format" "csv;LogFileName=$D/logs/AttackBurn-01.csv" AttackBurn.dfy >/dev/null 2>&1
echo "AttackBurn: $(grep finished $D/logs/AttackBurn-01.log) $(tail -1 $D/logs/AttackBurn-01.log)"
for f in AttackCore AttackMulti AttackTrace AttackBurn; do
  $O/tools/dafny_locked.sh r-integrate $W $D/logs/audit-$f.log 90 audit --report-format md --report-file $D/logs/audit-$f.md $f.dfy >/dev/null 2>&1
  echo "audit $f: $(tail -1 $D/logs/audit-$f.log); rows: $(grep -c '^|' $D/logs/audit-$f.md 2>/dev/null)"
done
