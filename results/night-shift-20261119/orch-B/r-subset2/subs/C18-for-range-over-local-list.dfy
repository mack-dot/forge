include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    var reasons := ["duplicate_charge", "service_not_delivered", "returned_item"];
    var found := false;
    for i := 0 to |reasons|
      invariant found <==> exists j :: 0 <= j < i && response.Candidate? && reasons[j] == response.reason
    {
      if response.Candidate? && reasons[i] == response.reason { found := true; }
    }
    assert found ==> response.Candidate? && response.reason in reasons;
    assert !found ==> !(response.Candidate? && response.reason in reasons);
    if ValidContext(context) && response.Candidate? && 0 <= response.amount <= context.remaining && found {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
