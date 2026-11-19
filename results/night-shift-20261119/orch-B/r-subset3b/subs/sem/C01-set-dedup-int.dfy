include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {

  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    var s1 := {1, 1};
    var s2 := {1, 2};
    var s3 := {2, 1};
    if Eligible(context, response) && |s1| == 1 && s2 == s3 {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
