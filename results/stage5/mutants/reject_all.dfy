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
    next := state;
    outcome := Rejected;
  }
}
