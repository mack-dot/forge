// Night shift 2026-11-19, Orchestrator B, task b-integrate (G3, core level). A DRAFT. NOT gate evidence. Dafny
// model only. NOT a proof about sink.ts, the dispatcher, SQLite or a file system.
//
// Several charges. A store is a map from a KEY to a SinkCoreV3 core. A delivery carries an ADVERSARY-CHOSEN key.
// Why this routing key (decision and reason): sink.ts holds ONE charge per database file; the caller chooses the
// database (Sink constructor path). The token body holds no clear pre-state, only preStateSha256; its readable
// charge ids are intent.chargeId and post.chargeId. So the sink's database key is chosen OUTSIDE the token. Routing
// by an arbitrary key covers every caller behaviour; routing by tok.pre.chargeId (today's CommitAt) is the special
// case key == tok.pre.chargeId (lemma MisroutedRejected shows that, from a well-keyed store, only deliveries whose
// key equals tok.pre.chargeId can commit, so the two routings commit the same deliveries).
// Every lemma in this file uses NO signature assumption (arbitrary tokens, arbitrary sigOk, arbitrary keys).
// No assume, no axiom, no bodiless lemma.
include "SinkCoreV3.dfy"
include "inputs/transport/sink/SinkCoreReqId.dfy"

module MultiCharge {
  import opened SinkCoreV3

  type Store = map<string, Core>
  datatype MDelivery = MDelivery(key: string, tok: SinkToken, sigOk: bool)

  function MStep(st: Store, d: MDelivery): Store
  {
    if d.key in st then st[d.key := Step(st[d.key], d.tok, d.sigOk).core] else st
  }

  function MRun(st: Store, ds: seq<MDelivery>): Store
    decreases |ds|
  {
    if |ds| == 0 then st else MRun(MStep(st, ds[0]), ds[1..])
  }

  // The deployment precondition per charge: the store under key k holds charge k and is GoodStart.
  ghost predicate WellKeyed(st: Store)
  {
    forall k | k in st :: st[k].charge.chargeId == k && GoodStart(st[k])
  }

  function FreshStore(inits: map<string, F.Charge>): Store
  {
    map k | k in inits :: Core(inits[k], {}, [])
  }

  lemma FreshStoreWellKeyed(inits: map<string, F.Charge>)
    requires forall k | k in inits :: inits[k].chargeId == k
    ensures WellKeyed(FreshStore(inits))
  {
    forall k | k in FreshStore(inits)
      ensures FreshStore(inits)[k].charge.chargeId == k && GoodStart(FreshStore(inits)[k])
    {
      InitGood(inits[k]);
    }
  }

  // A delivery changes at most the routed charge; an unknown key changes nothing.
  lemma MStepFrame(st: Store, d: MDelivery)
    ensures MStep(st, d).Keys == st.Keys
    ensures forall k | k in st && k != d.key :: MStep(st, d)[k] == st[k]
    ensures d.key !in st ==> MStep(st, d) == st
  {
  }

  lemma MStepKeeps(st: Store, d: MDelivery)
    requires WellKeyed(st)
    ensures WellKeyed(MStep(st, d))
  {
    if d.key in st {
      StepKeepsGoodV3(st[d.key], d.tok, d.sigOk);
    }
  }

  lemma MRunKeeps(st: Store, ds: seq<MDelivery>)
    requires WellKeyed(st)
    ensures WellKeyed(MRun(st, ds)) && MRun(st, ds).Keys == st.Keys
    decreases |ds|
  {
    if |ds| > 0 {
      MStepKeeps(st, ds[0]);
      MRunKeeps(MStep(st, ds[0]), ds[1..]);
    }
  }

  // The projection of a multi-charge run to one key.
  function Proj(ds: seq<MDelivery>, k: string): seq<Delivery>
    decreases |ds|
  {
    if |ds| == 0 then []
    else (if ds[0].key == k then [Delivery(ds[0].tok, ds[0].sigOk)] else []) + Proj(ds[1..], k)
  }

