#!/bin/bash
# c5-gate regression (orch-C red team, 2026-11-19). Exit 1 = a defect is present; 0 = safe.
# Usage: regress.sh [RULE_PY] [PATCHED_GATE_PY]
#   RULE_PY default: orch-B/e-subset3/subset_rule3.py ; PATCHED_GATE_PY default: gatecopy/refund.py
#   (gatecopy = 4af09308:gate/refund.py + orch-B/e-subset3/diff/refund-subset3-combined-scope.diff).
# D1 (availability): the rule ADMITS bypass/D-brace-nest-10000.dfy (10,000 nested `{` in a ghost requires
#    clause) and needs more than 5 s in-process (quadratic body search); the gate has no time bound for it.
# D2 (TOCTOU): the patched gate runs bounded_subset3 on bytes read in prepare() and takes the input snapshot
#    later in main(); no re-check of the snapshotted bytes follows. Static order check.
set -u
E=$(cd "$(dirname "$0")" && pwd)
RULE=${1:-<REPO>/results/night-shift-20261119/orch-B/e-subset3/subset_rule3.py}
GATE=${2:-$E/gatecopy/refund.py}
PY=/usr/local/bin/python3.10
defect=0
s=$(perl -MTime::HiRes=time -e 'print time')
out=$(timeout 30 $PY -I "$RULE" "$E/bypass/D-brace-nest-10000.dfy" 2>&1); rc=$?
e=$(perl -MTime::HiRes=time -e 'print time'); t=$(perl -e "printf '%.1f', $e-$s")
echo "D1 rule exit $rc elapsed $t s :: ${out##*| }"
if [ $rc -eq 124 ] || { echo "$out" | grep -q '| pass' && perl -e "exit !($t > 5)"; }; then echo "D1 DEFECT: admitted and slow"; defect=1; else echo "D1 safe"; fi
if [ -f "$GATE" ]; then
  r=$($PY -I - "$GATE" <<'PYEOF'
import sys
src = open(sys.argv[1]).read().splitlines()
check = [i for i, l in enumerate(src) if 'bounded_subset3(' in l and 'def ' not in l]
snap = [i for i, l in enumerate(src) if 'before = snapshot(' in l]
prep = [i for i, l in enumerate(src) if 'prepare()' in l and 'def ' not in l]
if not check:
    print('nocheck'); sys.exit()
late = [c for c in check if snap and c > snap[0]]
print('late' if late else 'early', check, snap, prep)
PYEOF
)
  echo "D2 $r"
  case "$r" in early*) echo "D2 DEFECT: rule checks bytes read before the input snapshot; no re-check"; defect=1;; *) echo "D2 safe or not applicable";; esac
else
  echo "D2 NOT RUN: no gate file $GATE"
fi
echo "regress exit $defect"
exit $defect
