// Night shift 2026-11-19, Orchestrator B, task b-restart (G1). A DRAFT in an evidence folder. NOT approved.
// NOT gate evidence. M1-B stays OPEN. A Dafny-MODEL statement only. NOT a proof about sink.ts, SQLite, Node,
// OpenSSL, Ed25519, SHA-256, a compiled program or a database file.
//
// Repair of review finding D1 (r-integrate): every trace theorem of SliceSafetyV3 starts from the EMPTY store,
// and GoodStart/AuditStart gives only structural facts (AttackCore.GoodStartDoesNotBoundMoney). A real sink
// restarts from a NON-EMPTY database. This file gives:
//  (a) COMPOSITIONAL restart. ExecAppend: Exec(init, a0 + a) == ExecFrom(Exec(init, a0), a). ExecFromCore: the
//      core part of a continued run depends ONLY on the durable core (charge, settled set, outbox); no ghost part
//      (model system, token list, minted set) must survive a restart. Restart: if the stored core is
//      Exec(init, a0).core with H1/A2/A5 on a0, and A2/A5 hold on the continuation a and H1 holds on a RELATIVE
//      TO THE FULL HISTORY (H1Cont), then all L0..L3 conclusions hold for every effect, old and new.
//      Sound(init, core) is the restart predicate (history form); it is kept by every continuation.
//  (b) CHECKABLE restart. AuditFull (compilable) replays a durable ledger of committed tokens from init through
//      the V3 Step, with the per-row signature-check results as input. AuditSound: AuditFull + A5 on the rows +
//      H1/A2 for a mint history ==> Sound, money bound, sum equation. AuditComplete: every reachable core passes
//      (no hypothesis). AuditFullSpec adds a per-row re-check of the approved relation: with it the money bound
//      and the sum equation hold with NO signature hypothesis (AuditSpecMoney).
// No assume, no axiom, no bodiless lemma in this file. Uninterpreted symbol: VerifyTag (as in SliceSafetyV3).
include "src/SliceSafetyV3.dfy"

module RestartV3 {
  import opened SinkCoreV3
  import opened SliceTheoremV3

  // =============================================================================================
  // (a) Compositional restart.
  ghost function ExecFrom(r: RunSt, acts: seq<Act>): RunSt
    decreases |acts|
  {
    if |acts| == 0 then r else Next(ExecFrom(r, acts[..|acts| - 1]), acts[|acts| - 1])
  }

  lemma ExecAppend(init: State, a0: seq<Act>, a: seq<Act>)
    ensures Exec(init, a0 + a) == ExecFrom(Exec(init, a0), a)
    decreases |a|
  {
    if |a| == 0 {
      assert a0 + a == a0;
    } else {
      var p := a[..|a| - 1];
      ExecAppend(init, a0, p);
      assert (a0 + a)[..|a0 + a| - 1] == a0 + p;
      assert (a0 + a)[|a0 + a| - 1] == a[|a| - 1];
    }
  }

  // What a restarted sink runs: the durable core only (compilable).
  function CoreNext(c: Core, a: Act): Core
  {
    match a
    case MintAct(_, _) => c
    case Deliver(tok, sigOk) => Step(c, tok, sigOk).core
  }

  function CoreRun(c: Core, acts: seq<Act>): Core
    decreases |acts|
  {
    if |acts| == 0 then c else CoreNext(CoreRun(c, acts[..|acts| - 1]), acts[|acts| - 1])
  }

  // The continued run's core depends only on the durable core: no ghost state must survive a restart.
  lemma ExecFromCore(r: RunSt, acts: seq<Act>)
    ensures ExecFrom(r, acts).core == CoreRun(r.core, acts)
    decreases |acts|
  {
    if |acts| > 0 {
      ExecFromCore(r, acts[..|acts| - 1]);
    }
  }

  lemma ContinueIsExec(init: State, a0: seq<Act>, a: seq<Act>)
    ensures CoreRun(Exec(init, a0).core, a) == Exec(init, a0 + a).core
  {
    ExecAppend(init, a0, a);
    ExecFromCore(Exec(init, a0), a);
  }

  // Old effects stay: the outbox before the restart is a prefix of the outbox after it.
  lemma CoreRunGrows(c: Core, a: seq<Act>)
    ensures |c.outbox| <= |CoreRun(c, a).outbox| && CoreRun(c, a).outbox[..|c.outbox|] == c.outbox
    ensures c.settled <= CoreRun(c, a).settled
    decreases |a|
  {
    if |a| > 0 {
      var p := a[..|a| - 1];
      CoreRunGrows(c, p);
      var cp := CoreRun(c, p);
      match a[|a| - 1]
      case MintAct(_, _) =>
      case Deliver(tok, sigOk) =>
        StepExact(cp, tok, sigOk);
        var c' := CoreRun(c, a);
        if Step(cp, tok, sigOk).out.Committed? {
          assert c'.outbox == cp.outbox + [tok.intent];
          assert c'.outbox[..|c.outbox|] == cp.outbox[..|c.outbox|];
        }
    }
  }

  // ---- the hypotheses split over a restart ----
  // H1 for the continuation, stated over the FULL history: a tag that verifies after the restart may come from a
  // mint BEFORE the restart (the issuer's signed set persists across sink restarts).
  ghost predicate H1Cont(a0: seq<Act>, a: seq<Act>)
  {
    forall k | 0 <= k < |a| && a[k].Deliver? ::
      VerifyTag(ClaimOf(a[k].tok), a[k].tok.sig) ==> SignedBefore(a0 + a, |a0| + k, ClaimOf(a[k].tok))
  }

