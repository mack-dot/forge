include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  function Decide(c: Context, r: ModelResponse): (Decision, seq<RefundIntent>)
  {
    match r
    case Candidate(a, why) =>
      if Eligible(c, r) then (Authorized(a, why), [Intent(c.chargeId, c.requestId, a, why)])
      else (Rejected, [])
    case Missing => (Rejected, [])
    case TimedOut => (Rejected, [])
    case _ => (Rejected, [])
  }

  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    var out := Decide(context, response);
    decision := out.0;
    plan := out.1;
  }
}
