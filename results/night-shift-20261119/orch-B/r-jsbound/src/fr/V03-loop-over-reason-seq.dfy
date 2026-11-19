include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  method IsAllowed(r: string) returns (b: bool)
    ensures b == AllowedReason(r)
  {
    var reasons := ["duplicate_charge", "service_not_delivered", "returned_item"];
    b := false;
    var i := 0;
    while i < |reasons|
      invariant 0 <= i <= |reasons|
      invariant b == (r in reasons[..i])
    {
      if reasons[i] == r {
        b := true;
      }
      assert reasons[..i + 1] == reasons[..i] + [reasons[i]];
      i := i + 1;
    }
    assert reasons[..|reasons|] == reasons;
  }
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    decision := Rejected;
    plan := [];
    if ValidContext(context) && response.Candidate? && 0 <= response.amount <= context.remaining {
      var allowed := IsAllowed(response.reason);
      if allowed {
        decision := Authorized(response.amount, response.reason);
        plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
      }
    }
  }
}
