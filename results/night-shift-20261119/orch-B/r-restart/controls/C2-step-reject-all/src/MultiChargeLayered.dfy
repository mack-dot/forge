// Night shift 2026-11-19, Orchestrator B, task b-integrate (G3, layered statement for several charges). A DRAFT.
// NOT gate evidence. Dafny model only.
//
// A multi-charge trace: mints (one issuer, one signed set for all charges) and keyed deliveries (the key is chosen
// by the adversary, as in MultiCharge.dfy). The store is FreshStore(inits): charge k under key k. Per charge, the run
// equals the single-charge Exec of SliceSafetyV3 on the PROJECTED trace (all mints, the deliveries with key k).
// The global hypotheses H1M, A2M, A5M on the multi-charge trace imply H1, A2, A5 on every projection (proved).
// Then the V3 layers hold for EVERY charge at once. No IdealMac. No assume, no axiom, no bodiless lemma.
include "SliceSafetyV3.dfy"
include "MultiCharge.dfy"

module MultiChargeLayered {
  import opened SinkCoreV3
  import opened SliceTheoremV3
  import opened MultiCharge

  datatype MAct = MMint(c: Claim, tag: Tag) | MDel(key: string, tok: SinkToken, sigOk: bool)

  function LiftAct(a: MAct, k: string): seq<Act>
  {
    match a
    case MMint(c, t) => [MintAct(c, t)]
    case MDel(key, tok, s) => if key == k then [Deliver(tok, s)] else []
  }

  function ProjActs(acts: seq<MAct>, k: string): seq<Act>
    decreases |acts|
  {
    if |acts| == 0 then [] else ProjActs(acts[..|acts| - 1], k) + LiftAct(acts[|acts| - 1], k)
  }

  function MStepA(st: Store, a: MAct): Store
  {
    match a
    case MMint(_, _) => st
    case MDel(key, tok, s) => MStep(st, MDelivery(key, tok, s))
  }

  function MExec(st: Store, acts: seq<MAct>): Store
    decreases |acts|
  {
    if |acts| == 0 then st else MStepA(MExec(st, acts[..|acts| - 1]), acts[|acts| - 1])
  }

  // ---- the global hypotheses on the multi-charge trace ----
  ghost predicate H1M(acts: seq<MAct>)
  {
    forall n | 0 <= n < |acts| && acts[n].MDel? ::
      VerifyTag(ClaimOf(acts[n].tok), acts[n].tok.sig) ==>
        exists j :: 0 <= j < n && acts[j].MMint? && acts[j].c == ClaimOf(acts[n].tok)
  }

  ghost predicate A2M(acts: seq<MAct>)
  {
    forall n | 0 <= n < |acts| && acts[n].MMint? && Ours(acts[n].c) ::
      exists pre: F.Charge, t: F.Transition :: F.Authorizes(pre, t) && acts[n].c == CheckedClaim(pre, t)
  }

  ghost predicate A5M(acts: seq<MAct>)
  {
    forall n | 0 <= n < |acts| && acts[n].MDel? :: A5_VerifierMatches(acts[n].tok, acts[n].sigOk)
  }

  // ---- per charge, the multi-charge run IS the single-charge Exec of the projection ----
  lemma ExecSnoc(init: State, p: seq<Act>, x: Act)
    ensures Exec(init, p + [x]) == Next(Exec(init, p), x)
  {
    assert (p + [x])[..|p|] == p;
  }

  lemma MExecIsExecPerCharge(inits: map<string, F.Charge>, acts: seq<MAct>, k: string)
    requires k in inits
    ensures MExec(FreshStore(inits), acts).Keys == inits.Keys
    ensures MExec(FreshStore(inits), acts)[k] == Exec(inits[k], ProjActs(acts, k)).core
    decreases |acts|
  {
    if |acts| > 0 {
      var p := acts[..|acts| - 1];
      var a := acts[|acts| - 1];
      MExecIsExecPerCharge(inits, p, k);
      var st := MExec(FreshStore(inits), p);
      var P := ProjActs(p, k);
      match a
      case MMint(c, t) =>
        ExecSnoc(inits[k], P, MintAct(c, t));
      case MDel(key, tok, s) =>
        MStepFrame(st, MDelivery(key, tok, s));
        if key == k {
          ExecSnoc(inits[k], P, Deliver(tok, s));
        } else {
          assert ProjActs(acts, k) == P + [];
          assert P + [] == P;
        }
    }
  }

