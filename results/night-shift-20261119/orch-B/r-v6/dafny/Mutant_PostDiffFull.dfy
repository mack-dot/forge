// r-v6 MUTANT of ShellCoreV6.dfy.
// d-v6sink (night shift 2026-11-19, Orchestrator B). A DRAFT. NOT gate evidence. NOT about sink.ts.
// G1: StepQ6 = the constant-state step ShellCoreV4.StepQ plus ONE more check on commit: the executable approved
// relation ShellCoreV5.AuthorizesX (== F.Authorizes, lemma ShellCoreV5.AuthorizesXIs, an iff) on the STORED charge.
// Order of the checks: ids, signature, request-id match, settled, pre-state hash, charge id, AUTHORIZES (last).
//   - settled before AUTHORIZES: an honest replay keeps the label "replayed" (the stored charge has moved on).
//   - preOk before AUTHORIZES: an honest but stale token keeps the label "stale pre-state".
//   - AUTHORIZES last: every token that StepQ (V4) rejects gets the SAME reason in StepQ6 (StepQ6RejectsAsV4).
// The request-id match and the charge-id check are IMPLIED by AuthorizesX (AuthorizesImpliesBindings); they stay
// as separate reasons for diagnostics. The pre-state compare preOk stays for the "stale token" reason; it is NOT
// used by spec conformance (V6ConformanceNoAssumption holds for ARBITRARY preOk, so also with preOk := true).
// No assume, no axiom, no bodiless lemma, no {:verify false}, no expect, no extern.
include "ShellCoreV5.dfy"

module ShellCoreV6 {
  import V5 = ShellCoreV5
  import V4 = ShellCoreV4
  import V3 = ShellCoreV3
  import C = SinkCoreV3
  import F = RefundFinality
  import R = Refund

  // A new reason: "not authorized by the approved relation for the stored state".
  datatype StepResult6 = Commit(newCharge: F.Charge, addId: string, intent: R.RefundIntent)
                       | Reject(why: C.Why)
                       | RejectNotAuthorized

  function StepQ6(charge: F.Charge, t: V3.ShellToken, sigOk: bool, preOk: bool, alreadySettled: bool): StepResult6
  {
    if t.specId != C.PINNED_SPEC || t.checkerId != C.PINNED_CHK then Reject(C.IdsNotPinned)
    else if !sigOk then Reject(C.SignatureInvalid)
    else if t.intent.requestId != t.requestId then Reject(C.ReqIdMismatch)
    else if alreadySettled then Reject(C.RequestSettled)
    else if !preOk then Reject(C.PreStateMismatch)
    else if !V3.ChargeOkP(charge, t) then Reject(C.ChargeIdMismatch)
    else if !AuthorizesPD(charge, t) then RejectNotAuthorized  // r-v6 MUTANT
    else Commit(t.post, t.requestId, t.intent)
  }

  // r-v6 MUTANT: the amount is taken from the post-state difference instead of the intent (all three conjuncts).
  predicate AuthorizesPD(cur: F.Charge, t: V3.ShellToken)
  {
    var d := cur.remaining - t.post.remaining;
    R.Eligible(F.ContextOf(cur, t.requestId), R.Candidate(d, t.intent.reason)) &&
    t.post == cur.(remaining := cur.remaining - d) &&
    t.intent == R.Intent(cur.chargeId, t.requestId, d, t.intent.reason)
  }

  // What the shell writes: on Commit, state := newCharge; one settled row; one outbox row. Otherwise nothing.
  function Apply6(core: C.Core, q: StepResult6): C.Core
  {
    if q.Commit? then C.Core(q.newCharge, core.settled + {q.addId}, core.outbox + [q.intent]) else core
  }

  // ---------------- the relation to V4 and the bindings ----------------
  lemma AuthorizesImpliesBindings(charge: F.Charge, t: V3.ShellToken)
    requires V5.AuthorizesX(charge, t)
    ensures V3.ChargeOkP(charge, t) && t.intent.requestId == t.requestId
    ensures t.intent.chargeId == charge.chargeId && t.post.chargeId == charge.chargeId
  {
  }

