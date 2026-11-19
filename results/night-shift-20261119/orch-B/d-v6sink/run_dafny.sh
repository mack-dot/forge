#!/bin/bash
# d-v6sink: light Dafny runs through dafny_locked.sh (gate options). Usage: run_dafny.sh <suffix> <steps...>
# steps: v (verify ShellCoreV6), mD mR mC mP (mutants: must FAIL), b (build --target js + .cjs wrapper), a (audit)
V=<REPO>/results/night-shift-20261119/orch-B/d-v6sink; S=$V/dafny; L=$V/logs
T=<REPO>/results/night-shift-20261119/orch-B/tools/dafny_locked.sh; Z3=<REPO>/.toolchain/dafny-4.11.0/dafny/z3/bin/z3-4.12.1
G=(--solver-path $Z3 --resource-limit 1000000 --verification-time-limit 0 --cores 1 --verify-included-files --track-print-effects)
TM=${TMO:-90}
x=$1; shift
for st in "$@"; do case $st in
 v)  $T d-v6sink $S $L/v-shellv6-verify$x.log $TM verify "${G[@]}" --log-format "csv;LogFileName=$L/v-shellv6-verify$x.csv" ShellCoreV6.dfy; echo "v exit $?";;
 mD) $T d-v6sink $S $L/mD-dropauthorizes$x.log $TM verify "${G[@]}" Mutant_DropAuthorizes.dfy; echo "mD exit $?";;
 mR) $T d-v6sink $S $L/mR-rejectall$x.log $TM verify "${G[@]}" Mutant_RejectAll.dfy; echo "mR exit $?";;
 mC) $T d-v6sink $S $L/mC-commitall$x.log $TM verify "${G[@]}" Mutant_CommitAll.dfy; echo "mC exit $?";;
 mP) $T d-v6sink $S $L/mP-claimedpre$x.log $TM verify "${G[@]}" Mutant_ClaimedPre.dfy; echo "mP exit $?";;
 b)  $T d-v6sink $S $L/b-shellv6-build$x.log $TM build --target js --output $V/build/shellcore-v6.js "${G[@]}" --log-format "csv;LogFileName=$L/b-shellv6-build$x.csv" ShellCoreV6.dfy; rc=$?; echo "b exit $rc"
     [ $rc = 0 ] && { cp $V/build/shellcore-v6.js $V/build/shellcore-v6.cjs; echo 'module.exports = { Shell6: ShellCoreV6, Shell5: ShellCoreV5, Shell4: ShellCoreV4, Shell: ShellCoreV3, C: SinkCoreV3, F: RefundFinality, R: Refund, rt: _dafny, BigNumber };' >> $V/build/shellcore-v6.cjs; };;
 a)  $T d-v6sink $S $L/a-audit$x.log $TM audit ShellCoreV6.dfy; echo "a exit $?";;
esac; done
for f in $L/*$x.log; do echo "== $(basename $f)"; grep -E "verified|Error|refused|TIMEOUT|finding|Warning|^exit" $f | head -14; done
