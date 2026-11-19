include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    var y := match response { case Candidate(a0, r0) => match response { case Candidate(a1, r1) => match response { case Candidate(a2, r2) => match response { case Candidate(a3, r3) => match response { case Candidate(a4, r4) => match response { case Candidate(a5, r5) => match response { case Candidate(a6, r6) => match response { case Candidate(a7, r7) => match response { case Candidate(a8, r8) => match response { case Candidate(a9, r9) => match response { case Candidate(a10, r10) => match response { case Candidate(a11, r11) => match response { case Candidate(a12, r12) => match response { case Candidate(a13, r13) => match response { case Candidate(a14, r14) => match response { case Candidate(a15, r15) => match response { case Candidate(a16, r16) => match response { case Candidate(a17, r17) => match response { case Candidate(a18, r18) => match response { case Candidate(a19, r19) => 0 case _ => 1 } case _ => 1 } case _ => 1 } case _ => 1 } case _ => 1 } case _ => 1 } case _ => 1 } case _ => 1 } case _ => 1 } case _ => 1 } case _ => 1 } case _ => 1 } case _ => 1 } case _ => 1 } case _ => 1 } case _ => 1 } case _ => 1 } case _ => 1 } case _ => 1 } case _ => 1 };
    if Eligible(context, response) {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
