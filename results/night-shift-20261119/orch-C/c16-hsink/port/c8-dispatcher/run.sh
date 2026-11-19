#!/bin/sh
# Usage: run.sh <script.ts> <args...>  (cwd = target-v6, scrubbed env per WORKER_RULES)
D=<SCRATCH>/redteam-C/retarget-608b5165/c8-dispatcher
cd <SCRATCH>/redteam-C/fix-608b5165 || exit 4
S=$1; shift
exec env -i PATH=/opt/homebrew/bin:/usr/bin:/bin HOME=$D LANG=C NODE_PATH=<REPO>/node_modules timeout 120 node --no-warnings --import tsx "$D/scripts/$S" "$@"
