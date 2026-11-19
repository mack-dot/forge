// Night shift 2026-11-19, Orchestrator B, task r-integrate. A DRAFT. NOT gate evidence. Dafny-model statements
// about MultiCharge (b-integrate, copied to ../src, SHA-256 70204489...). No assume, no axiom, no bodiless lemma.
include "../src/MultiCharge.dfy"

module AttackMulti {
  import opened SinkCoreV3
  import opened MultiCharge

  // ---- M-A: WellKeyed is load-bearing. Two keys hold the SAME charge (ch_1), both fresh (each GoodStart). ----
  // Nothing in sink.ts ties a database path to a charge id (init(state) takes any state). One token with a
  // verifying tag then commits in BOTH stores: two effects with the same (chargeId, requestId); total 200 > 100.
  function DupStore(): Store
  {
    map["db_a" := Core(F.Charge("ch_1", 100, 100, true), {}, []),
        "db_b" := Core(F.Charge("ch_1", 100, 100, true), {}, [])]
  }

  lemma NotWellKeyedDoubleRefund()
    ensures !WellKeyed(DupStore())
    ensures forall k | k in DupStore() :: GoodStart(DupStore()[k])
    ensures var c0 := F.Charge("ch_1", 100, 100, true);
            var t := SinkToken(PINNED_SPEC, PINNED_CHK, c0, "rq_x", c0.(remaining := 0),
                               R.Intent("ch_1", "rq_x", 100, "duplicate_charge"), "s");
            var st2 := MRun(DupStore(), [MDelivery("db_a", t, true), MDelivery("db_b", t, true)]);
            "db_a" in st2 && "db_b" in st2 &&
            st2["db_a"].outbox == [t.intent] && st2["db_b"].outbox == [t.intent] &&
            st2["db_a"].outbox[0].amount + st2["db_b"].outbox[0].amount > c0.original
  {
    var c0 := F.Charge("ch_1", 100, 100, true);
    InitGood(c0);
    assert "db_a" in DupStore() && DupStore()["db_a"].charge.chargeId != "db_a";
    var t := SinkToken(PINNED_SPEC, PINNED_CHK, c0, "rq_x", c0.(remaining := 0),
                       R.Intent("ch_1", "rq_x", 100, "duplicate_charge"), "s");
    var ds := [MDelivery("db_a", t, true), MDelivery("db_b", t, true)];
    var st1 := MStep(DupStore(), ds[0]);
    var st2 := MStep(st1, ds[1]);
    assert ds[1..] == [ds[1]] && ds[1..][1..] == [];
    assert MRun(DupStore(), ds) == MRun(st1, ds[1..]) == MRun(st2, []) == st2;
    assert st1["db_b"] == DupStore()["db_b"];
  }

  // ---- M-B: what MultiCharge really needs is INJECTIVITY of the stored charge id over keys (key == chargeId is
  // one way to get it). A weaker precondition, proved enough for global (chargeId, requestId) uniqueness. ----
  ghost predicate InjectiveCharges(st: Store)
  {
    (forall k | k in st :: GoodStart(st[k])) &&
    (forall k1, k2 | k1 in st && k2 in st && k1 != k2 :: st[k1].charge.chargeId != st[k2].charge.chargeId)
  }

  lemma InjectiveSuffices(st: Store, ds: seq<MDelivery>)
    requires InjectiveCharges(st)
    ensures forall k1, k2, i, j | k1 in MRun(st, ds) && k2 in MRun(st, ds) &&
        0 <= i < |MRun(st, ds)[k1].outbox| && 0 <= j < |MRun(st, ds)[k2].outbox| && (k1 != k2 || i != j) ::
      MRun(st, ds)[k1].outbox[i].chargeId != MRun(st, ds)[k2].outbox[j].chargeId ||
      MRun(st, ds)[k1].outbox[i].requestId != MRun(st, ds)[k2].outbox[j].requestId
  {
    var st' := MRun(st, ds);
    forall k | k in st
      ensures k in st' && st'[k] == Run(st[k], Proj(ds, k)) && GoodV3(st'[k]) &&
              st'[k].charge.chargeId == st[k].charge.chargeId
    {
      MRunIsRunPerCharge(st, ds, k);
      RunKeepsGoodV3(st[k], Proj(ds, k));
    }
    MRunKeys(st, ds);
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
      } else {
        assert st'[k1].outbox[i].chargeId == st[k1].charge.chargeId;
        assert st'[k2].outbox[j].chargeId == st[k2].charge.chargeId;
      }
    }
  }

  lemma MRunKeys(st: Store, ds: seq<MDelivery>)
    ensures MRun(st, ds).Keys == st.Keys
    decreases |ds|
  {
    if |ds| > 0 {
      MStepFrame(st, ds[0]);
      MRunKeys(MStep(st, ds[0]), ds[1..]);
    }
  }

  // ---- M-C: routing to a store whose stored charge EQUALS tok.pre is the only way to commit; the chargeId is a
  // field of the Charge value, so tok.pre == stored forces tok.pre.chargeId == stored chargeId. ----
  lemma CommitForcesChargeId(c: Core, tok: SinkToken, sigOk: bool)
    requires Step(c, tok, sigOk).out.Committed?
    ensures tok.pre.chargeId == c.charge.chargeId && tok.intent.chargeId == c.charge.chargeId &&
            tok.post.chargeId == c.charge.chargeId
  {
  }
}
