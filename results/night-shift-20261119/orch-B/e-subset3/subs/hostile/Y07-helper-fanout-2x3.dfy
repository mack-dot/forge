include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  predicate F0(c: Context, r: ModelResponse) { Eligible(c, r) }
  predicate F1(c: Context, r: ModelResponse) { F0(c, r) && F0(c, r) }
  predicate F2(c: Context, r: ModelResponse) { F1(c, r) && F1(c, r) }
  predicate F3(c: Context, r: ModelResponse) { F2(c, r) && F2(c, r) }
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    var f := F3(context, response);
    if Eligible(context, response) {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
