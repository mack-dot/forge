#!/bin/sh
# Usage: run.sh <base|tree> <script.ts> <args...>  (h-dispatch copy of orch-C/c8-dispatcher/run.sh; scrubbed env)
D=<REPO>/results/night-shift-20261119/orch-B/h-dispatch
T=$1; shift; S=$1; shift
cd "$D/$T" || exit 4
exec env -i PATH=/opt/homebrew/bin:/usr/bin:/bin HOME=$D/home LANG=C D_ROOT="$D/$T" NODE_PATH=<REPO>/node_modules timeout 120 node --no-warnings --import tsx "$D/c8copy/$S" "$@"