  // Every V4 rejection is a V6 rejection with the SAME reason.
  lemma StepQ6RejectsAsV4(charge: F.Charge, t: V3.ShellToken, sigOk: bool, preOk: bool, s: bool)
    requires V4.StepQ(charge, t, sigOk, preOk, s).Reject?
    ensures StepQ6(charge, t, sigOk, preOk, s) == Reject(V4.StepQ(charge, t, sigOk, preOk, s).why)
  {
  }

  // V6 commits only what V4 commits, with the same fields (V6 is V4 plus one check).
  lemma V6CommitIsV4Commit(charge: F.Charge, t: V3.ShellToken, sigOk: bool, preOk: bool, s: bool)
    requires StepQ6(charge, t, sigOk, preOk, s).Commit?
    ensures V4.StepQ(charge, t, sigOk, preOk, s) == V4.Commit(t.post, t.requestId, t.intent)
    ensures StepQ6(charge, t, sigOk, preOk, s) == Commit(t.post, t.requestId, t.intent)
    ensures F.Authorizes(charge, V5.TransOf(t))
  {
    V5.AuthorizesXIs(charge, t);
  }

  // ======== (b) EXACT ACCEPTANCE ========
  lemma StepQ6Exact(charge: F.Charge, t: V3.ShellToken, sigOk: bool, preOk: bool, s: bool)
    ensures StepQ6(charge, t, sigOk, preOk, s).Commit? <==>
      (t.specId == C.PINNED_SPEC && t.checkerId == C.PINNED_CHK && sigOk && preOk && !s &&
       F.Authorizes(charge, V5.TransOf(t)))
    ensures StepQ6(charge, t, sigOk, preOk, s).Commit? ==>
      StepQ6(charge, t, sigOk, preOk, s) == Commit(t.post, t.requestId, t.intent)
  {
    V5.AuthorizesXIs(charge, t);
  }

  // ======== (c) NO HONEST COMMIT LOST ========
  // For a token whose transition the approved relation authorizes on the stored charge, V4 and V6 agree exactly.
  lemma AuthorizedSameAsV4(charge: F.Charge, t: V3.ShellToken, sigOk: bool, preOk: bool, s: bool)
    requires F.Authorizes(charge, V5.TransOf(t))
    ensures V4.StepQ(charge, t, sigOk, preOk, s).Commit? <==> StepQ6(charge, t, sigOk, preOk, s).Commit?
    ensures V4.StepQ(charge, t, sigOk, preOk, s).Commit? ==>
            StepQ6(charge, t, sigOk, preOk, s) == Commit(t.post, t.requestId, t.intent)
  {
    V5.AuthorizesXIs(charge, t);
  }

  // EXACTLY the tokens that V4 commits and V6 rejects are the unauthorized ones (both directions).
  lemma LostExactlyUnauthorized(charge: F.Charge, t: V3.ShellToken, sigOk: bool, preOk: bool, s: bool)
    ensures (V4.StepQ(charge, t, sigOk, preOk, s).Commit? && !StepQ6(charge, t, sigOk, preOk, s).Commit?) <==>
            (V4.StepQ(charge, t, sigOk, preOk, s).Commit? && !F.Authorizes(charge, V5.TransOf(t)))
    ensures (V4.StepQ(charge, t, sigOk, preOk, s).Commit? && !StepQ6(charge, t, sigOk, preOk, s).Commit?) ==>
            StepQ6(charge, t, sigOk, preOk, s) == RejectNotAuthorized
  {
    V5.AuthorizesXIs(charge, t);
  }

