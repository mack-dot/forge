#!/bin/bash
# h-minter3: one light Node run. usage: run_m.sh <treeRoot> <script.ts> <logname> [args...]
H=<REPO>/results/night-shift-20261119/orch-B/h-minter3
T=$1; S=$2; L=$3; shift 3
pmset -g batt | head -1 > $H/runs/$L.log
cd "$T" || exit 65
env -i PATH=/opt/homebrew/bin:/usr/bin:/bin HOME=$H/home LANG=C TMPDIR=$H/home ${EXTRA_ENV} timeout 120 node --import tsx "$S" "$@" >> $H/runs/$L.log 2>&1
rc=$?; echo "exit $rc" >> $H/runs/$L.log; echo "$L exit=$rc"; exit $rc
