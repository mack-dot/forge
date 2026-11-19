// d-v3sink2 (night shift 2026-11-19, Orchestrator B). A DRAFT. NOT gate evidence. NOT about sink.ts.
// G1: StepQ, the CONSTANT-STATE form of ShellCoreV3.StepP. The shell gives the stored charge and ONE boolean
// alreadySettled (an indexed lookup) in place of the whole settled set and outbox. StepQAgrees: applying the
// StepQ result to a core IS StepP on that core when alreadySettled == (t.requestId in core.settled). So every
// V3 result (StepPAgrees, StepPKeepsGoodV3, StepPRefinesModelStep, ...) transfers.
// G2: a STREAMING start-up audit. The shell folds AuditStep over the outbox rows (seq order) with constant state
// AState(ok, count) and ends with AuditEnd. AuditEnd adds the BINDING stored chargeId == initId (initId: the
// initial charge id that the shell takes from the meta row). StreamIsAuditStartBound: under the named database
// assumptions A-DB1..A-DB3, the fold IS AuditStart(core) && core.charge.chargeId == initId.
// No assume, no axiom, no bodiless lemma, no {:verify false}, no expect, no extern.
include "ShellCoreV3.dfy"

module ShellCoreV4 {
  import V3 = ShellCoreV3
  import C = SinkCoreV3
  import F = RefundFinality
  import R = Refund

  // ---------------- G1: the constant-state step ----------------
  datatype StepResultQ = Commit(newCharge: F.Charge, addId: string, intent: R.RefundIntent) | Reject(why: C.Why)

  function StepQ(charge: F.Charge, t: V3.ShellToken, sigOk: bool, preOk: bool, alreadySettled: bool): StepResultQ
  {
    if t.specId != C.PINNED_SPEC || t.checkerId != C.PINNED_CHK then Reject(C.IdsNotPinned)
    else if !sigOk then Reject(C.SignatureInvalid)
    else if t.intent.requestId != t.requestId then Reject(C.ReqIdMismatch)
    else if alreadySettled then Reject(C.RequestSettled)
    else if !preOk then Reject(C.PreStateMismatch)
    else if !V3.ChargeOkP(charge, t) then Reject(C.ChargeIdMismatch)
    else Reject(C.NoSuchCharge)
  }

  // What the shell writes: on Commit, state := newCharge; one settled row addId; one outbox row intent. On Reject: nothing.
  function Apply(core: C.Core, q: StepResultQ): C.StepResult
  {
    match q
    case Commit(nc, rid, i) => C.StepResult(C.Core(nc, core.settled + {rid}, core.outbox + [i]), C.Committed)
    case Reject(w) => C.StepResult(core, C.Rejected(w))
  }

  // MAIN of G1: exact agreement with StepP (same outcome, same reason, same next core).
  lemma StepQAgrees(core: C.Core, t: V3.ShellToken, sigOk: bool, preOk: bool)
    ensures Apply(core, StepQ(core.charge, t, sigOk, preOk, t.requestId in core.settled)) == V3.StepP(core, t, sigOk, preOk)
  {
  }

  // The same, spelled out field by field.
  lemma StepQAgreesFields(core: C.Core, t: V3.ShellToken, sigOk: bool, preOk: bool)
    ensures var q := StepQ(core.charge, t, sigOk, preOk, t.requestId in core.settled);
            var p := V3.StepP(core, t, sigOk, preOk);
            (q.Commit? <==> p.out.Committed?) &&
            (q.Commit? ==> p.core == C.Core(q.newCharge, core.settled + {q.addId}, core.outbox + [q.intent])) &&
            (q.Reject? ==> p.out == C.Rejected(q.why) && p.core == core)
  {
  }

  // Through StepPAgrees: StepQ IS SinkCoreV3.Step on the full token (preOk := value compare).
  lemma StepQIsStep(core: C.Core, t: V3.ShellToken, sigOk: bool, pre: F.Charge)
    ensures Apply(core, StepQ(core.charge, t, sigOk, core.charge == pre, t.requestId in core.settled)) ==
            C.Step(core, V3.Full(t, pre), sigOk)
  {
    StepQAgrees(core, t, sigOk, core.charge == pre);
    V3.StepPAgrees(core, t, sigOk, pre);
  }