  // Each charge evolves exactly as a single-charge run of the deliveries routed to it.
  lemma MRunIsRunPerCharge(st: Store, ds: seq<MDelivery>, k: string)
    requires k in st
    ensures k in MRun(st, ds) && MRun(st, ds)[k] == Run(st[k], Proj(ds, k))
    decreases |ds|
  {
    if |ds| > 0 {
      var st1 := MStep(st, ds[0]);
      MStepFrame(st, ds[0]);
      MRunIsRunPerCharge(st1, ds[1..], k);
      if ds[0].key == k {
        var d := Delivery(ds[0].tok, ds[0].sigOk);
        assert Proj(ds, k) == [d] + Proj(ds[1..], k);
        assert ([d] + Proj(ds[1..], k))[1..] == Proj(ds[1..], k);
        assert Run(st[k], Proj(ds, k)) == Run(Step(st[k], d.tok, d.sigOk).core, Proj(ds[1..], k));
      } else {
        assert Proj(ds, k) == Proj(ds[1..], k);
      }
    }
  }

  // From a well-keyed store, a delivery whose key differs from tok.pre.chargeId never commits (PreStateMismatch or
  // an earlier reject). So routing by tok.pre.chargeId and routing by the database key commit the same deliveries.
  lemma MisroutedRejected(st: Store, d: MDelivery)
    requires WellKeyed(st) && d.key in st && d.tok.pre.chargeId != d.key
    ensures !Step(st[d.key], d.tok, d.sigOk).out.Committed? && MStep(st, d) == st
  {
    StepExact(st[d.key], d.tok, d.sigOk);
    assert st[d.key := st[d.key]] == st;
  }

  // THE G3 CORE THEOREM (no assumption). For every run of arbitrary keyed deliveries from a well-keyed store:
  //  (a) the keys never change and every charge stays well keyed (GoodV3 per charge; stored chargeId == key);
  //  (b) every effect in charge k's outbox has chargeId k;
  //  (c) GLOBAL: no two effects in ALL outboxes together have the same (chargeId, requestId) pair; so for each
  //      charge id k, the effects for k across all outboxes are exactly those of k's own outbox, with distinct
  //      request ids;
  //  (d) each charge is the single-charge run of the deliveries routed to it.
  lemma MultiChargeSafety(st: Store, ds: seq<MDelivery>)
    requires WellKeyed(st)
    ensures MRun(st, ds).Keys == st.Keys && WellKeyed(MRun(st, ds))
    ensures forall k, i | k in MRun(st, ds) && 0 <= i < |MRun(st, ds)[k].outbox| :: MRun(st, ds)[k].outbox[i].chargeId == k
    ensures forall k1, k2, i, j | k1 in MRun(st, ds) && k2 in MRun(st, ds) &&
        0 <= i < |MRun(st, ds)[k1].outbox| && 0 <= j < |MRun(st, ds)[k2].outbox| && (k1 != k2 || i != j) ::
      MRun(st, ds)[k1].outbox[i].chargeId != MRun(st, ds)[k2].outbox[j].chargeId ||
      MRun(st, ds)[k1].outbox[i].requestId != MRun(st, ds)[k2].outbox[j].requestId
    ensures forall k | k in st :: MRun(st, ds)[k] == Run(st[k], Proj(ds, k))
  {
    MRunKeeps(st, ds);
    var st' := MRun(st, ds);
    forall k1, k2, i, j | k1 in st' && k2 in st' && 0 <= i < |st'[k1].outbox| && 0 <= j < |st'[k2].outbox| &&
        (k1 != k2 || i != j)
      ensures st'[k1].outbox[i].chargeId != st'[k2].outbox[j].chargeId ||
              st'[k1].outbox[i].requestId != st'[k2].outbox[j].requestId
    {
      if k1 == k2 {
        if i < j {
          assert st'[k1].outbox[i].requestId != st'[k1].outbox[j].requestId;
        } else {
          assert st'[k1].outbox[j].requestId != st'[k1].outbox[i].requestId;
        }
      }
    }
    forall k | k in st
      ensures st'[k] == Run(st[k], Proj(ds, k))
    {
      MRunIsRunPerCharge(st, ds, k);
    }
  }

