include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  predicate Heavy(c: Context, r: ModelResponse) { Eligible(c, r) && Eligible(c, r) }
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    var f := Heavy;
    var b := f(context, response) && f(context, response) && f(context, response);
    if Eligible(context, response) {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
