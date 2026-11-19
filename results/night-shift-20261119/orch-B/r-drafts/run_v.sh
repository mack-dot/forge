#!/bin/bash
# r-drafts: light re-verification and audit of R1-R3 copies (gate options, CSV). Sequential.
E=/Users/mackianni/forge/results/night-shift-20261119/orch-B/r-drafts; L=$E/logs
T=/Users/mackianni/forge/results/night-shift-20261119/orch-B/tools/dafny_locked.sh; Z3=/Users/mackianni/forge/.toolchain/dafny-4.11.0/dafny/z3/bin/z3-4.12.1
G=(--solver-path $Z3 --resource-limit 1000000 --verification-time-limit 0 --cores 1 --verify-included-files --track-print-effects)
x=$1; shift
for st in "$@"; do case $st in
 v1) $T r-drafts $E/r1 $L/v1-issuebytes$x.log 90 verify "${G[@]}" --log-format "csv;LogFileName=$L/v1-issuebytes$x.csv" $E/r1/IssueBytes2.dfy; echo "v1 exit $?";;
 a1) $T r-drafts $E/r1 $L/a1-issuebytes$x.log 90 audit --report-file $L/a1-issuebytes$x.md $E/r1/IssueBytes2.dfy; echo "a1 exit $?";;
 v2) $T r-drafts $E/r2 $L/v2-shellv3$x.log 90 verify "${G[@]}" --log-format "csv;LogFileName=$L/v2-shellv3$x.csv" $E/r2/ShellCoreV3.dfy; echo "v2 exit $?";;
 a2) $T r-drafts $E/r2 $L/a2-shellv3$x.log 90 audit --report-file $L/a2-shellv3$x.md $E/r2/ShellCoreV3.dfy; echo "a2 exit $?";;
 v3) $T r-drafts $E/r3 $L/v3-bridge$x.log 90 verify "${G[@]}" --log-format "csv;LogFileName=$L/v3-bridge$x.csv" $E/r3/Bridge.dfy; echo "v3 exit $?";;
 a3) $T r-drafts $E/r3 $L/a3-bridge$x.log 90 audit --report-file $L/a3-bridge$x.md $E/r3/Bridge.dfy; echo "a3 exit $?";;
 n1) $T r-drafts $E/r1 $L/n1-strength$x.log 90 verify "${G[@]}" --log-format "csv;LogFileName=$L/n1-strength$x.csv" $E/r1/IB2S.dfy; echo "n1 exit $?";;
esac; done