  // ---- request ids are PER CHARGE: the same request id commits once in each of two charges ----
  function C1(): F.Charge { F.Charge("ch_1", 100, 100, true) }
  function C2(): F.Charge { F.Charge("ch_2", 50, 50, true) }
  function St0(): Store { map["ch_1" := Core(C1(), {}, []), "ch_2" := Core(C2(), {}, [])] }

  lemma St0WellKeyed()
    ensures WellKeyed(St0())
  {
    InitGood(C1());
    InitGood(C2());
  }

  lemma SameRequestIdInTwoCharges()
    ensures var a := SinkToken(PINNED_SPEC, PINNED_CHK, C1(), "rq_x", C1().(remaining := 90),
                               R.Intent("ch_1", "rq_x", 10, "duplicate_charge"), "s1");
            var b := SinkToken(PINNED_SPEC, PINNED_CHK, C2(), "rq_x", C2().(remaining := 40),
                               R.Intent("ch_2", "rq_x", 10, "duplicate_charge"), "s2");
            var st2 := MRun(St0(), [MDelivery("ch_1", a, true), MDelivery("ch_2", b, true)]);
            WellKeyed(St0()) && "ch_1" in st2 && "ch_2" in st2 &&
            st2["ch_1"].outbox == [a.intent] && st2["ch_2"].outbox == [b.intent] &&
            st2["ch_1"].outbox[0].requestId == st2["ch_2"].outbox[0].requestId == "rq_x" &&
            st2["ch_1"].outbox[0].chargeId != st2["ch_2"].outbox[0].chargeId
  {
    St0WellKeyed();
    var a := SinkToken(PINNED_SPEC, PINNED_CHK, C1(), "rq_x", C1().(remaining := 90),
                       R.Intent("ch_1", "rq_x", 10, "duplicate_charge"), "s1");
    var b := SinkToken(PINNED_SPEC, PINNED_CHK, C2(), "rq_x", C2().(remaining := 40),
                       R.Intent("ch_2", "rq_x", 10, "duplicate_charge"), "s2");
    var ds := [MDelivery("ch_1", a, true), MDelivery("ch_2", b, true)];
    var st1 := MStep(St0(), ds[0]);
    var st2 := MStep(st1, ds[1]);
    assert ds[1..] == [ds[1]] && ds[1..][1..] == [];
    assert MRun(St0(), ds) == MRun(st1, ds[1..]) == MRun(st2, []) == st2;
    assert st1["ch_1"].outbox == [a.intent] && st1["ch_2"] == St0()["ch_2"];
  }

