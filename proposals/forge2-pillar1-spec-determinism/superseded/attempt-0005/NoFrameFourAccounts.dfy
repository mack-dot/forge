// CONTROL (U413), item F1.1d: "bounded blindness". With four accounts or fewer, the planted no-frame specification
// allows only one result: sender, recipient and fee account are fixed by C4, and conservation fixes the one account
// that is left. So no test or bounded check with four accounts or fewer can show the planted bug.
// Balances and amounts are unbounded; only the number of accounts is bounded. Verification MUST SUCCEED.
include "LedgerSpecNoFrame.dfy"

abstract module NoFrameFourAccounts {
  import L : LedgerSpecNoFrame

  ghost predicate Post(state: L.State, id: int, request: L.Request, next: L.State, outcome: L.Outcome)
    requires L.WellFormed(state)
  {
    L.WellFormed(next) &&
    next.balances.Keys == state.balances.Keys &&
    L.Total(next.balances) == L.Total(state.balances) &&
    L.NonNegative(next.balances) &&
    (L.IsRetry(state, id, request) ==> outcome == L.Ok && next == state) &&
    (L.IsFreshValid(state, id, request) ==>
      outcome == L.Ok &&
      next.balances[request.sender] == state.balances[request.sender] - request.amount - 1 &&
      next.balances[request.recipient] == state.balances[request.recipient] + request.amount &&
      next.balances[0] == state.balances[0] + 1 &&
      next.accepted == state.accepted[id := request]) &&
    ((!L.IsRetry(state, id, request) && !L.IsFreshValid(state, id, request)) ==>
      outcome == L.Rejected && next == state)
  }

  method ApplyThenPost(state: L.State, id: int, request: L.Request)
      returns (next: L.State, outcome: L.Outcome)
    requires L.WellFormed(state)
    ensures Post(state, id, request, next, outcome)
  {
    next, outcome := L.Apply(state, id, request);
  }

  lemma TotalRemove(balances: map<int, int>, account: int)
    requires account in balances
    ensures L.Total(balances - {account}) == L.Total(balances) - balances[account]
    decreases |balances|
  {
    var picked :| picked in balances &&
      L.Total(balances) == balances[picked] + L.Total(balances - {picked});
    if picked != account {
      TotalRemove(balances - {picked}, account);
      TotalRemove(balances - {account}, picked);
      assert (balances - {picked}) - {account} ==
        (balances - {account}) - {picked};
    }
  }

  lemma EmptyTotal(m: map<int, int>)
    requires m.Keys == {}
    ensures L.Total(m) == 0
  {
    assert m == map[];
  }

  lemma RemoveThree(m: map<int, int>, a: int, b: int, c: int)
    requires a in m && b in m && c in m && a != b && a != c && b != c
    ensures L.Total(m - {a, b, c}) == L.Total(m) - m[a] - m[b] - m[c]
  {
    TotalRemove(m, a);
    TotalRemove(m - {a}, b);
    TotalRemove(m - {a} - {b}, c);
    assert m - {a} - {b} - {c} == m - {a, b, c};
  }

  lemma AtMostOneLeft(K: set<int>, a: int, b: int, c: int)
    requires |K| <= 4 && a in K && b in K && c in K && a != b && a != c && b != c
    ensures K - {a, b, c} == {} || exists d :: K - {a, b, c} == {d}
  {
    var R := K - {a, b, c};
    assert K * {a, b, c} == {a, b, c};
    assert |{a, b, c}| == 3;
    assert |R| == |K| - |K * {a, b, c}|;
    if R != {} {
      var d :| d in R;
      assert R * {d} == {d};
      assert |R - {d}| == |R| - |R * {d}|;
      assert R - {d} == {};
      assert R == {d};
    }
  }

  lemma SingletonTotal(m: map<int, int>, d: int)
    requires m.Keys == {d}
    ensures L.Total(m) == m[d]
  {
    TotalRemove(m, d);
    EmptyTotal(m - {d});
  }

  // Two balance maps with the same (at most four) accounts, equal on three of them and with equal totals, are equal.
  lemma AgreeOnThree(m1: map<int, int>, m2: map<int, int>, a: int, b: int, c: int)
    requires m1.Keys == m2.Keys && |m1.Keys| <= 4
    requires a in m1 && b in m1 && c in m1 && a != b && a != c && b != c
    requires m1[a] == m2[a] && m1[b] == m2[b] && m1[c] == m2[c]
    requires L.Total(m1) == L.Total(m2)
    ensures m1 == m2
  {
    RemoveThree(m1, a, b, c);
    RemoveThree(m2, a, b, c);
    AtMostOneLeft(m1.Keys, a, b, c);
    var R := m1.Keys - {a, b, c};
    var r1 := m1 - {a, b, c};
    var r2 := m2 - {a, b, c};
    assert r1.Keys == R && r2.Keys == R;
    if R == {} {
      assert forall k | k in m1 :: k in {a, b, c};
    } else {
      var d :| R == {d};
      SingletonTotal(r1, d);
      SingletonTotal(r2, d);
      assert r1[d] == m1[d] && r2[d] == m2[d];
      assert forall k | k in m1 :: k in {a, b, c} || k in R;
    }
    assert forall k | k in m1 :: m1[k] == m2[k];
  }

  lemma DeterministicUpToFourAccounts(state: L.State, id: int, request: L.Request,
                                      n1: L.State, o1: L.Outcome, n2: L.State, o2: L.Outcome)
    requires L.WellFormed(state) && |state.balances.Keys| <= 4
    requires Post(state, id, request, n1, o1)
    requires Post(state, id, request, n2, o2)
    ensures n1 == n2 && o1 == o2
  {
    if L.IsFreshValid(state, id, request) && !L.IsRetry(state, id, request) {
      AgreeOnThree(n1.balances, n2.balances, request.sender, request.recipient, 0);
    }
  }
}
