include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  predicate Elig(c: Context, r: ModelResponse) { Eligible(c, r) } by method { return true; }
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    if Elig(context, response) {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
