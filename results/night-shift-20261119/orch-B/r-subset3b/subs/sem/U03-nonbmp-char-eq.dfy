include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {

  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {

    if Eligible(context, response) && '\U{1F600}' == '\U{1F600}' && '\U{1F600}' != '\U{1F601}' {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
