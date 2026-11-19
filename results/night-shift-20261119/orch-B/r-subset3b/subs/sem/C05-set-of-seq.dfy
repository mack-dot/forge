include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {

  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    var s1 := {[1], [1]};
    if Eligible(context, response) && |s1| == 1 && [1] in s1 {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
