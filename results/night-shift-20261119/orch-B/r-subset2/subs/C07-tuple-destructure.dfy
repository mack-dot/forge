include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  function Decide(context: Context, response: ModelResponse): (Decision, seq<RefundIntent>)
  {
    if Eligible(context, response) then
      (Authorized(response.amount, response.reason), [Intent(context.chargeId, context.requestId, response.amount, response.reason)])
    else (Rejected, [])
  }

  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    var (d, p) := Decide(context, response);
    decision, plan := d, p;
  }
}
