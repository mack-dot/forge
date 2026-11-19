#!/bin/bash
# h-minter: run a COPY of a red-team script (paths edited; originals under orch-C untouched). Light single run.
# usage: run_rt.sh <log> <cwd> <script> [args...]   (env: extra VAR=VAL pairs in RT_ENV)
H=/Users/mackianni/forge/results/night-shift-20261119/orch-B/h-minter
L=$1; D=$2; S=$3; shift 3
pmset -g batt | head -1 | grep -q "AC Power" || { echo "not on AC"; exit 75; }
cd "$D" || exit 65
env -i PATH=/opt/homebrew/bin:/usr/bin:/bin HOME=$H/home LANG=C NODE_NO_WARNINGS=1 NODE_PATH=/Users/mackianni/forge/node_modules $RT_ENV \
  timeout 120 node --import file:///Users/mackianni/forge/node_modules/tsx/dist/loader.mjs "$S" "$@" > $L 2>&1
rc=$?; echo "exit $rc" >> $L; echo "$(basename $L) exit=$rc"; exit $rc