  // The byte-level world (b-ser2): the issuer runs the PROVED F.Check on the STORED charge and the shell token
  // carries the issued fields. Hypotheses: sigOk = true (the minted bytes verify: B5 + a correct verifier),
  // preOk = true (the issuer hashed the stored charge: SHA-256 of the same canonical text), the id is not settled.
  // Then StepQ6 commits (and V4 commits the same).
  lemma IssuedTokenCommits(stored: F.Charge, tr: F.Transition, t: V3.ShellToken)
    requires F.Authorizes(stored, tr)                         // the Issue postcondition of F.Check
    requires t.specId == C.PINNED_SPEC && t.checkerId == C.PINNED_CHK
    requires t.requestId == tr.request.requestId && t.post == tr.post && t.intent == tr.intent
    ensures V5.TransOf(t) == tr
    ensures StepQ6(stored, t, true, true, false) == Commit(tr.post, tr.request.requestId, tr.intent)
    ensures V4.StepQ(stored, t, true, true, false) == V4.Commit(tr.post, tr.request.requestId, tr.intent)
  {
    V5.AuthorizesXIs(stored, t);
  }

  // The same, through the PROVED method F.Check itself (no hypothesis on its output).
  method IssueThenStep(stored: F.Charge, preStateHash: string, tr: F.Transition)
      returns (v: F.Verdict, q: StepResult6)
    ensures v.Issue? ==> q == Commit(tr.post, tr.request.requestId, tr.intent)
    ensures v.Refuse? ==> !F.Authorizes(stored, tr)
  {
    var plan;
    v, plan := F.Check(stored, preStateHash, tr);
    if v.Issue? {
      var t := V3.ShellToken(C.PINNED_SPEC, C.PINNED_CHK, v.token.requestId, v.token.post, v.token.intent, "");
      IssuedTokenCommits(stored, tr, t);
      q := StepQ6(stored, t, true, true, false);
    } else {
      q := RejectNotAuthorized;
    }
  }

  // ---------------- the run of V6 deliveries ----------------
  ghost function Q6Of(c: C.Core, d: V5.Del): StepResult6
  {
    StepQ6(c.charge, d.tok, d.sigOk, d.preOk, d.tok.requestId in c.settled)
  }

  ghost function Next6(c: C.Core, d: V5.Del): C.Core { Apply6(c, Q6Of(c, d)) }

  ghost function Run6(init: F.Charge, ds: seq<V5.Del>): C.Core
    decreases |ds|
  {
    if |ds| == 0 then V5.Core0(init) else Next6(Run6(init, ds[..|ds| - 1]), ds[|ds| - 1])
  }

  // The rows the shell writes (one per committed delivery, with the sigOk/preOk of that commit).
  ghost function RowsOf6(init: F.Charge, ds: seq<V5.Del>): seq<V5.Row>
    decreases |ds|
  {
    if |ds| == 0 then [] else
      var p := ds[..|ds| - 1];
      var d := ds[|ds| - 1];
      if Q6Of(Run6(init, p), d).Commit? then RowsOf6(init, p) + [V5.Row(d.tok.requestId, d.tok, d.sigOk, d.preOk, d.tok.intent)]
      else RowsOf6(init, p)
  }

  // One V6 commit is one V4 commit of an authorized token, with the same next core.
  lemma Step6Commit(c: C.Core, d: V5.Del)
    requires Q6Of(c, d).Commit?
    ensures V5.QOf(c, d).Commit? && F.Authorizes(c.charge, V5.TransOf(d.tok))
    ensures Next6(c, d) == V5.Next(c, d)
    ensures Next6(c, d) == C.Core(d.tok.post, c.settled + {d.tok.requestId}, c.outbox + [d.tok.intent])
  {
    V6CommitIsV4Commit(c.charge, d.tok, d.sigOk, d.preOk, d.tok.requestId in c.settled);
  }

  // THEOREM, not hypothesis: EachCommitAuthorized holds for EVERY V6 run (V5 needed it as a hypothesis for V4 runs).
  ghost predicate EachCommitAuthorized6(init: F.Charge, ds: seq<V5.Del>)
  {
    forall k | 0 <= k < |ds| :: Q6Of(Run6(init, ds[..k]), ds[k]).Commit? ==> F.Authorizes(Run6(init, ds[..k]).charge, V5.TransOf(ds[k].tok))
  }

