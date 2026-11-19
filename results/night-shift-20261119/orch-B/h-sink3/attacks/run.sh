#!/bin/bash
# run.sh <tree> <script> [args...]: one adapted red-team script against <tree> (H3_ROOT), scrubbed env, cwd = tree.
T=$1; shift; S=$1; shift
EV=<REPO>/results/night-shift-20261119/orch-B/h-sink3/attacks
mkdir -p $EV/work/tmp
cd "$T" && exec env -i PATH=/opt/homebrew/bin:/usr/bin:/bin HOME=$EV H3_ROOT="$T" LANG=C TMPDIR=$EV/work/tmp/ NODE_PATH=<REPO>/node_modules \
  timeout ${TMO:-120} /opt/homebrew/bin/node --no-warnings --import tsx "$S" "$@"
