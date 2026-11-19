include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  lemma Heavy(x: int, y: int, z: int)
    requires 1 < x && 1 < y && 1 < z
    ensures x * x * x + y * y * y != z * z * z
  {}
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
