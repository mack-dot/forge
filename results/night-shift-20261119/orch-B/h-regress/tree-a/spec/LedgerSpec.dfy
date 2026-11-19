abstract module LedgerSpec {
  // Each fresh transfer pays one unit to fee account 0.
  datatype Request = TransferRequest(sender: int, recipient: int, amount: int)
  datatype Outcome = Ok | Rejected
  datatype State = LedgerState(
    balances: map<int, int>,
    accepted: map<int, Request>)

  ghost predicate NonNegative(balances: map<int, int>) {
    forall account | account in balances :: 0 <= balances[account]
  }

  ghost predicate WellFormed(state: State) {
    NonNegative(state.balances) &&
    (forall id | id in state.accepted ::
      state.accepted[id].sender in state.balances &&
      state.accepted[id].recipient in state.balances &&
      state.accepted[id].sender != state.accepted[id].recipient &&
      0 < state.accepted[id].amount)
  }

  ghost function Total(balances: map<int, int>): int
    decreases |balances|
  {
    if balances == map[] then 0
    else
      var account :| account in balances;
      balances[account] + Total(balances - {account})
  }

  predicate IsRetry(state: State, id: int, request: Request) {
    id in state.accepted && state.accepted[id] == request
  }

  predicate IsFreshValid(state: State, id: int, request: Request) {
    id !in state.accepted &&
    request.sender in state.balances &&
    request.recipient in state.balances &&
    request.sender != request.recipient &&
    0 in state.balances &&
    request.sender != 0 &&
    request.recipient != 0 &&
    0 < request.amount &&
    request.amount + 1 <= state.balances[request.sender]
  }

  method Apply(state: State, id: int, request: Request)
      returns (next: State, outcome: Outcome)
    requires WellFormed(state)
    ensures WellFormed(next)
    ensures next.balances.Keys == state.balances.Keys
    // C1: conservation.
    ensures Total(next.balances) == Total(state.balances)
    // C2: non-negative balances.
    ensures NonNegative(next.balances)
    // C3: accepted retries return Ok and do not repeat the effect.
    ensures IsRetry(state, id, request) ==>
      outcome == Ok && next == state
    // C4: a valid new request succeeds with exact debit, credit, and fee.
    ensures IsFreshValid(state, id, request) ==>
      outcome == Ok &&
      next.balances ==
        state.balances[
          request.sender := state.balances[request.sender] - request.amount - 1][
          request.recipient := state.balances[request.recipient] + request.amount][
          0 := state.balances[0] + 1] &&
      next.accepted == state.accepted[id := request]
    // C5: every other request is rejected with no state change.
    ensures (!IsRetry(state, id, request) && !IsFreshValid(state, id, request)) ==>
      outcome == Rejected && next == state
}
