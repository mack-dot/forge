// MUTANT (must FAIL verification): Mutant_NoSigOk.dfy
// d-v5sink (night shift 2026-11-19, Orchestrator B). A DRAFT. NOT gate evidence. NOT about sink.ts.
// G1: a STREAMING, money-conserving start-up audit (AuditV5). It replaces the structure-only audit of ShellCoreV4.
// The shell folds AuditStep over the stored rows in commit order with CONSTANT state AState(cur, count, ok):
//   cur   = the replayed charge (starts at the SUPPLIED initial charge `init`),
//   count = the number of rows seen, ok = all rows so far passed.
// One row = (settled.request_id, the DECODED stored token, sigOk, preOk, the decoded outbox intent). The shell
// recomputes sigOk (Ed25519 of the stored token text, pinned key) and preOk (SHA-256 of the canonical text of the
// replayed charge cur == the token's pre-state hash). Per row the step re-evaluates the approved relation
// F.Authorizes(cur, transition of the token) on the REPLAYED state; then cur := token.post.
// AuditEnd: ok, replayed charge == STORED charge, count == |settled| == |outbox| == #distinct settled ids, and
// 0 <= init.remaining <= init.original.
// MONEY IS CONSERVED RELATIVE TO THE SUPPLIED INITIAL CHARGE. The audit cannot know whether `init` is the true
// initial charge: the shell must take it from OUTSIDE the database (configuration). Rollback of the whole database
// to a state that this sink wrote earlier is NOT detectable here (it is a valid replay prefix).
// The soundness theorem has NO hypothesis about signatures (sigOk is checked, but money conservation does not use it).
// No assume, no axiom, no bodiless lemma, no {:verify false}, no expect, no extern.
include "ShellCoreV4.dfy"

module ShellCoreV5 {
  import V4 = ShellCoreV4
  import V3 = ShellCoreV3
  import C = SinkCoreV3
  import F = RefundFinality
  import R = Refund

  // ---------------- the executable audit (compiled; the shell calls AInit, AuditStep, AuditEnd) ----------------
  datatype Row = Row(settledId: string, tok: V3.ShellToken, sigOk: bool, preOk: bool, outIntent: R.RefundIntent)
  datatype AState = AState(cur: F.Charge, count: nat, ok: bool)

  // The transition that a token carries (the request is rebuilt from the token's request id and intent).
  function TransOf(t: V3.ShellToken): F.Transition
  {
    F.Transition(F.Request(t.requestId, t.intent.amount, t.intent.reason), t.post, t.intent)
  }

  // The executable form of the approved relation F.Authorizes (which is ghost). AuthorizesXIs: the same predicate.
  predicate AuthorizesX(cur: F.Charge, t: V3.ShellToken)
  {
    R.Eligible(F.ContextOf(cur, t.requestId), R.Candidate(t.intent.amount, t.intent.reason)) &&
    t.post == cur.(remaining := cur.remaining - t.intent.amount) &&
    t.intent == R.Intent(cur.chargeId, t.requestId, t.intent.amount, t.intent.reason)
  }

  lemma AuthorizesXIs(cur: F.Charge, t: V3.ShellToken)
    ensures AuthorizesX(cur, t) <==> F.Authorizes(cur, TransOf(t))
  {
  }

  // The per-row check. initId = the SUPPLIED initial charge's id.
  predicate RowOk(initId: string, cur: F.Charge, r: Row)
  {
    r.tok.specId == C.PINNED_SPEC && r.tok.checkerId == C.PINNED_CHK &&
    r.preOk &&
    r.tok.intent.requestId == r.tok.requestId &&      // request-id binding (token)
    r.settledId == r.tok.requestId &&                 // request-id binding (settled row)
    r.outIntent == r.tok.intent &&                    // the outbox intent IS the token's intent
    r.tok.intent.chargeId == initId &&                // charge-id binding to the INITIAL charge
    V3.ChargeOkP(cur, r.tok) &&
    AuthorizesX(cur, r.tok)                           // the approved relation on the REPLAYED pre-state
  }

  function AInit(init: F.Charge): AState { AState(init, 0, true) }

  function AuditStep(initId: string, st: AState, r: Row): AState
  {
    AState(r.tok.post, st.count + 1, st.ok && RowOk(initId, st.cur, r))
  }

