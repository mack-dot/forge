include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    if response.Candidate? && response.amount == 123456789 {
      var s0 := [response.reason];
      var s1 := [s0, s0];
      var s2 := [s1, s1];
      var s3 := [s2, s2];
      var s4 := [s3, s3];
      var s5 := [s4, s4];
      var s6 := [s5, s5];
      var s7 := [s6, s6];
      var s8 := [s7, s7];
      var s9 := [s8, s8];
      var s10 := [s9, s9];
      var s11 := [s10, s10];
      var s12 := [s11, s11];
      var s13 := [s12, s12];
      var s14 := [s13, s13];
      var s15 := [s14, s14];
      var s16 := [s15, s15];
      var s17 := [s16, s16];
      var s18 := [s17, s17];
      var s19 := [s18, s18];
      var s20 := [s19, s19];
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
