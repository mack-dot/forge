include "../../impl/Ledger.dfy"

module SuccessfulExecution {
  import L = Ledger

  // A concrete non-trivial witness, checked against the actual refinement.
  method Witness() {
    var state := L.LedgerState(map[0 := 0, 1 := 11, 2 := 0], map[]);
    var request := L.TransferRequest(1, 2, 10);
    assert L.WellFormed(state);
    assert L.IsFreshValid(state, 7, request);
    var next, outcome := L.Apply(state, 7, request);
    assert outcome == L.Ok;
    assert next.balances == map[0 := 1, 1 := 0, 2 := 10];
    assert next.accepted == map[7 := request];
    assert next != state;
  }
}
