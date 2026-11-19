#!/bin/bash
# h-minter2: run a COPY of a red-team script (originals under orch-C and h-minter untouched). Light single run.
# usage: run_rt.sh <tag> <before|after> <script.ts> [args...]
H=/Users/mackianni/forge/results/night-shift-20261119/orch-B/h-minter2
T=$1; W=$2; S=$3; shift 3
if [ "$W" = before ]; then R=$H/pristine; C=/Users/mackianni/forge/results/night-shift-20261119/orch-B/h-minter/build/issueonce.cjs
else R=$H/tree; C=$H/build/issueauth.cjs; fi
L=$H/rt/logs/$T-$W.log
pmset -g batt | head -1 > $L
cd "$R" || exit 65
env -i PATH=/opt/homebrew/bin:/usr/bin:/bin HOME=$H/home LANG=C NODE_NO_WARNINGS=1 NODE_PATH=/Users/mackianni/forge/node_modules \
  RT_ROOT=$R RT_CORE=$C C7_ROOT=$R C7_CORE=$C \
  timeout 120 node --import file:///Users/mackianni/forge/node_modules/tsx/dist/loader.mjs "$S" "$@" >> $L 2>&1
rc=$?; echo "exit $rc" >> $L; echo "$T-$W exit=$rc"; exit $rc
