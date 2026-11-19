#!/bin/bash
# r-harden: one short scrubbed Node run. usage: run_node.sh LOG TIMEOUT_S <node args...>. Never overwrites a log.
R=<REPO>/results/night-shift-20261119/orch-B/r-harden; LOG=$1; T=$2; shift 2
[ -e "$LOG" ] && { echo "log exists: $LOG"; exit 66; }
{ echo "# start=$(date -u +%FT%TZ) $(pmset -g batt | head -1)"; echo "# cmd: node $*"; } > "$LOG"
cd $R/tree || exit 65
/usr/bin/time -p env -i PATH=/opt/homebrew/bin:/usr/bin:/bin HOME=$R/home TMPDIR=$R/home LANG=C timeout $T node "$@" >> "$LOG" 2>&1; c=$?
echo "# end=$(date -u +%FT%TZ)"  >> "$LOG"; echo "exit $c" >> "$LOG"; echo "exit $c"; exit $c
