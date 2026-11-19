#!/bin/bash
# usage: run.sh <script relative to port/> <args...>; cwd = fix-608b5165 root; scrubbed env; preload = ledger policy.
unset GH_TOKEN GITHUB_TOKEN
EV=<REPO>/results/night-shift-20261119/orch-C/c16-hsink
ROOT=<SCRATCH>/redteam-C/fix-608b5165
S=$1; shift
cd "$ROOT" && exec env -i PATH=/opt/homebrew/bin:/usr/bin:/bin HOME=$EV LANG=C NODE_PATH=<REPO>/node_modules \
  PORT_LEDGER_POLICY=${PORT_LEDGER_POLICY:-first} timeout 120 node --no-warnings --import tsx --import "file://$EV/port/preload.cts" "$EV/$S" "$@"
