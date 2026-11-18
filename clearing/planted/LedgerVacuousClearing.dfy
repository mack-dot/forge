// Slice 2: clearing input for the PLANTED vacuous ledger specification (LedgerSpecVacuous.dfy).
// Post, the forward link and the two-run lemma are the text of
// proposals/forge2-pillar1-spec-determinism/LedgerDeterminism.dfy, over the planted module.
// Expected: the two-run lemma is PROVED (no choice) and NeverAccepts is PROVED (vacuous).
include "LedgerSpecVacuous.dfy"

abstract module LedgerVacuousClearing {
  import L : LedgerSpecVacuous

  ghost predicate Post(state: L.State, id: int, request: L.Request, next: L.State, outcome: L.Outcome)
    requires L.WellFormed(state)
  {
    L.WellFormed(next) &&
    next.balances.Keys == state.balances.Keys &&
    L.Total(next.balances) == L.Total(state.balances) &&
    L.NonNegative(next.balances) &&
    (L.IsRetry(state, id, request) ==> outcome == L.Ok && next == state) &&
    (L.IsFreshValid(state, id, request) ==>
      outcome == L.Ok &&
      next.balances ==
        state.balances[
          request.sender := state.balances[request.sender] - request.amount - 1][
          request.recipient := state.balances[request.recipient] + request.amount][
          0 := state.balances[0] + 1] &&
      next.accepted == state.accepted[id := request]) &&
    ((!L.IsRetry(state, id, request) && !L.IsFreshValid(state, id, request)) ==>
      outcome == L.Rejected && next == state)
  }

  method ApplyThenPost(state: L.State, id: int, request: L.Request)
      returns (next: L.State, outcome: L.Outcome)
    requires L.WellFormed(state)
    ensures Post(state, id, request, next, outcome)
  {
    next, outcome := L.Apply(state, id, request);
  }

  lemma SpecIsDeterministic(state: L.State, id: int, request: L.Request,
                            n1: L.State, o1: L.Outcome, n2: L.State, o2: L.Outcome)
    requires L.WellFormed(state)
    requires Post(state, id, request, n1, o1)
    requires Post(state, id, request, n2, o2)
    ensures n1 == n2 && o1 == o2
  {
  }

  // The planted specification accepts nothing: every allowed result is a rejection with the state unchanged.
  lemma NeverAccepts(state: L.State, id: int, request: L.Request, next: L.State, outcome: L.Outcome)
    requires L.WellFormed(state)
    requires Post(state, id, request, next, outcome)
    ensures outcome == L.Rejected && next == state
  {
  }
}

// A refinement exists: the implementation that rejects every request.
module LedgerVacuousRejectAll refines LedgerSpecVacuous {
  method Apply ... {
    next := state;
    outcome := Rejected;
  }
}
