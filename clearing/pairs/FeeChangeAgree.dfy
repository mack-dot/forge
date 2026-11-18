// Slice 2 (master idea F1.3): the claim "the ledger specification before the fee change and the approved
// one allow the same result for every input". It is FALSE (the fee change is a real change): the pinned
// Dafny must reject this lemma, and only this lemma. A rejection is not a result; the clearing tool then
// needs a concrete, verified input where the two results differ.
include "../../proposals/forge2-pillar1-spec-determinism/SpecDiffFee.dfy"

abstract module FeeChangeAgree {
  import D : SpecDiffFee

  lemma Agree(s: D.O.State, id: int, r: D.O.Request,
              n: D.O.State, o: D.O.Outcome, n': D.N.State, o': D.N.Outcome)
    requires D.O.WellFormed(s)
    requires D.PostO(s, id, r, n, o) && D.PostN(D.StateN(s), id, D.ReqN(r), n', o')
    ensures n' == D.StateN(n) && (o == D.O.Ok <==> o' == D.N.Ok)
  {
    D.PostOCases(s, id, r, n, o);
    D.PostNCases(D.StateN(s), id, D.ReqN(r), n', o');
  }
}
