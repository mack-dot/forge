#!/bin/bash
# r-v5: single short Node runs (pinned Node 24.3.0, env -i, HOME = this folder). Usage: run_node.sh <logname> <script> <args...>
W=/Users/mackianni/forge/results/night-shift-20261119/orch-B/r-v5; R=/Users/mackianni/forge
export PATH=/opt/homebrew/bin:/usr/bin:/bin
[ "$(node --version)" = "v24.3.0" ] || { echo "not the pinned Node"; exit 2; }
[ -e $R/results/night-shift-20261119/locks/hol.lock ] && { echo "hol.lock exists"; exit 3; }
name=$1; shift; n=1; while [ -e $W/logs/$name-$n.log ]; do n=$((n+1)); done; cd $R
{ echo "# start=$(date -u +%FT%TZ) cmd: node --import tsx $*"; /usr/bin/time -l env -i PATH=$PATH HOME=$W/home NODE_PATH=$R/node_modules node --import tsx "$@" 2>&1; echo "exit $?"; } > $W/logs/$name-$n.log 2>&1
echo $W/logs/$name-$n.log
