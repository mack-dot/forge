include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  function Min(a: int, b: int): int {
    if a < b then a else b
  }

  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    if Eligible(context, response) && 0 <= response.amount <= Min(context.remaining, context.original) {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
