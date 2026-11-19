#!/bin/bash
# run.sh <script> [args...]: one c27 script against the f67c5c16 overlay, scrubbed env, cwd = tree.
T=<SCRATCH>/redteam-C/fix-f67c5c16
EV=<REPO>/results/night-shift-20261119/orch-C/c27-sink3
S=$1; shift
mkdir -p $EV/tmp
cd "$T" && exec env -i PATH=/opt/homebrew/bin:/usr/bin:/bin HOME=$EV H3_ROOT="$T" LANG=C TMPDIR=$EV/tmp/ NODE_PATH=<REPO>/node_modules \
  timeout ${TMO:-120} /opt/homebrew/bin/node --no-warnings --import tsx "$EV/$S" "$@"
