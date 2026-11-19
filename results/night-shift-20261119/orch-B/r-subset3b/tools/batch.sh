#!/bin/bash
# Usage: batch.sh MODE RUNNO FILE... ; one light Dafny run per file, sequential; stops on battery.
D=<REPO>/results/night-shift-20261119/orch-B/r-subset3b
MODE=$1; K=$2; shift 2
for f in "$@"; do
  case "$(pmset -g batt | head -1)" in *"AC Power"*) ;; *) echo "$(basename $f .dfy) $MODE NOT RUN (battery)"; continue;; esac
  bash $D/tools/dv.sh $f $K $MODE
done
