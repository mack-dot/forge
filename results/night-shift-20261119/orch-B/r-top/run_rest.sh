#!/bin/bash
E=/Users/mackianni/forge/results/night-shift-20261119/orch-B/r-top
L=/Users/mackianni/forge/results/night-shift-20261119/orch-B/tools/dafny_locked.sh
Z3=/Users/mackianni/forge/.toolchain/dafny-4.11.0/dafny/z3/bin/z3-4.12.1
G="--solver-path $Z3 --resource-limit 1000000 --verification-time-limit 0 --cores 1 --track-print-effects"
cd $E/src
run() { n=$1; shift; $L r-top $E/src $E/logs/$n.log 300 "$@"; echo "$n $(tail -1 $E/logs/$n.log)"; }
run v-RefineTraceV3-01 verify $G --verify-included-files --log-format "csv;LogFileName=$E/logs/v-RefineTraceV3-01.csv" RefineTraceV3.dfy
run v-RTopLemmas-01 verify $G --log-format "csv;LogFileName=$E/logs/v-RTopLemmas-01.csv" RTopLemmas.dfy
for m in TopFromExport_M1b_swapCR_bothSides TopFromExport_M2b_swapEnabledOpen_bothSides TopFromExport_M1a_swapCR_oneSided TopFromExport_M5b_swapOrigRem_bothSides KeyedHash_M3_noKeyAbsentCheck KeyedHash_M4_routeByTok; do
  run mut-$m-01 verify $G $m.dfy
done
run audit-KeyedHash-01 audit --report-format md --report-file $E/logs/audit-KeyedHash-01.md KeyedHash.dfy
run audit-RefineTraceV3-01 audit --report-format md --report-file $E/logs/audit-RefineTraceV3-01.md RefineTraceV3.dfy
run audit-RTopLemmas-01 audit --report-format md --report-file $E/logs/audit-RTopLemmas-01.md RTopLemmas.dfy
