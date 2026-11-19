include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    var table := map["duplicate_charge" := true, "service_not_delivered" := true, "returned_item" := true];
    if ValidContext(context) && response.Candidate? && 0 <= response.amount <= context.remaining
        && response.reason in table {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
