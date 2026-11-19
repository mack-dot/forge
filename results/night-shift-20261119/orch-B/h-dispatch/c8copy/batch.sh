#!/bin/bash
# Usage: batch.sh <base|tree> <prefix>: runs the four C scripts (copies) with all modes; one log per run.
D=<REPO>/results/night-shift-20261119/orch-B/h-dispatch
T=$1; P=$2
[ -n "$T" ] && [ -n "$P" ] || exit 2
mkdir -p "$D/work" "$D/logs"
for spec in "l1_lock_theft two" "l1_lock_theft three" "l1_lock_theft control" "l2_silent_loss throw" "l2_silent_loss ok" "l3_ledger_restore ledger" "l3_ledger_restore dir" "l3_ledger_restore none" "l7_rowtype blob" "l7_rowtype nul" "l7_rowtype none"; do
  set -- $spec; n=$1-$2
  "$D/c8copy/run.sh" "$T" "$1.ts" "$D/work/$T-$n" "$2" > "$D/logs/$P-$n.log" 2>&1; e=$?
  echo "exit $e" >> "$D/logs/$P-$n.log"; echo "$P $n exit $e"
done
