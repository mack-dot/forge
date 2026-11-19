include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  const Reasons: seq<string> := ["duplicate_charge", "service_not_delivered", "returned_item"]

  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    var matches := 0;
    for i := 0 to |Reasons|
      invariant 0 <= matches <= i
    {
      if response.Candidate? && Reasons[i] == response.reason {
        matches := matches + 1;
      }
    }
    if Eligible(context, response) {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
