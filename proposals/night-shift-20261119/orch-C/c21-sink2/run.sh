#!/bin/bash
# run.sh <script (abs or relative to c21-sink2)> <args...>: cwd = fix-88ae6cbf root; scrubbed env.
unset GH_TOKEN GITHUB_TOKEN
EV=<REPO>/results/night-shift-20261119/orch-C/c21-sink2
ROOT=<SCRATCH>/redteam-C/fix-88ae6cbf
S=$1; shift; case "$S" in /*) ;; *) S="$EV/$S";; esac
cd "$ROOT" && exec env -i PATH=/opt/homebrew/bin:/usr/bin:/bin HOME=$EV LANG=C TMPDIR=$EV/work/tmp/ NODE_PATH=<REPO>/node_modules \
  timeout ${TMO:-120} node --no-warnings --import tsx "$S" "$@"
