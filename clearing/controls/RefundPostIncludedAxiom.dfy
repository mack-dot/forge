// CONTROL for Slice 2 (a broken clearing input; review finding F1). The weak Post of RefundWeakPostBase.dfy, and a
// two-run lemma that is "proved" by an {:axiom} lemma of ANOTHER FILE. An audit of this file alone reports nothing.
// The tool must audit every file that this file reaches, and answer LINK_BROKEN.
include "../../spec/refund/RefundSpec.dfy"
include "AxiomHelper.dfy"

abstract module RefundPostIncludedAxiom {
  import R : RefundSpec
  import H = AxiomHelper

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

  lemma SpecIsDeterministic(context: R.Context, response: R.ModelResponse,
                            d1: R.Decision, p1: seq<R.RefundIntent>, d2: R.Decision, p2: seq<R.RefundIntent>)
    requires Post(context, response, d1, p1)
    requires Post(context, response, d2, p2)
    ensures d1 == d2 && p1 == p2
  {
    H.Anything();
  }
}
