#!/bin/bash
# d-v5sink: the light Dafny runs (through dafny_locked.sh, gate options). Usage: run_dafny.sh <suffix> <steps...>
# steps: v (verify ShellCoreV5), mA mE mS mR (mutants: must FAIL), b (build --target js + .cjs wrapper), a (audit)
V=<REPO>/results/night-shift-20261119/orch-B/d-v5sink; S=$V/dafny; L=$V/logs
T=<REPO>/results/night-shift-20261119/orch-B/tools/dafny_locked.sh; Z3=<REPO>/.toolchain/dafny-4.11.0/dafny/z3/bin/z3-4.12.1
G=(--solver-path $Z3 --resource-limit 1000000 --verification-time-limit 0 --cores 1 --verify-included-files --track-print-effects)
TM=${TMO:-90}
x=$1; shift
for st in "$@"; do case $st in
 v)  $T d-v5sink $S $L/v-shellv5-verify$x.log $TM verify "${G[@]}" --log-format "csv;LogFileName=$L/v-shellv5-verify$x.csv" ShellCoreV5.dfy; echo "v exit $?";;
 mA) $T d-v5sink $S $L/mA-noauthorizes$x.log $TM verify "${G[@]}" Mutant_NoAuthorizes.dfy; echo "mA exit $?";;
 mE) $T d-v5sink $S $L/mE-noendcompare$x.log $TM verify "${G[@]}" Mutant_NoEndCompare.dfy; echo "mE exit $?";;
 mS) $T d-v5sink $S $L/mS-nosigok$x.log $TM verify "${G[@]}" Mutant_NoSigOk.dfy; echo "mS exit $?";;
 mR) $T d-v5sink $S $L/mR-rejectall$x.log $TM verify "${G[@]}" Mutant_RejectAll.dfy; echo "mR exit $?";;
 b)  $T d-v5sink $S $L/b-shellv5-build$x.log $TM build --target js --output $V/build/shellcore-v5.js "${G[@]}" --log-format "csv;LogFileName=$L/b-shellv5-build$x.csv" ShellCoreV5.dfy; rc=$?; echo "b exit $rc"
     [ $rc = 0 ] && { cp $V/build/shellcore-v5.js $V/build/shellcore-v5.cjs; echo 'module.exports = { Shell5: ShellCoreV5, Shell4: ShellCoreV4, Shell: ShellCoreV3, C: SinkCoreV3, F: RefundFinality, R: Refund, rt: _dafny, BigNumber };' >> $V/build/shellcore-v5.cjs; };;
 a)  $T d-v5sink $S $L/a-audit$x.log $TM audit ShellCoreV5.dfy; echo "a exit $?";;
esac; done
for f in $L/*$x.log; do echo "== $(basename $f)"; grep -E "verified|Error|error|refused|TIMEOUT|finding|Warning|^exit" $f | head -12; done
