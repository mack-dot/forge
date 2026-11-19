#!/bin/bash
v() { <REPO>/results/night-shift-20261119/orch-B/tools/dafny_locked.sh orchB-recheck "$1" <REPO>/results/night-shift-20261119/orch-B/recheck-s/$3.log $4 verify --solver-path <REPO>/.toolchain/dafny-4.11.0/dafny/z3/bin/z3-4.12.1 --resource-limit 1000000 --verification-time-limit 0 --cores 1 --verify-included-files --track-print-effects --log-format "csv;LogFileName=<REPO>/results/night-shift-20261119/orch-B/recheck-s/$3.csv" $2 2>/dev/null; echo "$3 rc=$?"; }
v <REPO>/results/night-shift-20261119/orch-B/b-ser SerModel.dfy SerModel 90
v <REPO>/results/night-shift-20261119/orch-B/b-ser RepairedBytes.dfy RepairedBytes 300
v <REPO>/results/night-shift-20261119/orch-B/x-issuer-bridge/dafny Bridge.dfy Bridge 90
v <REPO>/results/night-shift-20261119/orch-B/r-integrate/work AttackTrace.dfy AttackTrace 300
v <REPO>/results/night-shift-20261119/orch-B/r-integrate/work AttackCore.dfy AttackCore 90
v <REPO>/results/night-shift-20261119/orch-B/r-integrate/work AttackMulti.dfy AttackMulti 90
