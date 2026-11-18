// CONTROL for Slice 2 (a broken clearing input). Post is WEAKER than the approved refund specification: it lets
// the authorized amount be anything up to the proposed one. The forward link still holds (a weaker Post is
// true of every allowed result). The two-run lemma in RefundWeakPostClaim.dfy is rejected. A candidate with two
// amounts cannot be made real: the approved specification rejects one of the two refinements.
// The tool must answer UNDECIDED, never CHOICE and never NO_CHOICE.
include "../../spec/refund/RefundSpec.dfy"

abstract module RefundWeakPostBase {
  import R : RefundSpec

  ghost predicate Post(context: R.Context, response: R.ModelResponse, decision: R.Decision, plan: seq<R.RefundIntent>)
  {
    (decision.Authorized? ==>
      R.ValidContext(context) && R.Money(decision.amount) &&
      decision.amount <= context.remaining <= context.original) &&
    (decision.Authorized? ==> R.AllowedReason(decision.reason)) &&
    (!R.Eligible(context, response) ==> decision == R.Rejected && plan == []) &&
    (R.Eligible(context, response) ==>
      response.Candidate? && decision.Authorized? &&
      0 <= decision.amount <= response.amount && decision.reason == response.reason) &&
    (decision.Authorized? <==> R.Eligible(context, response)) &&
    (decision.Rejected? <==> |plan| == 0) &&
    |plan| <= 1 &&
    (decision.Authorized? ==>
      plan == [R.Intent(context.chargeId, context.requestId, decision.amount, decision.reason)]) &&
    (forall intent: R.RefundIntent :: intent in plan ==>
      R.ValidContext(context) && R.Money(intent.amount) &&
      intent.amount <= context.remaining <= context.original &&
      R.AllowedReason(intent.reason) &&
      intent.chargeId == context.chargeId && intent.requestId == context.requestId)
  }

  method AssessThenPost(context: R.Context, response: R.ModelResponse)
      returns (decision: R.Decision, plan: seq<R.RefundIntent>)
    ensures Post(context, response, decision, plan)
  {
    decision, plan := R.Assess(context, response);
  }
}
