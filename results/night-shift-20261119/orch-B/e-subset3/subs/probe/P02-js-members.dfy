include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  function toString(c: Context): int { 1 }
  function valueOf(c: Context): int { 2 }
  function require(c: Context): int { 3 }
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    var a := toString(context);
    var b := valueOf(context);
    var c := require(context);
    if Eligible(context, response) {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
