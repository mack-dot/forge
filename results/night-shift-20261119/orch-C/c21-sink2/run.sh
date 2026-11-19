#!/bin/bash
# run.sh <script (abs or relative to c21-sink2)> <args...>: cwd = fix-88ae6cbf root; scrubbed env.
unset GH_TOKEN GITHUB_TOKEN
EV=/Users/mackianni/forge/results/night-shift-20261119/orch-C/c21-sink2
ROOT=/private/tmp/claude-501/-Users-mackianni-forge/90d187ef-57dc-4fa3-a5b8-7a6708d00cf2/scratchpad/redteam-C/fix-88ae6cbf
S=$1; shift; case "$S" in /*) ;; *) S="$EV/$S";; esac
cd "$ROOT" && exec env -i PATH=/opt/homebrew/bin:/usr/bin:/bin HOME=$EV LANG=C TMPDIR=$EV/work/tmp/ NODE_PATH=/Users/mackianni/forge/node_modules \
  timeout ${TMO:-120} node --no-warnings --import tsx "$S" "$@"
