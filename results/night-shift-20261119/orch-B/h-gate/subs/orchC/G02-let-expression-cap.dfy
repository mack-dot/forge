include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  function Cap(c: Context): int {
    var r := c.remaining;
    if r < 0 then 0 else r
  }

  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    if Eligible(context, response) && response.amount <= Cap(context) {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
