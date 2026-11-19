include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  method P(x: int) returns (r: seq<(int, int)>) { r := [(x, x), (x, x), (x, x), (x, x), (x, x), (x, x), (x, x), (x, x), (x, x), (x, x)]; }
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    var q := P(1);
    var q2 := [q, q];
    if Eligible(context, response) && true {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
