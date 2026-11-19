#!/bin/bash
# Usage: run.sh WORKDIR LOGNAME TIMEOUT FILE [extra dafny args]  (dev runs omit --verify-included-files when EXTRA has --dev)
O=<REPO>/results/night-shift-20261119/orch-B
D=$O/b-restart; Z3=<REPO>/.toolchain/dafny-4.11.0/dafny/z3/bin/z3-4.12.1
W=$1; N=$2; T=$3; F=$4; shift 4
INC="--verify-included-files"; if [ "${1:-}" = "--dev" ]; then INC=""; shift; fi
$O/tools/dafny_locked.sh b-restart $W $D/logs/$N.log $T verify --solver-path $Z3 --resource-limit 1000000 --verification-time-limit 0 --cores 1 $INC --track-print-effects "--log-format" "csv;LogFileName=$D/logs/$N.csv" "$@" $F >/dev/null 2>&1
echo "$N: $(grep -E 'finished|Error|error' $D/logs/$N.log | head -30) $(tail -1 $D/logs/$N.log)"
