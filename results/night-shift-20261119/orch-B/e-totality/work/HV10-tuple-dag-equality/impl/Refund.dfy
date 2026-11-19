include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    if response.Candidate? && response.amount == 123456789 {
      var t0 := (response.reason, 0);
      var t1 := (t0, t0);
      var t2 := (t1, t1);
      var t3 := (t2, t2);
      var t4 := (t3, t3);
      var t5 := (t4, t4);
      var t6 := (t5, t5);
      var t7 := (t6, t6);
      var t8 := (t7, t7);
      var t9 := (t8, t8);
      var t10 := (t9, t9);
      var t11 := (t10, t10);
      var t12 := (t11, t11);
      var t13 := (t12, t12);
      var t14 := (t13, t13);
      var t15 := (t14, t14);
      var t16 := (t15, t15);
      var t17 := (t16, t16);
      var t18 := (t17, t17);
      var t19 := (t18, t18);
      var t20 := (t19, t19);
      var b := t20 == t20;
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
