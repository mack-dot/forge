// Slice 2 (master idea F1.1): the approved ledger specification leaves no choice, and Post is exact.
// Reuses, unchanged, proposals/forge2-pillar1-spec-determinism/LedgerDeterminism.dfy (Post written with
// the predicates of spec/LedgerSpec.dfy itself, the forward link, the two-run lemma).
// NOT an approved specification. NOT part of the gate.
include "../proposals/forge2-pillar1-spec-determinism/LedgerDeterminism.dfy"

abstract module LedgerExact {
  import D : LedgerDeterminism

  // Every result that satisfies Post IS the result that the specified method returns.
  method PostIsExact(state: D.L.State, id: int, request: D.L.Request, next: D.L.State, outcome: D.L.Outcome)
    requires D.L.WellFormed(state)
    requires D.Post(state, id, request, next, outcome)
  {
    var returnedNext, returnedOutcome := D.ApplyThenPost(state, id, request);
    D.SpecIsDeterministic(state, id, request, next, outcome, returnedNext, returnedOutcome);
    assert next == returnedNext && outcome == returnedOutcome;
  }
}
