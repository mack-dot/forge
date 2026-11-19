include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    var f := if ValidContext(context) then 1 else 0;
    var g := if response.Candidate? && 0 <= response.amount <= context.remaining then 1 else 0;
    var h := if response.Candidate? && AllowedReason(response.reason) then 1 else 0;
    var p := f * g * h;
    if p == 1 {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
