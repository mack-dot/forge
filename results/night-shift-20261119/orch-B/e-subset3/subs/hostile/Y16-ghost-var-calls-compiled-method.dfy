include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  method Spin(n: nat) returns (r: nat) { r := n; }
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    ghost var g := Spin(5);
    if Eligible(context, response) {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
