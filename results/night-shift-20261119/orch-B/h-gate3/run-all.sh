#!/bin/bash
# run-all.sh SET... : harness over mods/SET/*.cjs, one run at a time. Refuses to start a set when swap free < 512 MiB.
# After each set: canary directory, leftover child directories, files changed since the marker (must all be empty).
H=<REPO>/results/night-shift-20261119/orch-B/h-gate3; cd $H
for S in "$@"; do
  free=$(/usr/sbin/sysctl -n vm.swapusage | sed 's/.*free = \([0-9.]*\)M.*/\1/'); free=${free%.*}
  if [ "$free" -lt 512 ]; then echo "SET $S NOT RUN: swap free ${free} MiB < 512"; continue; fi
  touch $H/logs/marker-$S
  env -i PATH=/opt/homebrew/bin:/usr/bin:/bin HOME=$H/work /opt/homebrew/bin/node $H/harness.cjs $S $H/mods/$S/*.cjs > $H/logs/results-$S.jsonl 2> $H/logs/results-$S.stderr
  echo "SET $S harness exit $? runs $(wc -l < $H/logs/results-$S.jsonl) swapfree_before ${free}"
  echo "  canary: $(ls $H/probe/canary | wc -l | tr -d ' ') files; leftover D: $(ls -d $H/work/supervise-* 2>/dev/null | wc -l | tr -d ' ')"
  echo "  changed since marker (outside logs/): $(find $H /private/tmp -maxdepth 3 -newer $H/logs/marker-$S -type f 2>/dev/null | grep -v "^$H/logs/" | head -5 | tr '\n' ' ')"
done
