#!/bin/bash
# c23-jsgate regression. Exit 1 if the JS bound checker ACCEPTS any confirmed accepted-and-unsafe module
# (defect present); 0 if it refuses all of them. Usage: bash regress.sh [CHECKER.cjs]
# Each module is a real `dafny translate js` output of a .dfy that verified (logs/*.vt.*.log end "exit 0"),
# checked as the critical tier does (--no-load) and as the hostile tier does (gate-style build, with the load check).
E=<REPO>/results/night-shift-20261119/orch-C/c23-jsgate
CHK=${1:-<REPO>/results/night-shift-20261119/orch-B/h-gate/js_bound_check.cjs}
CONFIRMED="U01-mod-hidden-growth U02-set-equality-quadratic"
bad=0
for n in $CONFIRMED; do
  [ -f $E/js/$n.js ] || { echo "$n: no js (skipped)"; continue; }
  bash $E/tools/mkbuild.sh $E/js/$n.js > /dev/null
  for f in $E/js/$n.js $E/build/$n.build.js; do
    opt=""; case $f in *.build.js) ;; *) opt="--no-load";; esac
    out=$(env -i PATH=/opt/homebrew/bin:/usr/bin:/bin HOME=$E/work perl -e 'alarm 120; exec @ARGV' /opt/homebrew/bin/node "$CHK" $opt --work=$E/work "$f" 2>&1)
    v=$(echo "$out" | grep -o '"verdict":"[A-Z]*"' | tail -1)
    echo "$(basename $f) $v"
    case "$v" in *ACCEPT*) bad=1;; esac
  done
done
echo "regress exit $bad"; exit $bad
