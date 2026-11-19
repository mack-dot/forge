include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  function Verdict(c: Context, r: ModelResponse): (d: Decision)
    ensures d.Authorized? <==> Eligible(c, r)
  {
    if Eligible(c, r) then Authorized(r.amount, r.reason) else Rejected
  }
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    decision := Verdict(context, response);
    if decision.Authorized? {
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      plan := [];
    }
  }
}