  lemma HypsAppend(a0: seq<Act>, a: seq<Act>)
    ensures A2_MintOnlyOnCheck(a0 + a) <==> A2_MintOnlyOnCheck(a0) && A2_MintOnlyOnCheck(a)
    ensures A5_VerifierMatchesAtEachDelivery(a0 + a) <==>
      A5_VerifierMatchesAtEachDelivery(a0) && A5_VerifierMatchesAtEachDelivery(a)
    ensures H1_SignatureAuthenticity(a0 + a) <==> H1_SignatureAuthenticity(a0) && H1Cont(a0, a)
  {
    var f := a0 + a;
    assert forall k | 0 <= k < |a0| :: f[k] == a0[k];
    assert forall k | 0 <= k < |a| :: f[|a0| + k] == a[k];
    // A2
    if A2_MintOnlyOnCheck(f) {
      forall k | 0 <= k < |a0| && a0[k].MintAct? && Ours(a0[k].c)
        ensures exists pre: F.Charge, t: F.Transition :: F.Authorizes(pre, t) && a0[k].c == CheckedClaim(pre, t)
      {
        assert f[k] == a0[k];
      }
      forall k | 0 <= k < |a| && a[k].MintAct? && Ours(a[k].c)
        ensures exists pre: F.Charge, t: F.Transition :: F.Authorizes(pre, t) && a[k].c == CheckedClaim(pre, t)
      {
        assert f[|a0| + k] == a[k];
      }
    }
    if A2_MintOnlyOnCheck(a0) && A2_MintOnlyOnCheck(a) {
      forall k | 0 <= k < |f| && f[k].MintAct? && Ours(f[k].c)
        ensures exists pre: F.Charge, t: F.Transition :: F.Authorizes(pre, t) && f[k].c == CheckedClaim(pre, t)
      {
        if k < |a0| {
          assert f[k] == a0[k];
        } else {
          assert f[|a0| + (k - |a0|)] == a[k - |a0|];
        }
      }
    }
    // A5
    if A5_VerifierMatchesAtEachDelivery(f) {
      forall k | 0 <= k < |a0| && a0[k].Deliver?
        ensures A5_VerifierMatches(a0[k].tok, a0[k].sigOk)
      {
        assert f[k] == a0[k];
      }
      forall k | 0 <= k < |a| && a[k].Deliver?
        ensures A5_VerifierMatches(a[k].tok, a[k].sigOk)
      {
        assert f[|a0| + k] == a[k];
      }
    }
    if A5_VerifierMatchesAtEachDelivery(a0) && A5_VerifierMatchesAtEachDelivery(a) {
      forall k | 0 <= k < |f| && f[k].Deliver?
        ensures A5_VerifierMatches(f[k].tok, f[k].sigOk)
      {
        if k < |a0| {
          assert f[k] == a0[k];
        } else {
          assert f[|a0| + (k - |a0|)] == a[k - |a0|];
        }
      }
    }
    // H1
    if H1_SignatureAuthenticity(f) {
      forall k | 0 <= k < |a0| && a0[k].Deliver? && VerifyTag(ClaimOf(a0[k].tok), a0[k].tok.sig)
        ensures SignedBefore(a0, k, ClaimOf(a0[k].tok))
      {
        assert f[k] == a0[k];
        assert SignedBefore(f, k, ClaimOf(f[k].tok));
        var j :| 0 <= j < k && j < |f| && f[j].MintAct? && f[j].c == ClaimOf(a0[k].tok);
        assert f[j] == a0[j];
      }
      forall k | 0 <= k < |a| && a[k].Deliver? && VerifyTag(ClaimOf(a[k].tok), a[k].tok.sig)
        ensures SignedBefore(f, |a0| + k, ClaimOf(a[k].tok))
      {
        assert f[|a0| + k] == a[k];
      }
    }
    if H1_SignatureAuthenticity(a0) && H1Cont(a0, a) {
      forall k | 0 <= k < |f| && f[k].Deliver? && VerifyTag(ClaimOf(f[k].tok), f[k].tok.sig)
        ensures SignedBefore(f, k, ClaimOf(f[k].tok))
      {
        if k < |a0| {
          assert f[k] == a0[k];
          assert SignedBefore(a0, k, ClaimOf(a0[k].tok));
          var j :| 0 <= j < k && j < |a0| && a0[j].MintAct? && a0[j].c == ClaimOf(a0[k].tok);
          assert f[j] == a0[j];
        } else {
          var m := k - |a0|;
          assert f[|a0| + m] == a[m];
        }
      }
    }
  }

  // The local form (every verifying tag after the restart was minted after the restart) is SUFFICIENT for the
  // history form. It is not NECESSARY: RestartWitness has a mint before and its delivery after the restart.
  lemma H1LocalGivesCont(a0: seq<Act>, a: seq<Act>)
    requires H1_SignatureAuthenticity(a)
    ensures H1Cont(a0, a)
  {
    forall k | 0 <= k < |a| && a[k].Deliver? && VerifyTag(ClaimOf(a[k].tok), a[k].tok.sig)
      ensures SignedBefore(a0 + a, |a0| + k, ClaimOf(a[k].tok))
    {
      var j :| 0 <= j < k && j < |a| && a[j].MintAct? && a[j].c == ClaimOf(a[k].tok);
      assert (a0 + a)[|a0| + j] == a[j];
    }
  }

  // ---- the restart predicate (history form) ----
  ghost predicate HypsOn(acts: seq<Act>)
  {
    A2_MintOnlyOnCheck(acts) && A5_VerifierMatchesAtEachDelivery(acts) && H1_SignatureAuthenticity(acts)
  }

  ghost predicate Sound(init: State, core: Core)
  {
    InitOk(init) && exists a0: seq<Act> :: core == Exec(init, a0).core && HypsOn(a0)
  }

