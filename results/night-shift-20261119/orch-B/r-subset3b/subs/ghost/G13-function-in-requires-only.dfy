include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  function Heavy(x: int): int { x + x + x }
  method M(x: int) returns (y: int) requires Heavy(x) >= 0 ensures y == x { y := x; }
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    var q := M(1);
    if Eligible(context, response) && q == 1 {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
