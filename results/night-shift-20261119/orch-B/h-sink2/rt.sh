#!/bin/bash
# usage: rt.sh <treeRoot> <logfile> <script.ts> <args...>: run a copied red-team or reviewer script against <treeRoot>
T=$1; LOG=$2; S=$3; shift 3
EV=<REPO>/results/night-shift-20261119/orch-B/h-sink2
cd "$T" && env -i PATH=/opt/homebrew/bin:/usr/bin:/bin HOME=$EV LANG=C NODE_PATH=<REPO>/node_modules H_ROOT=$T H_MEM=${H_MEM:-off} \
  timeout 120 node --no-warnings --import tsx "$S" "$@" > "$LOG" 2>&1; rc=$?
echo "# cmd: rt.sh $T $S $*" >> "$LOG"; echo "exit $rc" >> "$LOG"; echo "$(basename $LOG) exit $rc"
