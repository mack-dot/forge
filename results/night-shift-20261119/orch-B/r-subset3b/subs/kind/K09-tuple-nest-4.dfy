include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  function Two(x: int): (int, int) { (x, x) }
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    var a1 := Two(response.amount);
    var a2 := (a1, a1);
    var a3 := (a2, a2);
    var a4 := (a3, a3);
    if Eligible(context, response) && a4 == a4 && a1.1 == response.amount {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
