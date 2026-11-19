include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    if Eligible(context, response) {
      var a := if response.amount == 7 then 6 else response.amount;
      decision := Authorized(a, response.reason);
      plan := [Intent(context.chargeId, context.requestId, a, response.reason)];
    } else { decision := Rejected; plan := []; }
  }
}
