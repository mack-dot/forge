include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  const Reasons := ["duplicate_charge", "service_not_delivered", "returned_item"]

  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    var i := 0;
    var hit := false;
    while i < |Reasons| && !hit
      invariant 0 <= i <= |Reasons|
      invariant hit <==> (i > 0 && response.Candidate? && Reasons[i - 1] == response.reason)
      invariant !hit ==> forall j :: 0 <= j < i ==> !(response.Candidate? && Reasons[j] == response.reason)
    {
      hit := response.Candidate? && Reasons[i] == response.reason;
      i := i + 1;
    }
    if ValidContext(context) && response.Candidate? && 0 <= response.amount <= context.remaining && hit {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
