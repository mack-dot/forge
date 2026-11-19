include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  method Grow(s: seq<Context>) returns (r: seq<seq<Context>>) { r := [s, s]; }
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    var o1 := Grow([context]);
    if Eligible(context, response) {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