  // ---- global hypotheses give the per-charge hypotheses ----
  lemma ProjPrefix(P: seq<Act>, Lx: seq<Act>, i: int)
    requires 0 <= i < |P|
    ensures (P + Lx)[i] == P[i]
  {
  }

  lemma A2A5Proj(acts: seq<MAct>, k: string)
    requires A2M(acts) && A5M(acts)
    ensures A2_MintOnlyOnCheck(ProjActs(acts, k)) && A5_VerifierMatchesAtEachDelivery(ProjActs(acts, k))
    decreases |acts|
  {
    if |acts| > 0 {
      var n := |acts|;
      var p := acts[..n - 1];
      forall m | 0 <= m < |p|
        ensures p[m] == acts[m]
      {
      }
      A2A5Proj(p, k);
      var P := ProjActs(p, k);
      var Q := ProjActs(acts, k);
      assert Q == P + LiftAct(acts[n - 1], k);
      forall i | 0 <= i < |Q| && Q[i].MintAct? && Ours(Q[i].c)
        ensures exists pre: F.Charge, t: F.Transition :: F.Authorizes(pre, t) && Q[i].c == CheckedClaim(pre, t)
      {
        if i < |P| {
          ProjPrefix(P, LiftAct(acts[n - 1], k), i);
        } else {
          assert acts[n - 1].MMint? && Q[i].c == acts[n - 1].c;
        }
      }
      forall i | 0 <= i < |Q| && Q[i].Deliver?
        ensures A5_VerifierMatches(Q[i].tok, Q[i].sigOk)
      {
        if i < |P| {
          ProjPrefix(P, LiftAct(acts[n - 1], k), i);
        } else {
          assert acts[n - 1].MDel? && Q[i].tok == acts[n - 1].tok && Q[i].sigOk == acts[n - 1].sigOk;
        }
      }
    }
  }

  lemma MintInProj(acts: seq<MAct>, j: int, k: string)
    requires 0 <= j < |acts| && acts[j].MMint?
    ensures exists m :: 0 <= m < |ProjActs(acts, k)| && ProjActs(acts, k)[m] == MintAct(acts[j].c, acts[j].tag)
    decreases |acts|
  {
    var n := |acts|;
    var p := acts[..n - 1];
    var P := ProjActs(p, k);
    assert ProjActs(acts, k) == P + LiftAct(acts[n - 1], k);
    if j == n - 1 {
      assert ProjActs(acts, k)[|P|] == MintAct(acts[j].c, acts[j].tag);
    } else {
      assert p[j] == acts[j];
      MintInProj(p, j, k);
      var m :| 0 <= m < |P| && P[m] == MintAct(p[j].c, p[j].tag);
      ProjPrefix(P, LiftAct(acts[n - 1], k), m);
    }
  }

  lemma H1Prefix(acts: seq<MAct>)
    requires |acts| > 0 && H1M(acts)
    ensures H1M(acts[..|acts| - 1])
  {
    var p := acts[..|acts| - 1];
    forall n | 0 <= n < |p| && p[n].MDel? && VerifyTag(ClaimOf(p[n].tok), p[n].tok.sig)
      ensures exists j :: 0 <= j < n && p[j].MMint? && p[j].c == ClaimOf(p[n].tok)
    {
      assert acts[n] == p[n];
      var j :| 0 <= j < n && acts[j].MMint? && acts[j].c == ClaimOf(acts[n].tok);
      assert p[j] == acts[j];
    }
  }