  // A Sound core already meets the money bound and the sum equation.
  lemma SoundMoney(init: State, core: Core)
    requires Sound(init, core)
    ensures 0 <= core.charge.remaining <= core.charge.original == init.original
    ensures SumIntents(core.outbox) == init.remaining - core.charge.remaining
    ensures 0 <= SumIntents(core.outbox) <= init.original
    ensures GoodV3(core) && core.charge.chargeId == init.chargeId
  {
    var a0 :| core == Exec(init, a0).core && HypsOn(a0);
    SliceSafetyV3_L2_Authentic(init, a0);
    SliceSafetyV3_L0_NoAssumption(init, a0);
  }

  // RESTART L0 (no hypothesis): continuing from the durable core is the full run; all L0 conclusions.
  lemma RestartL0(init: State, a0: seq<Act>, a: seq<Act>)
    ensures CoreRun(Exec(init, a0).core, a) == Exec(init, a0 + a).core
    ensures GoodV3(CoreRun(Exec(init, a0).core, a)) && CoreRun(Exec(init, a0).core, a).charge.chargeId == init.chargeId
    ensures forall e | e in CoreRun(Exec(init, a0).core, a).outbox ::
      exists i :: (0 <= i < |Exec(init, a0 + a).core.outbox| && Exec(init, a0 + a).core.outbox[i] == e &&
        UniqueAuthorizationCore(init, a0 + a, i))
  {
    var full := a0 + a;
    ContinueIsExec(init, a0, a);
    var r := Exec(init, full);
    ExecCore(init, full);
    forall e | e in r.core.outbox
      ensures exists i :: (0 <= i < |r.core.outbox| && r.core.outbox[i] == e && UniqueAuthorizationCore(init, full, i))
    {
      var i :| 0 <= i < |r.core.outbox| && r.core.outbox[i] == e;
      PerEntryCore(init, full, i);
    }
  }

  // THE RESTART THEOREM (history form). L0..L3 for every effect of the continued run, old and new.
  lemma Restart(init: State, a0: seq<Act>, a: seq<Act>, art: FlatFn)
    requires InitOk(init)
    requires HypsOn(a0)
    requires A2_MintOnlyOnCheck(a) && A5_VerifierMatchesAtEachDelivery(a) && H1Cont(a0, a)
    ensures CoreRun(Exec(init, a0).core, a) == Exec(init, a0 + a).core
    ensures HypsOn(a0 + a) && Sound(init, CoreRun(Exec(init, a0).core, a))
    ensures |Exec(init, a0).core.outbox| <= |CoreRun(Exec(init, a0).core, a).outbox|
    ensures CoreRun(Exec(init, a0).core, a).outbox[..|Exec(init, a0).core.outbox|] == Exec(init, a0).core.outbox
    ensures 0 <= CoreRun(Exec(init, a0).core, a).charge.remaining <= CoreRun(Exec(init, a0).core, a).charge.original
    ensures CoreRun(Exec(init, a0).core, a).charge.original == init.original
    ensures SumIntents(CoreRun(Exec(init, a0).core, a).outbox) == init.remaining - CoreRun(Exec(init, a0).core, a).charge.remaining
    ensures 0 <= SumIntents(CoreRun(Exec(init, a0).core, a).outbox) <= init.original
    ensures forall e | e in CoreRun(Exec(init, a0).core, a).outbox ::
      exists i :: (0 <= i < |Exec(init, a0 + a).core.outbox| && Exec(init, a0 + a).core.outbox[i] == e &&
        UniqueAuthorizationCore(init, a0 + a, i) && TagVerifies(init, a0 + a, i) &&
        ApprovedSpec(init, a0 + a, i) && SignedInTrace(init, a0 + a, i))
    ensures A6b_ArtifactComputesFlatContractOnBytes(art) ==>
      forall e | e in CoreRun(Exec(init, a0).core, a).outbox ::
        exists i :: (0 <= i < |Exec(init, a0 + a).core.outbox| && Exec(init, a0 + a).core.outbox[i] == e &&
          FlatResultAgrees(art, init, a0 + a, i))
  {
    var full := a0 + a;
    ContinueIsExec(init, a0, a);
    HypsAppend(a0, a);
    CoreRunGrows(Exec(init, a0).core, a);
    var r := Exec(init, full);
    SliceSafetyV3_L2_Authentic(init, full);
    SliceSafetyV3_L1_A5(init, full);
    assert Sound(init, r.core);
    forall e | e in r.core.outbox
      ensures exists i :: (0 <= i < |r.core.outbox| && r.core.outbox[i] == e &&
        UniqueAuthorizationCore(init, full, i) && TagVerifies(init, full, i) &&
        ApprovedSpec(init, full, i) && SignedInTrace(init, full, i))
    {
      var i :| 0 <= i < |r.core.outbox| && r.core.outbox[i] == e;
      PerEntryCore(init, full, i);
      PerEntryApproved(init, full, i);
    }
    if A6b_ArtifactComputesFlatContractOnBytes(art) {
      forall e | e in r.core.outbox
        ensures exists i :: 0 <= i < |r.core.outbox| && r.core.outbox[i] == e && FlatResultAgrees(art, init, full, i)
      {
        var i :| 0 <= i < |r.core.outbox| && r.core.outbox[i] == e;
        PerEntryFlat(init, full, art, i);
      }
    }
  }

  // Restart from a Sound core with the LOCAL form of H1 on the continuation (no history needed by the caller).
  // Sound is kept, so restarts compose: restart again from the result.
  lemma RestartFromSound(init: State, core: Core, a: seq<Act>)
    requires Sound(init, core)
    requires HypsOn(a)
    ensures Sound(init, CoreRun(core, a))
    ensures 0 <= CoreRun(core, a).charge.remaining <= CoreRun(core, a).charge.original == init.original
    ensures SumIntents(CoreRun(core, a).outbox) == init.remaining - CoreRun(core, a).charge.remaining
    ensures |core.outbox| <= |CoreRun(core, a).outbox| && CoreRun(core, a).outbox[..|core.outbox|] == core.outbox
  {
    var a0 :| core == Exec(init, a0).core && HypsOn(a0);
    H1LocalGivesCont(a0, a);
    Restart(init, a0, a, FlatSpecFn);
  }

