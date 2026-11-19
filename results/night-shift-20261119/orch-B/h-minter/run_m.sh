#!/bin/bash
# h-minter: one light Node run (seconds). usage: run_m.sh <treeRoot> <compiledModule> <script.ts> <logname> [extra args]
H=<REPO>/results/night-shift-20261119/orch-B/h-minter
T=$1; M=$2; S=$3; L=$4; shift 4
pmset -g batt | head -1 | grep -q "AC Power" || { echo "not on AC power"; exit 75; }
cd "$T" || exit 65
env -i PATH=/opt/homebrew/bin:/usr/bin:/bin HOME=$H/home LANG=C TMPDIR=$H/home timeout 120 node --import tsx "$S" "$T" "$M" "$@" > $H/runs/$L.log 2>&1
rc=$?; echo "exit $rc" >> $H/runs/$L.log; echo "$L exit=$rc"; exit $rc
