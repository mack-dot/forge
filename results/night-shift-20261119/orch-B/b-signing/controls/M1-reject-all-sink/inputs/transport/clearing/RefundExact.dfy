// Slice 2 (master idea F1.1): the approved refund specification leaves no choice, and Post is exact.
// Reuses, unchanged, the Post predicate, the forward link and the two-run lemma of
// proposals/forge2-pillar1-spec-determinism/RefundDeterminism.dfy. That Post is written with the
// predicates of spec/refund/RefundSpec.dfy itself (R.Eligible, R.ValidContext, R.Money, R.AllowedReason).
// NOT an approved specification. NOT part of the gate.
include "../proposals/forge2-pillar1-spec-determinism/RefundDeterminism.dfy"

abstract module RefundExact {
  import D : RefundDeterminism

  // Post is not weaker than the specification: every result that satisfies Post IS the result that
  // the specified method returns. (Forward link: the method's result satisfies Post. Two-run lemma:
  // Post has at most one result.) So Post and "allowed by the specification" name the same results.
  method PostIsExact(context: D.R.Context, response: D.R.ModelResponse,
                     decision: D.R.Decision, plan: seq<D.R.RefundIntent>)
    requires D.Post(context, response, decision, plan)
  {
    var returnedDecision, returnedPlan := D.AssessThenPost(context, response);
    D.SpecIsDeterministic(context, response, decision, plan, returnedDecision, returnedPlan);
    assert decision == returnedDecision && plan == returnedPlan;
  }

  // The specification is not vacuous: Post holds for one concrete accepted refund and for one
  // concrete rejected proposal.
  lemma AcceptsAndRejects()
    ensures D.Post(D.R.ChargeContext("ch_1", "rq_1", 100, 60, true, true), D.R.Candidate(40, "duplicate_charge"),
                   D.R.Authorized(40, "duplicate_charge"), [D.R.Intent("ch_1", "rq_1", 40, "duplicate_charge")])
    ensures D.Post(D.R.ChargeContext("ch_1", "rq_1", 100, 60, true, true), D.R.Candidate(61, "duplicate_charge"),
                   D.R.Rejected, [])
  {
  }
}