  // ---- CONTROL: drop the history (only GoodStart/AuditStart and local hypotheses) ==> the reviewer's core ----
  function BadCore(): Core
  {
    Core(F.Charge("ch_1", 100, 100, true), {"rq_a"}, [R.Intent("ch_1", "rq_a", 500, "duplicate_charge")])
  }

  lemma SumOne(x: R.RefundIntent)
    ensures SumIntents([x]) == x.amount
  {
    assert [x][..0] == [];
  }

  lemma SumSnoc(o: seq<R.RefundIntent>, x: R.RefundIntent)
    ensures SumIntents(o + [x]) == SumIntents(o) + x.amount
  {
    assert (o + [x])[..|o|] == o;
  }

  // The reviewer's core is NOT Sound for ANY init (so no history reaches it).
  lemma BadNotSound(init: State)
    ensures !Sound(init, BadCore())
  {
    if Sound(init, BadCore()) {
      SoundMoney(init, BadCore());
      SumOne(BadCore().outbox[0]);
      assert BadCore().outbox == [BadCore().outbox[0]];
      assert false;
    }
  }

  // Every LOCAL hypothesis holds (GoodStart, AuditStart, H1/A2/A5 on the continuation, which mints the honest
  // token's claim and delivers it), yet the money bound fails: 600 > 100. The history hypothesis (Sound) is
  // what excludes this start core.
  lemma DropHistoryBreaksMoney(t: SinkToken)
    requires t == SinkToken(PINNED_SPEC, PINNED_CHK, BadCore().charge, "rq_b", BadCore().charge.(remaining := 0),
                            R.Intent("ch_1", "rq_b", 100, "duplicate_charge"), "sig")
    requires VerifyTag(ClaimOf(t), t.sig)
    ensures GoodStart(BadCore()) && AuditStart(BadCore())
    ensures HypsOn([MintAct(ClaimOf(t), t.sig), Deliver(t, true)])
    ensures CoreRun(BadCore(), [MintAct(ClaimOf(t), t.sig), Deliver(t, true)]).outbox == BadCore().outbox + [t.intent]
    ensures SumIntents(CoreRun(BadCore(), [MintAct(ClaimOf(t), t.sig), Deliver(t, true)]).outbox) == 600
    ensures SumIntents(CoreRun(BadCore(), [MintAct(ClaimOf(t), t.sig), Deliver(t, true)]).outbox) > BadCore().charge.original
    ensures forall init :: !Sound(init, BadCore())
  {
    var acts := [MintAct(ClaimOf(t), t.sig), Deliver(t, true)];
    AuditStartIsGoodStart(BadCore());
    var pre := BadCore().charge;
    var tr := F.Transition(F.Request("rq_b", 100, "duplicate_charge"), pre.(remaining := 0), t.intent);
    assert "duplicate_charge" in {"duplicate_charge", "service_not_delivered", "returned_item"};
    assert F.Authorizes(pre, tr) && ClaimOf(t) == CheckedClaim(pre, tr);
    forall k | 0 <= k < |acts| && acts[k].MintAct? && Ours(acts[k].c)
      ensures exists pre': F.Charge, t': F.Transition :: F.Authorizes(pre', t') && acts[k].c == CheckedClaim(pre', t')
    {
      assert k == 0 && F.Authorizes(pre, tr) && acts[k].c == CheckedClaim(pre, tr);
    }
    assert acts[0].MintAct? && acts[0].c == ClaimOf(t);
    assert SignedBefore(acts, 1, ClaimOf(t));
    assert acts[..1] == [MintAct(ClaimOf(t), t.sig)] && acts[..1][..0] == [];
    assert "rq_b"[3] != "rq_a"[3];
    var c' := CoreRun(BadCore(), acts);
    assert CoreRun(BadCore(), acts[..1]) == BadCore();
    assert c'.outbox == BadCore().outbox + [t.intent];
    SumSnoc(BadCore().outbox, t.intent);
    SumOne(BadCore().outbox[0]);
    assert BadCore().outbox == [BadCore().outbox[0]];
    forall init: State
      ensures !Sound(init, BadCore())
    {
      BadNotSound(init);
    }
  }

  // =============================================================================================
  // (b) Checkable restart: an executable audit over a durable ledger.
  // A ledger row = the stored token (sink.ts: settled.token holds the canonical token text) and the result of
  // the signature check that the audit runs on it (sink.ts audit(): this.verified(token)). A5 on the rows says
  // that this result is the verifier's answer. init = the initial state (sink.ts stores only its SHA-256 in meta;
  // the model takes the state value; hash collision freedom is an ASSUMPTION outside this model).
  function Replay(init: F.Charge, ledger: seq<Delivery>): (bool, Core)
    decreases |ledger|
  {
    if |ledger| == 0 then (true, Core(init, {}, []))
    else
      var pr := Replay(init, ledger[..|ledger| - 1]);
      var d := ledger[|ledger| - 1];
      var r := Step(pr.1, d.tok, d.sigOk);
      (pr.0 && r.out.Committed?, r.core)
  }

  predicate InitOkB(init: F.Charge)
  {
    0 <= init.remaining <= init.original
  }

  // Every row must COMMIT again when replayed, and the replay must end at exactly the stored core.
  function AuditFull(init: F.Charge, core: Core, ledger: seq<Delivery>): bool
  {
    false // CONTROL C1: reject-all audit
  }

