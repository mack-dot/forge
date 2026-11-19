include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    var e := Eligible(context, response);
    decision := if e then Authorized(response.amount, response.reason) else Rejected;
    plan := if e then [Intent(context.chargeId, context.requestId, response.amount, response.reason)] else [];
  }
}
