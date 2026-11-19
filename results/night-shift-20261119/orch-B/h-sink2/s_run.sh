#!/bin/bash
# usage: s_run.sh <treeRoot (code under test)> <logfile> <s_name>: runs tree/tests/.../s_<name>.ts (always from the FIXED
# tree's test directory) against <treeRoot>.
T=$1; LOG=$2; N=$3
EV=<REPO>/results/night-shift-20261119/orch-B/h-sink2
cd "$EV/tree" && env -i PATH=/opt/homebrew/bin:/usr/bin:/bin HOME=$EV LANG=C timeout 120 node --no-warnings --import tsx \
  tests/refund-finality/regress/$N.ts "$T" <REPO>/results/night-shift-20261119/orch-B/h-minter/build/issueonce.cjs > "$LOG" 2>&1; rc=$?
echo "# cmd: (cwd $EV/tree) node --import tsx tests/refund-finality/regress/$N.ts $T <issueonce.cjs>" >> "$LOG"; echo "exit $rc" >> "$LOG"; echo "$(basename $LOG) exit $rc"
