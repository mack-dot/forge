include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  const NoPlan: seq<RefundIntent> := []
  const Refusal: Decision := Rejected
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    var ok := Eligible(context, response);
    var none := NoPlan;
    decision, plan := Refusal, none;
    if ok {
      var amount := response.amount;
      var why := response.reason;
      decision := Authorized(amount, why);
      plan := [Intent(context.chargeId, context.requestId, amount, why)];
    }
  }
}
