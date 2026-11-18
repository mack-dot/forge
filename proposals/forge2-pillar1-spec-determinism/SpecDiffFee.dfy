// Forge 2.0 master idea, Pillar I, item F1.3 (U413): spec-diff check on the approved fee change (proposals/fees.md).
// Old: spec/LedgerSpec.dfy at c909a640 (fixtures/LedgerSpecNoFee.dfy). New: the approved spec/LedgerSpec.dfy.
// NOT part of the gate. NOT a protected file. Every statement is about results that the specifications ALLOW.
// The two wrapper methods are checked against the two method specifications (spec result ==> Post).
include "../../spec/LedgerSpec.dfy"
include "fixtures/LedgerSpecNoFee.dfy"

abstract module SpecDiffFee {
  import O : LedgerSpecNoFee
  import N : LedgerSpec

  function ReqN(r: O.Request): N.Request
  {
    N.TransferRequest(r.sender, r.recipient, r.amount)
  }

  function StateN(s: O.State): N.State
  {
    N.LedgerState(s.balances, map id | id in s.accepted :: ReqN(s.accepted[id]))
  }

  opaque ghost predicate PostO(state: O.State, id: int, request: O.Request, next: O.State, outcome: O.Outcome)
  {
    O.WellFormed(next) &&
    next.balances.Keys == state.balances.Keys &&
    O.Total(next.balances) == O.Total(state.balances) &&
    O.NonNegative(next.balances) &&
    (O.IsRetry(state, id, request) ==> outcome == O.Ok && next == state) &&
    (O.IsFreshValid(state, id, request) ==>
      outcome == O.Ok &&
      next.balances ==
        state.balances[
          request.sender := state.balances[request.sender] - request.amount][
          request.recipient := state.balances[request.recipient] + request.amount] &&
      next.accepted == state.accepted[id := request]) &&
    ((!O.IsRetry(state, id, request) && !O.IsFreshValid(state, id, request)) ==>
      outcome == O.Rejected && next == state)
  }

  opaque ghost predicate PostN(state: N.State, id: int, request: N.Request, next: N.State, outcome: N.Outcome)
  {
    N.WellFormed(next) &&
    next.balances.Keys == state.balances.Keys &&
    N.Total(next.balances) == N.Total(state.balances) &&
    N.NonNegative(next.balances) &&
    (N.IsRetry(state, id, request) ==> outcome == N.Ok && next == state) &&
    (N.IsFreshValid(state, id, request) ==>
      outcome == N.Ok &&
      next.balances ==
        state.balances[
          request.sender := state.balances[request.sender] - request.amount - 1][
          request.recipient := state.balances[request.recipient] + request.amount][
          0 := state.balances[0] + 1] &&
      next.accepted == state.accepted[id := request]) &&
    ((!N.IsRetry(state, id, request) && !N.IsFreshValid(state, id, request)) ==>
      outcome == N.Rejected && next == state)
  }

  method OldApplyThenPost(state: O.State, id: int, request: O.Request)
      returns (next: O.State, outcome: O.Outcome)
    requires O.WellFormed(state)
    ensures PostO(state, id, request, next, outcome)
  {
    next, outcome := O.Apply(state, id, request);
    reveal PostO();
  }

  method NewApplyThenPost(state: N.State, id: int, request: N.Request)
      returns (next: N.State, outcome: N.Outcome)
    requires N.WellFormed(state)
    ensures PostN(state, id, request, next, outcome)
  {
    next, outcome := N.Apply(state, id, request);
    reveal PostN();
  }

  // What an allowed result must be, without the other clauses in the solver's context.
  lemma PostOCases(s: O.State, id: int, r: O.Request, n: O.State, o: O.Outcome)
    requires PostO(s, id, r, n, o)
    ensures n.balances.Keys == s.balances.Keys
    ensures O.IsRetry(s, id, r) ==> o == O.Ok && n == s
    ensures O.IsFreshValid(s, id, r) ==>
      o == O.Ok &&
      n.balances == s.balances[r.sender := s.balances[r.sender] - r.amount][r.recipient := s.balances[r.recipient] + r.amount] &&
      n.accepted == s.accepted[id := r]
    ensures (!O.IsRetry(s, id, r) && !O.IsFreshValid(s, id, r)) ==> o == O.Rejected && n == s
  {
    reveal PostO();
  }

