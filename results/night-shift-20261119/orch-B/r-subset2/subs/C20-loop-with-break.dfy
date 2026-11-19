include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  const Reasons: seq<string> := ["duplicate_charge", "service_not_delivered", "returned_item"]

  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    var found := false;
    var i := 0;
    while i < 3
      invariant 0 <= i <= 3
      invariant found <==> (response.Candidate? && exists j :: 0 <= j < i && Reasons[j] == response.reason)
    {
      if response.Candidate? && Reasons[i] == response.reason { found := true; break; }
      i := i + 1;
    }
    assert found ==> response.Candidate? && response.reason in Reasons;
    assert !found ==> !(response.Candidate? && response.reason in Reasons);
    if ValidContext(context) && response.Candidate? && 0 <= response.amount <= context.remaining && found {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
