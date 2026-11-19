include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  /* a /* nested */ comment; the next line is real code */
  lemma Hidden() ensures true { }
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    if Eligible(context, response) {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
