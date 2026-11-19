include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  const Reasons: seq<string> := ["duplicate_charge", "service_not_delivered", "returned_item"]

  method IsApproved(r: string) returns (found: bool)
    ensures found <==> AllowedReason(r)
  {
    var i := 0;
    while i < |Reasons|
      invariant 0 <= i <= |Reasons|
      invariant forall k :: 0 <= k < i ==> Reasons[k] != r
    {
      if Reasons[i] == r {
        assert i == 0 || i == 1 || i == 2;
        return true;
      }
      i := i + 1;
    }
    assert Reasons[0] != r && Reasons[1] != r && Reasons[2] != r;
    return false;
  }

  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    decision := Rejected;
    plan := [];
    if !ValidContext(context) || !response.Candidate? {
      return;
    }
    var approved := IsApproved(response.reason);
    if approved && 0 <= response.amount <= context.remaining {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    }
  }
}
