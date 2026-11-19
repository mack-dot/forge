#!/bin/bash
# usage: run.sh <script.ts> [args...]   (scrubbed env, cwd = target-v6, 120 s)
cd <SCRATCH>/redteam-C/target-v6 || exit 2
S=$1; shift
exec env -i PATH=/opt/homebrew/bin:/usr/bin:/bin HOME=<REPO>/results/night-shift-20261119/orch-C/c15-storage LANG=C \
  NODE_PATH=<REPO>/node_modules timeout 120 node --import tsx <REPO>/results/night-shift-20261119/orch-C/c15-storage/$S "$@"
