include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  function Pr(c: Context): (string, string) { (c.chargeId, c.requestId) }
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    var t := (Pr(context), Pr(context));
    var same := t.0 == t.1;
    if Eligible(context, response) {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
