#!/bin/bash
# c17-hminter runner: run.sh <script.ts> <log tag> [args...]  (cwd = target root, scrubbed env). Prints EXIT code.
unset GH_TOKEN GITHUB_TOKEN
E=<REPO>/results/night-shift-20261119/orch-C/c17-hminter
R=${C7_ROOT:-<SCRATCH>/redteam-C/fix-608b5165}
S=$1; T=$2; shift 2
cd "$R" || exit 3
env -i PATH=/opt/homebrew/bin:/usr/bin:/bin HOME=$E LANG=C NODE_PATH=<REPO>/node_modules ${EXTRA_ENV} \
  timeout 120 node --import tsx "$E/$S" "$@" > "$E/logs/$T.log" 2>&1
rc=$?; echo "$S $* -> EXIT $rc"; tail -3 "$E/logs/$T.log"; exit $rc
