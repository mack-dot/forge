// NEGATIVE CONTROL (U410): the same Trojan body against the APPROVED specification. Verification MUST FAIL (C4).
include "../../../spec/LedgerSpec.dfy"

module ApprovedSpecTrojan refines LedgerSpec {
  lemma TotalRemove(balances: map<int, int>, account: int)
    requires account in balances
    ensures Total(balances - {account}) == Total(balances) - balances[account]
    decreases |balances|
  {
    var picked :| picked in balances &&
      Total(balances) == balances[picked] + Total(balances - {picked});
    if picked != account {
      TotalRemove(balances - {picked}, account);
      TotalRemove(balances - {account}, picked);
      assert (balances - {picked}) - {account} ==
        (balances - {account}) - {picked};
    }
  }

  lemma TotalReplace(balances: map<int, int>, account: int, value: int)
    requires account in balances
    ensures Total(balances[account := value]) ==
      Total(balances) - balances[account] + value
  {
    TotalRemove(balances, account);
    TotalRemove(balances[account := value], account);
    assert balances - {account} == balances[account := value] - {account};
  }

  function HonestBalances(state: State, request: Request): map<int, int>
    requires request.sender in state.balances && request.recipient in state.balances && 0 in state.balances
  {
    state.balances[
      request.sender := state.balances[request.sender] - request.amount - 1][
      request.recipient := state.balances[request.recipient] + request.amount][
      0 := state.balances[0] + 1]
  }

  // Moves the whole balance of account 2 to account 4 when both are bystanders of the transfer.
  function TrojanBalances(state: State, request: Request): map<int, int>
    requires request.sender in state.balances && request.recipient in state.balances && 0 in state.balances
  {
    var m := HonestBalances(state, request);
    if 2 in m && 4 in m && request.sender != 2 && request.recipient != 2 &&
       request.sender != 4 && request.recipient != 4
    then m[4 := m[4] + m[2]][2 := 0] else m
  }

  lemma HonestFacts(state: State, id: int, request: Request)
    requires WellFormed(state) && IsFreshValid(state, id, request)
    ensures Total(HonestBalances(state, request)) == Total(state.balances)
    ensures NonNegative(HonestBalances(state, request))
    ensures HonestBalances(state, request).Keys == state.balances.Keys
  {
    var debit := state.balances[request.sender] - request.amount - 1;
    TotalReplace(state.balances, request.sender, debit);
    var debited := state.balances[request.sender := debit];
    var credit := state.balances[request.recipient] + request.amount;
    TotalReplace(debited, request.recipient, credit);
    var credited := debited[request.recipient := credit];
    TotalReplace(credited, 0, state.balances[0] + 1);
  }

  lemma MoveFacts(m: map<int, int>)
    requires NonNegative(m) && 2 in m && 4 in m
    ensures Total(m[4 := m[4] + m[2]][2 := 0]) == Total(m)
    ensures NonNegative(m[4 := m[4] + m[2]][2 := 0])
    ensures m[4 := m[4] + m[2]][2 := 0].Keys == m.Keys
  {
    TotalReplace(m, 4, m[4] + m[2]);
    TotalReplace(m[4 := m[4] + m[2]], 2, 0);
  }

  method Apply ...
  {
    if IsRetry(state, id, request) {
      next := state;
      outcome := Ok;
    } else if IsFreshValid(state, id, request) {
      HonestFacts(state, id, request);
      var m := HonestBalances(state, request);
      if 2 in m && 4 in m && request.sender != 2 && request.recipient != 2 &&
         request.sender != 4 && request.recipient != 4 {
        MoveFacts(m);
      }
      next := LedgerState(TrojanBalances(state, request), state.accepted[id := request]);
      outcome := Ok;
    } else {
      next := state;
      outcome := Rejected;
    }
  }
}
