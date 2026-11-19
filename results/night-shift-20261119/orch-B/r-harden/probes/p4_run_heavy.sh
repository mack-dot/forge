#!/bin/bash
# PREPARED, NOT RUN by r-harden. The orchestrator runs it in a heavy window. Refuses while HOL runs. Takes no heavy.lock.
R=<REPO>/results/night-shift-20261119/orch-B/r-harden
[ -e <REPO>/results/night-shift-20261119/locks/hol.lock ] && { echo "refused: hol.lock exists"; exit 75; }
pgrep -f bin/hol >/dev/null && { echo "refused: a HOL process runs"; exit 75; }
mkdir -p $R/tree && git -C <REPO> archive 608b5165 ts tests impl scripts spec interop package.json tsconfig.json | tar -x -C $R/tree
ln -sfn <REPO>/node_modules $R/tree/node_modules
$R/run_node.sh $R/logs/h01-p4_two_process_race.log 120 --import tsx $R/probes/p4_two_process_race.ts $R/tree $R/home/p4; c=$?
rm -rf $R/tree $R/home/p4; exit $c
