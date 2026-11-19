#!/bin/bash
# c13-gate-js regression (orch-C red team, 2026-11-19). Exit 1 = a defect is present; 0 = safe.
# Usage: regress.sh [RULE_PY]   (default: orch-B/e-subset3/subset_rule3.py). No Dafny run; Node + Python only.
# R1 (rule defect, gate still safe): rule 3's "ghost member without body" check looks only at the LAST token
#    of the declaration (`}`). A bodiless lemma / ghost predicate / ghost method whose last spec clause ends in a
#    set display `{1}` or `{}` is ADMITTED. Dafny 4.11 then refuses it only because of warnings
#    (verify exit 2, translate exit 3, audit exit 2; logs/A01-*, A02-*). Any admitted file here = defect.
# C1/C2 (controls, runtime): stored compiled probes; exit 1 if the runtime ever differs from the verifier's
#    verdicts recorded on 2026-11-19 (Probe: 29 predicates, P03 false; B01: 2000 cases x 3 seeds).
set -u
E=$(cd "$(dirname "$0")" && pwd)
RULE=${1:-/Users/mackianni/forge/results/night-shift-20261119/orch-B/e-subset3/subset_rule3.py}
PY=/usr/local/bin/python3.10
NODE="env -i PATH=/opt/homebrew/bin:/usr/bin:/bin HOME=$E LANG=C NODE_PATH=/Users/mackianni/forge/node_modules timeout 120 node"
defect=0
for f in A01-bodiless-lemma-brace-end A02-bodiless-ghost-pred-brace-end A13-ghost-method-bodiless-brace \
         A14-lemma-ensures-set-literal-end A15-forall-ensures-in-lemma A16-induction-false-lemma A17-isolate-on-bodiless; do
  out=$(timeout 30 $PY -I "$RULE" "$E/subs/$f.dfy" 2>&1)
  case "$out" in *"| pass"*) echo "R1 DEFECT admitted: $f"; defect=1;; *) echo "R1 refused: $f :: ${out##*| }";; esac
done
cd "$E"
$NODE tools/run_probe.cjs js/Probe.js probe/probe_args.json P03 > /dev/null 2>&1; c=$?
echo "C1 probe runtime vs verifier exit $c"; [ $c -ne 0 ] && defect=1
for sd in 7 8 9; do $NODE tools/oracle.cjs js/B01-verbatim-cr-dead-branch.js $sd > /dev/null 2>&1; c=$?
  echo "C2 B01 oracle seed $sd exit $c"; [ $c -ne 0 ] && defect=1; done
echo "regress exit $defect"
exit $defect
