// Slice 2 (master idea F1.3): the claim "the two specifications allow the same result for every input".
// Both sides are deterministic and satisfiable (base file), and each Post is linked to its
// specification. So this one lemma, if the pinned Dafny proves it, is universal equivalence of the pair.
// If Dafny rejects it, that is NOT a result: the clearing tool then needs a concrete, verified input
// where the two results differ.
include "RefundRewrite.dfy"

abstract module RefundRewriteAgree {
  import D : RefundRewrite

  lemma Agree(c: D.O.Context, r: D.O.ModelResponse,
              d: D.O.Decision, p: seq<D.O.RefundIntent>, d': D.N.Decision, p': seq<D.N.RefundIntent>)
    requires D.PostO(c, r, d, p) && D.PostN(D.CtxN(c), D.RespN(r), d', p')
    ensures d' == D.DecN(d) && p' == D.PlanN(p)
  {
    D.EligibleNewIff(c, r);
    D.PostOCases(c, r, d, p);
    D.PostNCases(D.CtxN(c), D.RespN(r), d', p');
    if D.O.Eligible(c, r) && D.N.Eligible(D.CtxN(c), D.RespN(r)) {
      assert D.PlanN(p) == [D.IntentN(p[0])];
    } else if !D.O.Eligible(c, r) {
      assert D.PlanN(p) == [];
    }
  }
}
