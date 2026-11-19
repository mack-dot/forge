#!/bin/bash
# h-regress: one short scrubbed Node run of the regression runner. Usage: run_light.sh LOG <runner args...>
# Refuses unless on AC power. Light run: one process, seconds, temp dirs under h-regress/tmp (TMPDIR), removed at exit.
D=<REPO>/results/night-shift-20261119/orch-B/h-regress; LOG=$1; shift
pmset -g batt | head -1 | grep -q "AC Power" || { echo "not on AC power" > "$LOG"; echo "exit 75" >> "$LOG"; exit 75; }
cd $D/tree-a || exit 65
{ echo "# start=$(date -u +%FT%TZ) node=$(env -i PATH=/opt/homebrew/bin:/usr/bin:/bin node --version)"; echo "# cmd: node --import tsx $D/work/tests/refund-finality/regress/run.ts $*"; } > "$LOG"
env -i PATH=/opt/homebrew/bin:/usr/bin:/bin HOME=$D/home TMPDIR=$D/tmp LANG=C timeout 20 node --import tsx $D/work/tests/refund-finality/regress/run.ts "$@" >> "$LOG" 2>&1; c=$?
echo "# end=$(date -u +%FT%TZ) tmp-left=$(ls $D/tmp | grep -c forge-regress | tr -d ' ')" >> "$LOG"; echo "exit $c" >> "$LOG"; exit $c
