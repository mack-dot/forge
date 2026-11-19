include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  predicate Ok(c: Context, a: int, r: string) {
    ValidContext(c) && 0 <= a <= c.remaining && AllowedReason(r)
  }

  lemma OkMeansEligible(c: Context, resp: ModelResponse)
    requires resp.Candidate?
    ensures Ok(c, resp.amount, resp.reason) <==> Eligible(c, resp)
  {}

  lemma OkBounds(c: Context, a: int, r: string)
    requires Ok(c, a, r)
    ensures Money(a) && a <= c.remaining <= c.original
  {}

  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    if response.Candidate? && Ok(context, response.amount, response.reason) {
      OkMeansEligible(context, response);
      OkBounds(context, response.amount, response.reason);
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      if response.Candidate? { OkMeansEligible(context, response); }
      decision := Rejected;
      plan := [];
    }
  }
}