  // ---- the cross-charge attack of r-reqid (CrossChargeWithReqIdPatch), against V3 ----
  // The same two tokens, routed by tok.pre.chargeId. V3 rejects the first (ChargeIdMismatch): ch_1 emits nothing;
  // ch_2 commits once; the total for ch_2 is 50 <= original 50.
  lemma CrossChargeClosed()
    ensures var t1 := SinkToken(PINNED_SPEC, PINNED_CHK, C1(), "rq_x", C1(),
                                R.Intent("ch_2", "rq_x", 50, "duplicate_charge"), "s1");
            var t2 := SinkToken(PINNED_SPEC, PINNED_CHK, C2(), "rq_x", C2().(remaining := 0),
                                R.Intent("ch_2", "rq_x", 50, "duplicate_charge"), "s2");
            var st2 := MRun(St0(), [MDelivery(t1.pre.chargeId, t1, true), MDelivery(t2.pre.chargeId, t2, true)]);
            Step(St0()["ch_1"], t1, true).out == Rejected(ChargeIdMismatch) && "ch_1" in st2 && "ch_2" in st2 &&
            st2["ch_1"].outbox == [] && st2["ch_2"].outbox == [t2.intent] && t2.intent.amount <= C2().original
  {
    var t1 := SinkToken(PINNED_SPEC, PINNED_CHK, C1(), "rq_x", C1(),
                        R.Intent("ch_2", "rq_x", 50, "duplicate_charge"), "s1");
    var t2 := SinkToken(PINNED_SPEC, PINNED_CHK, C2(), "rq_x", C2().(remaining := 0),
                        R.Intent("ch_2", "rq_x", 50, "duplicate_charge"), "s2");
    var ds := [MDelivery("ch_1", t1, true), MDelivery("ch_2", t2, true)];
    var st1 := MStep(St0(), ds[0]);
    var st2 := MStep(st1, ds[1]);
    assert st1["ch_1"] == St0()["ch_1"] && st1 == St0();
    assert ds[1..] == [ds[1]] && ds[1..][1..] == [];
    assert MRun(St0(), ds) == MRun(st1, ds[1..]) == MRun(st2, []) == st2;
  }
}

// The CONTRAST: the core WITHOUT the charge-id check (SinkCoreReqId, byte-equal copy of d-reqid) on the same
// keyed map: two effects for ch_2 with one request id, total 100 > original 50; and one store emits a refund for
// another charge. (The same construction as r-reqid's CrossChargeWithReqIdPatch, restated with MRun-style routing.)
module MultiChargeContrast {
  import P = SinkCoreReqId
  import F = RefundFinality
  import R = Refund

  function C1(): F.Charge { F.Charge("ch_1", 100, 100, true) }
  function C2(): F.Charge { F.Charge("ch_2", 50, 50, true) }

  function PStep(st: map<string, P.Core>, key: string, tok: P.SinkToken, sigOk: bool): map<string, P.Core>
  {
    if key in st then st[key := P.Step(st[key], tok, sigOk).core] else st
  }

  lemma CrossChargeOpenWithoutChargeCheck()
    ensures var st0 := map["ch_1" := P.Core(C1(), {}, []), "ch_2" := P.Core(C2(), {}, [])];
            var t1 := P.SinkToken(P.PINNED_SPEC, P.PINNED_CHK, C1(), "rq_x", C1(),
                                  R.Intent("ch_2", "rq_x", 50, "duplicate_charge"), "s1");
            var t2 := P.SinkToken(P.PINNED_SPEC, P.PINNED_CHK, C2(), "rq_x", C2().(remaining := 0),
                                  R.Intent("ch_2", "rq_x", 50, "duplicate_charge"), "s2");
            var st2 := PStep(PStep(st0, "ch_1", t1, true), "ch_2", t2, true);
            st2["ch_1"].outbox == [t1.intent] && st2["ch_2"].outbox == [t2.intent] &&
            st2["ch_1"].outbox[0].chargeId == "ch_2" &&
            st2["ch_1"].outbox[0].requestId == st2["ch_2"].outbox[0].requestId &&
            st2["ch_1"].outbox[0].amount + st2["ch_2"].outbox[0].amount > C2().original
  {
  }

  // The single-charge contrast of G1: without the charge check a token with a foreign charge id commits.
  lemma ForeignChargeCommitsWithoutCheck()
    ensures var t := P.SinkToken(P.PINNED_SPEC, P.PINNED_CHK, C1(), "rq_y", C2(),
                                 R.Intent("ch_1", "rq_y", 0, "duplicate_charge"), "s3");
            var r := P.Step(P.Core(C1(), {}, []), t, true);
            r.out.Committed? && r.core.charge.chargeId == "ch_2"
  {
  }
}
