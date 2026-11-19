#!/bin/bash
# run.sh <script> [args...]: run one TS script with the scrubbed env of WORKER_RULES, cwd = target tree.
T=/private/tmp/claude-501/-Users-mackianni-forge/90d187ef-57dc-4fa3-a5b8-7a6708d00cf2/scratchpad/redteam-C/fix-f08a21c1
EV=/Users/mackianni/forge/results/night-shift-20261119/orch-C/c19-dispatch2
cd "$T" && exec env -i PATH=/opt/homebrew/bin:/usr/bin:/bin HOME=$EV TMPDIR=$EV/tmp LANG=C NODE_PATH=/Users/mackianni/forge/node_modules \
  timeout ${TO:-120} /opt/homebrew/bin/node --no-warnings --import tsx "$@"
