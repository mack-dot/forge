#!/bin/bash
# usage: run.sh <script.ts relative to c16-hsink> <args...>   (cwd = fix-608b5165; scrubbed env; no preload)
unset GH_TOKEN GITHUB_TOKEN
EV=<REPO>/results/night-shift-20261119/orch-C/c16-hsink
ROOT=<SCRATCH>/redteam-C/fix-608b5165
S=$1; shift
cd "$ROOT" && exec env -i PATH=/opt/homebrew/bin:/usr/bin:/bin HOME=$EV LANG=C NODE_PATH=<REPO>/node_modules \
  H_ROOT=${H_ROOT:-$ROOT} H_MEM=${H_MEM:-off} timeout 120 node --no-warnings --import tsx "$EV/$S" "$@"
