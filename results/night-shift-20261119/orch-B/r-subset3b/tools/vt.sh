#!/bin/bash
# Usage: vt.sh LISTFILE RUNNO. Verify each file (skip if a log of this run number says exit 0); translate the
# ones that verify (light tier, sequential). Output of dv.sh goes to a file (its timer keeps a pipe open).
D=<REPO>/results/night-shift-20261119/orch-B/r-subset3b
while read f; do
  n=$(basename $f .dfy)
  case "$(pmset -g batt | head -1)" in *"AC Power"*) ;; *) echo "$n NOT RUN (battery)"; continue;; esac
  if [ "$(tail -1 $D/logs/$n.verify.$2.log 2>/dev/null)" != "exit 0" ]; then
    bash $D/tools/dv.sh $D/$f $2 verify > /dev/null 2>&1
  fi
  echo "$n verify $(tail -1 $D/logs/$n.verify.$2.log)"
  if [ "$(tail -1 $D/logs/$n.verify.$2.log)" = "exit 0" ]; then
    bash $D/tools/dv.sh $D/$f $2 translate > /dev/null 2>&1
    echo "$n translate $(tail -1 $D/logs/$n.translate.$2.log)"
  fi
done < $1
