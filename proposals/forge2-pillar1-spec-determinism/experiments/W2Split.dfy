// Round 3 task 3 (U430): experiment on the cost of witness W2 (fee change, both specifications accept).
// Question from the owner: do two or three explicit map-key assertions bring W2 below 300,000 resource units?
// Attempt 2: the statement split into four small lemmas. One batch per lemma, no isolation. NOT part of the gate. The recorded W2 (61 isolated batches) is unchanged.
include "../SpecDiffFee.dfy"

abstract module W2Split {
  import D : SpecDiffFee

  ghost function S(): D.O.State { D.O.LedgerState(map[0 := 0, 1 := 5, 2 := 0], map[]) }
  ghost function R(): D.O.Request { D.O.TransferRequest(1, 2, 4) }

  // Pure map arithmetic. No specification predicate is in scope.
  lemma MapFacts(b: map<int, int>, nb: map<int, int>, nb': map<int, int>)
    requires b == map[0 := 0, 1 := 5, 2 := 0]
    requires nb == b[1 := b[1] - 4][2 := b[2] + 4]
    requires nb' == b[1 := b[1] - 4 - 1][2 := b[2] + 4][0 := b[0] + 1]
    ensures nb.Keys == {0, 1, 2} && nb'.Keys == nb.Keys
    ensures nb[0] == 0 && nb[1] == 1 && nb[2] == 4
    ensures nb'[0] == 1 && nb'[1] == 0 && nb'[2] == 4
  {
  }

  // The numbers for ANY state with these balances and this request, from the general result lemma.
  lemma BothAcceptNumbers(s: D.O.State, id: int, r: D.O.Request, n: D.O.State, o: D.O.Outcome, n': D.N.State, o': D.N.Outcome)
    requires D.O.WellFormed(s) && D.N.IsFreshValid(D.StateN(s), id, D.ReqN(r))
    requires D.PostO(s, id, r, n, o) && D.PostN(D.StateN(s), id, D.ReqN(r), n', o')
    requires s.balances == map[0 := 0, 1 := 5, 2 := 0] && r == D.O.TransferRequest(1, 2, 4)
    ensures n.balances.Keys == {0, 1, 2} && n'.balances.Keys == n.balances.Keys
    ensures o == D.O.Ok && n.balances[0] == 0 && n.balances[1] == 1 && n.balances[2] == 4
    ensures o' == D.N.Ok && n'.balances[0] == 1 && n'.balances[1] == 0 && n'.balances[2] == 4
  {
    D.BothAcceptResult(s, id, r, n, o, n', o');
    MapFacts(s.balances, n.balances, n'.balances);
  }

  lemma OldFacts()
    ensures D.O.WellFormed(S()) && D.O.IsFreshValid(S(), 7, R())
  {
  }

  lemma NewFacts()
    requires D.O.WellFormed(S()) && D.O.IsFreshValid(S(), 7, R())
    ensures D.N.IsFreshValid(D.StateN(S()), 7, D.ReqN(R()))
  {
    D.NewFreshIff(S(), 7, R());
  }

  // Variant D: W2 from the pieces. One batch, no isolation.
  lemma W2D(n: D.O.State, o: D.O.Outcome, n': D.N.State, o': D.N.Outcome)
    requires D.PostO(S(), 7, R(), n, o)
    requires D.PostN(D.StateN(S()), 7, D.ReqN(R()), n', o')
    ensures n.balances.Keys == {0, 1, 2} && n'.balances.Keys == n.balances.Keys
    ensures o == D.O.Ok && n.balances[0] == 0 && n.balances[1] == 1 && n.balances[2] == 4
    ensures o' == D.N.Ok && n'.balances[0] == 1 && n'.balances[1] == 0 && n'.balances[2] == 4
  {
    OldFacts();
    NewFacts();
    BothAcceptNumbers(S(), 7, R(), n, o, n', o');
  }
}
