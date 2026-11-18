// NEGATIVE CONTROL (U418). A FALSE claim: "the capped variant never changes the decision". Verification MUST FAIL.
include "../SpecDiffRefundCap.dfy"

abstract module SpecDiffRefundFalseClaim {
  import D : SpecDiffRefundCap

  lemma NeverChanges(c: D.O.Context, r: D.O.ModelResponse,
                     d: D.O.Decision, p: seq<D.O.RefundIntent>, d': D.N.Decision, p': seq<D.N.RefundIntent>)
    requires D.PostO(c, r, d, p) && D.PostN(D.CtxN(c), D.RespN(r), d', p')
    ensures d' == D.DecN(d)
  {
    D.EligibleNewIff(c, r);
    D.PostOCases(c, r, d, p);
    D.PostNCases(D.CtxN(c), D.RespN(r), d', p');
  }
}
