#!/bin/bash
# h-gate control for C-GATE-02 (red team's nested-brace inputs). Exit 0 = every input refused within 5 s by the
# PROPOSED source scope (run in a child process with a hard alarm); 1 = a defect. Light (Python, no Dafny).
H=<REPO>/results/night-shift-20261119/orch-B/h-gate; B=<REPO>/results/night-shift-20261119/orch-C/c5-gate/bypass
GATE=${1:-$H/gate-new/b/gate/refund.py}; bad=0
for f in $B/D-brace-nest-5000.dfy $B/D-brace-nest-10000.dfy $B/D-brace-nest-20000.dfy $B/C30-brace-nest-dos.dfy; do
  s=$(perl -MTime::HiRes=time -e 'print time')
  out=$(perl -e 'alarm 5; exec @ARGV' /usr/local/bin/python3.10 -I $H/tools/scope_check.py $GATE $f 2>&1); rc=$?
  e=$(perl -MTime::HiRes=time -e 'print time'); t=$(perl -e "printf '%.2f', $e-$s")
  echo "$(basename $f) rc=$rc ${t}s :: ${out##*| }"
  case "$out" in *"| PASS"*) bad=1;; esac; [ $rc -ne 0 ] && bad=1
done
echo "regress_hgate exit $bad"; exit $bad
