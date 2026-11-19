module BasicTests {
  import L = Ledger

  method Main() {
    var initial := L.LedgerState(map[0 := 0, 1 := 10, 2 := 0], map[]);
    var next, outcome := L.Apply(initial, 123, L.TransferRequest(1, 2, 3));
    expect outcome == L.Ok;
    expect next.balances == map[0 := 1, 1 := 6, 2 := 3];
    var rejected, status := L.Apply(next, 456, L.TransferRequest(1, 99, 1));
    expect status == L.Rejected;
    expect rejected == next;
    print "basic unit tests passed\n";
  }
}
