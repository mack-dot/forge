include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  function F(x: int): int { x } by {:induction false} method { var i := 0; while i < 1 { i := i + 1; } return x; }
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    if Eligible(context, response) {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
