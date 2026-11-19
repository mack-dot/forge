#!/bin/bash
# d-v3sink: the light Dafny runs (through dafny_locked.sh, gate options). Usage: run_dafny.sh <suffix> <steps...>
# steps: v01 (verify ShellCoreV3), m01 (mutant: must fail), b01 (build --target js), a01 (audit)
V=<REPO>/results/night-shift-20261119/orch-B/d-v3sink; S=$V/dafny; L=$V/logs
T=<REPO>/results/night-shift-20261119/orch-B/tools/dafny_locked.sh; Z3=<REPO>/.toolchain/dafny-4.11.0/dafny/z3/bin/z3-4.12.1
G=(--solver-path $Z3 --resource-limit 1000000 --verification-time-limit 0 --cores 1 --verify-included-files --track-print-effects)
x=$1; shift
for st in "$@"; do case $st in
 v01) $T d-v3sink $S $L/v01-shellv3-verify$x.log 90 verify "${G[@]}" --log-format "csv;LogFileName=$L/v01-shellv3-verify$x.csv" ShellCoreV3.dfy; echo "v01 exit $?";;
 m01) $T d-v3sink $S $L/m01-mutant-nochargecheck-verify$x.log 90 verify "${G[@]}" --log-format "csv;LogFileName=$L/m01-mutant-nochargecheck-verify$x.csv" Mutant_ShellNoChargeCheck.dfy; echo "m01 exit $?";;
 b01) $T d-v3sink $S $L/b01-shellv3-build$x.log 90 build --target js --output $V/build/shellcore-v3.js "${G[@]}" --log-format "csv;LogFileName=$L/b01-shellv3-build$x.csv" ShellCoreV3.dfy; echo "b01 exit $?";;
 a01) $T d-v3sink $S $L/a01-audit$x.log 90 audit ShellCoreV3.dfy; echo "a01 exit $?";;
esac; done
for f in $L/*$x.log; do echo "== $(basename $f)"; grep -E "verified|Error|error|refused|TIMEOUT|finding|Warning|^exit" $f | head -8; done
