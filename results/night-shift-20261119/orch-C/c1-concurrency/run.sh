#!/bin/sh
# usage: run.sh <script.ts> [args]   (the run recipe of WORKER_RULES.md; HOME = this evidence dir)
unset GH_TOKEN GITHUB_TOKEN
E=<REPO>/results/night-shift-20261119/orch-C/c1-concurrency
cd <SCRATCH>/redteam-C/target-v6 || exit 4
S=$1; shift
exec env -i PATH=/opt/homebrew/bin:/usr/bin:/bin HOME=$E LANG=C NODE_NO_WARNINGS=1 NODE_PATH=<REPO>/node_modules timeout 120 node --import tsx "$E/$S" "$@"
