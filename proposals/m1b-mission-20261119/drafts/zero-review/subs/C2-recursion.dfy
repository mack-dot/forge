include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  function CountTrue(bs: seq<bool>): nat
    decreases |bs|
  {
    if |bs| == 0 then 0 else (if bs[0] then 1 else 0) + CountTrue(bs[1..])
  }

  lemma AllTrue(bs: seq<bool>)
    ensures CountTrue(bs) == |bs| <==> forall i :: 0 <= i < |bs| ==> bs[i]
    decreases |bs|
  {
    if |bs| > 0 { AllTrue(bs[1..]); assert CountTrue(bs[1..]) <= |bs[1..]| by { Bound(bs[1..]); } }
  }

  lemma Bound(bs: seq<bool>)
    ensures CountTrue(bs) <= |bs|
    decreases |bs|
  {
    if |bs| > 0 { Bound(bs[1..]); }
  }

  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    if response.Candidate? {
      var checks := [ValidContext(context), 0 <= response.amount, response.amount <= context.remaining,
                     AllowedReason(response.reason)];
      AllTrue(checks);
      if CountTrue(checks) == |checks| {
        assert checks[0] && checks[1] && checks[2] && checks[3];
        return Authorized(response.amount, response.reason),
               [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
      } else {
        assert !(checks[0] && checks[1] && checks[2] && checks[3]);
      }
    }
    return Rejected, [];
  }
}
