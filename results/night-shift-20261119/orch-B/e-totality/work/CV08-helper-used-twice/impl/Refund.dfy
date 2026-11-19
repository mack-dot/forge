include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  predicate Ok(c: Context, r: ModelResponse) { Eligible(c, r) }
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    decision := if Ok(context, response) then Authorized(response.amount, response.reason) else Rejected;
    plan := if Ok(context, response)
            then [Intent(context.chargeId, context.requestId, response.amount, response.reason)] else [];
  }
}
