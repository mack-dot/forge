// Dafny resolves this import against the approved interface.
// The gate also requires an explicit Ledger refines LedgerSpec declaration.
abstract module RequiredLedger {
  import L : LedgerSpec
}

module BoundLedger refines RequiredLedger {
  import L = Ledger
}