  // Exact acceptance (rules out a reject-all and a commit-all StepQ). The commit fields are the token's.
  lemma StepQExact(charge: F.Charge, t: V3.ShellToken, sigOk: bool, preOk: bool, alreadySettled: bool)
    ensures StepQ(charge, t, sigOk, preOk, alreadySettled).Commit? <==>
      (t.specId == C.PINNED_SPEC && t.checkerId == C.PINNED_CHK && sigOk && t.intent.requestId == t.requestId &&
       !alreadySettled && preOk && V3.ChargeOkP(charge, t))
    ensures StepQ(charge, t, sigOk, preOk, alreadySettled).Commit? ==>
      StepQ(charge, t, sigOk, preOk, alreadySettled) == Commit(t.post, t.requestId, t.intent)
  {
  }

  // Zero-amount refunds: the amount is never a reason to reject.
  lemma StepQZeroAmountCommits(charge: F.Charge, t: V3.ShellToken)
    requires t.specId == C.PINNED_SPEC && t.checkerId == C.PINNED_CHK && t.intent.requestId == t.requestId
    requires V3.ChargeOkP(charge, t) && t.intent.amount == 0
    ensures StepQ(charge, t, true, true, false) == Commit(t.post, t.requestId, t.intent)
  {
  }

  // A settled request id never commits again (any other input).
  lemma SettledNeverCommits(charge: F.Charge, t: V3.ShellToken, sigOk: bool, preOk: bool)
    ensures !StepQ(charge, t, sigOk, preOk, true).Commit?
  {
  }

  // A token for another charge never commits (any sigOk, preOk, alreadySettled).
  lemma ForeignChargeNeverCommitsQ(charge: F.Charge, t: V3.ShellToken, sigOk: bool, preOk: bool, s: bool)
    requires t.intent.chargeId != charge.chargeId || t.post.chargeId != charge.chargeId
    ensures !StepQ(charge, t, sigOk, preOk, s).Commit?
  {
  }

  // NO assumption: GoodV3 is kept and the stored chargeId never changes (transferred from StepPKeepsGoodV3).
  lemma StepQKeepsGoodV3(core: C.Core, t: V3.ShellToken, sigOk: bool, preOk: bool)
    requires C.GoodV3(core)
    ensures C.GoodV3(Apply(core, StepQ(core.charge, t, sigOk, preOk, t.requestId in core.settled)).core)
    ensures Apply(core, StepQ(core.charge, t, sigOk, preOk, t.requestId in core.settled)).core.charge.chargeId == core.charge.chargeId
  {
    StepQAgrees(core, t, sigOk, preOk);
    V3.StepPKeepsGoodV3(core, t, sigOk, preOk);
  }

  // ---------------- G2: the streaming start-up audit with the initial-charge binding ----------------
  // One outbox row as the shell gives it: the decoded intent and hit = (an indexed lookup: its request id is settled).
  datatype ARow = ARow(intent: R.RefundIntent, hit: bool)
  datatype AState = AState(ok: bool, count: nat)

  function AInit(): AState { AState(true, 0) }

  // Constant state per row. cid = the stored charge's chargeId.
  function AuditStep(cid: string, st: AState, row: ARow): AState
  {
    AState(st.ok && row.hit && row.intent.chargeId == cid, st.count + 1)
  }

  // nSettled = number of distinct settled request ids; outboxDistinct = no two outbox rows share a request id.
  // initId = the initial charge id (from the meta row). The last conjunct is the NEW binding (D-b).
  function AuditEnd(charge: F.Charge, initId: string, st: AState, nSettled: int, outboxDistinct: bool): bool
  {
    st.ok && st.count == nSettled && outboxDistinct && charge.chargeId == initId
  }

  // The left fold that the shell's loop computes (ghost: the shell never builds the sequence).
  ghost function Fold(cid: string, st: AState, rows: seq<ARow>): AState
    decreases |rows|
  {
    if |rows| == 0 then st else Fold(cid, AuditStep(cid, st, rows[0]), rows[1..])
  }

  ghost predicate RowsOk(cid: string, rows: seq<ARow>)
  {
    forall i | 0 <= i < |rows| :: rows[i].hit && rows[i].intent.chargeId == cid
  }

