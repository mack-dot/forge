#!/bin/bash
E=/Users/mackianni/forge/results/night-shift-20261119/orch-B/r-v6
L=/Users/mackianni/forge/results/night-shift-20261119/orch-B/tools/dafny_locked.sh
Z3=/Users/mackianni/forge/.toolchain/dafny-4.11.0/dafny/z3/bin/z3-4.12.1
G="--solver-path $Z3 --resource-limit 1000000 --verification-time-limit 0 --cores 1 --verify-included-files --track-print-effects"
cd $E/dafny
run() { name=$1; shift; n=1; while [ -e $E/logs/$name-$n.log ]; do n=$((n+1)); done
  for try in 1 2 3 4 5; do
    $L r-v6 $E/dafny $E/logs/$name-$n.log 90 "$@"; rc=$?
    if [ $rc = 75 ] || [ $rc = 76 ] || [ $rc = 124 ]; then n=$((n+1)); sleep 120; else break; fi
  done; echo "$name rc=$rc" >> $E/logs/summary.txt; }
run v6-verify verify $G --log-format "csv;LogFileName=$E/logs/v6-verify.csv" ShellCoreV6.dfy
run v6-audit audit ShellCoreV6.dfy
run r6-verify verify $G --log-format "csv;LogFileName=$E/logs/r6-verify.csv" R6Review.dfy
run r6-audit audit R6Review.dfy
for m in Mutant_DropAuthorizes Mutant_RejectAll Mutant_PostDiffFull Mutant_PostDiffWeak Mutant_AuthFirst; do
  run m-$m verify $G $m.dfy
done
echo DONE >> $E/logs/summary.txt
