include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  method Zero() returns (a: int, b: int) { a, b := 0, 0; }
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    var i := 0;
    while i < 10 {
      var t;
      t, i := Zero();
      i := i + 1;
    }
    if Eligible(context, response) {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
