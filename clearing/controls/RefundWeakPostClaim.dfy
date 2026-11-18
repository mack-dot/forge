// CONTROL for Slice 2: the two-run lemma for the weakened Post of RefundWeakPostBase.dfy. Dafny must reject it.
include "RefundWeakPostBase.dfy"

abstract module RefundWeakPostClaim {
  import B : RefundWeakPostBase

  lemma SpecIsDeterministic(context: B.R.Context, response: B.R.ModelResponse,
                            d1: B.R.Decision, p1: seq<B.R.RefundIntent>, d2: B.R.Decision, p2: seq<B.R.RefundIntent>)
    requires B.Post(context, response, d1, p1)
    requires B.Post(context, response, d2, p2)
    ensures d1 == d2 && p1 == p2
  {
  }
}
