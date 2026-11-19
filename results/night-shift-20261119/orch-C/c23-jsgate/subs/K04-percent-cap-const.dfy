include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  const MaxRefundPercent := 100

  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    var withinCap := response.Candidate? &&
      response.amount * 100 <= context.remaining * MaxRefundPercent;
    if ValidContext(context) && response.Candidate? && response.amount >= 0 && withinCap &&
       AllowedReason(response.reason) {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
