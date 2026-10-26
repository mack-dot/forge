module BasicTests {
  import L = Ledger

  method Main() {
    var initial := L.LedgerState(map[0 := 10, 1 := 0], map[]);
    var next, outcome := L.Apply(initial, 123, L.TransferRequest(0, 1, 3));
    expect outcome == L.Ok;
    expect next.balances == map[0 := 7, 1 := 3];
    var rejected, status := L.Apply(next, 456, L.TransferRequest(0, 99, 1));
    expect status == L.Rejected;
    expect rejected == next;
    print "basic unit tests passed\n";
  }
}
