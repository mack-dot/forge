include "RefundLogSpec.dfy"

// Lemmas ABOUT the proposed specification RefundLogSpec. NOT approved. They are machine-checked statements
// about the specification text only. They say nothing about any engine, log file or compiled code.
// No assume, no axiom, no lemma without a body, no extern. end_to_end=false.

// The shape that scripts/spec_clearing.py clears: a forward link to the specified method, and the
// two-run claim (two results that the specification allows for one input are equal).
abstract module RefundLogClaim {
  import S : RefundLogSpec

  method DecideThenPost(s: S.LedgerState, q: S.RefundRequest) returns (r: S.Option<S.LedgerState>)
    ensures S.DecidePost(s, q, r)
  {
    r := S.Decide(s, q);
  }

  lemma NoChoice(s: S.LedgerState, q: S.RefundRequest, r1: S.Option<S.LedgerState>, r2: S.Option<S.LedgerState>)
    requires S.DecidePost(s, q, r1)
    requires S.DecidePost(s, q, r2)
    ensures r1 == r2
  {
  }
}

abstract module RefundLogSpecLemmas {
  import S : RefundLogSpec

  // ---------------- Step and Decide ----------------

  // L1. Step is the executable form of DecidePost: Some exactly when Allowed, and then the Effect.
  lemma StepIsDecidePost(s: S.LedgerState, q: S.RefundRequest)
    ensures S.DecidePost(s, q, S.Step(s, q))
    ensures S.Step(s, q).Some? <==> S.Allowed(s, q)
    ensures S.Step(s, q).Some? ==> S.Effect(s, q, S.Step(s, q).value)
  {
  }

  // L2. NO_CHOICE: the effect leaves no choice, so DecidePost allows one result only, and it is Step's.
  lemma EffectIsUnique(s: S.LedgerState, q: S.RefundRequest, t1: S.LedgerState, t2: S.LedgerState)
    requires S.Effect(s, q, t1) && S.Effect(s, q, t2)
    ensures t1 == t2
  {
  }

  lemma DecidePostIsStep(s: S.LedgerState, q: S.RefundRequest, r: S.Option<S.LedgerState>)
    requires S.DecidePost(s, q, r)
    ensures r == S.Step(s, q)
  {
    StepIsDecidePost(s, q);
    if r.Some? {
      EffectIsUnique(s, q, r.value, S.Step(s, q).value);
    }
  }

  // L3. The stateful permission cannot accept what the approved stateless specification refuses:
  // Allowed is the approved Eligible on the derived inputs, and the approved Assess, called on those
  // inputs, authorizes exactly the allowed requests, with the exact amount, reason and intent.
  lemma AllowedIsApprovedEligible(s: S.LedgerState, q: S.RefundRequest)
    ensures S.Allowed(s, q) <==> S.R.Eligible(S.ContextAt(s, q), S.R.Candidate(q.amount, q.reason))
    ensures S.Allowed(s, q) ==> S.R.ValidContext(S.ContextAt(s, q))
    ensures S.Allowed(s, q) ==> S.RequestOpen(s, q.requestId) && S.RefundEnabled(s)
  {
  }

  method ApprovedAssessAgrees(s: S.LedgerState, q: S.RefundRequest)
  {
    var decision, plan := S.R.Assess(S.ContextAt(s, q), S.R.Candidate(q.amount, q.reason));
    assert decision.Authorized? <==> S.Allowed(s, q);
    assert S.Allowed(s, q) ==>
      decision == S.R.Authorized(q.amount, q.reason) &&
      plan == [S.R.Intent(s.chargeId, q.requestId, q.amount, q.reason)];
    assert !S.Allowed(s, q) ==> decision == S.R.Rejected && plan == [];
  }

  // L4. An allowed step keeps the state well formed.
  lemma StepKeepsWellFormed(s: S.LedgerState, q: S.RefundRequest)
    requires S.Step(s, q).Some?
    ensures S.WellFormed(S.Step(s, q).value)
  {
  }

  // ---------------- The fold ----------------

