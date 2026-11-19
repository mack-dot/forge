#!/bin/bash
# Usage: batch.sh <base|tree> <prefix>: the C-HOST script copies; one log per run with the actual exit code.
H=/Users/mackianni/forge/results/night-shift-20261119/orch-B/h-dispatch
DT=$1; P=$2; [ -n "$DT" ] && [ -n "$P" ] || exit 2
export DT
for spec in "h1_dispatch_exit emitfail" "h1_dispatch_exit lock" "h1_dispatch_exit chain" "h1_dispatch_exit refused" "h2_signal_lock TERM" "h2_signal_lock INT" "h5_lock_removed_report -" "h6_commit_exit -" "h7_relative_ledger -" "h3_tool_anchor -" "h9_epipe -"; do
  set -- $spec; n=$1-$2
  bash "$H/c11copy/$1.sh" "$2" > "$H/logs/$P-$n.log" 2>&1; e=$?
  echo "exit $e" >> "$H/logs/$P-$n.log"; echo "$P $n exit $e"
done
