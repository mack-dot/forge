include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  ghost function Sum(n: nat): nat
    decreases n
  {
    if n == 0 then 0 else n + Sum(n - 1)
  }

  lemma SumBound(n: nat)
    ensures Sum(n) <= n * n
    decreases n
  {
    if n > 0 { SumBound(n - 1); }
  }
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    SumBound(3);
    if Eligible(context, response) {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
