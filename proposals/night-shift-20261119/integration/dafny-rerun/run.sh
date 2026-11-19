#!/bin/bash
# Integrator re-run of the Dafny files that this pull request adds under impl/finality-core (serial; dafny.lock held).
set -u
SP=$1; F=${FORGE:?path of the checkout that holds .toolchain}; D=$F/.toolchain/dafny-4.11.0/dafny; LOCK=$F/results/night-shift-20261119/locks/dafny.lock
mkdir "$LOCK" || { echo "lock busy"; exit 76; }
trap 'rm -rf "$LOCK"' EXIT
echo integrator > $LOCK/owner; echo $$ > $LOCK/pid
cd $SP/wt/impl/finality-core
for f in IssueAuth IssueOnce ShellCoreV6; do
  { echo "# start $(date -u +%FT%TZ) swap: $(sysctl -n vm.swapusage)"; echo "# cmd: dafny verify --solver-path z3-4.12.1 --resource-limit 1000000 --verification-time-limit 0 --cores 1 --verify-included-files --track-print-effects $f.dfy (cwd impl/finality-core)"; } > $SP/checks/dafny/$f.log
  $D/dafny verify --solver-path $D/z3/bin/z3-4.12.1 --resource-limit 1000000 --verification-time-limit 0 --cores 1 --verify-included-files --track-print-effects $f.dfy >> $SP/checks/dafny/$f.log 2>&1
  echo "exit $?" >> $SP/checks/dafny/$f.log
  echo "$f $(tail -2 $SP/checks/dafny/$f.log | tr '\n' ' ')"
done
