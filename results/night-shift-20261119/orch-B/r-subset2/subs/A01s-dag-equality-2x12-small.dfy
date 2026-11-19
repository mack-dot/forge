include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    var c := 0;
    var a0 := [true];
    var b0 := [true];
    var a1 := [if c == c then a0 else a0, if c == c then a0 else a0];
    var b1 := [if c == c then b0 else b0, if c == c then b0 else b0];
    var a2 := [if c == c then a1 else a1, if c == c then a1 else a1];
    var b2 := [if c == c then b1 else b1, if c == c then b1 else b1];
    var a3 := [if c == c then a2 else a2, if c == c then a2 else a2];
    var b3 := [if c == c then b2 else b2, if c == c then b2 else b2];
    var a4 := [if c == c then a3 else a3, if c == c then a3 else a3];
    var b4 := [if c == c then b3 else b3, if c == c then b3 else b3];
    var a5 := [if c == c then a4 else a4, if c == c then a4 else a4];
    var b5 := [if c == c then b4 else b4, if c == c then b4 else b4];
    var a6 := [if c == c then a5 else a5, if c == c then a5 else a5];
    var b6 := [if c == c then b5 else b5, if c == c then b5 else b5];
    var a7 := [if c == c then a6 else a6, if c == c then a6 else a6];
    var b7 := [if c == c then b6 else b6, if c == c then b6 else b6];
    var a8 := [if c == c then a7 else a7, if c == c then a7 else a7];
    var b8 := [if c == c then b7 else b7, if c == c then b7 else b7];
    var a9 := [if c == c then a8 else a8, if c == c then a8 else a8];
    var b9 := [if c == c then b8 else b8, if c == c then b8 else b8];
    var a10 := [if c == c then a9 else a9, if c == c then a9 else a9];
    var b10 := [if c == c then b9 else b9, if c == c then b9 else b9];
    var a11 := [if c == c then a10 else a10, if c == c then a10 else a10];
    var b11 := [if c == c then b10 else b10, if c == c then b10 else b10];
    var a12 := [if c == c then a11 else a11, if c == c then a11 else a11];
    var b12 := [if c == c then b11 else b11, if c == c then b11 else b11];
    var same := a12 == b12;
    if same { decision := Rejected; }
    if Eligible(context, response) {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
