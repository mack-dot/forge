#!/bin/bash
# confirm.sh <sink.ts> <dispatcher.ts> <case> <tag>  (scrubbed env, cwd = v6 tree)
EV=/Users/mackianni/forge/results/night-shift-20261119/orch-C/c10-judges
cd $EV/v6 && env -i PATH=/opt/homebrew/bin:/usr/bin:/bin HOME=$EV TMPDIR=$EV/tmp LANG=C NODE_PATH=/Users/mackianni/forge/node_modules \
  timeout 120 node --no-warnings --import tsx $EV/confirm.ts "$1" "$2" "$3" > $EV/logs/confirm-$4.log 2>&1
c=$?; echo "exit $c" >> $EV/logs/confirm-$4.log; exit $c