  // nSettled / nOutbox: the row counts of the two tables; nDistinct: COUNT(DISTINCT request_id) of settled.
  function AuditEnd(init: F.Charge, stored: F.Charge, st: AState, nSettled: int, nOutbox: int, nDistinct: int): bool
  {
    st.ok && st.cur == stored && st.count == nSettled && st.count == nOutbox && st.count == nDistinct &&
    0 <= init.remaining <= init.original
  }

  // ---------------- G1(d): the fold (left fold; resumable) ----------------
  ghost function Fold(initId: string, st: AState, rows: seq<Row>): AState
    decreases |rows|
  {
    if |rows| == 0 then st else AuditStep(initId, Fold(initId, st, rows[..|rows| - 1]), rows[|rows| - 1])
  }

  ghost function AuditV5(init: F.Charge, stored: F.Charge, rows: seq<Row>, nSettled: int, nOutbox: int, nDistinct: int): bool
  {
    AuditEnd(init, stored, Fold(init.chargeId, AInit(init), rows), nSettled, nOutbox, nDistinct)
  }

  lemma FoldSnoc(initId: string, st: AState, rows: seq<Row>, r: Row)
    ensures Fold(initId, st, rows + [r]) == AuditStep(initId, Fold(initId, st, rows), r)
  {
    assert (rows + [r])[..|rows|] == rows;
  }

