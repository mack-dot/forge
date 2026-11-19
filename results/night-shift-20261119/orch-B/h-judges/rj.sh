#!/bin/bash
# rj.sh <cwd tree> <log> <cmd args...>: one light judge run, scrubbed env, pinned Node; appends "exit N".
D=/Users/mackianni/forge/results/night-shift-20261119/orch-B/h-judges
T=$1; L=$2; shift 2
cd "$T" || exit 3
{ echo "# $(date -u +%FT%TZ) cwd=$T cmd=$*"; pmset -g batt | head -1; } > "$L"
env -i PATH=/opt/homebrew/bin:/usr/bin:/bin HOME=$D/home TMPDIR=$D/tmp LANG=C NODE_PATH=/Users/mackianni/forge/node_modules \
  timeout 600 node --no-warnings --import tsx "$@" >> "$L" 2>&1
c=$?; echo "exit $c" >> "$L"; exit $c
