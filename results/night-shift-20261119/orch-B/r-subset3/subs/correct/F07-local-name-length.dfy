include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    var name := response;
    var length := 0;
    if Eligible(context, name) {
      decision := Authorized(name.amount, name.reason);
      plan := [Intent(context.chargeId, context.requestId, name.amount, name.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
