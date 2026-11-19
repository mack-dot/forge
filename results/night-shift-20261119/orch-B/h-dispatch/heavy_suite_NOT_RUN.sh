#!/bin/bash
# NOT RUN by h-dispatch. For the orchestrator's heavy window only. Runs the full refund-finality suite (multi-minute,
# many processes) on a fresh export of 608b5165 with h-dispatch.diff AND unapplied/suite-C-ATT-18.diff applied.
# Refuses while results/night-shift-20261119/locks/hol.lock exists or a HOL process runs. Does not take heavy.lock.
# Usage: bash heavy_suite_NOT_RUN.sh <empty work dir>
set -u
F=/Users/mackianni/forge; H=$F/results/night-shift-20261119/orch-B/h-dispatch; W=${1:?work dir}
[ -e $F/results/night-shift-20261119/locks/hol.lock ] && { echo "refused: hol.lock exists"; exit 75; }
pgrep -f bin/hol >/dev/null && { echo "refused: a HOL process runs"; exit 75; }
mkdir -p "$W" && cd "$W" || exit 4
git -C $F archive 608b5165 ts tests impl scripts spec interop proposals/forge2-pillar2-finality-protocol package.json tsconfig.json | tar -x
ln -s $F/node_modules node_modules; ln -s $F/.toolchain .toolchain; git init -q .
git apply $H/h-dispatch.diff && git apply $H/unapplied/suite-C-ATT-18.diff || exit 5
env -i PATH=/opt/homebrew/bin:/usr/bin:/bin HOME="$W" LANG=C node --import tsx tests/refund-finality/suite.ts "$W/out" $F/results/night-shift-20261119/orch-B/h-minter/build/issueonce.cjs; echo "exit $?"
# Note: suite.ts on 608b5165 (unchanged) may already fail rows that write raw SQL into the hardened store (triggers);
# compare with the same run WITHOUT the two diffs before judging.
