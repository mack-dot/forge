include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  ghost method GM(x: int) returns (y: int) { y := x; }
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    ghost var z := 0;
    if Eligible(context, response) && true {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
