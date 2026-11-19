#!/bin/bash
# Usage: runall.sh NAME... : build js/NAME.cjs and run drive2.cjs once under the hard limit.
D=<REPO>/results/night-shift-20261119/orch-B/r-subset3b
for n in "$@"; do
  [ -f $D/js/$n.js ] || { echo "$n NO-JS"; continue; }
  bash $D/tools/mkcjs.sh $n
  out=$(bash $D/tools/run2s.sh $D/js/drive2.cjs $D/js/$n.cjs 2>&1)
  echo "$n | $(echo "$out" | grep -E 'MISMATCH|ALL-OK|Error|FAIL' | head -3 | tr '\n' ' ') | $(echo "$out" | tail -1)"
done
