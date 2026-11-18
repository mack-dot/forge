// HISTORICAL FIXTURE for Slice 2. impl/Ledger.dfy at commit c909a640 (before the approved fee change), with TWO
// changes: the path of the included file and the module names. It is the implementation of the old ledger specification
// (fixtures/LedgerSpecNoFee.dfy of the Pillar I packet). It shows that the old side of the fee pair has a refinement.
include "../../proposals/forge2-pillar1-spec-determinism/fixtures/LedgerSpecNoFee.dfy"

module LedgerNoFeeImpl refines LedgerSpecNoFee {
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
      var debit := state.balances[request.sender] - request.amount;
      TotalReplace(state.balances, request.sender, debit);
      var debited := state.balances[request.sender := debit];
      var credit := state.balances[request.recipient] + request.amount;
      TotalReplace(debited, request.recipient, credit);
      next := LedgerState(
        debited[request.recipient := credit],
        state.accepted[id := request]);
      outcome := Ok;
    } else {
      next := state;
      outcome := Rejected;
    }
  }
}
