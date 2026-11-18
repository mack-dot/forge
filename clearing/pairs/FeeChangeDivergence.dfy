// Slice 2 (master idea F1.3): SUPPLIED divergence witness for the fee change. The input is row W1 of the
// boundary table of proposals/forge2-pillar1-spec-determinism (balances {0:0, 1:5, 2:0}, request 7:
// account 1 sends 5 to account 2). The proof is the existing lemma W1; this file only states the
// divergence in one line. Supplied by hand, not made by the solver; the pinned Dafny checks it.
include "../../proposals/forge2-pillar1-spec-determinism/SpecDiffFeeWitnesses.dfy"

abstract module FeeChangeDivergence {
  import W : SpecDiffFeeWitnesses

  // Every result that the old specification allows for this input is Ok with balances {0:0, 1:0, 2:5}.
  // Every result that the approved specification allows is Rejected with the balances unchanged.
  lemma AtThisInput(n: W.D.O.State, o: W.D.O.Outcome, n': W.D.N.State, o': W.D.N.Outcome)
    requires W.D.PostO(W.D.O.LedgerState(map[0 := 0, 1 := 5, 2 := 0], map[]), 7, W.D.O.TransferRequest(1, 2, 5), n, o)
    requires W.D.PostN(W.D.StateN(W.D.O.LedgerState(map[0 := 0, 1 := 5, 2 := 0], map[])), 7,
                       W.D.ReqN(W.D.O.TransferRequest(1, 2, 5)), n', o')
    ensures o == W.D.O.Ok && n.balances == map[0 := 0, 1 := 0, 2 := 5]
    ensures o' == W.D.N.Rejected && n'.balances == map[0 := 0, 1 := 5, 2 := 0]
    ensures n'.balances != n.balances
  {
    W.W1(n, o, n', o');
    assert n.balances[1] != n'.balances[1];
  }

  // Both specifications allow a result for this input.
  lemma BothAllowAResult()
    ensures exists n: W.D.O.State, o: W.D.O.Outcome ::
      W.D.PostO(W.D.O.LedgerState(map[0 := 0, 1 := 5, 2 := 0], map[]), 7, W.D.O.TransferRequest(1, 2, 5), n, o)
    ensures exists n': W.D.N.State, o': W.D.N.Outcome ::
      W.D.PostN(W.D.StateN(W.D.O.LedgerState(map[0 := 0, 1 := 5, 2 := 0], map[])), 7,
                W.D.ReqN(W.D.O.TransferRequest(1, 2, 5)), n', o')
  {
    W.W1_NonVacuous();
  }
}
