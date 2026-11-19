#!/bin/bash
# x-issuer-bridge: light Dafny checks through dafny_locked.sh (gate options). Usage: run_dafny.sh <n>
D=/Users/mackianni/forge/results/night-shift-20261119/orch-B/x-issuer-bridge/dafny; L=$D/logs; n=${1:-2}
T=/Users/mackianni/forge/results/night-shift-20261119/orch-B/tools/dafny_locked.sh
Z3=/Users/mackianni/forge/.toolchain/dafny-4.11.0/dafny/z3/bin/z3-4.12.1
G=(--solver-path $Z3 --resource-limit 1000000 --verification-time-limit 0 --cores 1 --verify-included-files --track-print-effects)
$T x-issuer-bridge $D $L/verify-bridge.$n.log 90 verify "${G[@]}" --log-format "csv;LogFileName=$L/verify-bridge.$n.csv" $D/Bridge.dfy; echo "main exit $?"
for c in C1-ignore-native C2-reject-all C3-skip-count C4-skip-stderr; do
  $T x-issuer-bridge $D/controls/$c $L/control-$c.$n.log 90 verify "${G[@]}" $D/controls/$c/Bridge.dfy; echo "$c exit $?"
done
$T x-issuer-bridge $D $L/audit-bridge.$n.log 90 audit $D/Bridge.dfy; echo "audit exit $?"