  lemma PostNCases(s: N.State, id: int, r: N.Request, n: N.State, o: N.Outcome)
    requires PostN(s, id, r, n, o)
    ensures n.balances.Keys == s.balances.Keys
    ensures N.IsRetry(s, id, r) ==> o == N.Ok && n == s
    ensures N.IsFreshValid(s, id, r) ==>
      o == N.Ok &&
      n.balances == s.balances[r.sender := s.balances[r.sender] - r.amount - 1][
                      r.recipient := s.balances[r.recipient] + r.amount][0 := s.balances[0] + 1] &&
      n.accepted == s.accepted[id := r]
    ensures (!N.IsRetry(s, id, r) && !N.IsFreshValid(s, id, r)) ==> o == N.Rejected && n == s
  {
    reveal PostN();
  }

  lemma WellFormedCarries(s: O.State)
    requires O.WellFormed(s)
    ensures N.WellFormed(StateN(s))
  {
  }

  lemma RetryCarries(s: O.State, id: int, r: O.Request)
    ensures N.IsRetry(StateN(s), id, ReqN(r)) <==> O.IsRetry(s, id, r)
  {
  }

  lemma NewFreshImpliesOldFresh(s: O.State, id: int, r: O.Request)
    requires N.IsFreshValid(StateN(s), id, ReqN(r))
    ensures O.IsFreshValid(s, id, r)
  {
  }

  lemma NewFreshIff(s: O.State, id: int, r: O.Request)
    requires O.IsFreshValid(s, id, r)
    ensures N.IsFreshValid(StateN(s), id, ReqN(r)) <==>
            (0 in s.balances && r.sender != 0 && r.recipient != 0 && r.amount + 1 <= s.balances[r.sender])
  {
  }

  // D1. Unchanged region: every input that the old specification does not accept as a fresh transfer
  // (retries and rejections). Both specifications force the same state and the same outcome.
  lemma UnchangedWhenOldDoesNotAccept(s: O.State, id: int, r: O.Request,
                                      n: O.State, o: O.Outcome, n': N.State, o': N.Outcome)
    requires O.WellFormed(s) && !O.IsFreshValid(s, id, r)
    requires PostO(s, id, r, n, o) && PostN(StateN(s), id, ReqN(r), n', o')
    ensures n == s && n' == StateN(s)
    ensures (o == O.Ok <==> o' == N.Ok) && (o == O.Rejected <==> o' == N.Rejected)
    ensures o == (if O.IsRetry(s, id, r) then O.Ok else O.Rejected)
  {
    PostOCases(s, id, r, n, o);
    PostNCases(StateN(s), id, ReqN(r), n', o');
    RetryCarries(s, id, r);
    if N.IsFreshValid(StateN(s), id, ReqN(r)) {
      NewFreshImpliesOldFresh(s, id, r);
    }
  }

  // D2. Both accept: the new result is the old result with one unit moved from the sender to account 0.
  lemma FeeDeltaWhenBothAccept(s: O.State, id: int, r: O.Request,
                               n: O.State, o: O.Outcome, n': N.State, o': N.Outcome)
    requires O.WellFormed(s) && N.IsFreshValid(StateN(s), id, ReqN(r))
    requires PostO(s, id, r, n, o) && PostN(StateN(s), id, ReqN(r), n', o')
    ensures o == O.Ok && o' == N.Ok
    ensures O.IsFreshValid(s, id, r) && 0 in s.balances && r.sender != 0 && r.recipient != 0
    ensures n.balances ==
            s.balances[r.sender := s.balances[r.sender] - r.amount][r.recipient := s.balances[r.recipient] + r.amount]
    ensures n'.balances.Keys == n.balances.Keys
    ensures n'.balances[r.sender] == n.balances[r.sender] - 1
    ensures n'.balances[0] == n.balances[0] + 1
    ensures forall k | k in n.balances && k != r.sender && k != 0 :: n'.balances[k] == n.balances[k]
    ensures n.accepted == s.accepted[id := r] && n'.accepted == StateN(s).accepted[id := ReqN(r)]
  {
    NewFreshImpliesOldFresh(s, id, r);
    PostOCases(s, id, r, n, o);
    PostNCases(StateN(s), id, ReqN(r), n', o');
  }