  // The per-row re-check of the approved relation (an executable copy of F.Authorizes for the token's claim).
  predicate RowAuthorized(tok: SinkToken)
  {
    R.Eligible(F.ContextOf(tok.pre, tok.requestId), R.Candidate(tok.intent.amount, tok.intent.reason)) &&
    tok.post == tok.pre.(remaining := tok.pre.remaining - tok.intent.amount) &&
    tok.intent == R.Intent(tok.pre.chargeId, tok.requestId, tok.intent.amount, tok.intent.reason)
  }

  lemma RowAuthorizedIsAuthorizes(tok: SinkToken)
    ensures RowAuthorized(tok) <==>
      F.Authorizes(tok.pre, F.Transition(F.Request(tok.requestId, tok.intent.amount, tok.intent.reason), tok.post, tok.intent))
  {
  }

  function AuditFullSpec(init: F.Charge, core: Core, ledger: seq<Delivery>): bool
  {
    AuditFull(init, core, ledger) && forall i | 0 <= i < |ledger| :: RowAuthorized(ledger[i].tok)
  }

  // ---- ledger to trace ----
  function DelActs(ledger: seq<Delivery>): seq<Act>
  {
    seq(|ledger|, i requires 0 <= i < |ledger| => Deliver(ledger[i].tok, ledger[i].sigOk))
  }

  function MintActs(ms: seq<(Claim, Tag)>): seq<Act>
  {
    seq(|ms|, i requires 0 <= i < |ms| => MintAct(ms[i].0, ms[i].1))
  }

  lemma ReplayIsCoreRun(init: F.Charge, ledger: seq<Delivery>)
    ensures Replay(init, ledger).1 == CoreRun(Core(init, {}, []), DelActs(ledger))
    decreases |ledger|
  {
    if |ledger| > 0 {
      var p := ledger[..|ledger| - 1];
      ReplayIsCoreRun(init, p);
      assert DelActs(ledger)[..|ledger| - 1] == DelActs(p);
    }
  }

  lemma MintsOnlyCore(init: State, ms: seq<(Claim, Tag)>)
    ensures Exec(init, MintActs(ms)).core == Core(init, {}, [])
  {
    ExecAppend(init, [], MintActs(ms));
    assert [] + MintActs(ms) == MintActs(ms);
    ExecFromCore(Exec(init, []), MintActs(ms));
    MintsCoreRun(Core(init, {}, []), MintActs(ms));
  }

  lemma MintsCoreRun(c: Core, acts: seq<Act>)
    requires forall k | 0 <= k < |acts| :: acts[k].MintAct?
    ensures CoreRun(c, acts) == c
    decreases |acts|
  {
    if |acts| > 0 {
      MintsCoreRun(c, acts[..|acts| - 1]);
    }
  }

  // The ledger hypotheses. ms = the issuer's mint history (the issuer's signed set; it persists).
  ghost predicate A5Ledger(ledger: seq<Delivery>)
  {
    forall i | 0 <= i < |ledger| :: A5_VerifierMatches(ledger[i].tok, ledger[i].sigOk)
  }

  ghost predicate A2Mints(ms: seq<(Claim, Tag)>)
  {
    forall j | 0 <= j < |ms| && Ours(ms[j].0) ::
      exists pre: F.Charge, t: F.Transition :: F.Authorizes(pre, t) && ms[j].0 == CheckedClaim(pre, t)
  }

  ghost predicate H1Ledger(ms: seq<(Claim, Tag)>, ledger: seq<Delivery>)
  {
    forall i | 0 <= i < |ledger| :: VerifyTag(ClaimOf(ledger[i].tok), ledger[i].tok.sig) ==>
      exists j :: 0 <= j < |ms| && ms[j].0 == ClaimOf(ledger[i].tok)
  }

  lemma LedgerHyps(ms: seq<(Claim, Tag)>, ledger: seq<Delivery>)
    requires A5Ledger(ledger) && A2Mints(ms) && H1Ledger(ms, ledger)
    ensures HypsOn(MintActs(ms) + DelActs(ledger))
  {
    var M := MintActs(ms);
    var D := DelActs(ledger);
    var f := M + D;
    assert forall k | 0 <= k < |M| :: f[k] == M[k] == MintAct(ms[k].0, ms[k].1);
    assert forall i | 0 <= i < |D| :: f[|M| + i] == D[i] == Deliver(ledger[i].tok, ledger[i].sigOk);
    forall k | 0 <= k < |f| && f[k].MintAct? && Ours(f[k].c)
      ensures exists pre: F.Charge, t: F.Transition :: F.Authorizes(pre, t) && f[k].c == CheckedClaim(pre, t)
    {
      if k >= |M| {
        assert f[|M| + (k - |M|)] == D[k - |M|];
      }
    }
    forall k | 0 <= k < |f| && f[k].Deliver?
      ensures A5_VerifierMatches(f[k].tok, f[k].sigOk)
    {
      assert k >= |M|;
      assert f[|M| + (k - |M|)] == D[k - |M|];
    }
    forall k | 0 <= k < |f| && f[k].Deliver? && VerifyTag(ClaimOf(f[k].tok), f[k].tok.sig)
      ensures SignedBefore(f, k, ClaimOf(f[k].tok))
    {
      assert k >= |M|;
      var i := k - |M|;
      assert f[|M| + i] == D[i];
      var j :| 0 <= j < |ms| && ms[j].0 == ClaimOf(ledger[i].tok);
      assert f[j] == M[j];
    }
  }

