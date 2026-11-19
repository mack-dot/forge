include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    // flags as integers; product is 1 exactly when every check holds
    var f := (if ValidContext(context) then 1 else 0);
    var g := (if response.Candidate? && 0 <= response.amount <= context.remaining then 1 else 0);
    var h := (if response.Candidate? && AllowedReason(response.reason) then 1 else 0);
    var p := f * g * h;
    if p * p - p + 1 == 1 && p != 0 {
      var amt := response.amount * p + (1 - p) * 0;
      decision := Authorized(amt, response.reason);
      plan := [Intent(context.chargeId, context.requestId, amt, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
