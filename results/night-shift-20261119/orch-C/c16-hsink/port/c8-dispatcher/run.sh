#!/bin/sh
# Usage: run.sh <script.ts> <args...>  (cwd = target-v6, scrubbed env per WORKER_RULES)
D=/private/tmp/claude-501/-Users-mackianni-forge/90d187ef-57dc-4fa3-a5b8-7a6708d00cf2/scratchpad/redteam-C/retarget-608b5165/c8-dispatcher
cd /private/tmp/claude-501/-Users-mackianni-forge/90d187ef-57dc-4fa3-a5b8-7a6708d00cf2/scratchpad/redteam-C/fix-608b5165 || exit 4
S=$1; shift
exec env -i PATH=/opt/homebrew/bin:/usr/bin:/bin HOME=$D LANG=C NODE_PATH=/Users/mackianni/forge/node_modules timeout 120 node --no-warnings --import tsx "$D/scripts/$S" "$@"