  // D2 in explicit form: both results as updates of the old balances.
  lemma BothAcceptResult(s: O.State, id: int, r: O.Request,
                         n: O.State, o: O.Outcome, n': N.State, o': N.Outcome)
    requires O.WellFormed(s) && N.IsFreshValid(StateN(s), id, ReqN(r))
    requires PostO(s, id, r, n, o) && PostN(StateN(s), id, ReqN(r), n', o')
    ensures o == O.Ok && o' == N.Ok
    ensures r.sender in s.balances && r.recipient in s.balances && 0 in s.balances
    ensures n.balances ==
            s.balances[r.sender := s.balances[r.sender] - r.amount][r.recipient := s.balances[r.recipient] + r.amount]
    ensures n'.balances ==
            s.balances[r.sender := s.balances[r.sender] - r.amount - 1][
              r.recipient := s.balances[r.recipient] + r.amount][0 := s.balances[0] + 1]
  {
    NewFreshImpliesOldFresh(s, id, r);
    PostOCases(s, id, r, n, o);
    PostNCases(StateN(s), id, ReqN(r), n', o');
  }

  // D3. The exact boundary: inputs that the old specification accepts and the new one rejects.
  lemma NewlyRejectedIff(s: O.State, id: int, r: O.Request)
    requires O.WellFormed(s) && O.IsFreshValid(s, id, r)
    ensures !N.IsFreshValid(StateN(s), id, ReqN(r)) <==>
            (0 !in s.balances || r.sender == 0 || r.recipient == 0 || s.balances[r.sender] == r.amount)
  {
    NewFreshIff(s, id, r);
  }

  lemma NewlyRejected(s: O.State, id: int, r: O.Request,
                      n: O.State, o: O.Outcome, n': N.State, o': N.Outcome)
    requires O.WellFormed(s) && O.IsFreshValid(s, id, r) && !N.IsFreshValid(StateN(s), id, ReqN(r))
    requires PostO(s, id, r, n, o) && PostN(StateN(s), id, ReqN(r), n', o')
    ensures o == O.Ok && o' == N.Rejected && n' == StateN(s)
    ensures n.balances ==
            s.balances[r.sender := s.balances[r.sender] - r.amount][r.recipient := s.balances[r.recipient] + r.amount]
  {
    PostOCases(s, id, r, n, o);
    PostNCases(StateN(s), id, ReqN(r), n', o');
    RetryCarries(s, id, r);
  }

  // D4. Changed region: every input that the old specification accepts gives a different result under the new one.
  lemma ChangedWhenOldAccepts(s: O.State, id: int, r: O.Request,
                              n: O.State, o: O.Outcome, n': N.State, o': N.Outcome)
    requires O.WellFormed(s) && O.IsFreshValid(s, id, r)
    requires PostO(s, id, r, n, o) && PostN(StateN(s), id, ReqN(r), n', o')
    ensures o == O.Ok
    ensures o' == N.Rejected || n'.balances != n.balances
  {
    if N.IsFreshValid(StateN(s), id, ReqN(r)) {
      FeeDeltaWhenBothAccept(s, id, r, n, o, n', o');
      assert r.sender in n.balances && n'.balances[r.sender] != n.balances[r.sender];
    } else {
      NewlyRejected(s, id, r, n, o, n', o');
    }
  }

