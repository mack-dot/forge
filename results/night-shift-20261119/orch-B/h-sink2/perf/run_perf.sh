#!/bin/bash
# usage: run_perf.sh <treeRoot> <mode> <log>. Mode commits1000 (about 17 s with fullfsync) refuses while locks/hol.lock exists or a HOL process runs. 60 s limit.
L=<REPO>/results/night-shift-20261119/locks
if [ "$2" = commits1000 ] && { [ -e $L/hol.lock ] || pgrep -f bin/hol > /dev/null; }; then echo "REFUSED: hol.lock or HOL process" > "$3"; echo "exit 75" >> "$3"; exit 75; fi
EV=<REPO>/results/night-shift-20261119/orch-B/h-sink2
{ pmset -g batt | head -1; sysctl vm.swapusage; } > "$3"
cd "$1" && env -i PATH=/opt/homebrew/bin:/usr/bin:/bin HOME=$EV /usr/bin/time -l timeout 60 node --no-warnings --import tsx $EV/perf/perf.ts "$1" "$2" $EV/work/perf-$2 >> "$3" 2>&1; rc=$?
echo "exit $rc" >> "$3"; echo "$(basename $3) exit $rc"
