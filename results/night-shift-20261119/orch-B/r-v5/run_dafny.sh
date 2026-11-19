#!/bin/bash
# r-v5: light Dafny runs through the lock script (gate options). Usage: run_dafny.sh <step...>
E=/Users/mackianni/forge/results/night-shift-20261119/orch-B/r-v5
L=/Users/mackianni/forge/results/night-shift-20261119/orch-B/tools/dafny_locked.sh
Z3=/Users/mackianni/forge/.toolchain/dafny-4.11.0/dafny/z3/bin/z3-4.12.1
G="--solver-path $Z3 --resource-limit 1000000 --verification-time-limit 0 --cores 1 --verify-included-files --track-print-effects"
cd $E/dafny
run() { name=$1; shift; n=1; while [ -e $E/logs/$name-$n.log ]; do n=$((n+1)); done
  for try in 1 2 3 4 5; do
    $L r-v5 $E/dafny $E/logs/$name-$n.log 90 "$@"; rc=$?
    if [ $rc = 75 ] || [ $rc = 76 ] || [ $rc = 124 ]; then n=$((n+1)); sleep 120; else break; fi
  done; echo "$name rc=$rc" >> $E/logs/summary.txt; }
for s in "$@"; do case $s in
 v5) run v5-verify verify $G --log-format "csv;LogFileName=$E/logs/v5-verify.csv" ShellCoreV5.dfy;;
 v5a) run v5-audit audit ShellCoreV5.dfy;;
 atk) run atk-verify verify $G --log-format "csv;LogFileName=$E/logs/atk-verify.csv" AttackV5.dfy;;
 atka) run atk-audit audit AttackV5.dfy;;
 m*) run $s verify $G Mutant_${s#m}.dfy;;
esac; done
