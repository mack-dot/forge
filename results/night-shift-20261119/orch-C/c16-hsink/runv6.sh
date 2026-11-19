#!/bin/bash
# like run.sh, but cwd and H_ROOT = target-v6 (the earlier adopted v6 sink), for a control run
unset GH_TOKEN GITHUB_TOKEN
EV=/Users/mackianni/forge/results/night-shift-20261119/orch-C/c16-hsink
ROOT=/private/tmp/claude-501/-Users-mackianni-forge/90d187ef-57dc-4fa3-a5b8-7a6708d00cf2/scratchpad/redteam-C/target-v6
S=$1; shift
cd "$ROOT" && exec env -i PATH=/opt/homebrew/bin:/usr/bin:/bin HOME=$EV LANG=C NODE_PATH=/Users/mackianni/forge/node_modules \
  H_ROOT=$ROOT H_CORE=/Users/mackianni/forge/results/night-shift-20261119/orch-B/d-minter/build/issuebytes2.cjs timeout 120 node --no-warnings --import tsx "$EV/$S" "$@"
