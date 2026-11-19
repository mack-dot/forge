#!/bin/bash
# run.sh <script> [args...]: run one TS script with the scrubbed env of WORKER_RULES, cwd = target tree.
T=<REPO>/results/night-shift-20261119/orch-B/h-judges2/tree
EV=<REPO>/results/night-shift-20261119/orch-B/h-judges2/bs2
cd "$T" && exec env -i PATH=/opt/homebrew/bin:/usr/bin:/bin HOME=$EV TMPDIR=$EV/tmp LANG=C NODE_PATH=<REPO>/node_modules \
  timeout ${TO:-120} /opt/homebrew/bin/node --no-warnings --import tsx "$@"
