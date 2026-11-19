#!/bin/bash
# x-bridge2: light Dafny checks through dafny_locked.sh (gate options). Usage: run_dafny.sh <what> <n>
# what = main | audit | <mutant dir name under controls/>
D=<REPO>/results/night-shift-20261119/orch-B/x-bridge2/dafny; L=$D/logs; w=$1; n=$2
T=<REPO>/results/night-shift-20261119/orch-B/tools/dafny_locked.sh
Z3=<REPO>/.toolchain/dafny-4.11.0/dafny/z3/bin/z3-4.12.1
G=(--solver-path $Z3 --resource-limit 1000000 --verification-time-limit 0 --cores 1 --verify-included-files --track-print-effects)
case $w in
  main)  $T x-bridge2 $D $L/verify-bridge2.$n.log 90 verify "${G[@]}" --log-format "csv;LogFileName=$L/verify-bridge2.$n.csv" $D/Bridge2.dfy ;;
  audit) $T x-bridge2 $D $L/audit-bridge2.$n.log 90 audit $D/Bridge2.dfy ;;
  *)     $T x-bridge2 $D/controls/$w $L/control-$w.$n.log 90 verify "${G[@]}" $D/controls/$w/Bridge2.dfy ;;
esac
echo "$w exit $?"
