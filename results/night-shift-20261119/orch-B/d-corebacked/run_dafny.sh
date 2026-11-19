#!/bin/bash
# d-corebacked: the light Dafny runs (through dafny_locked.sh, gate options). Usage: run_dafny.sh <suffix>
D=/Users/mackianni/forge/results/night-shift-20261119/orch-B/d-corebacked; S=$D/dafny/inputs/sink; L=$D/logs
T=/Users/mackianni/forge/results/night-shift-20261119/orch-B/tools/dafny_locked.sh; Z3=/Users/mackianni/forge/.toolchain/dafny-4.11.0/dafny/z3/bin/z3-4.12.1
G=(--solver-path $Z3 --resource-limit 1000000 --verification-time-limit 0 --cores 1 --verify-included-files --track-print-effects)
x=${1:-}
$T d-corebacked $S $L/v02-mutant-nopreok-verify$x.log 90 verify "${G[@]}" --log-format "csv;LogFileName=$L/v02-mutant-nopreok-verify$x.csv" Mutant_ShellNoPreOk.dfy; echo "v02 exit $?"
$T d-corebacked $S $L/v03-shellreqid-build$x.log 90 build --target js --output $D/build/shellcore-reqid.js "${G[@]}" --log-format "csv;LogFileName=$L/v03-shellreqid-build$x.csv" ShellCoreReqId.dfy; echo "v03 exit $?"
$T d-corebacked $S $L/v04-shellorig-build$x.log 90 build --target js --output $D/build/shellcore-orig.js "${G[@]}" --log-format "csv;LogFileName=$L/v04-shellorig-build$x.csv" ShellCoreOrig.dfy; echo "v04 exit $?"
$T d-corebacked $S $L/a01-audit$x.log 90 audit ShellCoreReqId.dfy ShellCoreOrig.dfy; echo "a01 exit $?"
for f in v02-mutant-nopreok-verify v03-shellreqid-build v04-shellorig-build a01-audit; do echo "== $f"; grep -E "verified|Error|error|refused|TIMEOUT|finding|Warning" $L/$f$x.log | head -6; done
echo ALLDONE
