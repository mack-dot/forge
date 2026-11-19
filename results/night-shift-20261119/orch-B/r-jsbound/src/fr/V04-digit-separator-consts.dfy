include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  const Ceiling: int := 9_223_372_036_854_775_807
  const Floor: int := 0
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    var fits := Floor <= context.remaining <= context.original <= Ceiling;
    if fits && context.refundEnabled && context.requestOpen && context.chargeId != "" &&
       context.requestId != "" && response.Candidate? && Floor <= response.amount <= context.remaining &&
       AllowedReason(response.reason) {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
