include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  lemma Twice(x: int)
    ensures x + x == 2 * x
  {
    calc {
      x + x;
    ==
      2 * x;
    }
  }

  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    if Eligible(context, response) {
      Twice(response.amount);
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
