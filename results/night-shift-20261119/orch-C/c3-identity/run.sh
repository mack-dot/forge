#!/bin/bash
# usage: run.sh <v6|merged> <script.ts> [args...]   (workdir is created under c3-identity/work/<name>-<target>)
unset GH_TOKEN GITHUB_TOKEN
EV=/Users/mackianni/forge/results/night-shift-20261119/orch-C/c3-identity
SC=/private/tmp/claude-501/-Users-mackianni-forge/90d187ef-57dc-4fa3-a5b8-7a6708d00cf2/scratchpad/redteam-C
case "$1" in v6) ROOT=$SC/target-v6;; merged) ROOT=$SC/wt;; *) echo bad target; exit 9;; esac
S=$2; shift 2
NAME=$(basename "$S" .ts)-$( [ "$ROOT" = "$SC/wt" ] && echo merged || echo v6 )
cd "$ROOT" && env -i PATH=/opt/homebrew/bin:/usr/bin:/bin HOME=$EV LANG=C NODE_PATH=/Users/mackianni/forge/node_modules \
  timeout 120 node --import file:///Users/mackianni/forge/node_modules/tsx/dist/loader.mjs "$EV/$S" "$ROOT" "$EV/work/$NAME" "$@" > "$EV/logs/$NAME.log" 2>&1
rc=$?; echo "exit=$rc" >> "$EV/logs/$NAME.log"; echo "$NAME exit=$rc"; exit $rc