  // Resumable: the fold over a + b is the fold over b started from the fold over a.
  lemma FoldResume(initId: string, st: AState, a: seq<Row>, b: seq<Row>)
    ensures Fold(initId, st, a + b) == Fold(initId, Fold(initId, st, a), b)
    decreases |b|
  {
    if |b| == 0 {
      assert a + b == a;
    } else {
      var b' := b[..|b| - 1];
      var x := b[|b| - 1];
      assert b == b' + [x];
      assert a + b == (a + b') + [x];
      FoldResume(initId, st, a, b');
      FoldSnoc(initId, st, a + b', x);
      FoldSnoc(initId, Fold(initId, st, a), b', x);
    }
  }

  lemma FoldCount(initId: string, st: AState, rows: seq<Row>)
    ensures Fold(initId, st, rows).count == st.count + |rows|
    decreases |rows|
  {
    if |rows| > 0 { FoldCount(initId, st, rows[..|rows| - 1]); }
  }

  // The shape of the shell's loop: one AuditStep per row, constant state. (Proved for an in-memory sequence; the
  // TypeScript loop over SQL rows is TESTED-UNPROVED against it.)
  method AuditLoop(init: F.Charge, stored: F.Charge, rows: seq<Row>, nSettled: int, nOutbox: int, nDistinct: int)
      returns (b: bool)
    ensures b == AuditV5(init, stored, rows, nSettled, nOutbox, nDistinct)
  {
    var st := AInit(init);
    var i := 0;
    while i < |rows|
      invariant 0 <= i <= |rows|
      invariant st == Fold(init.chargeId, AInit(init), rows[..i])
    {
      assert rows[..i + 1] == rows[..i] + [rows[i]];
      FoldSnoc(init.chargeId, AInit(init), rows[..i], rows[i]);
      st := AuditStep(init.chargeId, st, rows[i]);
      i := i + 1;
    }
    assert rows[..i] == rows;
    b := AuditEnd(init, stored, st, nSettled, nOutbox, nDistinct);
  }

  // ---------------- the stored core and the replay ----------------
  ghost function Intents(rows: seq<Row>): seq<R.RefundIntent>
    decreases |rows|
  {
    if |rows| == 0 then [] else Intents(rows[..|rows| - 1]) + [rows[|rows| - 1].outIntent]
  }

  ghost function IdSet(rows: seq<Row>): set<string>
    decreases |rows|
  {
    if |rows| == 0 then {} else IdSet(rows[..|rows| - 1]) + {rows[|rows| - 1].settledId}
  }

  // A-DB1 (named database assumption): rows is the zip, in seq order, of the settled and outbox tables;
  // nSettled and nOutbox are their row counts. Then the stored core is:
  ghost function StoredCore(stored: F.Charge, rows: seq<Row>): C.Core
  {
    C.Core(stored, IdSet(rows), Intents(rows))
  }

  function Core0(init: F.Charge): C.Core { C.Core(init, {}, []) }

  datatype Del = Del(tok: V3.ShellToken, sigOk: bool, preOk: bool)

  ghost function QOf(c: C.Core, d: Del): V4.StepResultQ
  {
    V4.StepQ(c.charge, d.tok, d.sigOk, d.preOk, d.tok.requestId in c.settled)
  }

  // One delivery through the PROVED constant-state step (StepQAgrees: this IS ShellCoreV3.StepP).
  ghost function Next(c: C.Core, d: Del): C.Core
  {
    V4.Apply(c, QOf(c, d)).core
  }

  ghost function DelOf(r: Row): Del { Del(r.tok, r.sigOk, r.preOk) }

  // The replay of the stored rows from the supplied initial charge, through StepQ.
  ghost function Replay(init: F.Charge, rows: seq<Row>): C.Core
    decreases |rows|
  {
    if |rows| == 0 then Core0(init) else Next(Replay(init, rows[..|rows| - 1]), DelOf(rows[|rows| - 1]))
  }

  // ---------------- distinctness from the count (A-DB2: nDistinct == |IdSet(rows)|) ----------------
  lemma IdSetCard(rows: seq<Row>)
    ensures |IdSet(rows)| <= |rows|
    decreases |rows|
  {
    if |rows| > 0 { IdSetCard(rows[..|rows| - 1]); }
  }

  lemma IdSetDistinctLast(rows: seq<Row>)
    requires |rows| > 0 && |IdSet(rows)| == |rows|
    ensures |IdSet(rows[..|rows| - 1])| == |rows| - 1
    ensures rows[|rows| - 1].settledId !in IdSet(rows[..|rows| - 1])
  {
    var p := rows[..|rows| - 1];
    IdSetCard(p);
    if rows[|rows| - 1].settledId in IdSet(p) {
      assert IdSet(rows) == IdSet(p);
      assert false;
    }
  }

  // ---------------- the money induction (NO distinctness, NO signature hypothesis) ----------------
  ghost predicate MoneyInv(init: F.Charge, rows: seq<Row>, st: AState)
  {
    st.cur.chargeId == init.chargeId && st.cur.original == init.original &&
    st.cur.refundEnabled == init.refundEnabled &&
    st.cur.remaining == init.remaining - C.SumIntents(Intents(rows)) &&
    (|rows| > 0 ==> 0 <= st.cur.remaining <= st.cur.original)
  }

  lemma SumSnoc(o: seq<R.RefundIntent>, x: R.RefundIntent)
    ensures C.SumIntents(o + [x]) == C.SumIntents(o) + x.amount
  {
    assert (o + [x])[..|o|] == o;
  }

  lemma FoldOkPrefix(initId: string, st: AState, rows: seq<Row>)
    requires |rows| > 0 && Fold(initId, st, rows).ok
    ensures Fold(initId, st, rows[..|rows| - 1]).ok
    ensures RowOk(initId, Fold(initId, st, rows[..|rows| - 1]).cur, rows[|rows| - 1])
  {
  }

  lemma MoneyInd(init: F.Charge, rows: seq<Row>)
    requires Fold(init.chargeId, AInit(init), rows).ok
    ensures MoneyInv(init, rows, Fold(init.chargeId, AInit(init), rows))
    decreases |rows|
  {
    if |rows| > 0 {
      var p := rows[..|rows| - 1];
      var r := rows[|rows| - 1];
      FoldOkPrefix(init.chargeId, AInit(init), rows);
      MoneyInd(init, p);
      var cp := Fold(init.chargeId, AInit(init), p).cur;
      assert AuthorizesX(cp, r.tok);
      assert Intents(rows) == Intents(p) + [r.outIntent];
      SumSnoc(Intents(p), r.outIntent);
      assert r.outIntent.amount == r.tok.intent.amount;
    }
  }

  // ---------------- the replay induction (distinctness from A-DB2) ----------------
  lemma ReplayInd(init: F.Charge, rows: seq<Row>)
    requires Fold(init.chargeId, AInit(init), rows).ok
    requires |IdSet(rows)| == |rows|
    ensures Replay(init, rows) == C.Core(Fold(init.chargeId, AInit(init), rows).cur, IdSet(rows), Intents(rows))
    decreases |rows|
  {
    if |rows| > 0 {
      var p := rows[..|rows| - 1];
      var r := rows[|rows| - 1];
      FoldOkPrefix(init.chargeId, AInit(init), rows);
      IdSetDistinctLast(rows);
      ReplayInd(init, p);
      var cp := Fold(init.chargeId, AInit(init), p).cur;
      assert RowOk(init.chargeId, cp, r);
      assert r.tok.requestId !in Replay(init, p).settled;
      V4.StepQExact(cp, r.tok, r.sigOk, r.preOk, false);
    }
  }

  // Every row commits in the replay and is Authorized on its replayed pre-state.
  lemma ReplayRowsAuthorized(init: F.Charge, rows: seq<Row>)
    requires Fold(init.chargeId, AInit(init), rows).ok
    requires |IdSet(rows)| == |rows|
    ensures forall i | 0 <= i < |rows| ::
      F.Authorizes(Replay(init, rows[..i]).charge, TransOf(rows[i].tok)) &&
      QOf(Replay(init, rows[..i]), DelOf(rows[i])).Commit?
    decreases |rows|
  {
    if |rows| > 0 {
      var n := |rows| - 1;
      var p := rows[..n];
      FoldOkPrefix(init.chargeId, AInit(init), rows);
      IdSetDistinctLast(rows);
      ReplayRowsAuthorized(init, p);
      ReplayInd(init, p);
      var cp := Fold(init.chargeId, AInit(init), p).cur;
      AuthorizesXIs(cp, rows[n].tok);
      V4.StepQExact(cp, rows[n].tok, rows[n].sigOk, rows[n].preOk, false);
      forall i | 0 <= i < |rows|
        ensures F.Authorizes(Replay(init, rows[..i]).charge, TransOf(rows[i].tok)) &&
                QOf(Replay(init, rows[..i]), DelOf(rows[i])).Commit?
      {
        if i < n {
          assert rows[..i] == p[..i];
          assert rows[i] == p[i];
        } else {
          assert rows[..i] == p;
        }
      }
    }
  }

  lemma ReplayGood(init: F.Charge, rows: seq<Row>)
    ensures C.GoodV3(Replay(init, rows)) && Replay(init, rows).charge.chargeId == init.chargeId
    decreases |rows|
  {
    if |rows| == 0 {
      C.InitGood(init);
      C.AuditStartIsGoodStart(Core0(init));
    } else {
      var p := rows[..|rows| - 1];
      var d := DelOf(rows[|rows| - 1]);
      ReplayGood(init, p);
      V4.StepQKeepsGoodV3(Replay(init, p), d.tok, d.sigOk, d.preOk);
    }
  }

  // ======== MAIN (a): soundness. MONEY IS CONSERVED RELATIVE TO THE SUPPLIED INITIAL CHARGE. ========
  // Hypotheses: the audit is true, and A-DB2 (nDistinct is the number of distinct settled ids of these rows).
  // NO hypothesis about signatures (sigOk may be anything the shell computed). `init` is an INPUT: if it is not the
  // true initial charge, the conclusions hold for that wrong charge. The anchor must come from outside the database.
  lemma AuditV5SoundRelativeToSuppliedInitial(init: F.Charge, stored: F.Charge, rows: seq<Row>,
                                             nSettled: int, nOutbox: int, nDistinct: int)
    requires AuditV5(init, stored, rows, nSettled, nOutbox, nDistinct)
    requires nDistinct == |IdSet(rows)|                                   // A-DB2
    ensures nSettled == |rows| && nOutbox == |rows|                       // every row of both tables was audited
    ensures StoredCore(stored, rows) == Replay(init, rows)                // the stored core IS the replay
    ensures forall i | 0 <= i < |rows| ::
      F.Authorizes(Replay(init, rows[..i]).charge, TransOf(rows[i].tok)) &&
      QOf(Replay(init, rows[..i]), DelOf(rows[i])).Commit?
    ensures 0 <= stored.remaining <= stored.original && stored.original == init.original
    ensures stored.chargeId == init.chargeId
    ensures C.SumIntents(Intents(rows)) == init.remaining - stored.remaining
    ensures V4.AuditStartBound(StoredCore(stored, rows), init.chargeId)  // the V4 audit is implied
  {
    var st := Fold(init.chargeId, AInit(init), rows);
    FoldCount(init.chargeId, AInit(init), rows);
    MoneyInd(init, rows);
    ReplayInd(init, rows);
    ReplayRowsAuthorized(init, rows);
    ReplayGood(init, rows);
    C.AuditStartIsGoodStart(StoredCore(stored, rows));
  }

  // The money part alone needs NOT EVEN A-DB2.
  lemma AuditV5MoneyRelativeToSuppliedInitial(init: F.Charge, stored: F.Charge, rows: seq<Row>,
                                              nSettled: int, nOutbox: int, nDistinct: int)
    requires AuditV5(init, stored, rows, nSettled, nOutbox, nDistinct)
    ensures 0 <= stored.remaining <= stored.original && stored.original == init.original
    ensures stored.chargeId == init.chargeId
    ensures C.SumIntents(Intents(rows)) == init.remaining - stored.remaining
    ensures forall i | 0 <= i < |rows| :: rows[i].outIntent == rows[i].tok.intent
  {
    MoneyInd(init, rows);
    AllRowsOk(init.chargeId, AInit(init), rows);
  }

  lemma AllRowsOk(initId: string, st: AState, rows: seq<Row>)
    requires Fold(initId, st, rows).ok
    ensures forall i | 0 <= i < |rows| :: RowOk(initId, Fold(initId, st, rows[..i]).cur, rows[i])
    decreases |rows|
  {
    if |rows| > 0 {
      var n := |rows| - 1;
      var p := rows[..n];
      FoldOkPrefix(initId, st, rows);
      AllRowsOk(initId, st, p);
      forall i | 0 <= i < |rows| ensures RowOk(initId, Fold(initId, st, rows[..i]).cur, rows[i]) {
        if i < n { assert rows[..i] == p[..i]; assert rows[i] == p[i]; } else { assert rows[..i] == p; }
      }
    }
  }

  // ======== MAIN (b): completeness for honest commits ========
  // A run of deliveries through StepQ (== StepP by V4.StepQAgrees) from Core0(init). RowsOf: the rows the shell
  // writes (one per committed delivery; a rejected delivery writes nothing), with the sigOk/preOk of that commit.
  ghost function Run(init: F.Charge, ds: seq<Del>): C.Core
    decreases |ds|
  {
    if |ds| == 0 then Core0(init) else Next(Run(init, ds[..|ds| - 1]), ds[|ds| - 1])
  }

  ghost function RowsOf(init: F.Charge, ds: seq<Del>): seq<Row>
    decreases |ds|
  {
    if |ds| == 0 then [] else
      var p := ds[..|ds| - 1];
      var d := ds[|ds| - 1];
      if QOf(Run(init, p), d).Commit? then RowsOf(init, p) + [Row(d.tok.requestId, d.tok, d.sigOk, d.preOk, d.tok.intent)]
      else RowsOf(init, p)
  }

  // THE hypothesis under which honest commits happen: each COMMITTED token was authorized on the state it was
  // committed on (the signer is the proved checker). A store with an unapproved committed token (possible only
  // through a faulty signer, since StepQ itself does not re-check Authorizes) is REFUSED by AuditV5, by design.
  ghost predicate EachCommitAuthorized(init: F.Charge, ds: seq<Del>)
  {
    forall k | 0 <= k < |ds| :: QOf(Run(init, ds[..k]), ds[k]).Commit? ==> F.Authorizes(Run(init, ds[..k]).charge, TransOf(ds[k].tok))
  }

  ghost predicate CInv(init: F.Charge, c: C.Core, rows: seq<Row>)
  {
    Fold(init.chargeId, AInit(init), rows) == AState(c.charge, |rows|, true) &&
    c.settled == IdSet(rows) && c.outbox == Intents(rows) && |IdSet(rows)| == |rows| &&
    c.charge.chargeId == init.chargeId
  }

  lemma EachCommitPrefix(init: F.Charge, ds: seq<Del>)
    requires |ds| > 0 && EachCommitAuthorized(init, ds)
    ensures EachCommitAuthorized(init, ds[..|ds| - 1])
    ensures QOf(Run(init, ds[..|ds| - 1]), ds[|ds| - 1]).Commit? ==>
            F.Authorizes(Run(init, ds[..|ds| - 1]).charge, TransOf(ds[|ds| - 1].tok))
  {
    var p := ds[..|ds| - 1];
    forall k | 0 <= k < |p| ensures QOf(Run(init, p[..k]), p[k]).Commit? ==> F.Authorizes(Run(init, p[..k]).charge, TransOf(p[k].tok)) {
      assert p[..k] == ds[..k];
      assert p[k] == ds[k];
    }
  }

  // One committed delivery keeps CInv (the new row passes RowOk on the replayed state).
  lemma CompleteCommitStep(init: F.Charge, cp: C.Core, rp: seq<Row>, d: Del)
    requires CInv(init, cp, rp)
    requires QOf(cp, d).Commit? && F.Authorizes(cp.charge, TransOf(d.tok))
    ensures CInv(init, Next(cp, d), rp + [Row(d.tok.requestId, d.tok, d.sigOk, d.preOk, d.tok.intent)])
  {
    var r := Row(d.tok.requestId, d.tok, d.sigOk, d.preOk, d.tok.intent);
    AuthorizesXIs(cp.charge, d.tok);
    V4.StepQExact(cp.charge, d.tok, d.sigOk, d.preOk, d.tok.requestId in cp.settled);
    FoldSnoc(init.chargeId, AInit(init), rp, r);
    assert RowOk(init.chargeId, cp.charge, r);
    assert (rp + [r])[..|rp|] == rp;
    assert IdSet(rp + [r]) == IdSet(rp) + {r.settledId};
    assert Intents(rp + [r]) == Intents(rp) + [r.outIntent];
    assert Next(cp, d) == C.Core(d.tok.post, cp.settled + {d.tok.requestId}, cp.outbox + [d.tok.intent]);
  }

  lemma CompleteInd(init: F.Charge, ds: seq<Del>)
    requires EachCommitAuthorized(init, ds)
    ensures CInv(init, Run(init, ds), RowsOf(init, ds))
    decreases |ds|
  {
    if |ds| > 0 {
      var p := ds[..|ds| - 1];
      var d := ds[|ds| - 1];
      EachCommitPrefix(init, ds);
      CompleteInd(init, p);
      if QOf(Run(init, p), d).Commit? {
        CompleteCommitStep(init, Run(init, p), RowsOf(init, p), d);
      }
    }
  }

  // MAIN (b). Hypotheses: InitOk(init) and EachCommitAuthorized. Then the store that the run wrote passes AuditV5
  // with the true counts (A-DB1/A-DB2 hold with these values), and its stored core is the run's core.
  // A-DET (named shell assumption): at audit time the shell recomputes the same sigOk and preOk as at commit time.
  lemma AuditV5CompleteForHonestCommits(init: F.Charge, ds: seq<Del>)
    requires 0 <= init.remaining <= init.original                     // InitOk
    requires EachCommitAuthorized(init, ds)
    ensures var c := Run(init, ds); var rows := RowsOf(init, ds);
            AuditV5(init, c.charge, rows, |rows|, |rows|, |IdSet(rows)|) && StoredCore(c.charge, rows) == c
  {
    CompleteInd(init, ds);
  }

  // ---------------- G1(c): the reviewer's stores are refused (proved examples) ----------------
  function Ch(rem: int): F.Charge { F.Charge("ch_1", 1000, rem, true) }
  function Tk(rid: string, pre: F.Charge, amount: int): V3.ShellToken
  {
    V3.ShellToken(C.PINNED_SPEC, C.PINNED_CHK, rid, pre.(remaining := pre.remaining - amount),
                  R.Intent(pre.chargeId, rid, amount, "duplicate_charge"), "")
  }
  function RowT(t: V3.ShellToken, s: bool, p: bool): Row { Row(t.requestId, t, s, p, t.intent) }

  lemma Fold2(initId: string, st: AState, a: Row, b: Row)
    ensures Fold(initId, st, [a, b]) == AuditStep(initId, AuditStep(initId, st, a), b)
  {
    assert [a] == [] + [a];
    assert [a, b] == [a] + [b];
    FoldSnoc(initId, st, [], a);
    FoldSnoc(initId, st, [a], b);
  }

  // S1 (running sink): 1000 refunded; the balance was reset to 1000 by another writer; a second 1000 committed.
  // Store: state (ch_1, 1000, 0); rows rq_1 (1000 from 1000), rq_2 (1000 from the RESET 1000). REFUSED for every
  // value of the shell's booleans and counts: rq_2 is not Authorized on the replayed pre-state (remaining 0).
  lemma ReviewerS1BalanceResetRefused(s1: bool, p1: bool, s2: bool, p2: bool, nS: int, nO: int, nD: int)
    ensures !AuditV5(Ch(1000), Ch(0), [RowT(Tk("rq_1", Ch(1000), 1000), s1, p1), RowT(Tk("rq_2", Ch(1000), 1000), s2, p2)], nS, nO, nD)
  {
    Fold2("ch_1", AInit(Ch(1000)), RowT(Tk("rq_1", Ch(1000), 1000), s1, p1), RowT(Tk("rq_2", Ch(1000), 1000), s2, p2));
  }

  // S1 at restart (after the reset, before the second commit): state (ch_1, 1000, 1000), one row of 1000. REFUSED:
  // the replayed charge (remaining 0) is not the stored one.
  lemma ReviewerS1RestartRefused(s1: bool, p1: bool, nS: int, nO: int, nD: int)
    ensures !AuditV5(Ch(1000), Ch(1000), [RowT(Tk("rq_1", Ch(1000), 1000), s1, p1)], nS, nO, nD)
  {
    assert [RowT(Tk("rq_1", Ch(1000), 1000), s1, p1)][..0] == [];
  }

  // General: a stored balance other than init.remaining - (sum of outbox amounts) is always refused.
  lemma BalanceResetRefused(init: F.Charge, stored: F.Charge, rows: seq<Row>, nS: int, nO: int, nD: int)
    requires stored.remaining != init.remaining - C.SumIntents(Intents(rows))
    ensures !AuditV5(init, stored, rows, nS, nO, nD)
  {
    if AuditV5(init, stored, rows, nS, nO, nD) { AuditV5MoneyRelativeToSuppliedInitial(init, stored, rows, nS, nO, nD); }
  }

  // S2: an outbox amount rewritten (the token says 100, the outbox row says 1). General and the concrete store.
  lemma OutboxNotTokenIntentRefused(init: F.Charge, stored: F.Charge, rows: seq<Row>, i: int, nS: int, nO: int, nD: int)
    requires 0 <= i < |rows| && rows[i].outIntent != rows[i].tok.intent
    ensures !AuditV5(init, stored, rows, nS, nO, nD)
  {
    if AuditV5(init, stored, rows, nS, nO, nD) { AuditV5MoneyRelativeToSuppliedInitial(init, stored, rows, nS, nO, nD); }
  }

  lemma ReviewerS2OutboxAmountRefused(s1: bool, p1: bool, nS: int, nO: int, nD: int)
    ensures var t := Tk("rq_1", Ch(1000), 100);
            !AuditV5(Ch(1000), Ch(900), [Row("rq_1", t, s1, p1, t.intent.(amount := 1))], nS, nO, nD)
  {
    var t := Tk("rq_1", Ch(1000), 100);
    OutboxNotTokenIntentRefused(Ch(1000), Ch(900), [Row("rq_1", t, s1, p1, t.intent.(amount := 1))], 0, nS, nO, nD);
  }

  // S7: the original rewritten under the same charge id. General: any stored original other than the supplied one.
  lemma OriginalRewrittenRefused(init: F.Charge, stored: F.Charge, rows: seq<Row>, nS: int, nO: int, nD: int)
    requires stored.original != init.original
    ensures !AuditV5(init, stored, rows, nS, nO, nD)
  {
    if AuditV5(init, stored, rows, nS, nO, nD) { AuditV5MoneyRelativeToSuppliedInitial(init, stored, rows, nS, nO, nD); }
  }

  // S7 concrete: stored (ch_1, 5000, 5000) with no row, and with the 5000 refund that v4 committed. Both REFUSED.
  lemma ReviewerS7Refused(s1: bool, p1: bool, nS: int, nO: int, nD: int)
    ensures !AuditV5(Ch(1000), F.Charge("ch_1", 5000, 5000, true), [], nS, nO, nD)
    ensures !AuditV5(Ch(1000), F.Charge("ch_1", 5000, 0, true),
                     [RowT(Tk("rq_1", F.Charge("ch_1", 5000, 5000, true), 5000), s1, p1)], nS, nO, nD)
  {
    OriginalRewrittenRefused(Ch(1000), F.Charge("ch_1", 5000, 5000, true), [], nS, nO, nD);
    OriginalRewrittenRefused(Ch(1000), F.Charge("ch_1", 5000, 0, true),
                             [RowT(Tk("rq_1", F.Charge("ch_1", 5000, 5000, true), 5000), s1, p1)], nS, nO, nD);
  }

  // A stored charge with another id than the supplied initial one (reviewer S5, D-b) is always refused.
  lemma ForeignChargeIdRefused(init: F.Charge, stored: F.Charge, rows: seq<Row>, nS: int, nO: int, nD: int)
    requires stored.chargeId != init.chargeId
    ensures !AuditV5(init, stored, rows, nS, nO, nD)
  {
    if AuditV5(init, stored, rows, nS, nO, nD) { AuditV5MoneyRelativeToSuppliedInitial(init, stored, rows, nS, nO, nD); }
  }

  // A row whose stored token does not verify (sigOk false) is always refused (S3: a changed token text).
  lemma UnsignedRowRefused(init: F.Charge, stored: F.Charge, rows: seq<Row>, i: int, nS: int, nO: int, nD: int)
    requires 0 <= i < |rows| && !rows[i].sigOk
    ensures !AuditV5(init, stored, rows, nS, nO, nD)
  {
    if AuditV5(init, stored, rows, nS, nO, nD) { AllRowsOk(init.chargeId, AInit(init), rows); }
  }

  // Non-vacuity and zero amount: a 100 refund then a ZERO refund; the store passes AuditV5; the stored core is
  // the replay. Also: an unauthorized-but-signed token (amount 2000 > remaining) commits in StepQ (StepQ does not
  // re-check Authorizes) and its store is REFUSED by AuditV5 (by design).
  lemma Witness()
    ensures var t1 := Tk("rq_1", Ch(1000), 100);
            var t2 := Tk("rq_2", Ch(900), 0);
            var rows := [RowT(t1, true, true), RowT(t2, true, true)];
            AuditV5(Ch(1000), Ch(900), rows, 2, 2, 2) && |IdSet(rows)| == 2 &&
            StoredCore(Ch(900), rows) == Replay(Ch(1000), rows)
    ensures var tb := Tk("rq_b", Ch(1000), 2000);
            V4.StepQ(Ch(1000), tb, true, true, false).Commit? &&
            !AuditV5(Ch(1000), Ch(-1000), [RowT(tb, true, true)], 1, 1, 1)
  {
    var t1 := Tk("rq_1", Ch(1000), 100);
    var t2 := Tk("rq_2", Ch(900), 0);
    var rows := [RowT(t1, true, true), RowT(t2, true, true)];
    Fold2("ch_1", AInit(Ch(1000)), rows[0], rows[1]);
    assert rows[..1] == [rows[0]];
    assert [rows[0]][..0] == [];
    assert "rq_1"[3] != "rq_2"[3];
    assert IdSet([rows[0]]) == {"rq_1"};
    assert IdSet(rows) == IdSet(rows[..1]) + {"rq_2"};
    assert IdSet(rows) == {"rq_1", "rq_2"};
    AuditV5SoundRelativeToSuppliedInitial(Ch(1000), Ch(900), rows, 2, 2, 2);
    var tb := Tk("rq_b", Ch(1000), 2000);
    assert [RowT(tb, true, true)][..0] == [];
  }

  // Non-vacuity of completeness: a concrete run (commit 100, a foreign-charge reject, commit 0) meets the hypothesis.
  lemma CompletenessWitness()
    ensures var ds := [Del(Tk("rq_1", Ch(1000), 100), true, true),
                       Del(Tk("rq_x", F.Charge("ch_9", 1000, 900, true), 10), true, true),
                       Del(Tk("rq_2", Ch(900), 0), true, true)];
            EachCommitAuthorized(Ch(1000), ds) && |RowsOf(Ch(1000), ds)| == 2 && Run(Ch(1000), ds).charge == Ch(900)
  {
    var ds := [Del(Tk("rq_1", Ch(1000), 100), true, true),
               Del(Tk("rq_x", F.Charge("ch_9", 1000, 900, true), 10), true, true),
               Del(Tk("rq_2", Ch(900), 0), true, true)];
    assert ds[..0] == [];
    assert ds[..1] == [ds[0]];
    assert ds[..2] == [ds[0], ds[1]];
    assert ds[..1][..0] == [];
    assert ds[..2][..1] == [ds[0]];
    assert ds[..3] == ds;
    assert "ch_9"[3] != "ch_1"[3];
    assert "rq_2"[3] != "rq_1"[3];
    assert Run(Ch(1000), ds[..1]) == Next(Run(Ch(1000), []), ds[0]);
    assert Run(Ch(1000), []) == Core0(Ch(1000));
    assert QOf(Core0(Ch(1000)), ds[0]) == V4.Commit(Ch(900), "rq_1", ds[0].tok.intent);
    var c1 := Run(Ch(1000), ds[..1]);
    assert c1 == C.Core(Ch(900), {"rq_1"}, [ds[0].tok.intent]);
    assert Run(Ch(1000), ds[..2]) == c1;
    assert RowsOf(Ch(1000), ds[..1]) == [RowT(ds[0].tok, true, true)];
    assert RowsOf(Ch(1000), ds[..2]) == [RowT(ds[0].tok, true, true)];
    forall k | 0 <= k < |ds|
      ensures QOf(Run(Ch(1000), ds[..k]), ds[k]).Commit? ==> F.Authorizes(Run(Ch(1000), ds[..k]).charge, TransOf(ds[k].tok))
    {
      AuthorizesXIs(Run(Ch(1000), ds[..k]).charge, ds[k].tok);
    }
  }
}
