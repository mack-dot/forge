// Slice 2: the claim "the PLANTED loose refund specification leaves no choice". It is FALSE: the
// pinned Dafny must reject this lemma, and only this lemma. A rejection is not a result; the clearing
// tool then needs two verified refinements that return different results for one concrete input.
include "RefundLooseBase.dfy"

abstract module RefundLooseClaim {
  import B : RefundLooseBase

  lemma SpecIsDeterministic(context: B.R.Context, response: B.R.ModelResponse,
                            d1: B.R.Decision, p1: seq<B.R.RefundIntent>, d2: B.R.Decision, p2: seq<B.R.RefundIntent>)
    requires B.Post(context, response, d1, p1)
    requires B.Post(context, response, d2, p2)
    ensures d1 == d2 && p1 == p2
  {
  }
}