  // L5. Replay of a log with one more record (the shape of a verifier's loop).
  lemma ReplaySnoc(g: S.LedgerState, log: seq<S.RefundRequest>, q: S.RefundRequest)
    ensures S.Replay(g, log + [q]) ==
      (match S.Replay(g, log) case None => S.None case Some(s) => S.Step(s, q))
  {
    assert (log + [q])[..|log|] == log;
  }

  // L6. Every prefix of a valid history is a valid history.
  lemma PrefixIsValid(g: S.LedgerState, log: seq<S.RefundRequest>, k: nat)
    requires S.ValidHistory(g, log)
    requires k <= |log|
    ensures S.ValidHistory(g, log[..k])
    decreases |log|
  {
    if k < |log| {
      var p := log[..|log| - 1];
      assert S.Replay(g, p).Some?;
      PrefixIsValid(g, p, k);
      assert p[..k] == log[..k];
    } else {
      assert log[..k] == log;
    }
  }

  // L7. The invariant of the fold: conservation, at most once, and a well-formed state.
  lemma ReplayInvariant(g: S.LedgerState, log: seq<S.RefundRequest>)
    requires S.ValidGenesis(g)
    requires S.Replay(g, log).Some?
    ensures S.Conserves(g, log, S.Replay(g, log).value)
    ensures S.WellFormed(S.Replay(g, log).value)
    ensures S.AtMostOnce(log)
    decreases |log|
  {
    if |log| > 0 {
      var p := log[..|log| - 1];
      var q := log[|log| - 1];
      assert log == p + [q];
      ReplayInvariant(g, p);
      var s0 := S.Replay(g, p).value;
      assert S.Replay(g, log) == S.Step(s0, q);
      assert S.Allowed(s0, q);
      assert q.requestId !in S.Ids(p);
      forall i, j | 0 <= i < j < |log|
        ensures log[i].requestId != log[j].requestId
      {
        if j < |log| - 1 {
          assert log[i] == p[i] && log[j] == p[j];
        } else {
          IdIn(p, i);
          assert log[i] == p[i];
        }
      }
    }
  }

  lemma IdIn(log: seq<S.RefundRequest>, i: nat)
    requires i < |log|
    ensures log[i].requestId in S.Ids(log)
    decreases |log|
  {
    if i < |log| - 1 {
      var p := log[..|log| - 1];
      IdIn(p, i);
      assert p[i] == log[i];
    }
  }

  // L8. CONSERVATION for every valid history: original == remaining + the sum of the amounts, and
  // 0 <= remaining <= original; the settled set is the set of the ids of the log, one per record.
  lemma Conservation(g: S.LedgerState, log: seq<S.RefundRequest>)
    requires S.ValidHistory(g, log)
    ensures S.Conserves(g, log, S.Replay(g, log).value)
    ensures g.original == S.Replay(g, log).value.remaining + S.SumAmounts(log)
    ensures 0 <= S.Replay(g, log).value.remaining <= g.original
  {
    ReplayInvariant(g, log);
  }

  // L9. AT MOST ONCE for every valid history: no request id is settled twice.
  lemma AtMostOnceHolds(g: S.LedgerState, log: seq<S.RefundRequest>)
    requires S.ValidHistory(g, log)
    ensures S.AtMostOnce(log)
  {
    ReplayInvariant(g, log);
  }

  // L10. A record that repeats an earlier id ends every history: it is never allowed.
  lemma RepeatedIdIsRefused(g: S.LedgerState, log: seq<S.RefundRequest>, q: S.RefundRequest)
    requires S.ValidHistory(g, log)
    requires q.requestId in S.Ids(log)
    ensures !S.ValidHistory(g, log + [q])
  {
    ReplayInvariant(g, log);
    ReplaySnoc(g, log, q);
  }

  // ---------------- Non-vacuity: one accepted history, and one refusal for each cause ----------------

  function G(): S.LedgerState { S.Genesis("ch_1", 100, true) }
  function Q1(): S.RefundRequest { S.RefundRequest("rq_1", 40, "duplicate_charge") }
  function Q2(): S.RefundRequest { S.RefundRequest("rq_2", 60, "returned_item") }
  function S1(): S.LedgerState { S.LedgerState("ch_1", 100, 60, true, {"rq_1"}, 1) }

