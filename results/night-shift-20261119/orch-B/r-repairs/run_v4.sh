#!/bin/bash
D=/Users/mackianni/forge/results/night-shift-20261119/orch-B/r-repairs/v4/dafny; L=/Users/mackianni/forge/results/night-shift-20261119/orch-B/r-repairs/logs
T=/Users/mackianni/forge/results/night-shift-20261119/orch-B/tools/dafny_locked.sh
Z3=/Users/mackianni/forge/.toolchain/dafny-4.11.0/dafny/z3/bin/z3-4.12.1
G=(--solver-path $Z3 --resource-limit 1000000 --verification-time-limit 0 --cores 1 --verify-included-files --track-print-effects)
$T r-repairs $D $L/v4-verify.1.log 90 verify "${G[@]}" --log-format "csv;LogFileName=$L/v4-verify.1.csv" $D/ShellCoreV4.dfy; echo "verify $?"
$T r-repairs $D $L/v4-audit.1.log 90 audit $D/ShellCoreV4.dfy; echo "audit $?"
