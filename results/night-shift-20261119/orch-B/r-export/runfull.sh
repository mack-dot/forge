#!/bin/bash
# r-export: full verify of a file with gate options and CSV. Usage: runfull.sh WORKDIR FILE TAG
R=<REPO>/results/night-shift-20261119/orch-B/r-export
T=<REPO>/results/night-shift-20261119/orch-B/tools/dafny_locked.sh
Z=<REPO>/.toolchain/dafny-4.11.0/dafny/z3/bin/z3-4.12.1
k=1; while [ -e $R/logs/$3-0$k.log ]; do k=$((k+1)); done
bash $T r-export $1 $R/logs/$3-0$k.log 300 verify --solver-path $Z --resource-limit 1000000 --verification-time-limit 0 --cores 1 --verify-included-files --track-print-effects --log-format "csv;LogFileName=$R/logs/$3-0$k.csv" $2 >/dev/null 2>&1
echo "$3-0$k | $(tail -1 $R/logs/$3-0$k.log) | $(grep -m1 'verifier finished' $R/logs/$3-0$k.log)"
