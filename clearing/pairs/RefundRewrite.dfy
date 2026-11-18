// Slice 2 (master idea F1.3): clearing input for the pair (approved refund specification, PLANTED rewritten
// variant clearing/planted/RefundSpecRewritten.dfy). Same structure as
// proposals/forge2-pillar1-spec-determinism/SpecDiffRefundCap.dfy: one Post per side, written with that
// side's own predicates; forward links; case lemmas; determinism and satisfiability of both sides.
// NOT part of the gate. The variant is a fixture, not a proposed change.
include "../../spec/refund/RefundSpec.dfy"
include "../planted/RefundSpecRewritten.dfy"

abstract module RefundRewrite {
  import O : RefundSpec
  import N : RefundSpecRewritten

  function CtxN(c: O.Context): N.Context
  {
    N.ChargeContext(c.chargeId, c.requestId, c.original, c.remaining, c.refundEnabled, c.requestOpen)
  }

  function RespN(r: O.ModelResponse): N.ModelResponse
  {
    match r
    case Candidate(amount, reason) => N.Candidate(amount, reason)
    case Missing => N.Missing
    case TimedOut => N.TimedOut
    case Failed => N.Failed
    case Malformed => N.Malformed
    case Oversized => N.Oversized
    case Unsupported => N.Unsupported
  }

  function DecN(d: O.Decision): N.Decision
  {
    match d
    case Rejected => N.Rejected
    case Authorized(amount, reason) => N.Authorized(amount, reason)
  }

  function IntentN(i: O.RefundIntent): N.RefundIntent
  {
    N.Intent(i.chargeId, i.requestId, i.amount, i.reason)
  }

  function PlanN(p: seq<O.RefundIntent>): seq<N.RefundIntent>
  {
    seq(|p|, k requires 0 <= k < |p| => IntentN(p[k]))
  }

  // The four mappings are one-to-one and onto: each has an inverse (review finding F4). Without this,
  // a lemma about CtxN(c) and RespN(r) would say nothing about inputs of the new side that no input of
  // the old side maps to. PlanN maps a sequence element by element with IntentN.
  function CtxO(c: N.Context): O.Context
  {
    O.ChargeContext(c.chargeId, c.requestId, c.original, c.remaining, c.refundEnabled, c.requestOpen)
  }

  function RespO(r: N.ModelResponse): O.ModelResponse
  {
    match r
    case Candidate(amount, reason) => O.Candidate(amount, reason)
    case Missing => O.Missing
    case TimedOut => O.TimedOut
    case Failed => O.Failed
    case Malformed => O.Malformed
    case Oversized => O.Oversized
    case Unsupported => O.Unsupported
  }

  function DecO(d: N.Decision): O.Decision
  {
    match d
    case Rejected => O.Rejected
    case Authorized(amount, reason) => O.Authorized(amount, reason)
  }

  function IntentO(i: N.RefundIntent): O.RefundIntent
  {
    O.Intent(i.chargeId, i.requestId, i.amount, i.reason)
  }

  lemma MappingsAreOneToOneAndOnto()
    ensures forall c: O.Context :: CtxO(CtxN(c)) == c
    ensures forall c: N.Context :: CtxN(CtxO(c)) == c
    ensures forall r: O.ModelResponse :: RespO(RespN(r)) == r
    ensures forall r: N.ModelResponse :: RespN(RespO(r)) == r
    ensures forall d: O.Decision :: DecO(DecN(d)) == d
    ensures forall d: N.Decision :: DecN(DecO(d)) == d
    ensures forall i: O.RefundIntent :: IntentO(IntentN(i)) == i
    ensures forall i: N.RefundIntent :: IntentN(IntentO(i)) == i
  {
  }

  opaque ghost predicate PostO(context: O.Context, response: O.ModelResponse, decision: O.Decision, plan: seq<O.RefundIntent>)
  {
    (decision.Authorized? ==>
      O.ValidContext(context) && O.Money(decision.amount) &&
      decision.amount <= context.remaining <= context.original) &&
    (decision.Authorized? ==> O.AllowedReason(decision.reason)) &&
    (!O.Eligible(context, response) ==> decision == O.Rejected && plan == []) &&
    (O.Eligible(context, response) ==>
      response.Candidate? && decision == O.Authorized(response.amount, response.reason) &&
      plan == [O.Intent(context.chargeId, context.requestId, response.amount, response.reason)]) &&
    (decision.Authorized? <==> O.Eligible(context, response)) &&
    (decision.Rejected? <==> |plan| == 0) &&
    |plan| <= 1 &&
    (decision.Authorized? ==>
      plan == [O.Intent(context.chargeId, context.requestId, decision.amount, decision.reason)]) &&
    (forall intent: O.RefundIntent :: intent in plan ==>
      O.ValidContext(context) && O.Money(intent.amount) &&
      intent.amount <= context.remaining <= context.original &&
      O.AllowedReason(intent.reason) &&
      intent.chargeId == context.chargeId && intent.requestId == context.requestId)
  }

