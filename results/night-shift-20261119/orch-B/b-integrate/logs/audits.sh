#!/bin/bash
O=/Users/mackianni/forge/results/night-shift-20261119/orch-B
D=$O/b-integrate
for f in SinkCoreV3 SliceSafetyV3 MultiCharge MultiChargeLayered; do
  $O/tools/dafny_locked.sh b-integrate $D $D/logs/audit-$f.log 90 audit --report-format md --report-file $D/logs/audit-$f.md $f.dfy >/dev/null 2>&1
  echo "audit $f: $(tail -1 $D/logs/audit-$f.log); rows: $(grep -c '^|' $D/logs/audit-$f.md 2>/dev/null)"
done
