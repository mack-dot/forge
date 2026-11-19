#!/bin/bash
# Usage: run.sh NAME FILE [extra dafny verify args]  -> logs/NAME.log, logs/NAME.csv ; retries on 75/76/124 up to 5 times
D=<REPO>/results/night-shift-20261119/orch-B/r-signing
NAME=$1; FILE=$2; shift 2
Z=<REPO>/.toolchain/dafny-4.11.0/dafny/z3/bin/z3-4.12.1
for try in 1 2 3 4 5 6; do
  LOG=$D/logs/$NAME.log; [ $try -gt 1 ] && LOG=$D/logs/$NAME-try$try.log
  <REPO>/results/night-shift-20261119/orch-B/tools/dafny_locked.sh r-signing $D/work $LOG 90 verify \
    --solver-path $Z --resource-limit 1000000 --verification-time-limit 0 --cores 1 --verify-included-files --track-print-effects \
    --log-format "csv;LogFileName=$D/logs/$NAME.csv" "$@" $FILE
  rc=$?
  case $rc in 75|76|124) echo "$NAME try $try rc=$rc (not run), waiting"; sleep 120;; *) echo "$NAME rc=$rc log=$LOG"; exit $rc;; esac
done
echo "$NAME NOT RUN after retries"; exit $rc