  // AUDIT SOUNDNESS. AuditFull + the ledger hypotheses ==> the stored core is Sound, so the restart theorem
  // applies, and the money bound and the sum equation hold AT the restart.
  lemma AuditSound(init: F.Charge, core: Core, ledger: seq<Delivery>, ms: seq<(Claim, Tag)>)
    requires AuditFull(init, core, ledger)
    requires A5Ledger(ledger) && A2Mints(ms) && H1Ledger(ms, ledger)
    ensures core == Exec(init, MintActs(ms) + DelActs(ledger)).core
    ensures Sound(init, core)
    ensures 0 <= core.charge.remaining <= core.charge.original == init.original
    ensures SumIntents(core.outbox) == init.remaining - core.charge.remaining
    ensures 0 <= SumIntents(core.outbox) <= init.original
  {
    var acts0 := MintActs(ms) + DelActs(ledger);
    ContinueIsExec(init, MintActs(ms), DelActs(ledger));
    MintsOnlyCore(init, ms);
    ReplayIsCoreRun(init, ledger);
    LedgerHyps(ms, ledger);
    assert core == Exec(init, acts0).core;
    assert Sound(init, core);
    SoundMoney(init, core);
  }

  // AUDIT SOUNDNESS WITHOUT A SIGNATURE HYPOTHESIS for the spec-checking audit: money bound and sum equation.
  lemma ReplaySpecInv(init: F.Charge, ledger: seq<Delivery>)
    requires InitOkB(init) && Replay(init, ledger).0
    requires forall i | 0 <= i < |ledger| :: RowAuthorized(ledger[i].tok)
    ensures var c := Replay(init, ledger).1;
      c.charge.original == init.original && 0 <= c.charge.remaining <= c.charge.original &&
      SumIntents(c.outbox) == init.remaining - c.charge.remaining && 0 <= SumIntents(c.outbox)
    decreases |ledger|
  {
    if |ledger| > 0 {
      var p := ledger[..|ledger| - 1];
      var d := ledger[|ledger| - 1];
      assert forall i | 0 <= i < |p| :: p[i] == ledger[i];
      ReplaySpecInv(init, p);
      var c := Replay(init, p).1;
      StepExact(c, d.tok, d.sigOk);
      assert RowAuthorized(d.tok);
      SumSnoc(c.outbox, d.tok.intent);
    }
  }

  lemma AuditSpecMoney(init: F.Charge, core: Core, ledger: seq<Delivery>)
    requires AuditFullSpec(init, core, ledger)
    ensures 0 <= core.charge.remaining <= core.charge.original == init.original
    ensures SumIntents(core.outbox) == init.remaining - core.charge.remaining
    ensures 0 <= SumIntents(core.outbox) <= init.original
  {
    ReplaySpecInv(init, ledger);
  }

  // ---- AUDIT COMPLETENESS: an honest store is never refused ----
  function LedgerOf(toks: seq<SinkToken>): seq<Delivery>
  {
    seq(|toks|, i requires 0 <= i < |toks| => Delivery(toks[i], true))
  }

  lemma ReplayLedgerOf(init: State, acts: seq<Act>)
    ensures Replay(init, LedgerOf(Exec(init, acts).toks)) == (true, Exec(init, acts).core)
    decreases |acts|
  {
    if |acts| > 0 {
      var p := acts[..|acts| - 1];
      ReplayLedgerOf(init, p);
      var r := Exec(init, p);
      assert Exec(init, acts) == Next(r, acts[|acts| - 1]);
      match acts[|acts| - 1]
      case MintAct(_, _) =>
      case Deliver(tok, sigOk) =>
        StepExact(r.core, tok, sigOk);
        if Step(r.core, tok, sigOk).out.Committed? {
          assert sigOk;
          var L := LedgerOf(r.toks + [tok]);
          assert L[..|L| - 1] == LedgerOf(r.toks);
          assert L[|L| - 1] == Delivery(tok, true);
        }
    }
  }

  // No hypothesis at all: every reachable core passes AuditFull on its own ledger.
  lemma AuditComplete(init: State, acts: seq<Act>)
    requires InitOk(init)
    ensures AuditFull(init, Exec(init, acts).core, LedgerOf(Exec(init, acts).toks))
  {
    ReplayLedgerOf(init, acts);
  }

  // Under A5 the stored check results of an honest ledger ARE the verifier's answers (all true).
  lemma AuditCompleteA5(init: State, acts: seq<Act>)
    requires A5_VerifierMatchesAtEachDelivery(acts)
    ensures A5Ledger(LedgerOf(Exec(init, acts).toks))
  {
    var r := Exec(init, acts);
    SliceSafetyV3_L1_A5(init, acts);
    ExecCore(init, acts);
    forall i | 0 <= i < |r.toks|
      ensures A5_VerifierMatches(r.toks[i], true)
    {
      assert TagVerifies(init, acts, i);
    }
  }

  // Under H1 + A2 + A5 every honest row also passes the spec re-check, so AuditFullSpec refuses no honest store.
  lemma AuditSpecComplete(init: State, acts: seq<Act>)
    requires InitOk(init) && HypsOn(acts)
    ensures AuditFullSpec(init, Exec(init, acts).core, LedgerOf(Exec(init, acts).toks))
  {
    var r := Exec(init, acts);
    AuditComplete(init, acts);
    ExecCore(init, acts);
    forall i | 0 <= i < |r.toks|
      ensures RowAuthorized(r.toks[i])
    {
      PerEntryApproved(init, acts, i);
      RowAuthorizedIsAuthorizes(r.toks[i]);
    }
  }

  // ---- the reviewer's core under the audits ----
  // (1) AuditFullSpec refuses it for EVERY init and EVERY ledger, with NO hypothesis.
  lemma BadCoreRefusedBySpecAudit(init: F.Charge, ledger: seq<Delivery>)
    ensures !AuditFullSpec(init, BadCore(), ledger)
  {
    if AuditFullSpec(init, BadCore(), ledger) {
      AuditSpecMoney(init, BadCore(), ledger);
      SumOne(BadCore().outbox[0]);
      assert BadCore().outbox == [BadCore().outbox[0]];
    }
  }

