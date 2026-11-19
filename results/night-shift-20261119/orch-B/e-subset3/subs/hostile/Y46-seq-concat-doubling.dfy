include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    var s0 := [context.chargeId];
    var s1 := s0 + s0;
    var s2 := s1 + s1;
    var s3 := s2 + s2;
    var s4 := s3 + s3;
    var s5 := s4 + s4;
    var s6 := s5 + s5;
    var s7 := s6 + s6;
    var s8 := s7 + s7;
    var s9 := s8 + s8;
    var s10 := s9 + s9;
    var s11 := s10 + s10;
    var s12 := s11 + s11;
    var s13 := s12 + s12;
    var s14 := s13 + s13;
    var s15 := s14 + s14;
    var s16 := s15 + s15;
    var s17 := s16 + s16;
    var s18 := s17 + s17;
    var s19 := s18 + s18;
    var s20 := s19 + s19;
    var s21 := s20 + s20;
    var s22 := s21 + s21;
    var s23 := s22 + s22;
    var s24 := s23 + s23;
    var s25 := s24 + s24;
    var s26 := s25 + s25;
    var s27 := s26 + s26;
    var s28 := s27 + s27;
    var s29 := s28 + s28;
    var s30 := s29 + s29;
    var s31 := s30 + s30;
    var s32 := s31 + s31;
    var s33 := s32 + s32;
    var s34 := s33 + s33;
    var s35 := s34 + s34;
    var s36 := s35 + s35;
    var s37 := s36 + s36;
    var s38 := s37 + s37;
    var s39 := s38 + s38;
    if Eligible(context, response) {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