  lemma H1Proj(acts: seq<MAct>, k: string)
    requires H1M(acts)
    ensures H1_SignatureAuthenticity(ProjActs(acts, k))
    decreases |acts|
  {
    if |acts| > 0 {
      var n := |acts|;
      var p := acts[..n - 1];
      H1Prefix(acts);
      H1Proj(p, k);
      var P := ProjActs(p, k);
      var Lx := LiftAct(acts[n - 1], k);
      var Q := ProjActs(acts, k);
      assert Q == P + Lx;
      forall i | 0 <= i < |Q| && Q[i].Deliver? && VerifyTag(ClaimOf(Q[i].tok), Q[i].tok.sig)
        ensures SignedBefore(Q, i, ClaimOf(Q[i].tok))
      {
        if i < |P| {
          ProjPrefix(P, Lx, i);
          assert SignedBefore(P, i, ClaimOf(P[i].tok));
          var j :| 0 <= j < i && j < |P| && P[j].MintAct? && P[j].c == ClaimOf(P[i].tok);
          ProjPrefix(P, Lx, j);
        } else {
          assert acts[n - 1].MDel? && Q[i].tok == acts[n - 1].tok && i == |P|;
          var j :| 0 <= j < n - 1 && acts[j].MMint? && acts[j].c == ClaimOf(acts[n - 1].tok);
          assert p[j] == acts[j];
          MintInProj(p, j, k);
          var m :| 0 <= m < |P| && P[m] == MintAct(p[j].c, p[j].tag);
          ProjPrefix(P, Lx, m);
          assert Q[m].MintAct? && Q[m].c == ClaimOf(Q[i].tok);
        }
      }
    }
  }

  // ---- the global no-duplicate statement from per-charge facts ----
  lemma GlobalDistinct(st: Store)
    requires WellKeyed(st)
    ensures forall k, i | k in st && 0 <= i < |st[k].outbox| :: st[k].outbox[i].chargeId == k
    ensures forall k1, k2, i, j | k1 in st && k2 in st && 0 <= i < |st[k1].outbox| && 0 <= j < |st[k2].outbox| &&
        (k1 != k2 || i != j) ::
      st[k1].outbox[i].chargeId != st[k2].outbox[j].chargeId || st[k1].outbox[i].requestId != st[k2].outbox[j].requestId
  {
    forall k1, k2, i, j | k1 in st && k2 in st && 0 <= i < |st[k1].outbox| && 0 <= j < |st[k2].outbox| &&
        (k1 != k2 || i != j)
      ensures st[k1].outbox[i].chargeId != st[k2].outbox[j].chargeId ||
              st[k1].outbox[i].requestId != st[k2].outbox[j].requestId
    {
      if k1 == k2 {
        if i < j {
          assert st[k1].outbox[i].requestId != st[k1].outbox[j].requestId;
        } else {
          assert st[k1].outbox[j].requestId != st[k1].outbox[i].requestId;
        }
      }
    }
  }

  ghost predicate KeyedInits(inits: map<string, F.Charge>)
  {
    forall k | k in inits :: inits[k].chargeId == k
  }

  // L0 for several charges: NO hypothesis.
  lemma MultiL0(inits: map<string, F.Charge>, acts: seq<MAct>)
    requires KeyedInits(inits)
    ensures MExec(FreshStore(inits), acts).Keys == inits.Keys
    ensures WellKeyed(MExec(FreshStore(inits), acts))
    ensures forall k | k in inits :: MExec(FreshStore(inits), acts)[k] == Exec(inits[k], ProjActs(acts, k)).core
    ensures forall k1, k2, i, j | k1 in inits && k2 in inits &&
        0 <= i < |MExec(FreshStore(inits), acts)[k1].outbox| && 0 <= j < |MExec(FreshStore(inits), acts)[k2].outbox| &&
        (k1 != k2 || i != j) ::
      MExec(FreshStore(inits), acts)[k1].outbox[i].chargeId != MExec(FreshStore(inits), acts)[k2].outbox[j].chargeId ||
      MExec(FreshStore(inits), acts)[k1].outbox[i].requestId != MExec(FreshStore(inits), acts)[k2].outbox[j].requestId
    ensures forall k, i | k in inits && 0 <= i < |MExec(FreshStore(inits), acts)[k].outbox| ::
      MExec(FreshStore(inits), acts)[k].outbox[i].chargeId == k
  {
    var st := MExec(FreshStore(inits), acts);
    MExecIsExecPerChargeKeys(inits, acts);
    forall k | k in inits
      ensures st.Keys == inits.Keys && st[k] == Exec(inits[k], ProjActs(acts, k)).core
      ensures st[k].charge.chargeId == k && GoodStart(st[k])
    {
      MExecIsExecPerCharge(inits, acts, k);
      ExecCore(inits[k], ProjActs(acts, k));
    }
    MExecIsExecPerChargeKeys(inits, acts);
    assert WellKeyed(st);
    GlobalDistinct(st);
  }

