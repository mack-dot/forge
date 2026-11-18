// NEGATIVE CONTROL (U410): the determinism lemma for the planted-bug specification. Verification MUST FAIL.
include "LedgerSpecNoFrame.dfy"

abstract module NoFrameDeterminism {
  import L : LedgerSpecNoFrame

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
      next.balances[request.sender] == state.balances[request.sender] - request.amount - 1 &&
      next.balances[request.recipient] == state.balances[request.recipient] + request.amount &&
      next.balances[0] == state.balances[0] + 1 &&
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
}