  lemma FoldClosed(cid: string, b: bool, k: nat, rows: seq<ARow>)
    ensures Fold(cid, AState(b, k), rows) == AState(b && RowsOk(cid, rows), k + |rows|)
    decreases |rows|
  {
    if |rows| > 0 {
      FoldClosed(cid, b && rows[0].hit && rows[0].intent.chargeId == cid, k + 1, rows[1..]);
      assert RowsOk(cid, rows) <==> (rows[0].hit && rows[0].intent.chargeId == cid && RowsOk(cid, rows[1..])) by {
        if RowsOk(cid, rows[1..]) && rows[0].hit && rows[0].intent.chargeId == cid {
          forall i | 0 <= i < |rows| ensures rows[i].hit && rows[i].intent.chargeId == cid {
            if i > 0 { assert rows[i] == rows[1..][i - 1]; }
          }
        }
        if RowsOk(cid, rows) {
          forall i | 0 <= i < |rows[1..]| ensures rows[1..][i].hit && rows[1..][i].intent.chargeId == cid {
            assert rows[1..][i] == rows[i + 1];
          }
        }
      }
    }
  }

  // The fold is a LEFT fold: one more row = one more AuditStep. So the shell may stop and resume (incremental
  // re-audit over rows appended later) without changing the result.
  lemma FoldSnoc(cid: string, st: AState, rows: seq<ARow>, r: ARow)
    ensures Fold(cid, st, rows + [r]) == AuditStep(cid, Fold(cid, st, rows), r)
  {
    FoldClosed(cid, st.ok, st.count, rows + [r]);
    FoldClosed(cid, st.ok, st.count, rows);
    assert RowsOk(cid, rows + [r]) <==> (RowsOk(cid, rows) && r.hit && r.intent.chargeId == cid) by {
      if RowsOk(cid, rows + [r]) {
        assert (rows + [r])[|rows|] == r;
        forall i | 0 <= i < |rows| ensures rows[i].hit && rows[i].intent.chargeId == cid {
          assert (rows + [r])[i] == rows[i];
        }
      }
    }
  }

  // The named database assumptions (the shell's SQL results), stated as predicates.
  // A-DB1: rows is the outbox in seq order, and each hit is the membership of that row's request id in settled.
  ghost predicate RowsMatch(core: C.Core, rows: seq<ARow>)
  {
    |rows| == |core.outbox| &&
    forall i | 0 <= i < |rows| :: rows[i].intent == core.outbox[i] && rows[i].hit == (core.outbox[i].requestId in core.settled)
  }
  ghost predicate DistinctIds(o: seq<R.RefundIntent>)
  {
    forall i, j | 0 <= i < j < |o| :: o[i].requestId != o[j].requestId
  }

  // The bound audit on a whole core (executable; the shell does not call it: it streams).
  function AuditStartBound(core: C.Core, initId: string): bool
  {
    C.AuditStart(core) && core.charge.chargeId == initId
  }

  // MAIN of G2. A-DB2: nSettled == |settled|. A-DB3: outboxDistinct == DistinctIds(outbox).
  lemma StreamIsAuditStartBound(core: C.Core, initId: string, rows: seq<ARow>, nSettled: int, outboxDistinct: bool)
    requires RowsMatch(core, rows)                          // A-DB1
    requires nSettled == |core.settled|                     // A-DB2
    requires outboxDistinct == DistinctIds(core.outbox)     // A-DB3
    ensures AuditEnd(core.charge, initId, Fold(core.charge.chargeId, AInit(), rows), nSettled, outboxDistinct)
            == AuditStartBound(core, initId)
  {
    FoldClosed(core.charge.chargeId, true, 0, rows);
    var cid := core.charge.chargeId;
    assert RowsOk(cid, rows) <==> ((forall i | 0 <= i < |core.outbox| :: core.outbox[i].requestId in core.settled) &&
                                   (forall i | 0 <= i < |core.outbox| :: core.outbox[i].chargeId == cid)) by {
      if RowsOk(cid, rows) {
        forall i | 0 <= i < |core.outbox| ensures core.outbox[i].requestId in core.settled && core.outbox[i].chargeId == cid {
          assert rows[i].hit && rows[i].intent == core.outbox[i];
        }
      }
    }
  }

