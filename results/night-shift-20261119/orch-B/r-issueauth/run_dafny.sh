#!/bin/bash
# r-issueauth: Dafny runs through the lock script (light: 90 s). One try per file per call of this script.
OPTS="verify --solver-path <REPO>/.toolchain/dafny-4.11.0/dafny/z3/bin/z3-4.12.1 --resource-limit 1000000 --verification-time-limit 0 --cores 1 --verify-included-files --track-print-effects"
n=$1; shift
for f in "$@"; do
  b=$(basename $f .dfy)
  pmset -g batt | head -1
  <REPO>/results/night-shift-20261119/orch-B/tools/dafny_locked.sh r-issueauth <REPO>/results/night-shift-20261119/orch-B/r-issueauth/x/impl/finality-core <REPO>/results/night-shift-20261119/orch-B/r-issueauth/logs/$b.$n.log 90 $OPTS $f
  echo "$b try $n: exit $?"
done
