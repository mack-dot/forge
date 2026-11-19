include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  const Approved: set<string> := {"duplicate_charge", "service_not_delivered", "returned_item"}

  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    if ValidContext(context) && response.Candidate? && response.reason in Approved &&
       0 <= response.amount <= context.remaining {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
