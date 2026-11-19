#!/bin/bash
D=<REPO>/results/night-shift-20261119/orch-B/r-repairs/b2; L=<REPO>/results/night-shift-20261119/orch-B/r-repairs/logs
T=<REPO>/results/night-shift-20261119/orch-B/tools/dafny_locked.sh
Z3=<REPO>/.toolchain/dafny-4.11.0/dafny/z3/bin/z3-4.12.1
G=(--solver-path $Z3 --resource-limit 1000000 --verification-time-limit 0 --cores 1 --verify-included-files --track-print-effects)
$T r-repairs $D $L/b2-verify.1.log 90 verify "${G[@]}" --log-format "csv;LogFileName=$L/b2-verify.1.csv" $D/Bridge2.dfy; echo "verify $?"
$T r-repairs $D $L/b2-audit.1.log 90 audit $D/Bridge2.dfy; echo "audit $?"
$T r-repairs $D $L/b2-attack.1.log 90 verify "${G[@]}" --log-format "csv;LogFileName=$L/b2-attack.1.csv" $D/AttackR.dfy; echo "attack $?"
$T r-repairs $D $L/b2-expectfail.1.log 90 verify "${G[@]}" $D/AttackR_EXPECTFAIL.dfy; echo "expectfail $?"
