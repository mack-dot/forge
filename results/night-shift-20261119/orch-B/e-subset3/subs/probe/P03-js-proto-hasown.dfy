include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  function prototype(c: Context): int { 4 }
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    var hasOwnProperty := 1;
    var x := prototype(context);
    if Eligible(context, response) {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
