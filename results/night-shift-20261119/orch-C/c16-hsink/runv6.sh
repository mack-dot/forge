#!/bin/bash
# like run.sh, but cwd and H_ROOT = target-v6 (the earlier adopted v6 sink), for a control run
unset GH_TOKEN GITHUB_TOKEN
EV=<REPO>/results/night-shift-20261119/orch-C/c16-hsink
ROOT=<SCRATCH>/redteam-C/target-v6
S=$1; shift
cd "$ROOT" && exec env -i PATH=/opt/homebrew/bin:/usr/bin:/bin HOME=$EV LANG=C NODE_PATH=<REPO>/node_modules \
  H_ROOT=$ROOT H_CORE=<REPO>/results/night-shift-20261119/orch-B/d-minter/build/issuebytes2.cjs timeout 120 node --no-warnings --import tsx "$EV/$S" "$@"