  lemma MExecIsExecPerChargeKeys(inits: map<string, F.Charge>, acts: seq<MAct>)
    ensures MExec(FreshStore(inits), acts).Keys == inits.Keys
    decreases |acts|
  {
    if |acts| > 0 {
      MExecIsExecPerChargeKeys(inits, acts[..|acts| - 1]);
      match acts[|acts| - 1]
      case MMint(_, _) =>
      case MDel(key, tok, s) =>
        MStepFrame(MExec(FreshStore(inits), acts[..|acts| - 1]), MDelivery(key, tok, s));
    }
  }

  // L2 + L3 for EVERY charge at once, from the GLOBAL hypotheses H1M, A2M, A5M (and A6b for L3).
  lemma MultiLayered(inits: map<string, F.Charge>, acts: seq<MAct>, art: FlatFn, k: string)
    requires KeyedInits(inits) && k in inits && InitOk(inits[k])
    requires H1M(acts) && A2M(acts) && A5M(acts)
    ensures k in MExec(FreshStore(inits), acts)
    ensures MExec(FreshStore(inits), acts)[k] == Exec(inits[k], ProjActs(acts, k)).core
    ensures 0 <= MExec(FreshStore(inits), acts)[k].charge.remaining <= MExec(FreshStore(inits), acts)[k].charge.original == inits[k].original
    ensures SumIntents(MExec(FreshStore(inits), acts)[k].outbox) == inits[k].remaining - MExec(FreshStore(inits), acts)[k].charge.remaining
    ensures 0 <= SumIntents(MExec(FreshStore(inits), acts)[k].outbox) <= inits[k].original
    ensures forall e | CommittedEffect(inits[k], ProjActs(acts, k), e) ::
      exists i :: (0 <= i < |Exec(inits[k], ProjActs(acts, k)).core.outbox| && Exec(inits[k], ProjActs(acts, k)).core.outbox[i] == e &&
        ApprovedSpec(inits[k], ProjActs(acts, k), i) && SignedInTrace(inits[k], ProjActs(acts, k), i))
    ensures A6b_ArtifactComputesFlatContractOnBytes(art) ==>
      forall e | CommittedEffect(inits[k], ProjActs(acts, k), e) ::
        exists i :: (0 <= i < |Exec(inits[k], ProjActs(acts, k)).core.outbox| && Exec(inits[k], ProjActs(acts, k)).core.outbox[i] == e &&
          FlatResultAgrees(art, inits[k], ProjActs(acts, k), i))
  {
    var P := ProjActs(acts, k);
    MExecIsExecPerCharge(inits, acts, k);
    A2A5Proj(acts, k);
    H1Proj(acts, k);
    SliceSafetyV3_L2_Authentic(inits[k], P);
    if A6b_ArtifactComputesFlatContractOnBytes(art) {
      SliceSafetyV3_L3_Artifact(inits[k], P, art);
    }
  }

  // The same, quantified over all charges (money part).
  lemma MultiLayeredAll(inits: map<string, F.Charge>, acts: seq<MAct>)
    requires KeyedInits(inits) && forall k | k in inits :: InitOk(inits[k])
    requires H1M(acts) && A2M(acts) && A5M(acts)
    ensures forall k | k in inits ::
      k in MExec(FreshStore(inits), acts) &&
      0 <= SumIntents(MExec(FreshStore(inits), acts)[k].outbox) <= inits[k].original &&
      SumIntents(MExec(FreshStore(inits), acts)[k].outbox) == inits[k].remaining - MExec(FreshStore(inits), acts)[k].charge.remaining
  {
    forall k | k in inits
      ensures k in MExec(FreshStore(inits), acts) &&
        0 <= SumIntents(MExec(FreshStore(inits), acts)[k].outbox) <= inits[k].original &&
        SumIntents(MExec(FreshStore(inits), acts)[k].outbox) == inits[k].remaining - MExec(FreshStore(inits), acts)[k].charge.remaining
    {
      MExecIsExecPerChargeKeys(inits, acts);
      MultiLayered(inits, acts, FlatSpecFn, k);
    }
  }
}
