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
