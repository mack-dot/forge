#!/bin/bash
# usage: run.sh <script.ts> [args...]   (scrubbed env, cwd = target-v6, 120 s)
cd /private/tmp/claude-501/-Users-mackianni-forge/90d187ef-57dc-4fa3-a5b8-7a6708d00cf2/scratchpad/redteam-C/target-v6 || exit 2
S=$1; shift
exec env -i PATH=/opt/homebrew/bin:/usr/bin:/bin HOME=/Users/mackianni/forge/results/night-shift-20261119/orch-C/c15-storage LANG=C \
  NODE_PATH=/Users/mackianni/forge/node_modules timeout 120 node --import tsx /Users/mackianni/forge/results/night-shift-20261119/orch-C/c15-storage/$S "$@"