  lemma KeysOf(s: O.State, id: int, r: O.Request, n: O.State, o: O.Outcome, n': N.State, o': N.Outcome)
    requires PostO(s, id, r, n, o) && PostN(StateN(s), id, ReqN(r), n', o')
    ensures n.balances.Keys == s.balances.Keys && n'.balances.Keys == s.balances.Keys
  {
    PostOCases(s, id, r, n, o);
    PostNCases(StateN(s), id, ReqN(r), n', o');
  }

  // ---- Non-vacuity: each specification allows a result for every well-formed state. ----
  lemma TotalRemoveO(balances: map<int, int>, account: int)
    requires account in balances
    ensures O.Total(balances - {account}) == O.Total(balances) - balances[account]
    decreases |balances|
  {
    var picked :| picked in balances &&
      O.Total(balances) == balances[picked] + O.Total(balances - {picked});
    if picked != account {
      TotalRemoveO(balances - {picked}, account);
      TotalRemoveO(balances - {account}, picked);
      assert (balances - {picked}) - {account} == (balances - {account}) - {picked};
    }
  }

  lemma TotalReplaceO(balances: map<int, int>, account: int, value: int)
    requires account in balances
    ensures O.Total(balances[account := value]) == O.Total(balances) - balances[account] + value
  {
    TotalRemoveO(balances, account);
    TotalRemoveO(balances[account := value], account);
    assert balances - {account} == balances[account := value] - {account};
  }

  lemma TotalRemoveN(balances: map<int, int>, account: int)
    requires account in balances
    ensures N.Total(balances - {account}) == N.Total(balances) - balances[account]
    decreases |balances|
  {
    var picked :| picked in balances &&
      N.Total(balances) == balances[picked] + N.Total(balances - {picked});
    if picked != account {
      TotalRemoveN(balances - {picked}, account);
      TotalRemoveN(balances - {account}, picked);
      assert (balances - {picked}) - {account} == (balances - {account}) - {picked};
    }
  }

  lemma TotalReplaceN(balances: map<int, int>, account: int, value: int)
    requires account in balances
    ensures N.Total(balances[account := value]) == N.Total(balances) - balances[account] + value
  {
    TotalRemoveN(balances, account);
    TotalRemoveN(balances[account := value], account);
    assert balances - {account} == balances[account := value] - {account};
  }

  lemma OldAcceptFacts(s: O.State, id: int, r: O.Request)
    requires O.WellFormed(s) && O.IsFreshValid(s, id, r)
    ensures var m := s.balances[r.sender := s.balances[r.sender] - r.amount][r.recipient := s.balances[r.recipient] + r.amount];
            O.Total(m) == O.Total(s.balances) && O.NonNegative(m) && m.Keys == s.balances.Keys
  {
    var debit := s.balances[r.sender] - r.amount;
    TotalReplaceO(s.balances, r.sender, debit);
    TotalReplaceO(s.balances[r.sender := debit], r.recipient, s.balances[r.recipient] + r.amount);
  }

  lemma NewAcceptFacts(s: N.State, id: int, r: N.Request)
    requires N.WellFormed(s) && N.IsFreshValid(s, id, r)
    ensures var m := s.balances[r.sender := s.balances[r.sender] - r.amount - 1][
                       r.recipient := s.balances[r.recipient] + r.amount][0 := s.balances[0] + 1];
            N.Total(m) == N.Total(s.balances) && N.NonNegative(m) && m.Keys == s.balances.Keys
  {
    var debit := s.balances[r.sender] - r.amount - 1;
    TotalReplaceN(s.balances, r.sender, debit);
    var debited := s.balances[r.sender := debit];
    TotalReplaceN(debited, r.recipient, s.balances[r.recipient] + r.amount);
    TotalReplaceN(debited[r.recipient := s.balances[r.recipient] + r.amount], 0, s.balances[0] + 1);
  }

