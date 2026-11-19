include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    if Eligible(context, response) && response.amount == 0 {
      // A zero refund is valid: it is authorized and recorded like any other.
      decision := Authorized(0, response.reason);
      plan := [Intent(context.chargeId, context.requestId, 0, response.reason)];
    } else if Eligible(context, response) {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
