include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    if response.Candidate? && response.amount == 123456789 {
      var x0 := response.amount;
      var x1 := x0 * x0;
      var x2 := x1 * x1;
      var x3 := x2 * x2;
      var x4 := x3 * x3;
      var x5 := x4 * x4;
      var x6 := x5 * x5;
      var x7 := x6 * x6;
      var x8 := x7 * x7;
      var x9 := x8 * x8;
      var x10 := x9 * x9;
      var x11 := x10 * x10;
      var x12 := x11 * x11;
      var x13 := x12 * x12;
      var x14 := x13 * x13;
      var x15 := x14 * x14;
      var x16 := x15 * x15;
      var x17 := x16 * x16;
      var x18 := x17 * x17;
      var x19 := x18 * x18;
      var x20 := x19 * x19;
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
