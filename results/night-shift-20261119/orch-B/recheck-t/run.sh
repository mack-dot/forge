#!/bin/bash
v() { <REPO>/results/night-shift-20261119/orch-B/tools/dafny_locked.sh orchB-recheck <REPO>/results/night-shift-20261119/orch-B/b-top/src <REPO>/results/night-shift-20261119/orch-B/recheck-t/$1.log 300 verify --solver-path <REPO>/.toolchain/dafny-4.11.0/dafny/z3/bin/z3-4.12.1 --resource-limit 1000000 --verification-time-limit 0 --cores 1 --verify-included-files --track-print-effects --log-format "csv;LogFileName=<REPO>/results/night-shift-20261119/orch-B/recheck-t/$1.csv" $1.dfy 2>/dev/null; echo "$1 rc=$?"; }
v TopFromExport; v IssuerLink; v KeyedHash; v RefineTraceV3
