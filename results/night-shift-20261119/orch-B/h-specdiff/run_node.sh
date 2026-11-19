#!/bin/bash
# h-specdiff: one short scrubbed Node run (light). Usage: run_node.sh CWD LOG TIMEOUT_S <node args...>
H=/Users/mackianni/forge/results/night-shift-20261119/orch-B/h-specdiff; CWD=$1; LOG=$2; T=$3; shift 3
pmset -g batt | head -1 | grep -q "AC Power" || { echo "refused: not on AC power" > "$LOG"; echo "exit 75" >> "$LOG"; exit 75; }
cd "$CWD" || exit 65
{ echo "# start=$(date -u +%FT%TZ) cwd=$CWD node=$(env -i PATH=/opt/homebrew/bin:/usr/bin:/bin node --version)"; echo "# cmd: node $*"; } > "$LOG"
/usr/bin/time -l env -i PATH=/opt/homebrew/bin:/usr/bin:/bin HOME=$H/home LANG=C TMPDIR=$H/home timeout $T node --no-warnings "$@" >> "$LOG" 2>&1; c=$?
echo "# end=$(date -u +%FT%TZ)" >> "$LOG"; echo "exit $c" >> "$LOG"; exit $c
