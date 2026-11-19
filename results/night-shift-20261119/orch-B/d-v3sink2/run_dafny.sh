#!/bin/bash
# d-v3sink2: the light Dafny runs (through dafny_locked.sh, gate options). Usage: run_dafny.sh <suffix> <steps...>
# steps: v (verify ShellCoreV4), mS mR mB mH (mutants: must FAIL), b (build --target js), a (audit)
V=<REPO>/results/night-shift-20261119/orch-B/d-v3sink2; S=$V/dafny; L=$V/logs
T=<REPO>/results/night-shift-20261119/orch-B/tools/dafny_locked.sh; Z3=<REPO>/.toolchain/dafny-4.11.0/dafny/z3/bin/z3-4.12.1
G=(--solver-path $Z3 --resource-limit 1000000 --verification-time-limit 0 --cores 1 --verify-included-files --track-print-effects)
x=$1; shift
for st in "$@"; do case $st in
 v)  $T d-v3sink2 $S $L/v-shellv4-verify$x.log 90 verify "${G[@]}" --log-format "csv;LogFileName=$L/v-shellv4-verify$x.csv" ShellCoreV4.dfy; echo "v exit $?";;
 mS) $T d-v3sink2 $S $L/mS-ignoresettled$x.log 90 verify "${G[@]}" Mutant_IgnoreSettled.dfy; echo "mS exit $?";;
 mR) $T d-v3sink2 $S $L/mR-rejectall$x.log 90 verify "${G[@]}" Mutant_RejectAll.dfy; echo "mR exit $?";;
 mB) $T d-v3sink2 $S $L/mB-nobinding$x.log 90 verify "${G[@]}" Mutant_NoBinding.dfy; echo "mB exit $?";;
 mH) $T d-v3sink2 $S $L/mH-ignorehit$x.log 90 verify "${G[@]}" Mutant_IgnoreHit.dfy; echo "mH exit $?";;
 b)  $T d-v3sink2 $S $L/b-shellv4-build$x.log 90 build --target js --output $V/build/shellcore-v4.js "${G[@]}" --log-format "csv;LogFileName=$L/b-shellv4-build$x.csv" ShellCoreV4.dfy; echo "b exit $?";;
 a)  $T d-v3sink2 $S $L/a-audit$x.log 90 audit ShellCoreV4.dfy; echo "a exit $?";;
esac; done
for f in $L/*$x.log; do echo "== $(basename $f)"; grep -E "verified|Error|error|refused|TIMEOUT|finding|Warning|^exit" $f | head -8; done