  lemma EachCommitAuthorized6Holds(init: F.Charge, ds: seq<V5.Del>)
    ensures EachCommitAuthorized6(init, ds)
  {
    forall k | 0 <= k < |ds| && Q6Of(Run6(init, ds[..k]), ds[k]).Commit?
      ensures F.Authorizes(Run6(init, ds[..k]).charge, V5.TransOf(ds[k].tok))
    {
      Step6Commit(Run6(init, ds[..k]), ds[k]);
    }
  }

  lemma Complete6Ind(init: F.Charge, ds: seq<V5.Del>)
    ensures V5.CInv(init, Run6(init, ds), RowsOf6(init, ds))
    decreases |ds|
  {
    if |ds| > 0 {
      var p := ds[..|ds| - 1];
      var d := ds[|ds| - 1];
      Complete6Ind(init, p);
      if Q6Of(Run6(init, p), d).Commit? {
        Step6Commit(Run6(init, p), d);
        V5.CompleteCommitStep(init, Run6(init, p), RowsOf6(init, p), d);
      }
    }
  }

  // ======== (d) NO BRICK ========
  // Hypothesis: InitOk(init). NO hypothesis EachCommitAuthorized (it is EachCommitAuthorized6Holds).
  // A-DET (named shell assumption, as in V5): at audit time the shell recomputes the same sigOk and preOk per row as
  // at commit time (the rows carry the commit-time values). A-DB1/A-DB2 hold with these counts.
  lemma V6NoBrick(init: F.Charge, ds: seq<V5.Del>)
    requires 0 <= init.remaining <= init.original                     // InitOk
    ensures var c := Run6(init, ds); var rows := RowsOf6(init, ds);
            V5.AuditV5(init, c.charge, rows, |rows|, |rows|, |V5.IdSet(rows)|) && V5.StoredCore(c.charge, rows) == c
  {
    Complete6Ind(init, ds);
  }

  lemma RunPrefixNext(init: F.Charge, ds: seq<V5.Del>, k: int)
    requires 0 <= k < |ds|
    ensures Run6(init, ds[..k + 1]) == Next6(Run6(init, ds[..k]), ds[k])
  {
    assert ds[..k + 1][..k] == ds[..k];
  }

  // ======== (a) NO-ASSUMPTION CONFORMANCE ========
  // For EVERY run from an InitOk initial charge: ANY tokens, ANY sigOk, ANY preOk (so also preOk := true: the
  // pre-state compare is not needed), no hypothesis on signatures, the issuer or hashes.
  // Unfolds to the approved definitions: F.Authorizes (impl/RefundFinality.dfy) = R.Eligible on
  // F.ContextOf(pre, rid) = R.ChargeContext(chargeId, rid, original, remaining, refundEnabled, requestOpen := TRUE)
  // with R.Candidate(amount, reason); R.Eligible = ValidContext (ids nonempty, refundEnabled, requestOpen,
  // Money(original), 0 <= remaining <= original) && 0 <= amount <= remaining && AllowedReason(reason)
  // (spec/refund/RefundSpec.dfy); post == pre.(remaining := remaining - amount); intent == Intent(pre.chargeId, rid,
  // amount, reason).
  ghost predicate CommitConformsAt(init: F.Charge, ds: seq<V5.Del>, k: int)
    requires 0 <= k < |ds|
  {
    var pre := Run6(init, ds[..k]).charge; var t := ds[k].tok;
    F.Authorizes(pre, V5.TransOf(t)) &&
    R.Eligible(R.ChargeContext(pre.chargeId, t.requestId, pre.original, pre.remaining, pre.refundEnabled, true),
               R.Candidate(t.intent.amount, t.intent.reason)) &&
    R.Money(t.intent.amount) && R.AllowedReason(t.intent.reason) &&
    Run6(init, ds[..k + 1]).charge == pre.(remaining := pre.remaining - t.intent.amount) &&
    Run6(init, ds[..k + 1]).outbox ==
      Run6(init, ds[..k]).outbox + [R.Intent(pre.chargeId, t.requestId, t.intent.amount, t.intent.reason)]
  }

  ghost predicate PerCommitConforms(init: F.Charge, ds: seq<V5.Del>)
  {
    forall k | 0 <= k < |ds| :: Q6Of(Run6(init, ds[..k]), ds[k]).Commit? ==> CommitConformsAt(init, ds, k)
  }

