#!/bin/sh
# usage: run.sh <script.ts> [args]   (the run recipe of WORKER_RULES.md; HOME = this evidence dir)
unset GH_TOKEN GITHUB_TOKEN
E=/Users/mackianni/forge/results/night-shift-20261119/orch-C/c1-concurrency
cd /private/tmp/claude-501/-Users-mackianni-forge/90d187ef-57dc-4fa3-a5b8-7a6708d00cf2/scratchpad/redteam-C/target-v6 || exit 4
S=$1; shift
exec env -i PATH=/opt/homebrew/bin:/usr/bin:/bin HOME=$E LANG=C NODE_NO_WARNINGS=1 NODE_PATH=/Users/mackianni/forge/node_modules timeout 120 node --import tsx "$E/$S" "$@"
