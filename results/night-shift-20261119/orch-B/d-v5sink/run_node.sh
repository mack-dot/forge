#!/bin/bash
# d-v5sink: single short Node runs (pinned Node 24.3.0, env -i, HOME = this folder). Usage: run_node.sh <suffix> <steps...>
# steps: n (31 conformance cases), k (attack_v5), d (d_sink_v5), s (ONE 20,000-row scaling probe)
W=<REPO>/results/night-shift-20261119/orch-B/d-v5sink; L=$W/logs; R=<REPO>
export PATH=/opt/homebrew/bin:/usr/bin:/bin
[ "$(node --version)" = "v24.3.0" ] || { echo "not the pinned Node"; exit 2; }
x=$1; shift; cd $R
run() { local name=$1; shift; { echo "# start=$(date -u +%FT%TZ) cmd: node --import tsx $*"; /usr/bin/time -l env -i PATH=$PATH HOME=$W NODE_PATH=$R/node_modules node --import tsx "$@" 2>&1; echo "exit $?"; } > $L/$name$x.log 2>&1; tail -1 $L/$name$x.log; }
for st in "$@"; do case $st in
 n) run n01-conformance-v5 $W/ts/conformance_v5.ts $W/ts/conformance-v5$x.json;;
 k) run k01-attack-v5 $W/ts/attack_v5.ts $W/work-attack;;
 d) run r01-dsink-v5 $W/ts/d_sink_v5.ts $W/work-dsink;;
 s) run s01-scale20k-v5 $W/ts/probe_scale_v5.ts $W/work-scale 20000;;
esac; done