  ghost predicate PerRowConforms(init: F.Charge, ds: seq<V5.Del>)
  {
    var c := Run6(init, ds); var rows := RowsOf6(init, ds);
    c.outbox == V5.Intents(rows) && |rows| == |c.outbox| &&
    (forall i | 0 <= i < |rows| :: F.Authorizes(V5.Replay(init, rows[..i]).charge, V5.TransOf(rows[i].tok)) &&
                                   rows[i].tok.intent == c.outbox[i])
  }

  ghost predicate StoreConforms(init: F.Charge, ds: seq<V5.Del>)
  {
    var c := Run6(init, ds);
    0 <= c.charge.remaining <= c.charge.original && c.charge.original == init.original &&
    c.charge.chargeId == init.chargeId &&
    C.SumIntents(c.outbox) == init.remaining - c.charge.remaining &&
    C.GoodV3(c)          // one effect per request id; each outbox intent carries the stored (= initial) charge id
  }

  lemma PerCommitHolds(init: F.Charge, ds: seq<V5.Del>)
    ensures PerCommitConforms(init, ds)
  {
    forall k | 0 <= k < |ds| && Q6Of(Run6(init, ds[..k]), ds[k]).Commit?
      ensures CommitConformsAt(init, ds, k)
    {
      Step6Commit(Run6(init, ds[..k]), ds[k]);
      RunPrefixNext(init, ds, k);
    }
  }

  lemma PerRowAndStoreHold(init: F.Charge, ds: seq<V5.Del>)
    requires 0 <= init.remaining <= init.original
    ensures PerRowConforms(init, ds) && StoreConforms(init, ds)
  {
    var c := Run6(init, ds);
    var rows := RowsOf6(init, ds);
    Complete6Ind(init, ds);
    V6NoBrick(init, ds);
    V5.AuditV5SoundRelativeToSuppliedInitial(init, c.charge, rows, |rows|, |rows|, |V5.IdSet(rows)|);
    V5.AuditV5MoneyRelativeToSuppliedInitial(init, c.charge, rows, |rows|, |rows|, |V5.IdSet(rows)|);
    V5.ReplayGood(init, rows);
    IntentsLen(rows);
    forall i | 0 <= i < |rows| ensures rows[i].tok.intent == c.outbox[i] {
      IntentsAt(rows, i);
    }
  }

  // ======== (a) NO-ASSUMPTION CONFORMANCE ========
  // For EVERY run from an InitOk initial charge: ANY tokens, ANY sigOk, ANY preOk (so also preOk := true: the
  // pre-state compare is not needed), no hypothesis on signatures, the issuer or hashes.
  // Unfolds to the approved definitions: F.Authorizes (impl/RefundFinality.dfy) = R.Eligible on
  // F.ContextOf(pre, rid) = R.ChargeContext(chargeId, rid, original, remaining, refundEnabled, requestOpen := TRUE)
  // with R.Candidate(amount, reason); R.Eligible = ValidContext (ids nonempty, refundEnabled, requestOpen,
  // Money(original), 0 <= remaining <= original) && 0 <= amount <= remaining && AllowedReason(reason)
  // (spec/refund/RefundSpec.dfy); post == pre.(remaining := remaining - amount); intent == Intent(pre.chargeId, rid,
  // amount, reason).
  //   PerCommitConforms: each commit is F.Authorizes / R.Eligible on the charge STORED at that commit; the next
  //     stored charge and the new outbox row are exactly those of the approved relation.
  //   PerRowConforms: each stored outbox row is F.Authorizes on the replayed stored charge before it.
  //   StoreConforms: 0 <= remaining <= original == initial original; sum of outbox amounts == initial remaining -
  //     remaining; one effect per request id; charge-id binding.
  lemma V6ConformanceNoAssumption(init: F.Charge, ds: seq<V5.Del>)
    requires 0 <= init.remaining <= init.original                     // InitOk
    ensures PerCommitConforms(init, ds) && PerRowConforms(init, ds) && StoreConforms(init, ds)
  {
    PerCommitHolds(init, ds);
    PerRowAndStoreHold(init, ds);
  }

