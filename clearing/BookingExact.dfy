// Slice 2 (master idea F1.1): the approved booking specification leaves no choice, and Post is exact.
// Reuses, unchanged, proposals/forge2-pillar1-spec-determinism/BookingDeterminism.dfy (Post written with
// the predicates of spec/booking/BookingSpec.dfy itself, the forward link, the two-run lemma).
// NOT an approved specification. NOT part of the gate.
include "../proposals/forge2-pillar1-spec-determinism/BookingDeterminism.dfy"

abstract module BookingExact {
  import D : BookingDeterminism

  // Every result that satisfies Post IS the result that the specified method returns.
  method PostIsExact(state: D.B.State, id: int, request: D.B.Request, next: D.B.State, outcome: D.B.Outcome)
    requires D.B.WellFormed(state)
    requires D.Post(state, id, request, next, outcome)
  {
    var returnedNext, returnedOutcome := D.ApplyThenPost(state, id, request);
    D.SpecIsDeterministic(state, id, request, next, outcome, returnedNext, returnedOutcome);
    assert next == returnedNext && outcome == returnedOutcome;
  }
}
