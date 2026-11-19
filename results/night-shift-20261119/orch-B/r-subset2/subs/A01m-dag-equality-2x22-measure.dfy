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
    var a13 := [if c == c then a12 else a12, if c == c then a12 else a12];
    var b13 := [if c == c then b12 else b12, if c == c then b12 else b12];
    var a14 := [if c == c then a13 else a13, if c == c then a13 else a13];
    var b14 := [if c == c then b13 else b13, if c == c then b13 else b13];
    var a15 := [if c == c then a14 else a14, if c == c then a14 else a14];
    var b15 := [if c == c then b14 else b14, if c == c then b14 else b14];
    var a16 := [if c == c then a15 else a15, if c == c then a15 else a15];
    var b16 := [if c == c then b15 else b15, if c == c then b15 else b15];
    var a17 := [if c == c then a16 else a16, if c == c then a16 else a16];
    var b17 := [if c == c then b16 else b16, if c == c then b16 else b16];
    var a18 := [if c == c then a17 else a17, if c == c then a17 else a17];
    var b18 := [if c == c then b17 else b17, if c == c then b17 else b17];
    var a19 := [if c == c then a18 else a18, if c == c then a18 else a18];
    var b19 := [if c == c then b18 else b18, if c == c then b18 else b18];
    var a20 := [if c == c then a19 else a19, if c == c then a19 else a19];
    var b20 := [if c == c then b19 else b19, if c == c then b19 else b19];
    var a21 := [if c == c then a20 else a20, if c == c then a20 else a20];
    var b21 := [if c == c then b20 else b20, if c == c then b20 else b20];
    var a22 := [if c == c then a21 else a21, if c == c then a21 else a21];
    var b22 := [if c == c then b21 else b21, if c == c then b21 else b21];
    var same := a22 == b22;
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
