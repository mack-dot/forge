#!/bin/bash
# spec_only.sh <tree> <sink.ts> <mode> <count> <seed> <tag>: one spec-conformance run, scrubbed env, cwd = tree.
EV=<REPO>/results/night-shift-20261119/orch-C/c10-judges
MODEL=${MODEL:-<REPO>/results/night-shift-20261119/orch-B/p-adopt/build/pristine-core/model.cjs}
cd "$1" || exit 3
env -i PATH=/opt/homebrew/bin:/usr/bin:/bin HOME=$EV TMPDIR=$EV/tmp LANG=C NODE_PATH=<REPO>/node_modules \
  timeout 120 node --no-warnings --import tsx tests/refund-finality/spec-conformance/run.ts "$2" "$3" "$4" "$5" "$MODEL" "$EV/work" > "$EV/logs/$6.spec.log" 2>&1
echo "exit $?" >> "$EV/logs/$6.spec.log"
