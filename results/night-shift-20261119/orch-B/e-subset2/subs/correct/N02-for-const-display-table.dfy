include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  const Reasons: seq<string> := ["duplicate_charge", "service_not_delivered", "returned_item"]
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    var found := false;
    for i := 0 to |Reasons|
      invariant found <==> response.Candidate? && response.reason in Reasons[..i]
    {
      if response.Candidate? && Reasons[i] == response.reason { found := true; }
    }
    assert Reasons[..|Reasons|] == Reasons;
    if found && ValidContext(context) && 0 <= response.amount <= context.remaining {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
