include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  function Outcome(context: Context, response: ModelResponse): (Decision, seq<RefundIntent>) {
    if Eligible(context, response)
    then (Authorized(response.amount, response.reason),
          [Intent(context.chargeId, context.requestId, response.amount, response.reason)])
    else (Rejected, [])
  }
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    var o := Outcome(context, response);
    decision := o.0;
    plan := o.1;
  }
}
