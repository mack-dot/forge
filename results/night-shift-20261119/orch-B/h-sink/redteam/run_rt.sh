#!/bin/bash
# h-sink: run the red team's scripts (copies; ROOT -> h-sink/tree) against the hardened tree. Light single runs.
H=<REPO>/results/night-shift-20261119/orch-B/h-sink; R=$H/redteam; ATT=${1:-1}
run() { local s=$1 mode=$2; local n=$(basename $s .ts)${mode:+-$mode}
  rm -rf $R/work/$n; $H/run_node.sh $H/tree $H/logs/rt-$n-$ATT.log 90 --import tsx $R/$s $R/work/$n $mode >/dev/null; echo "$n exit $?"; }
run c4/a6_dup_reqid.ts restart; run c4/a6_dup_reqid.ts running; run c4/a5_index_root.ts; run c4/a2_brick.ts off
run c4/a1_double_refund.ts running; run c4/a8_tamper_table.ts; run c4/a8_tamper_hostile.ts
