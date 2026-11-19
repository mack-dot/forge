#!/bin/bash
# d-v6sink: single short Node runs (pinned Node 24.3.0, env -i, HOME = this folder). Usage: run_node.sh <suffix> <steps...>
# steps: n (31 conformance cases, 5 sinks), k (attack_v6), s (ONE 20,000-row scaling probe), m (d-minter tokens -> v6)
W=/Users/mackianni/forge/results/night-shift-20261119/orch-B/d-v6sink; L=$W/logs; R=/Users/mackianni/forge
export PATH=/opt/homebrew/bin:/usr/bin:/bin
[ "$(node --version)" = "v24.3.0" ] || { echo "not the pinned Node"; exit 2; }
x=$1; shift; cd $R
run() { local name=$1; shift; { echo "# start=$(date -u +%FT%TZ) cmd: node --import tsx $*"; /usr/bin/time -l env -i PATH=$PATH HOME=$W NODE_PATH=$R/node_modules node --import tsx "$@" 2>&1; echo "exit $?"; } > $L/$name$x.log 2>&1; tail -1 $L/$name$x.log; }
for st in "$@"; do case $st in
 n) run n01-conformance-v6 $W/ts/conformance_v6.ts $W/ts/conformance-v6$x.json;;
 k) run k01-attack-v6 $W/ts/attack_v6.ts $W/work-attack;;
 s) run s01-scale20k-v6 $W/ts/probe_scale_v6.ts $W/work-scale 20000;;
 m) run m01-minterconf-v6 $W/minterconf/run_v6.ts $R/results/night-shift-20261119/orch-B/d-minter/build/issuebytes2.cjs $R/spec.lock $W/minterconf/result-v6$x.json;;
esac; done