  // (2) AuditFull refuses it for every init and every ledger that meets the ledger hypotheses.
  lemma BadCoreRefusedByAuditUnderHyps(init: F.Charge, ledger: seq<Delivery>, ms: seq<(Claim, Tag)>)
    requires A5Ledger(ledger) && A2Mints(ms) && H1Ledger(ms, ledger)
    ensures !AuditFull(init, BadCore(), ledger)
  {
    if AuditFull(init, BadCore(), ledger) {
      AuditSound(init, BadCore(), ledger, ms);
      BadNotSound(init);
    }
  }

  // (3) COUNTEREXAMPLE KEPT: AuditFull ALONE does not bound money. A forged row (a claim the approved relation
  // does not authorize) whose stored check result is true replays to the reviewer's core. This is why AuditFull
  // needs A5 + H1 + A2 on the rows (or the spec re-check of AuditFullSpec).
  function ForgedRow(): SinkToken
  {
    SinkToken(PINNED_SPEC, PINNED_CHK, F.Charge("ch_1", 100, 100, true), "rq_a", F.Charge("ch_1", 100, 100, true),
              R.Intent("ch_1", "rq_a", 500, "duplicate_charge"), "forged")
  }

  lemma AuditFullAloneAcceptsForgedLedger()
    ensures AuditFull(F.Charge("ch_1", 100, 100, true), BadCore(), [Delivery(ForgedRow(), true)])
    ensures !RowAuthorized(ForgedRow())
    ensures !AuditFullSpec(F.Charge("ch_1", 100, 100, true), BadCore(), [Delivery(ForgedRow(), true)])
  {
    var l := [Delivery(ForgedRow(), true)];
    assert l[..0] == [];
  }

  // (4) The empty ledger is refused (the core is not the initial core).
  lemma BadCoreEmptyLedgerRefused(init: F.Charge)
    ensures !AuditFull(init, BadCore(), [])
  {
  }

  // ---- zero amount passes the audits ----
  function ZeroRow(): SinkToken
  {
    SinkToken(PINNED_SPEC, PINNED_CHK, F.Charge("ch_1", 100, 100, true), "rq_z", F.Charge("ch_1", 100, 100, true),
              R.Intent("ch_1", "rq_z", 0, "returned_item"), "sig_rq_z")
  }

  lemma ZeroAmountRowPasses()
    ensures AuditFullSpec(F.Charge("ch_1", 100, 100, true),
                          Core(F.Charge("ch_1", 100, 100, true), {"rq_z"}, [ZeroRow().intent]),
                          [Delivery(ZeroRow(), true)])
  {
    var l := [Delivery(ZeroRow(), true)];
    assert l[..0] == [];
    assert "returned_item" in {"duplicate_charge", "service_not_delivered", "returned_item"};
    assert RowAuthorized(ZeroRow());
  }

  // A reject-all store cannot pass completeness: the witness (RestartWitness) has commits, and AuditComplete
  // requires the replay of every committed row to COMMIT again.
}

// =================================================================================================
// Non-vacuity under the TOTAL verifier reading of SliceWitnessV3 (each lemma is conditional on SigReading()).
module RestartWitness {
  import opened SinkCoreV3
  import opened SliceTheoremV3
  import opened SliceWitnessV3
  import opened RestartV3

  // After the restart: a positive refund of 5 on the stored post-state (remaining 20 -> 15).
  const W2_PRE: F.Charge := F.Charge("ch_1", 100, 20, true)
  const W2_POST: F.Charge := F.Charge("ch_1", 100, 15, true)
  const W2_INTENT: R.RefundIntent := R.Intent("ch_1", "rq_2", 5, "returned_item")
  const V2_TOK: SinkToken := SinkToken(PINNED_SPEC, PINNED_CHK, W2_PRE, "rq_2", W2_POST, W2_INTENT, "sig_rq_2")

  // Before the restart: the zero-amount effect, the positive effect, and the issuer's mint of V2 (it persists).
  function A0(): seq<Act>
  {
    [MintAct(ClaimOf(V0_TOK), V0_TOK.sig), Deliver(V0_TOK, true),
     MintAct(ClaimOf(V_TOK), V_TOK.sig), Deliver(V_TOK, true),
     MintAct(ClaimOf(V2_TOK), V2_TOK.sig)]
  }

  // After the restart: V2 commits; a REPLAY of V_TOK (committed before the restart) is rejected.
  function A1(): seq<Act>
  {
    [Deliver(V2_TOK, true), Deliver(V_TOK, true)]
  }

  function Core0(): Core { Core(W_POST, {"rq_0", "rq_1"}, [W0_INTENT, W_INTENT]) }
  function Core1(): Core { Core(W2_POST, {"rq_0", "rq_1", "rq_2"}, [W0_INTENT, W_INTENT, W2_INTENT]) }

  lemma A0Core()
    ensures Exec(W_PRE, A0()).core == Core0()
    ensures Exec(W_PRE, A0()).toks == [V0_TOK, V_TOK]
  {
    MainTraceFirst();
    assert A0() == MainActs()[..4] + [MintAct(ClaimOf(V2_TOK), V2_TOK.sig)];
    assert A0()[..4] == MainActs()[..4];
    assert Exec(W_PRE, A0()) == Next(Exec(W_PRE, A0()[..4]), A0()[4]);
  }

  lemma A1Run()
    ensures Step(Core0(), V2_TOK, true).out.Committed?
    ensures Step(Core0(), V2_TOK, true).core == Core1()
    ensures Step(Core1(), V_TOK, true).out == Rejected(RequestSettled)
    ensures CoreRun(Core0(), A1()) == Core1()
  {
    assert "rq_2"[3] != "rq_0"[3] && "rq_2"[3] != "rq_1"[3];
    assert "rq_1" in Core1().settled;
    assert A1()[..1] == [Deliver(V2_TOK, true)];
    assert A1()[..1][..0] == [];
    assert CoreRun(Core0(), A1()[..1]) == Core1();
  }

