// Forge 2.0 master idea, Pillar I (U410). NOT part of the gate. NOT a protected file.
// The postcondition of the approved RefundSpec.Assess as a predicate, and the two-run determinism lemma.
// AssessThenPost is checked against the approved method specification.
include "../../spec/refund/RefundSpec.dfy"

abstract module RefundDeterminism {
  import R : RefundSpec

  ghost predicate Post(context: R.Context, response: R.ModelResponse, decision: R.Decision, plan: seq<R.RefundIntent>)
  {
    (decision.Authorized? ==>
      R.ValidContext(context) && R.Money(decision.amount) &&
      decision.amount <= context.remaining <= context.original) &&
    (decision.Authorized? ==> R.AllowedReason(decision.reason)) &&
    (!R.Eligible(context, response) ==> decision == R.Rejected && plan == []) &&
    (R.Eligible(context, response) ==>
      response.Candidate? && decision == R.Authorized(response.amount, response.reason) &&
      plan == [R.Intent(context.chargeId, context.requestId, response.amount, response.reason)]) &&
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

  lemma SpecIsDeterministic(context: R.Context, response: R.ModelResponse,
                            d1: R.Decision, p1: seq<R.RefundIntent>, d2: R.Decision, p2: seq<R.RefundIntent>)
    requires Post(context, response, d1, p1)
    requires Post(context, response, d2, p2)
    ensures d1 == d2 && p1 == p2
  {
  }
}
