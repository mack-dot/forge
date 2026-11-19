#!/bin/bash
# r-export: run MutantIffFlat (ExportedContract <==> FlatContract) on each export mutant via the lock script.
R=<REPO>/results/night-shift-20261119/orch-B/r-export
T=<REPO>/results/night-shift-20261119/orch-B/tools/dafny_locked.sh
Z=<REPO>/.toolchain/dafny-4.11.0/dafny/z3/bin/z3-4.12.1
for n in "$@"; do
  d=$R/xm/$n
  cat > $d/Check.dfy <<EOD
// r-export mutant harness. Must FAIL unless the mutant is semantically neutral.
include "gen/ExportedContract.dfy"
module MutantCheck {
  import opened SliceTheorem
  import L = LinkedRefund
  import opened ExportedGen
  lemma MutantIffFlat(x: FlatIn, o: L.FlatTuple)
    ensures ExportedContract(x, o) <==> FlatContract(x, o)
  {
  }
}
EOD
  k=1; while [ -e $R/logs/xm-$n-0$k.log ]; do k=$((k+1)); done
  LOG=$R/logs/xm-$n-0$k.log
  bash $T r-export $d $LOG 90 verify --solver-path $Z --resource-limit 1000000 --verification-time-limit 0 --cores 1 --verify-included-files --track-print-effects --filter-symbol MutantIffFlat Check.dfy >/dev/null 2>&1
  echo "$n | $(tail -1 $LOG) | $(grep -m1 'verifier finished' $LOG) | $(grep -m1 -o 'Error: [^.]*' $LOG)"
done