  lemma OldAcceptWellFormed(s: O.State, id: int, r: O.Request, m: map<int, int>)
    requires O.WellFormed(s) && O.IsFreshValid(s, id, r)
    requires O.NonNegative(m) && m.Keys == s.balances.Keys
    ensures O.WellFormed(O.LedgerState(m, s.accepted[id := r]))
  {
  }

  lemma NewAcceptWellFormed(s: N.State, id: int, r: N.Request, m: map<int, int>)
    requires N.WellFormed(s) && N.IsFreshValid(s, id, r)
    requires N.NonNegative(m) && m.Keys == s.balances.Keys
    ensures N.WellFormed(N.LedgerState(m, s.accepted[id := r]))
  {
  }

  lemma PostOSame(s: O.State, id: int, r: O.Request)
    requires O.WellFormed(s) && !O.IsFreshValid(s, id, r)
    ensures PostO(s, id, r, s, if O.IsRetry(s, id, r) then O.Ok else O.Rejected)
  {
    reveal PostO();
  }

  lemma PostNSame(s: N.State, id: int, r: N.Request)
    requires N.WellFormed(s) && !N.IsFreshValid(s, id, r)
    ensures PostN(s, id, r, s, if N.IsRetry(s, id, r) then N.Ok else N.Rejected)
  {
    reveal PostN();
  }

  lemma PostOAccept(s: O.State, id: int, r: O.Request, n: O.State)
    requires O.WellFormed(s) && O.IsFreshValid(s, id, r)
    requires O.WellFormed(n) && n.balances.Keys == s.balances.Keys && O.Total(n.balances) == O.Total(s.balances)
    requires n.balances ==
             s.balances[r.sender := s.balances[r.sender] - r.amount][r.recipient := s.balances[r.recipient] + r.amount]
    requires n.accepted == s.accepted[id := r]
    ensures PostO(s, id, r, n, O.Ok)
  {
    reveal PostO();
  }

  lemma PostNAccept(s: N.State, id: int, r: N.Request, n: N.State)
    requires N.WellFormed(s) && N.IsFreshValid(s, id, r)
    requires N.WellFormed(n) && n.balances.Keys == s.balances.Keys && N.Total(n.balances) == N.Total(s.balances)
    requires n.balances ==
             s.balances[r.sender := s.balances[r.sender] - r.amount - 1][
               r.recipient := s.balances[r.recipient] + r.amount][0 := s.balances[0] + 1]
    requires n.accepted == s.accepted[id := r]
    ensures PostN(s, id, r, n, N.Ok)
  {
    reveal PostN();
  }

  lemma OldPostSatisfiable(s: O.State, id: int, r: O.Request)
    requires O.WellFormed(s)
    ensures exists n: O.State, o: O.Outcome :: PostO(s, id, r, n, o)
  {
    if O.IsFreshValid(s, id, r) {
      OldAcceptFacts(s, id, r);
      var m := s.balances[r.sender := s.balances[r.sender] - r.amount][r.recipient := s.balances[r.recipient] + r.amount];
      OldAcceptWellFormed(s, id, r, m);
      PostOAccept(s, id, r, O.LedgerState(m, s.accepted[id := r]));
    } else {
      PostOSame(s, id, r);
    }
  }

  lemma NewPostSatisfiable(s: N.State, id: int, r: N.Request)
    requires N.WellFormed(s)
    ensures exists n: N.State, o: N.Outcome :: PostN(s, id, r, n, o)
  {
    if N.IsFreshValid(s, id, r) {
      NewAcceptFacts(s, id, r);
      var m := s.balances[r.sender := s.balances[r.sender] - r.amount - 1][
                 r.recipient := s.balances[r.recipient] + r.amount][0 := s.balances[0] + 1];
      NewAcceptWellFormed(s, id, r, m);
      PostNAccept(s, id, r, N.LedgerState(m, s.accepted[id := r]));
    } else {
      PostNSame(s, id, r);
    }
  }
}
