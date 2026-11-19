#!/bin/bash
v() { <REPO>/results/night-shift-20261119/orch-B/tools/dafny_locked.sh orchB-recheck "$1" <REPO>/results/night-shift-20261119/orch-B/recheck-x/$3.log $4 verify --solver-path <REPO>/.toolchain/dafny-4.11.0/dafny/z3/bin/z3-4.12.1 --resource-limit 1000000 --verification-time-limit 0 --cores 1 --verify-included-files --track-print-effects --log-format "csv;LogFileName=<REPO>/results/night-shift-20261119/orch-B/recheck-x/$3.csv" $2 2>/dev/null; echo "$3 rc=$?"; }
v <REPO>/results/night-shift-20261119/orch-B/b-export-bridge ExportBridge.dfy ExportBridge 300
v <REPO>/results/night-shift-20261119/orch-B/b-export-bridge SliceSafetyFromExport.dfy SliceSafetyFromExport 300