  lemma FullHyps()
    requires SigReading()
    ensures HypsOn(A0() + A1())
    ensures VerifyTag(ClaimOf(V2_TOK), V2_TOK.sig)
  {
    var f := A0() + A1();
    assert f == [MintAct(ClaimOf(V0_TOK), V0_TOK.sig), Deliver(V0_TOK, true),
                 MintAct(ClaimOf(V_TOK), V_TOK.sig), Deliver(V_TOK, true),
                 MintAct(ClaimOf(V2_TOK), V2_TOK.sig), Deliver(V2_TOK, true), Deliver(V_TOK, true)];
    SigOf(V0_TOK);
    SigOf(V_TOK);
    SigOf(V2_TOK);
    assert VerifyTag(ClaimOf(V0_TOK), V0_TOK.sig);
    assert VerifyTag(ClaimOf(V_TOK), V_TOK.sig);
    assert VerifyTag(ClaimOf(V2_TOK), V2_TOK.sig);
    var t0 := F.Transition(F.Request("rq_0", 0, "duplicate_charge"), W_PRE, W0_INTENT);
    var t1 := F.Transition(F.Request("rq_1", 40, "duplicate_charge"), W_POST, W_INTENT);
    var t2 := F.Transition(F.Request("rq_2", 5, "returned_item"), W2_POST, W2_INTENT);
    assert W_PRE.(remaining := W_PRE.remaining - 0) == W_PRE;
    assert "duplicate_charge" in {"duplicate_charge", "service_not_delivered", "returned_item"};
    assert "returned_item" in {"duplicate_charge", "service_not_delivered", "returned_item"};
    assert F.Authorizes(W_PRE, t0) && ClaimOf(V0_TOK) == CheckedClaim(W_PRE, t0);
    assert F.Authorizes(W_PRE, t1) && ClaimOf(V_TOK) == CheckedClaim(W_PRE, t1);
    assert F.Authorizes(W2_PRE, t2) && ClaimOf(V2_TOK) == CheckedClaim(W2_PRE, t2);
    forall k | 0 <= k < |f| && f[k].MintAct? && Ours(f[k].c)
      ensures exists pre: F.Charge, t: F.Transition :: F.Authorizes(pre, t) && f[k].c == CheckedClaim(pre, t)
    {
      if k == 0 {
        assert F.Authorizes(W_PRE, t0) && f[k].c == CheckedClaim(W_PRE, t0);
      } else if k == 2 {
        assert F.Authorizes(W_PRE, t1) && f[k].c == CheckedClaim(W_PRE, t1);
      } else {
        assert k == 4;
        assert F.Authorizes(W2_PRE, t2) && f[k].c == CheckedClaim(W2_PRE, t2);
      }
    }
    forall k | 0 <= k < |f| && f[k].Deliver?
      ensures A5_VerifierMatches(f[k].tok, f[k].sigOk)
    {
      assert k == 1 || k == 3 || k == 5 || k == 6;
    }
    forall k | 0 <= k < |f| && f[k].Deliver? && VerifyTag(ClaimOf(f[k].tok), f[k].tok.sig)
      ensures SignedBefore(f, k, ClaimOf(f[k].tok))
    {
      if k == 1 {
        assert f[0].MintAct? && f[0].c == ClaimOf(f[k].tok);
      } else if k == 5 {
        assert f[4].MintAct? && f[4].c == ClaimOf(f[k].tok);
      } else {
        assert k == 3 || k == 6;
        assert f[2].MintAct? && f[2].c == ClaimOf(f[k].tok);
      }
    }
  }

  // NON-VACUITY of the restart theorem. All hypotheses hold (history form). Before the restart a zero-amount
  // and a positive effect commit; the stored core passes AuditFull and AuditFullSpec on its ledger; after the
  // restart a positive effect commits and a replay of a pre-restart token is rejected (RequestSettled).
  // The LOCAL form of H1 FAILS on the continuation (V2 was minted before the restart): history is needed.
  lemma RestartWitnessMain()
    requires SigReading()
    ensures InitOk(W_PRE) && HypsOn(A0())
    ensures A2_MintOnlyOnCheck(A1()) && A5_VerifierMatchesAtEachDelivery(A1()) && H1Cont(A0(), A1())
    ensures !H1_SignatureAuthenticity(A1())
    ensures Exec(W_PRE, A0()).core.outbox == [W0_INTENT, W_INTENT] && W0_INTENT.amount == 0 && W_INTENT.amount == 40
    ensures AuditFull(W_PRE, Core0(), LedgerOf([V0_TOK, V_TOK]))
    ensures AuditFullSpec(W_PRE, Core0(), LedgerOf([V0_TOK, V_TOK]))
    ensures Sound(W_PRE, Core0())
    ensures CoreRun(Core0(), A1()).outbox == [W0_INTENT, W_INTENT, W2_INTENT] && W2_INTENT.amount == 5
    ensures Step(Core1(), V_TOK, true).out == Rejected(RequestSettled)
    ensures SumIntents(CoreRun(Core0(), A1()).outbox) == W_PRE.remaining - CoreRun(Core0(), A1()).charge.remaining
    ensures Sound(W_PRE, CoreRun(Core0(), A1()))
  {
    FullHyps();
    HypsAppend(A0(), A1());
    A0Core();
    A1Run();
    AuditComplete(W_PRE, A0());
    AuditSpecComplete(W_PRE, A0());
    Restart(W_PRE, A0(), A1(), FlatSpecFn);
    assert !SignedBefore(A1(), 0, ClaimOf(V2_TOK));
    assert A1()[0].Deliver? && VerifyTag(ClaimOf(A1()[0].tok), A1()[0].tok.sig);
  }
}
