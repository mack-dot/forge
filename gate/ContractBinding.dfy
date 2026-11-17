// Dafny resolves this import against the approved interface.
// The gate also requires an explicit Ledger refines LedgerSpec declaration.
abstract module RequiredLedger {
  import L : LedgerSpec
}

module BoundLedger refines RequiredLedger {
  import L = Ledger
}

// A caller of Ledger.Apply without a {:print} attribute. With --track-print-effects,
// Dafny rejects the program when Apply, or anything it calls, has print effects.
module NoPrintEffects {
  import L = Ledger

  method CallApply(state: L.State, id: int, request: L.Request)
      returns (next: L.State, outcome: L.Outcome)
    requires L.WellFormed(state)
  {
    next, outcome := L.Apply(state, id, request);
  }
}
