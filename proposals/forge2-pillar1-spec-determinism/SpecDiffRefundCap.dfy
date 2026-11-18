// Forge 2.0 master idea, Pillar I, Round 2 task 1 (U418): spec-diff check of the approved refund specification
// against a stricter VARIANT (refund cap of half the original charge; fixtures/RefundSpecCapped.dfy).
// The variant is a fixture for this check. It is NOT a proposed specification change.
// NOT part of the gate. Every statement is about results that the specifications ALLOW.
include "../../spec/refund/RefundSpec.dfy"
include "fixtures/RefundSpecCapped.dfy"

abstract module SpecDiffRefundCap {
  import O : RefundSpec
  import N : RefundSpecCapped

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

  // E. The exact relation between the two eligibility predicates.
  lemma EligibleNewIff(c: O.Context, r: O.ModelResponse)
    ensures N.Eligible(CtxN(c), RespN(r)) <==> (O.Eligible(c, r) && r.amount * 2 <= c.original)
  {
  }

  // D1. Unchanged region: every input that the old specification rejects, and every eligible input within the cap.
  lemma UnchangedOutsideTheCap(c: O.Context, r: O.ModelResponse,
                               d: O.Decision, p: seq<O.RefundIntent>, d': N.Decision, p': seq<N.RefundIntent>)
    requires !O.Eligible(c, r) || r.amount * 2 <= c.original
    requires PostO(c, r, d, p) && PostN(CtxN(c), RespN(r), d', p')
    ensures d' == DecN(d) && p' == PlanN(p)
  {
    EligibleNewIff(c, r);
    PostOCases(c, r, d, p);
    PostNCases(CtxN(c), RespN(r), d', p');
    if O.Eligible(c, r) {
      assert PlanN(p) == [IntentN(p[0])];
    } else {
      assert PlanN(p) == [];
    }
  }

  // D2. Changed region: eligible under the old specification and above the cap. Old authorizes; new rejects.
  lemma NewlyRejectedAboveTheCap(c: O.Context, r: O.ModelResponse,
                                 d: O.Decision, p: seq<O.RefundIntent>, d': N.Decision, p': seq<N.RefundIntent>)
    requires O.Eligible(c, r) && r.amount * 2 > c.original
    requires PostO(c, r, d, p) && PostN(CtxN(c), RespN(r), d', p')
    ensures d == O.Authorized(r.amount, r.reason) && |p| == 1
    ensures d' == N.Rejected && p' == []
  {
    EligibleNewIff(c, r);
    PostOCases(c, r, d, p);
    PostNCases(CtxN(c), RespN(r), d', p');
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
