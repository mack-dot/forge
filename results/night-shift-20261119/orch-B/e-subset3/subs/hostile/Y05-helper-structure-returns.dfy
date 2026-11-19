include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  function P1(c: Context): seq<RefundIntent> { [Intent(c.chargeId, c.requestId, 0, ""), Intent(c.chargeId, c.requestId, 1, "")] }
  function P2(c: Context): seq<seq<RefundIntent>> { [P1(c), P1(c)] }
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    var q := [P2(context), P2(context)];
    if Eligible(context, response) {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
