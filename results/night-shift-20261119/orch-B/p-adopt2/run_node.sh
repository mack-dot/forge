#!/bin/bash
# p-adopt2: one short scrubbed Node run. Usage: run_node.sh CWD LOG TIMEOUT_S <node args...>. Refuses no light run.
P=/Users/mackianni/forge/results/night-shift-20261119/orch-B/p-adopt2; CWD=$1; LOG=$2; T=$3; shift 3
cd "$CWD" || exit 65
{ echo "# start=$(date -u +%FT%TZ) cwd=$CWD node=$(env -i PATH=/opt/homebrew/bin:/usr/bin:/bin node --version)"; echo "# cmd: node $*"; } > "$LOG"
/usr/bin/time -p env -i PATH=/opt/homebrew/bin:/usr/bin:/bin HOME=$P/home LANG=C timeout $T node "$@" >> "$LOG" 2>&1; c=$?
echo "# end=$(date -u +%FT%TZ)" >> "$LOG"; echo "exit $c" >> "$LOG"; exit $c
