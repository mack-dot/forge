include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    var codes := map["duplicate_charge" := 1, "service_not_delivered" := 2, "returned_item" := 3];
    var known := response.Candidate? && response.reason in codes;
    if ValidContext(context) && known && 0 <= response.amount <= context.remaining {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
