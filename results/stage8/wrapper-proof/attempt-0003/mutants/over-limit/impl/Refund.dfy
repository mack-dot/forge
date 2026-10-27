include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    decision := Authorized(context.original + 1, "duplicate_charge");
    plan := [Intent(context.chargeId, context.requestId, context.original + 1, "duplicate_charge")];
  }
}
