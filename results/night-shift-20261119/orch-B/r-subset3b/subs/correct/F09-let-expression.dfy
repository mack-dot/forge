include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  function Pick(c: Context, r: ModelResponse): Decision {
    var ok := Eligible(c, r);
    if ok then Authorized(r.amount, r.reason) else Rejected
  }
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    decision := Pick(context, response);
    plan := if decision.Authorized? then [Intent(context.chargeId, context.requestId, response.amount, response.reason)] else [];
  }
}