  // What a true bound audit gives: GoodStart and the binding; then every StepQ keeps both, for ANY inputs.
  lemma BoundAuditGives(core: C.Core, initId: string)
    requires AuditStartBound(core, initId)
    ensures C.GoodStart(core) && core.charge.chargeId == initId
  {
    C.AuditStartIsGoodStart(core);
  }

  lemma StepQKeepsBound(core: C.Core, initId: string, t: V3.ShellToken, sigOk: bool, preOk: bool)
    requires AuditStartBound(core, initId)
    ensures AuditStartBound(Apply(core, StepQ(core.charge, t, sigOk, preOk, t.requestId in core.settled)).core, initId)
  {
    C.AuditStartIsGoodStart(core);
    StepQKeepsGoodV3(core, t, sigOk, preOk);
    C.AuditStartIsGoodStart(Apply(core, StepQ(core.charge, t, sigOk, preOk, t.requestId in core.settled)).core);
  }

  // A fresh store passes the bound audit with its own charge id.
  lemma InitBound(init: F.Charge)
    ensures AuditStartBound(C.Core(init, {}, []), init.chargeId)
    ensures AuditEnd(init, init.chargeId, Fold(init.chargeId, AInit(), []), 0, true)
  {
  }

  // D-b, in general: a stored charge with another id than the initial one is ALWAYS refused (any rows, any counts).
  lemma ForeignStoredChargeRefused(charge: F.Charge, initId: string, st: AState, n: int, d: bool)
    requires charge.chargeId != initId
    ensures !AuditEnd(charge, initId, st, n, d)
  {
  }

  // D-b, the reviewer's case D2c: the old sink committed a foreign post-state (ch_2) on a ch_1 store. The V3 audit
  // ACCEPTS that store (it is self-consistent on ch_2); the bound audit and the stream REFUSE it.
  lemma ReviewerD2cRefused()
    ensures var core := C.Core(F.Charge("ch_2", 1000, 900, true), {"rq_f"}, [R.Intent("ch_2", "rq_f", 100, "duplicate_charge")]);
            C.AuditStart(core) && !AuditStartBound(core, "ch_1") &&
            !AuditEnd(core.charge, "ch_1", Fold("ch_2", AInit(), [ARow(core.outbox[0], true)]), 1, true)
  {
  }

  // Non-vacuity: two commits (the second with amount 0), a foreign-charge reject, a replay reject; the stream
  // audit on the reached store (rows as the database gives them) is TRUE with the initial charge id.
  lemma Witness()
    ensures var c := F.Charge("ch_1", 1000, 1000, true);
            var t1 := V3.ShellToken(C.PINNED_SPEC, C.PINNED_CHK, "rq_1", F.Charge("ch_1", 1000, 900, true),
                                    R.Intent("ch_1", "rq_1", 100, "returned_item"), "");
            var t2 := V3.ShellToken(C.PINNED_SPEC, C.PINNED_CHK, "rq_2", F.Charge("ch_1", 1000, 900, true),
                                    R.Intent("ch_1", "rq_2", 0, "returned_item"), "");
            var tf := V3.ShellToken(C.PINNED_SPEC, C.PINNED_CHK, "rq_3", F.Charge("ch_1", 1000, 800, true),
                                    R.Intent("ch_9", "rq_3", 100, "returned_item"), "");
            var q1 := StepQ(c, t1, true, true, false);
            var q2 := StepQ(t1.post, t2, true, true, false);
            var qf := StepQ(t2.post, tf, true, true, false);
            var qr := StepQ(t2.post, t1, true, true, true);
            q1 == Commit(t1.post, "rq_1", t1.intent) && q2 == Commit(t2.post, "rq_2", t2.intent) &&
            qf == Reject(C.ChargeIdMismatch) && qr == Reject(C.RequestSettled) &&
            AuditEnd(t2.post, "ch_1", Fold("ch_1", AInit(), [ARow(t1.intent, true), ARow(t2.intent, true)]), 2, true)
  {
    var r := [ARow(R.Intent("ch_1", "rq_1", 100, "returned_item"), true), ARow(R.Intent("ch_1", "rq_2", 0, "returned_item"), true)];
    FoldClosed("ch_1", true, 0, r);
  }
}
