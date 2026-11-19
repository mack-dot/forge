include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  // We expect a decision. /* expect /* nested expect */ still comment */
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    /* expect */ // expect
    if Eligible(context, response) {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