  opaque ghost predicate PostN(context: N.Context, response: N.ModelResponse, decision: N.Decision, plan: seq<N.RefundIntent>)
  {
    (decision.Authorized? ==>
      N.ValidContext(context) && N.Money(decision.amount) &&
      decision.amount <= context.remaining <= context.original) &&
    (decision.Authorized? ==> N.AllowedReason(decision.reason)) &&
    (!N.Eligible(context, response) ==> decision == N.Rejected && plan == []) &&
    (N.Eligible(context, response) ==>
      response.Candidate? && decision == N.Authorized(response.amount, response.reason) &&
      plan == [N.Intent(context.chargeId, context.requestId, response.amount, response.reason)]) &&
    (decision.Authorized? <==> N.Eligible(context, response)) &&
    (decision.Rejected? <==> |plan| == 0) &&
    |plan| <= 1 &&
    (decision.Authorized? ==>
      plan == [N.Intent(context.chargeId, context.requestId, decision.amount, decision.reason)]) &&
    (forall intent: N.RefundIntent :: intent in plan ==>
      N.ValidContext(context) && N.Money(intent.amount) &&
      intent.amount <= context.remaining <= context.original &&
      N.AllowedReason(intent.reason) &&
      intent.chargeId == context.chargeId && intent.requestId == context.requestId)
  }

  method OldAssessThenPost(context: O.Context, response: O.ModelResponse)
      returns (decision: O.Decision, plan: seq<O.RefundIntent>)
    ensures PostO(context, response, decision, plan)
  {
    decision, plan := O.Assess(context, response);
    reveal PostO();
  }

  method NewAssessThenPost(context: N.Context, response: N.ModelResponse)
      returns (decision: N.Decision, plan: seq<N.RefundIntent>)
    ensures PostN(context, response, decision, plan)
  {
    decision, plan := N.Assess(context, response);
    reveal PostN();
  }

  lemma PostOCases(c: O.Context, r: O.ModelResponse, d: O.Decision, p: seq<O.RefundIntent>)
    requires PostO(c, r, d, p)
    ensures !O.Eligible(c, r) ==> d == O.Rejected && p == []
    ensures O.Eligible(c, r) ==>
      r.Candidate? && d == O.Authorized(r.amount, r.reason) && p == [O.Intent(c.chargeId, c.requestId, r.amount, r.reason)]
  {
    reveal PostO();
  }

  lemma PostNCases(c: N.Context, r: N.ModelResponse, d: N.Decision, p: seq<N.RefundIntent>)
    requires PostN(c, r, d, p)
    ensures !N.Eligible(c, r) ==> d == N.Rejected && p == []
    ensures N.Eligible(c, r) ==>
      r.Candidate? && d == N.Authorized(r.amount, r.reason) && p == [N.Intent(c.chargeId, c.requestId, r.amount, r.reason)]
  {
    reveal PostN();
  }

  // E. The two eligibility predicates name the same inputs.
  lemma EligibleNewIff(c: O.Context, r: O.ModelResponse)
    ensures N.Eligible(CtxN(c), RespN(r)) <==> O.Eligible(c, r)
  {
  }

  // D3. Both specifications are deterministic (two-run lemma), so "the result" is well defined.
  lemma OldDeterministic(c: O.Context, r: O.ModelResponse, d1: O.Decision, p1: seq<O.RefundIntent>,
                         d2: O.Decision, p2: seq<O.RefundIntent>)
    requires PostO(c, r, d1, p1) && PostO(c, r, d2, p2)
    ensures d1 == d2 && p1 == p2
  {
    PostOCases(c, r, d1, p1);
    PostOCases(c, r, d2, p2);
  }

  lemma NewDeterministic(c: N.Context, r: N.ModelResponse, d1: N.Decision, p1: seq<N.RefundIntent>,
                         d2: N.Decision, p2: seq<N.RefundIntent>)
    requires PostN(c, r, d1, p1) && PostN(c, r, d2, p2)
    ensures d1 == d2 && p1 == p2
  {
    PostNCases(c, r, d1, p1);
    PostNCases(c, r, d2, p2);
  }

  // Non-vacuity: each specification allows a result for every input.
  lemma OldPostSatisfiable(c: O.Context, r: O.ModelResponse)
    ensures exists d: O.Decision, p: seq<O.RefundIntent> :: PostO(c, r, d, p)
  {
    reveal PostO();
    if O.Eligible(c, r) {
      assert PostO(c, r, O.Authorized(r.amount, r.reason), [O.Intent(c.chargeId, c.requestId, r.amount, r.reason)]);
    } else {
      assert PostO(c, r, O.Rejected, []);
    }
  }

  lemma NewPostSatisfiable(c: N.Context, r: N.ModelResponse)
    ensures exists d: N.Decision, p: seq<N.RefundIntent> :: PostN(c, r, d, p)
  {
    reveal PostN();
    if N.Eligible(c, r) {
      assert PostN(c, r, N.Authorized(r.amount, r.reason), [N.Intent(c.chargeId, c.requestId, r.amount, r.reason)]);
    } else {
      assert PostN(c, r, N.Rejected, []);
    }
  }
}