  // preOk is not needed: the same theorem for runs where EVERY preOk is forced to true (the compare removed).
  lemma V6ConformanceWithoutPreCompare(init: F.Charge, ds: seq<V5.Del>)
    requires 0 <= init.remaining <= init.original
    requires forall k | 0 <= k < |ds| :: ds[k].preOk
    ensures PerCommitConforms(init, ds) && PerRowConforms(init, ds) && StoreConforms(init, ds)
  {
    V6ConformanceNoAssumption(init, ds);
  }

  lemma IntentsLen(rows: seq<V5.Row>)
    ensures |V5.Intents(rows)| == |rows|
    decreases |rows|
  {
    if |rows| > 0 { IntentsLen(rows[..|rows| - 1]); }
  }

  lemma IntentsAt(rows: seq<V5.Row>, i: int)
    requires 0 <= i < |rows|
    ensures |V5.Intents(rows)| == |rows| && V5.Intents(rows)[i] == rows[i].outIntent
    decreases |rows|
  {
    IntentsLen(rows);
    if i < |rows| - 1 {
      IntentsAt(rows[..|rows| - 1], i);
    }
  }

  // ---------------- proved examples and controls ----------------
  function Ch(rem: int): F.Charge { V5.Ch(rem) }
  function Tk(rid: string, pre: F.Charge, amount: int): V3.ShellToken { V5.Tk(rid, pre, amount) }

  // Signed (sigOk), hash-matching (preOk), pinned, fresh, charge-id-consistent tokens that the approved relation
  // does NOT authorize on the stored charge: V4 (and V5's commit path) COMMITS each one; StepQ6 REJECTS each one
  // with RejectNotAuthorized. Four kinds: amount above remaining; a wrong post-state; an unapproved reason;
  // conformance case 24 (original above MaxMoney, amount 2^63).
  lemma UnauthorizedSignedTokensRejected()
    ensures var t := Tk("rq_a", Ch(1000), 2000);
            V4.StepQ(Ch(1000), t, true, true, false).Commit? && StepQ6(Ch(1000), t, true, true, false) == RejectNotAuthorized
    ensures var t := Tk("rq_b", Ch(1000), 100).(post := Ch(950));
            V4.StepQ(Ch(1000), t, true, true, false).Commit? && StepQ6(Ch(1000), t, true, true, false) == RejectNotAuthorized
    ensures var t0 := Tk("rq_c", Ch(1000), 100); var t := t0.(intent := t0.intent.(reason := "goodwill"));
            V4.StepQ(Ch(1000), t, true, true, false).Commit? && StepQ6(Ch(1000), t, true, true, false) == RejectNotAuthorized
    ensures var big := F.Charge("ch_1", R.MaxMoney + 1, R.MaxMoney + 1, true);
            var t := Tk("rq_d", big, R.MaxMoney + 1);
            V4.StepQ(big, t, true, true, false).Commit? && StepQ6(big, t, true, true, false) == RejectNotAuthorized
  {
    var t0 := Tk("rq_c", Ch(1000), 100);
    var tc := t0.(intent := t0.intent.(reason := "goodwill"));
    assert !R.AllowedReason(tc.intent.reason) by {
      assert "goodwill"[0] != "duplicate_charge"[0];
      assert "goodwill"[0] != "service_not_delivered"[0];
      assert "goodwill"[0] != "returned_item"[0];
    }
  }

  // The same at run level: the store is unchanged, and it passes AuditV5 (restart works; no brick).
  lemma UnauthorizedRunNoBrick()
    ensures var ds := [V5.Del(Tk("rq_a", Ch(1000), 2000), true, true)];
            Run6(Ch(1000), ds) == V5.Core0(Ch(1000)) && RowsOf6(Ch(1000), ds) == [] &&
            V5.AuditV5(Ch(1000), Ch(1000), [], 0, 0, 0)
  {
    var ds := [V5.Del(Tk("rq_a", Ch(1000), 2000), true, true)];
    assert ds[..0] == [];
    UnauthorizedSignedTokensRejected();
  }

