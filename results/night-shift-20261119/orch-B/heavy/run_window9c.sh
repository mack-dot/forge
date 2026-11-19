#!/bin/bash
# Orchestrator B: heavy window 9c: spec-conformance heavy run on the hardened sink of the branch worktree (f08a21c1), 5,000 sequences per mode.
[ -e <REPO>/results/night-shift-20261119/locks/hol.lock ] && { echo "refused: hol.lock"; exit 75; }
mkdir <REPO>/results/night-shift-20261119/locks/heavy.lock || exit 76
trap 'rm -rf <REPO>/results/night-shift-20261119/locks/heavy.lock' EXIT
echo orch-B > <REPO>/results/night-shift-20261119/locks/heavy.lock/owner; date -u +%FT%TZ > <REPO>/results/night-shift-20261119/locks/heavy.lock/start
echo "# start $(date -u +%FT%TZ) $(pmset -g batt | head -1) $(sysctl -n vm.swapusage | cut -c1-70)"
cd <SCRATCH>/B-trust && ln -sfn <REPO>/node_modules node_modules
bash tests/refund-finality/spec-conformance/heavy_spec.sh <REPO>/results/night-shift-20261119/orch-B/p-adopt/build/pristine-core/model.cjs <REPO>/results/night-shift-20261119/orch-B/heavy/spec-h-1 <SCRATCH>/B-trust/ts/refund-finality/sink.ts
echo "# heavy_spec exit $? end $(date -u +%FT%TZ)"
