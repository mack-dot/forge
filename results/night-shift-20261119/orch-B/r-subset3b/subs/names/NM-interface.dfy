include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  method interface(x: int) returns (y: int) ensures y == x + 1 { y := x + 1; }
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    var q := interface(1);
    if Eligible(context, response) && q == 2 {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
