include "../spec/LedgerSpec.dfy"

module Ledger refines LedgerSpec {
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

  method Apply ... {
    if IsRetry(state, id, request) {
      next := state;
      outcome := Ok;
    } else if IsFreshValid(state, id, request) {
      var debit := state.balances[request.sender] - request.amount - 1;
      TotalReplace(state.balances, request.sender, debit);
      var debited := state.balances[request.sender := debit];
      var credit := state.balances[request.recipient] + request.amount;
      TotalReplace(debited, request.recipient, credit);
      var credited := debited[request.recipient := credit];
      var fee := state.balances[0] + 1;
      TotalReplace(credited, 0, fee);
      next := LedgerState(
        credited[0 := fee],
        state.accepted[id := request]);
      outcome := Ok;
    } else {
      next := state;
      outcome := Rejected;
    }
  }
}
