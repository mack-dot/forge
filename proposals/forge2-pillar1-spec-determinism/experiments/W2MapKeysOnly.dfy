// Round 3 task 3 (U430): experiment on the cost of witness W2 (fee change, both specifications accept).
// Question from the owner: do two or three explicit map-key assertions bring W2 below 300,000 resource units?
// Attempt 1: explicit map-key assertions only. RESULT: variants A, B and C run OUT OF RESOURCE (exit 4). That is a
// failed attempt, not a proof of anything. Kept as a record. NOT part of the gate. The recorded W2 (61 isolated batches) is unchanged.
include "../SpecDiffFee.dfy"

abstract module W2MapKeysOnly {
  import D : SpecDiffFee

  ghost function S(): D.O.State { D.O.LedgerState(map[0 := 0, 1 := 5, 2 := 0], map[]) }
  ghost function R(): D.O.Request { D.O.TransferRequest(1, 2, 4) }

  // Facts about the literal state, proved once, away from the opaque predicates.
  lemma StateFacts()
    ensures S().balances.Keys == {0, 1, 2}
    ensures S().balances[0] == 0 && S().balances[1] == 5 && S().balances[2] == 0
    ensures D.O.WellFormed(S()) && D.O.IsFreshValid(S(), 7, R())
    ensures D.N.IsFreshValid(D.StateN(S()), 7, D.ReqN(R()))
  {
    assert D.O.WellFormed(S());
    assert D.O.IsFreshValid(S(), 7, R());
    D.NewFreshIff(S(), 7, R());
  }

  // Variant A: three explicit map-key assertions, ONE verification batch (no isolation).
  lemma W2A(n: D.O.State, o: D.O.Outcome, n': D.N.State, o': D.N.Outcome)
    requires D.PostO(S(), 7, R(), n, o)
    requires D.PostN(D.StateN(S()), 7, D.ReqN(R()), n', o')
    ensures n.balances.Keys == {0, 1, 2} && n'.balances.Keys == n.balances.Keys
    ensures o == D.O.Ok && n.balances[0] == 0 && n.balances[1] == 1 && n.balances[2] == 4
    ensures o' == D.N.Ok && n'.balances[0] == 1 && n'.balances[1] == 0 && n'.balances[2] == 4
  {
    StateFacts();
    D.KeysOf(S(), 7, R(), n, o, n', o');
    D.BothAcceptResult(S(), 7, R(), n, o, n', o');
    var b := S().balances;
    assert n.balances == b[1 := 1][2 := 4];                 // map-key assertion 1
    assert n'.balances == b[1 := 0][2 := 4][0 := 1];        // map-key assertion 2
    assert 0 in b && 1 in b && 2 in b;                      // map-key assertion 3
  }

  // Variant B: the same body with isolated assertions (the mechanism of the recorded W2).
  lemma {:isolate_assertions} W2B(n: D.O.State, o: D.O.Outcome, n': D.N.State, o': D.N.Outcome)
    requires D.PostO(S(), 7, R(), n, o)
    requires D.PostN(D.StateN(S()), 7, D.ReqN(R()), n', o')
    ensures n.balances.Keys == {0, 1, 2} && n'.balances.Keys == n.balances.Keys
    ensures o == D.O.Ok && n.balances[0] == 0 && n.balances[1] == 1 && n.balances[2] == 4
    ensures o' == D.N.Ok && n'.balances[0] == 1 && n'.balances[1] == 0 && n'.balances[2] == 4
  {
    StateFacts();
    D.KeysOf(S(), 7, R(), n, o, n', o');
    D.BothAcceptResult(S(), 7, R(), n, o, n', o');
    var b := S().balances;
    assert n.balances == b[1 := 1][2 := 4];
    assert n'.balances == b[1 := 0][2 := 4][0 := 1];
    assert 0 in b && 1 in b && 2 in b;
  }

  // Variant C: no explicit map-key assertion, one batch. The control: this is the shape that failed five times in Round 1.
  lemma W2C(n: D.O.State, o: D.O.Outcome, n': D.N.State, o': D.N.Outcome)
    requires D.PostO(S(), 7, R(), n, o)
    requires D.PostN(D.StateN(S()), 7, D.ReqN(R()), n', o')
    ensures n.balances.Keys == {0, 1, 2} && n'.balances.Keys == n.balances.Keys
    ensures o == D.O.Ok && n.balances[0] == 0 && n.balances[1] == 1 && n.balances[2] == 4
    ensures o' == D.N.Ok && n'.balances[0] == 1 && n'.balances[1] == 0 && n'.balances[2] == 4
  {
    StateFacts();
    D.KeysOf(S(), 7, R(), n, o, n', o');
    D.BothAcceptResult(S(), 7, R(), n, o, n', o');
  }
}
