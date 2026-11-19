include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    var a0 := [context];
    var a1 := [a0, a0];
    var a2 := [a1, a1];
    var a3 := [a2, a2];
    var a4 := [a3, a3];
    var a5 := [a4, a4];
    var a6 := [a5, a5];
    var a7 := [a6, a6];
    var a8 := [a7, a7];
    var a9 := [a8, a8];
    var a10 := [a9, a9];
    var a11 := [a10, a10];
    var a12 := [a11, a11];
    var a13 := [a12, a12];
    var a14 := [a13, a13];
    var a15 := [a14, a14];
    var a16 := [a15, a15];
    var a17 := [a16, a16];
    var a18 := [a17, a17];
    var a19 := [a18, a18];
    var a20 := [a19, a19];
    var a21 := [a20, a20];
    var a22 := [a21, a21];
    var a23 := [a22, a22];
    var a24 := [a23, a23];
    var a25 := [a24, a24];
    var a26 := [a25, a25];
    var a27 := [a26, a26];
    var a28 := [a27, a27];
    var a29 := [a28, a28];
    var same := a29 == a29;
    if Eligible(context, response) {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
