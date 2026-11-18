// CANDIDATE gate text (U414), NOT applied: a caller of Ledger.Apply that has no {:print} attribute.
// With --track-print-effects, Dafny rejects the program when Ledger.Apply (or anything it calls) has print effects,
// including when the implementer marks Apply with {:print}. No text scan is needed.
module NoPrintEffects {
  import L = Ledger

  method CallApply(state: L.State, id: int, request: L.Request)
      returns (next: L.State, outcome: L.Outcome)
    requires L.WellFormed(state)
  {
    next, outcome := L.Apply(state, id, request);
  }
}
