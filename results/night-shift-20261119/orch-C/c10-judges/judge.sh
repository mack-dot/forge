#!/bin/bash
# judge.sh <tree> <sink.ts> <dispatcher.ts> <tag> : runs BOTH judges (regress run.ts; spec-conformance run.ts seq 200 1)
# with the scrubbed env, cwd = <tree>. Writes logs/<tag>.regress.log and logs/<tag>.spec.log with actual exit codes.
EV=/Users/mackianni/forge/results/night-shift-20261119/orch-C/c10-judges
T=$1; S=$2; D=$3; TAG=$4; MODEL=${MODEL:-/Users/mackianni/forge/results/night-shift-20261119/orch-B/p-adopt/build/pristine-core/model.cjs}
SEQN=${SEQN:-200}; SEED=${SEED:-1}
E="env -i PATH=/opt/homebrew/bin:/usr/bin:/bin HOME=$EV TMPDIR=$EV/tmp LANG=C NODE_PATH=/Users/mackianni/forge/node_modules"
cd "$T" || exit 3
$E timeout 120 node --no-warnings --import tsx tests/refund-finality/regress/run.ts "$S" "$D" > "$EV/logs/$TAG.regress.log" 2>&1; echo "exit $?" >> "$EV/logs/$TAG.regress.log"
$E timeout 120 node --no-warnings --import tsx tests/refund-finality/spec-conformance/run.ts "$S" seq "$SEQN" "$SEED" "$MODEL" "$EV/work" > "$EV/logs/$TAG.spec.log" 2>&1; echo "exit $?" >> "$EV/logs/$TAG.spec.log"
