include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  function Decide(c: Context, r: ModelResponse): Decision {
    if Eligible(c, r) then Authorized(r.amount, r.reason) else Rejected
  }

  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    decision := Decide(context, response);
    if decision.Authorized? {
      plan := [Intent(context.chargeId, context.requestId, decision.amount, decision.reason)];
    } else {
      plan := [];
    }
  }
}
