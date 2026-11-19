include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  function AllTrue(bs: seq<bool>): bool
    decreases |bs|
  {
    if |bs| == 0 then true else bs[0] && AllTrue(bs[1..])
  }

  lemma AllTrueIff(bs: seq<bool>)
    ensures AllTrue(bs) <==> forall i :: 0 <= i < |bs| ==> bs[i]
    decreases |bs|
  {
    if |bs| > 0 { AllTrueIff(bs[1..]); }
  }

  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    var checks := [ValidContext(context), response.Candidate? && 0 <= response.amount,
                   response.Candidate? && response.amount <= context.remaining,
                   response.Candidate? && AllowedReason(response.reason)];
    AllTrueIff(checks);
    if AllTrue(checks) {
      assert checks[0] && checks[1] && checks[2] && checks[3];
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      assert !(checks[0] && checks[1] && checks[2] && checks[3]);
      decision := Rejected;
      plan := [];
    }
  }
}
