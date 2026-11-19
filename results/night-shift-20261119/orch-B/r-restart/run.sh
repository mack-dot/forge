#!/bin/bash
# Usage: run.sh LOGNAME TIMEOUT FILE [extra]
O=/Users/mackianni/forge/results/night-shift-20261119/orch-B; R=$O/r-restart; W=$R/work
Z3=/Users/mackianni/forge/.toolchain/dafny-4.11.0/dafny/z3/bin/z3-4.12.1
N=$1; T=$2; F=$3; shift 3
$O/tools/dafny_locked.sh r-restart $W $R/logs/$N.log $T verify --solver-path $Z3 --resource-limit 1000000 --verification-time-limit 0 --cores 1 --verify-included-files --track-print-effects "--log-format" "csv;LogFileName=$R/logs/$N.csv" "$@" $F >/dev/null 2>&1
echo "$N: $(grep -E 'finished|Error' $R/logs/$N.log | head -20) $(tail -1 $R/logs/$N.log)"
