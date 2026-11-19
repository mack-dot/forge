#!/bin/bash
v() { <REPO>/results/night-shift-20261119/orch-B/tools/dafny_locked.sh orchB-recheck "$1" <REPO>/results/night-shift-20261119/orch-B/recheck-r/$3.log $4 verify --solver-path <REPO>/.toolchain/dafny-4.11.0/dafny/z3/bin/z3-4.12.1 --resource-limit 1000000 --verification-time-limit 0 --cores 1 --verify-included-files --track-print-effects --log-format "csv;LogFileName=<REPO>/results/night-shift-20261119/orch-B/recheck-r/$3.csv" $2 2>/dev/null; echo "$3 rc=$?"; }
v $(dirname $(find <REPO>/results/night-shift-20261119/orch-B/b-restart -name Restart.dfy -not -path '*/controls/*' | head -1)) Restart.dfy Restart 300
v $(dirname $(find <REPO>/results/night-shift-20261119/orch-B/b-restart -name KeyedStore.dfy -not -path '*/controls/*' | head -1)) KeyedStore.dfy KeyedStore 300
