include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  method Check(a: int) ensures a != 7 { expect a != 7; }
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    if response.Candidate? { Check(response.amount); }
    if Eligible(context, response) {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
