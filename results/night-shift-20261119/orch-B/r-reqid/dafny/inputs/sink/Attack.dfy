// r-reqid (night shift 2026-11-19, Orchestrator B): adversarial review of d-reqid. A DRAFT.
// No assume, no axiom, no bodiless lemma. Uses the reviewed files unchanged (SinkCore.dfy, SinkCoreReqId.dfy).
include "SinkCore.dfy"
include "SinkCoreReqId.dfy"

module ReqIdAttack {
  import S = SinkCore
  import P = SinkCoreReqId
  import F = RefundFinality
  import R = Refund

  function C0(): F.Charge { F.Charge("ch_1", 100, 100, true) }
  function C2(): F.Charge { F.Charge("ch_2", 50, 50, true) }

  // (a1) COUNTEREXAMPLE. The patched core repeats an intent.requestId that is ALREADY in the outbox when
  // the start core is not Good. The start core is exactly the store that the UNPATCHED core writes on the
  // gap trace (Contrast.UnpatchedGap, first step). So a store written by the unpatched sink and then
  // served by the patched sink emits a second effect for "rq_victim".
  lemma UpgradeAfterGapStillDuplicates()
    ensures var bad := S.SinkToken(S.PINNED_SPEC, S.PINNED_CHK, C0(), "rq_body", C0().(remaining := 90),
                                   R.Intent("ch_1", "rq_victim", 10, "duplicate_charge"), "sigA");
            var r1 := S.Step(S.Core(C0(), {}, []), bad, true);
            var c := P.Core(r1.core.charge, r1.core.settled, r1.core.outbox);
            var honest := P.SinkToken(P.PINNED_SPEC, P.PINNED_CHK, C0().(remaining := 90), "rq_victim",
                                      C0().(remaining := 80), R.Intent("ch_1", "rq_victim", 10, "duplicate_charge"), "sigB");
            var r2 := P.Step(c, honest, true);
            r1.out.Committed? && !P.Good(c) && r2.out.Committed? &&
            |r2.core.outbox| == 2 && r2.core.outbox[0].requestId == r2.core.outbox[1].requestId == "rq_victim"
  {
    var bad := S.SinkToken(S.PINNED_SPEC, S.PINNED_CHK, C0(), "rq_body", C0().(remaining := 90),
                           R.Intent("ch_1", "rq_victim", 10, "duplicate_charge"), "sigA");
    var r1 := S.Step(S.Core(C0(), {}, []), bad, true);
    var c := P.Core(r1.core.charge, r1.core.settled, r1.core.outbox);
    assert c.outbox[0].requestId == "rq_victim" && c.settled == {"rq_body"};
  }

  // (a2) The weakest start condition that suffices: every outbox request id is settled (the first
  // conjunct of Good only). Then no new effect repeats an old outbox request id, for ANY deliveries.
  lemma NoRepeatIfOutboxSettled(c: P.Core, ds: seq<P.Delivery>)
    requires forall i | 0 <= i < |c.outbox| :: c.outbox[i].requestId in c.settled
    ensures var c' := P.Run(c, ds);
            |c.outbox| <= |c'.outbox| && c'.outbox[..|c.outbox|] == c.outbox &&
            forall i, j | 0 <= i < |c.outbox| <= j < |c'.outbox| :: c'.outbox[j].requestId != c'.outbox[i].requestId
  {
    P.RunGrowth(c, ds);
    var c' := P.Run(c, ds);
    forall i, j | 0 <= i < |c.outbox| <= j < |c'.outbox|
      ensures c'.outbox[j].requestId != c'.outbox[i].requestId
    {
      assert c'.outbox[i] == c'.outbox[..|c.outbox|][i] == c.outbox[i];
    }
  }

  // (b) The bad token of UnpatchedGap is NOT authorized by the approved relation: the real issuer
  // (proved Check) cannot sign it. The gap needs a faulty signer, a stolen key, or a failure of A1/A2.
  lemma GapTokenNotAuthorized()
    ensures !F.Authorizes(C0(), F.Transition(F.Request("rq_body", 10, "duplicate_charge"), C0().(remaining := 90),
                                             R.Intent("ch_1", "rq_victim", 10, "duplicate_charge")))
  {
  }

  // (c) Cross-charge effect with the request-id patch and routing by tok.pre.chargeId (the body of
  // CommitAt). A token routed to the ch_1 store emits an intent for ch_2 and leaves ch_1 unchanged.
  // The ch_2 store then commits an honest-shaped token with the SAME request id (settled is per store).
  // Result: two effects for ch_2 with one intent.requestId, total 100 > original 50 of ch_2.
  function Route(stores: map<string, P.Core>, tok: P.SinkToken, sigOk: bool): map<string, P.Core>
  {
    var k := tok.pre.chargeId;
    if k in stores then stores[k := P.Step(stores[k], tok, sigOk).core] else stores
  }

  lemma CrossChargeWithReqIdPatch()
    ensures var st0 := map["ch_1" := P.Core(C0(), {}, []), "ch_2" := P.Core(C2(), {}, [])];
            var t1 := P.SinkToken(P.PINNED_SPEC, P.PINNED_CHK, C0(), "rq_x", C0(),
                                  R.Intent("ch_2", "rq_x", 50, "duplicate_charge"), "s1");
            var t2 := P.SinkToken(P.PINNED_SPEC, P.PINNED_CHK, C2(), "rq_x", C2().(remaining := 0),
                                  R.Intent("ch_2", "rq_x", 50, "duplicate_charge"), "s2");
            var st1 := Route(st0, t1, true);
            var st2 := Route(st1, t2, true);
            P.Step(st0["ch_1"], t1, true).out.Committed? && P.Step(st1["ch_2"], t2, true).out.Committed? &&
            st2["ch_1"].outbox == [t1.intent] && st2["ch_2"].outbox == [t2.intent] &&
            st2["ch_1"].outbox[0].chargeId == "ch_2" && st2["ch_1"].charge == C0() &&
            st2["ch_1"].outbox[0].requestId == st2["ch_2"].outbox[0].requestId &&
            st2["ch_1"].outbox[0].amount + st2["ch_2"].outbox[0].amount > C2().original
  {
  }

  // (c2) A token whose post has another charge id locks the routed store: afterwards no token that is
  // routed to that store can commit (its pre.chargeId is the key, the stored charge has the other id).
  lemma ForeignPostLocksStore(core: P.Core, key: string, tok: P.SinkToken, sigOk: bool)
    requires core.charge.chargeId != key && tok.pre.chargeId == key
    ensures !P.Step(core, tok, sigOk).out.Committed?
  {
  }

  lemma ForeignPostWitness()
    ensures var t := P.SinkToken(P.PINNED_SPEC, P.PINNED_CHK, C0(), "rq_y", C2(),
                                 R.Intent("ch_1", "rq_y", 0, "duplicate_charge"), "s3");
            var r := P.Step(P.Core(C0(), {}, []), t, true);
            r.out.Committed? && r.core.charge.chargeId == "ch_2"
  {
  }
}