  // Zero amount: on a valid charge, a zero refund with an approved reason is ALWAYS authorized, so it commits when
  // pinned, signed, fresh and current.
  lemma ZeroAmountCommits(charge: F.Charge, rid: string, reason: string)
    requires charge.chargeId != "" && rid != "" && charge.refundEnabled && R.Money(charge.original)
    requires 0 <= charge.remaining <= charge.original && R.AllowedReason(reason)
    ensures var t := V3.ShellToken(C.PINNED_SPEC, C.PINNED_CHK, rid, charge, R.Intent(charge.chargeId, rid, 0, reason), "");
            StepQ6(charge, t, true, true, false) == Commit(charge, rid, t.intent)
  {
  }

  // The largest authorized amount (amount == remaining) commits.
  lemma LargestAmountCommits(charge: F.Charge, rid: string, reason: string)
    requires charge.chargeId != "" && rid != "" && charge.refundEnabled && R.Money(charge.original)
    requires 0 <= charge.remaining <= charge.original && R.AllowedReason(reason)
    ensures var t := V3.ShellToken(C.PINNED_SPEC, C.PINNED_CHK, rid, charge.(remaining := 0),
                                   R.Intent(charge.chargeId, rid, charge.remaining, reason), "");
            StepQ6(charge, t, true, true, false).Commit?
  {
  }

  // NON-VACUITY: a concrete run commits TWO ZERO-AMOUNT tokens with distinct ids, then the full remaining 1000,
  // then MaxMoney on a MaxMoney charge is shown separately. The reached store passes AuditV5.
  lemma Witness()
    ensures var ds := [V5.Del(Tk("rq_1", Ch(1000), 0), true, true),
                       V5.Del(Tk("rq_2", Ch(1000), 0), true, true),
                       V5.Del(Tk("rq_3", Ch(1000), 1000), true, true)];
            Run6(Ch(1000), ds) == C.Core(Ch(0), {"rq_1", "rq_2", "rq_3"},
                                         [ds[0].tok.intent, ds[1].tok.intent, ds[2].tok.intent]) &&
            |RowsOf6(Ch(1000), ds)| == 3
    ensures var m := F.Charge("ch_1", R.MaxMoney, R.MaxMoney, true);
            StepQ6(m, Tk("rq_m", m, R.MaxMoney), true, true, false).Commit?
  {
    var ds := [V5.Del(Tk("rq_1", Ch(1000), 0), true, true),
               V5.Del(Tk("rq_2", Ch(1000), 0), true, true),
               V5.Del(Tk("rq_3", Ch(1000), 1000), true, true)];
    assert ds[..0] == [];
    assert ds[..1] == [ds[0]];
    assert ds[..2] == [ds[0], ds[1]];
    assert ds[..3] == ds;
    assert ds[..1][..0] == [];
    assert ds[..2][..1] == [ds[0]];
    assert "rq_2"[3] != "rq_1"[3];
    assert "rq_3"[3] != "rq_1"[3];
    assert "rq_3"[3] != "rq_2"[3];
    RunPrefixNext(Ch(1000), ds, 0);
    RunPrefixNext(Ch(1000), ds, 1);
    RunPrefixNext(Ch(1000), ds, 2);
    var c0 := V5.Core0(Ch(1000));
    assert Run6(Ch(1000), ds[..0]) == c0;
    assert Q6Of(c0, ds[0]).Commit?;
    var c1 := Run6(Ch(1000), ds[..1]);
    assert c1 == C.Core(Ch(1000), {"rq_1"}, [ds[0].tok.intent]);
    assert Q6Of(c1, ds[1]).Commit?;
    var c2 := Run6(Ch(1000), ds[..2]);
    assert c2 == C.Core(Ch(1000), {"rq_1", "rq_2"}, [ds[0].tok.intent, ds[1].tok.intent]);
    assert Q6Of(c2, ds[2]).Commit?;
    assert |RowsOf6(Ch(1000), ds[..1])| == 1;
    assert |RowsOf6(Ch(1000), ds[..2])| == 2;
  }
}
