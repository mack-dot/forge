include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  lemma EligibleAmountIsMoney(context: Context, response: ModelResponse)
    requires Eligible(context, response)
    ensures response.Candidate? && Money(response.amount)
  {
  }

  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    if Eligible(context, response) {
      EligibleAmountIsMoney(context, response);
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
