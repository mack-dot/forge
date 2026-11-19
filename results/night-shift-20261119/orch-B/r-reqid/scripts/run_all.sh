#!/bin/bash
R=/Users/mackianni/forge/results/night-shift-20261119/orch-B/r-reqid
L=/Users/mackianni/forge/results/night-shift-20261119/orch-B/tools/dafny_locked.sh
W=$R/dafny/inputs/sink
Z3=/Users/mackianni/forge/.toolchain/dafny-4.11.0/dafny/z3/bin/z3-4.12.1
O="--solver-path $Z3 --resource-limit 1000000 --verification-time-limit 0 --cores 1 --verify-included-files --track-print-effects"
run() { n=$1; shift; f=$1; shift; $L r-reqid $W $R/logs/$n.log 90 "$@"; echo "$n $?" >> $R/logs/summary.txt; }
run r01-reqid-verify x verify $O "--log-format" "csv;LogFileName=$R/logs/r01-reqid-verify.csv" SinkCoreReqId.dfy
run r02-reqid-build x build $O "--log-format" "csv;LogFileName=$R/logs/r02-reqid-build.csv" --target js --output $R/build/sinkcore-reqid SinkCoreReqId.dfy
run r03-contrast-verify x verify $O "--log-format" "csv;LogFileName=$R/logs/r03-contrast-verify.csv" Contrast.dfy
run r04-audit-reqid x audit SinkCoreReqId.dfy
run r05-audit-contrast x audit Contrast.dfy
run r06-attack-verify x verify $O "--log-format" "csv;LogFileName=$R/logs/r06-attack-verify.csv" Attack.dfy
run r07-audit-attack x audit Attack.dfy
run r08-rejectall-verify x verify $O "--log-format" "csv;LogFileName=$R/logs/r08-rejectall-verify.csv" R_RejectAll.dfy
run r09-commitall-verify x verify $O "--log-format" "csv;LogFileName=$R/logs/r09-commitall-verify.csv" R_CommitAll.dfy
