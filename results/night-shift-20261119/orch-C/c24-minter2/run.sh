#!/bin/bash
# c24-minter2 runner: run.sh <script.ts> <log tag> [args...]  (cwd = target root, scrubbed env). Prints EXIT code.
unset GH_TOKEN GITHUB_TOKEN
E=<REPO>/results/night-shift-20261119/orch-C/c24-minter2
R=<SCRATCH>/redteam-C/fix-370ff65c
S=$1; T=$2; shift 2
cd "$R" || exit 3
env -i PATH=/opt/homebrew/bin:/usr/bin:/bin HOME=$E LANG=C NODE_PATH=<REPO>/node_modules \
  C7_ROOT=$R C7_CORE=<REPO>/results/night-shift-20261119/orch-B/h-minter2/build/issueauth.cjs ${EXTRA_ENV} \
  timeout 120 node --import tsx "$E/$S" "$@" > "$E/logs/$T.log" 2>&1
rc=$?; echo "$S $* -> EXIT $rc"; tail -4 "$E/logs/$T.log"; exit $rc