  lemma FirstStep()
    ensures S.ValidGenesis(G())
    ensures S.Replay(G(), [Q1()]) == S.Some(S1())
  {
    var log := [Q1()];
    assert log[..0] == [];
    assert S.Replay(G(), log[..0]) == S.Some(G());
    assert S.Replay(G(), log) == S.Step(G(), Q1());
    assert S.Allowed(G(), Q1());
    assert {} + {"rq_1"} == {"rq_1"};
    assert S.Step(G(), Q1()) == S.Some(S1());
  }

  // ACCEPTS: a history of length 2 that refunds the whole charge.
  lemma AcceptedHistoryOfTwo()
    ensures S.ValidHistory(G(), [Q1(), Q2()])
    ensures S.Replay(G(), [Q1(), Q2()]) == S.Some(S.LedgerState("ch_1", 100, 0, true, {"rq_1", "rq_2"}, 2))
  {
    FirstStep();
    var log := [Q1(), Q2()];
    assert log[..1] == [Q1()];
    assert S.Replay(G(), log[..1]) == S.Some(S1());
    assert S.Replay(G(), log) == S.Step(S1(), Q2());
    assert "rq_2" != "rq_1";
    assert S.Allowed(S1(), Q2());
    assert {"rq_1"} + {"rq_2"} == {"rq_1", "rq_2"};
    assert S.Step(S1(), Q2()) == S.Some(S.LedgerState("ch_1", 100, 0, true, {"rq_1", "rq_2"}, 2));
  }

  // ACCEPTS, documented (OWNER DECISION D2, default: the approved Eligible allows zero): a zero amount.
  lemma ZeroAmountIsAllowed()
    ensures S.Allowed(S1(), S.RefundRequest("rq_3", 0, "returned_item"))
  {
    assert "rq_3" != "rq_1";
  }

  // REFUSED: the request id is settled already.
  lemma SettledIdIsRefused()
    ensures S.Step(S1(), S.RefundRequest("rq_1", 10, "duplicate_charge")) == S.None
    ensures !S.ValidHistory(G(), [Q1(), S.RefundRequest("rq_1", 10, "duplicate_charge")])
  {
    FirstStep();
    assert [Q1(), S.RefundRequest("rq_1", 10, "duplicate_charge")][..1] == [Q1()];
  }

  // REFUSED: the amount is above the remaining amount.
  lemma OverRemainingIsRefused()
    ensures S.Step(S1(), S.RefundRequest("rq_2", 61, "duplicate_charge")) == S.None
  {
  }

  // REFUSED: a negative amount.
  lemma NegativeAmountIsRefused()
    ensures S.Step(S1(), S.RefundRequest("rq_2", -1, "duplicate_charge")) == S.None
  {
  }

  // REFUSED: a reason that is not one of the three approved labels (matching is exact).
  lemma ReasonNotAllowedIsRefused()
    ensures S.Step(S1(), S.RefundRequest("rq_2", 10, "goodwill")) == S.None
    ensures S.Step(S1(), S.RefundRequest("rq_2", 10, "Duplicate_charge")) == S.None
  {
    assert "goodwill" !in {"duplicate_charge", "service_not_delivered", "returned_item"};
    assert "Duplicate_charge" != "duplicate_charge";
  }

  // REFUSED: the refund flag of the charge is off (OWNER DECISION D1, option B).
  lemma FlagOffIsRefused()
    ensures S.ValidGenesis(S.Genesis("ch_1", 100, false))
    ensures S.Step(S.Genesis("ch_1", 100, false), Q1()) == S.None
  {
  }

  // REFUSED: an empty request id.
  lemma EmptyRequestIdIsRefused()
    ensures S.Step(S1(), S.RefundRequest("", 10, "duplicate_charge")) == S.None
  {
  }

  // A refusal is not the empty claim: the same state allows a request that differs only in the refused part.
  lemma RefusalsAreNotVacuous()
    ensures S.Step(S1(), S.RefundRequest("rq_2", 60, "duplicate_charge")).Some?
  {
    assert "rq_2" != "rq_1";
  }
}
