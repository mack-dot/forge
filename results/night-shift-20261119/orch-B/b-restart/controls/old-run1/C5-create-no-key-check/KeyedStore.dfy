// Night shift 2026-11-19, Orchestrator B, task b-restart (G2 + G3). A DRAFT in an evidence folder. NOT approved.
// NOT gate evidence. M1-B stays OPEN. A Dafny-MODEL statement only. NOT a proof about sink.ts, the dispatcher,
// SQLite, a file system or a path.
//
// Repair of review finding D2 (r-integrate): MultiCharge needs WellKeyed (stored charge ids injective over the
// databases) as a HYPOTHESIS; AttackMulti.NotWellKeyedDoubleRefund shows it is load-bearing. Here charge
// CREATION is an action. Create(key, init) is refused unless key == init.chargeId, key is not present, and
// 0 <= init.remaining <= init.original. From the EMPTY map, for every run of Mint/Create/Deliver actions with
// adversary-chosen keys and tokens, WellKeyed is an INVARIANT (KExecWellKeyed), so all MultiChargeSafety
// conclusions hold with NO hypothesis (KeyedL0). Contrast: creation without the key check (UExec) reaches the
// reviewer's double refund from the empty map (UncheckedCreateDoubleRefund).
// G3: KeyedTop, the combined top lemma for a multi-charge store with creation.
// No assume, no axiom, no bodiless lemma in this file.
include "Restart.dfy"
include "src/MultiChargeLayered.dfy"

module KeyedStore {
  import opened SinkCoreV3
  import opened SliceTheoremV3
  import opened MultiCharge
  import MCL = MultiChargeLayered
  import RS = RestartV3

  datatype KAct = KMint(c: Claim, tag: Tag) | KCreate(key: string, init: F.Charge)
                | KDel(key: string, tok: SinkToken, sigOk: bool)

  // The creation check (compilable).
  predicate CreateOk(st: Store, key: string, init: F.Charge)
  {
    key !in st && 0 <= init.remaining <= init.original // CONTROL C5: no key == chargeId check
  }

  function KStep(st: Store, a: KAct): Store
  {
    match a
    case KMint(_, _) => st
    case KCreate(key, init) => if CreateOk(st, key, init) then st[key := Core(init, {}, [])] else st
    case KDel(key, tok, s) => MStep(st, MDelivery(key, tok, s))
  }

  function KExec(acts: seq<KAct>): Store
    decreases |acts|
  {
    if |acts| == 0 then map[] else KStep(KExec(acts[..|acts| - 1]), acts[|acts| - 1])
  }

  // Stored charge ids are injective over the keys (what D2 asks for).
  ghost predicate InjectiveChargeIds(st: Store)
  {
    forall k1, k2 | k1 in st && k2 in st && k1 != k2 :: st[k1].charge.chargeId != st[k2].charge.chargeId
  }

  // ---- G2: WellKeyed is an invariant from the empty map (NO hypothesis) ----
  lemma KStepKeeps(st: Store, a: KAct)
    requires WellKeyed(st)
    ensures WellKeyed(KStep(st, a))
    ensures st.Keys <= KStep(st, a).Keys
  {
    match a
    case KMint(_, _) =>
    case KCreate(key, init) =>
      if CreateOk(st, key, init) {
        InitGood(init);
      }
    case KDel(key, tok, s) =>
      MStepKeeps(st, MDelivery(key, tok, s));
      MStepFrame(st, MDelivery(key, tok, s));
  }

  lemma KExecWellKeyed(acts: seq<KAct>)
    ensures WellKeyed(KExec(acts)) && InjectiveChargeIds(KExec(acts))
    decreases |acts|
  {
    if |acts| > 0 {
      KExecWellKeyed(acts[..|acts| - 1]);
      KStepKeeps(KExec(acts[..|acts| - 1]), acts[|acts| - 1]);
    }
  }

  // KEYED L0 (NO hypothesis): every run of arbitrary creates and deliveries with arbitrary keys from the empty map.
  lemma KeyedL0(acts: seq<KAct>)
    ensures WellKeyed(KExec(acts)) && InjectiveChargeIds(KExec(acts))
    ensures forall k, i | k in KExec(acts) && 0 <= i < |KExec(acts)[k].outbox| :: KExec(acts)[k].outbox[i].chargeId == k
    ensures forall k1, k2, i, j | k1 in KExec(acts) && k2 in KExec(acts) &&
        0 <= i < |KExec(acts)[k1].outbox| && 0 <= j < |KExec(acts)[k2].outbox| && (k1 != k2 || i != j) ::
      KExec(acts)[k1].outbox[i].chargeId != KExec(acts)[k2].outbox[j].chargeId ||
      KExec(acts)[k1].outbox[i].requestId != KExec(acts)[k2].outbox[j].requestId
    ensures forall k | k in KExec(acts) :: KExec(acts)[k].charge.chargeId == k && GoodV3(KExec(acts)[k])
  {
    KExecWellKeyed(acts);
    MCL.GlobalDistinct(KExec(acts));
  }

  // From the keyed store, the MultiChargeSafety conclusions hold for ANY later keyed deliveries (no hypothesis).
  lemma KeyedThenMultiChargeSafety(acts: seq<KAct>, ds: seq<MDelivery>)
    ensures WellKeyed(KExec(acts))
    ensures MRun(KExec(acts), ds).Keys == KExec(acts).Keys && WellKeyed(MRun(KExec(acts), ds))
    ensures forall k1, k2, i, j | k1 in MRun(KExec(acts), ds) && k2 in MRun(KExec(acts), ds) &&
        0 <= i < |MRun(KExec(acts), ds)[k1].outbox| && 0 <= j < |MRun(KExec(acts), ds)[k2].outbox| && (k1 != k2 || i != j) ::
      MRun(KExec(acts), ds)[k1].outbox[i].chargeId != MRun(KExec(acts), ds)[k2].outbox[j].chargeId ||
      MRun(KExec(acts), ds)[k1].outbox[i].requestId != MRun(KExec(acts), ds)[k2].outbox[j].requestId
  {
    KExecWellKeyed(acts);
    MultiChargeSafety(KExec(acts), ds);
  }

  // Creation refusals (concrete).
  lemma CreateRefusals()
    ensures KExec([KCreate("db_a", F.Charge("ch_1", 100, 100, true))]) == map[]
    ensures var st := KExec([KCreate("ch_1", F.Charge("ch_1", 100, 100, true)), KCreate("ch_1", F.Charge("ch_1", 100, 50, true))]);
            st.Keys == {"ch_1"} && st["ch_1"] == Core(F.Charge("ch_1", 100, 100, true), {}, [])
    ensures KExec([KCreate("ch_1", F.Charge("ch_1", 100, 101, true))]) == map[]
  {
    var a := [KCreate("ch_1", F.Charge("ch_1", 100, 100, true)), KCreate("ch_1", F.Charge("ch_1", 100, 50, true))];
    assert a[..1] == [a[0]] && a[..1][..0] == [];
    var b := [KCreate("db_a", F.Charge("ch_1", 100, 100, true))];
    assert b[..0] == [];
    var c := [KCreate("ch_1", F.Charge("ch_1", 100, 101, true))];
    assert c[..0] == [];
  }

  // ---- CONTRAST: creation WITHOUT the key check (only "key not present", e.g. a meta row per database file) ----
  function UStep(st: Store, a: KAct): Store
  {
    match a
    case KMint(_, _) => st
    case KCreate(key, init) => if key !in st then st[key := Core(init, {}, [])] else st
    case KDel(key, tok, s) => MStep(st, MDelivery(key, tok, s))
  }

  function UExec(acts: seq<KAct>): Store
    decreases |acts|
  {
    if |acts| == 0 then map[] else UStep(UExec(acts[..|acts| - 1]), acts[|acts| - 1])
  }

  function DupToken(): SinkToken
  {
    SinkToken(PINNED_SPEC, PINNED_CHK, F.Charge("ch_1", 100, 100, true), "rq_x", F.Charge("ch_1", 100, 0, true),
              R.Intent("ch_1", "rq_x", 100, "duplicate_charge"), "s")
  }

  function DupActs(): seq<KAct>
  {
    [KCreate("db_a", F.Charge("ch_1", 100, 100, true)), KCreate("db_b", F.Charge("ch_1", 100, 100, true)),
     KDel("db_a", DupToken(), true), KDel("db_b", DupToken(), true)]
  }

  // From the EMPTY map, unchecked creation reaches two stores of ch_1; one token commits in both:
  // two effects with the same (chargeId, requestId); total 200 > original 100. The checked KExec refuses both
  // creations (keys differ from the charge id), so nothing commits.
  lemma UncheckedCreateDoubleRefund()
    ensures var st := UExec(DupActs());
            "db_a" in st && "db_b" in st && st["db_a"].outbox == [DupToken().intent] &&
            st["db_b"].outbox == [DupToken().intent] && !InjectiveChargeIds(st) &&
            st["db_a"].outbox[0].amount + st["db_b"].outbox[0].amount > 100
    ensures KExec(DupActs()) == map[]
  {
    var A := DupActs();
    assert A[..3][..2] == A[..2] && A[..2][..1] == A[..1] && A[..1][..0] == [];
    assert A[..1] == [A[0]];
    assert UExec(A[..1][..0]) == map[];
    var u1 := UExec(A[..1]);
    assert u1 == UStep(map[], A[0]);
    assert u1 == map["db_a" := Core(F.Charge("ch_1", 100, 100, true), {}, [])];
    var u2 := UExec(A[..2]);
    assert u2 == u1["db_b" := Core(F.Charge("ch_1", 100, 100, true), {}, [])];
    var u3 := UExec(A[..3]);
    assert u3 == MStep(u2, MDelivery("db_a", DupToken(), true));
    assert u3["db_b"] == u2["db_b"];
    var u4 := UExec(A);
    assert u4 == MStep(u3, MDelivery("db_b", DupToken(), true));
    assert u4["db_a"] == u3["db_a"];
    assert KExec(A[..1]) == map[];
    assert KExec(A[..2]) == map[];
    assert KExec(A[..3]) == map[];
  }

  // =============================================================================================
  // G3: the layered statement for a multi-charge store WITH creation.
  // Per charge k: the deliveries routed to k AFTER k's creation, and ALL mints (the issuer's signed set is
  // global and persists), form a single-charge trace from the created initial charge.
  function LiftK(st: Store, a: KAct, k: string): seq<Act>
  {
    match a
    case KMint(c, t) => [MintAct(c, t)]
    case KCreate(_, _) => []
    case KDel(key, tok, s) => if key == k && k in st then [Deliver(tok, s)] else []
  }

  function KProj(acts: seq<KAct>, k: string): seq<Act>
    decreases |acts|
  {
    if |acts| == 0 then [] else KProj(acts[..|acts| - 1], k) + LiftK(KExec(acts[..|acts| - 1]), acts[|acts| - 1], k)
  }

  // The initial charge with which k was created (a dummy before creation).
  function InitOfK(acts: seq<KAct>, k: string): F.Charge
    decreases |acts|
  {
    if |acts| == 0 then F.Charge(k, 0, 0, false)
    else
      var a := acts[|acts| - 1];
      if a.KCreate? && a.key == k && CreateOk(KExec(acts[..|acts| - 1]), a.key, a.init) then a.init
      else InitOfK(acts[..|acts| - 1], k)
  }

  lemma ExecMintsOnly(init: State, P: seq<Act>)
    requires forall i | 0 <= i < |P| :: P[i].MintAct?
    ensures Exec(init, P).core == Core(init, {}, [])
  {
    RS.ExecAppend(init, [], P);
    assert [] + P == P;
    RS.ExecFromCore(Exec(init, []), P);
    RS.MintsCoreRun(Core(init, {}, []), P);
  }

  lemma KPerCharge(acts: seq<KAct>, k: string)
    ensures k !in KExec(acts) ==> forall i | 0 <= i < |KProj(acts, k)| :: KProj(acts, k)[i].MintAct?
    ensures k in KExec(acts) ==>
      InitOfK(acts, k).chargeId == k && InitOk(InitOfK(acts, k)) &&
      KExec(acts)[k] == Exec(InitOfK(acts, k), KProj(acts, k)).core
    decreases |acts|
  {
    if |acts| > 0 {
      var n := |acts|;
      var p := acts[..n - 1];
      var a := acts[n - 1];
      var st := KExec(p);
      KPerCharge(p, k);
      var P := KProj(p, k);
      var Q := KProj(acts, k);
      assert Q == P + LiftK(st, a, k);
      KExecWellKeyed(p);
      KStepKeeps(st, a);
      match a
      case KMint(c, t) =>
        assert KExec(acts) == st;
        if k in st {
          MCL.ExecSnoc(InitOfK(p, k), P, MintAct(c, t));
        }
      case KCreate(key, init) =>
        assert Q == P;
        if key == k && CreateOk(st, key, init) {
          ExecMintsOnly(init, P);
        }
      case KDel(key, tok, s) =>
        MStepFrame(st, MDelivery(key, tok, s));
        if key == k && k in st {
          MCL.ExecSnoc(InitOfK(p, k), P, Deliver(tok, s));
        } else {
          assert Q == P;
        }
    }
  }

  // ---- the global hypotheses over the keyed trace ----
  ghost predicate H1K(acts: seq<KAct>)
  {
    forall n | 0 <= n < |acts| && acts[n].KDel? ::
      VerifyTag(ClaimOf(acts[n].tok), acts[n].tok.sig) ==>
        exists j :: 0 <= j < n && acts[j].KMint? && acts[j].c == ClaimOf(acts[n].tok)
  }

  ghost predicate A2K(acts: seq<KAct>)
  {
    forall n | 0 <= n < |acts| && acts[n].KMint? && Ours(acts[n].c) ::
      exists pre: F.Charge, t: F.Transition :: F.Authorizes(pre, t) && acts[n].c == CheckedClaim(pre, t)
  }

  ghost predicate A5K(acts: seq<KAct>)
  {
    forall n | 0 <= n < |acts| && acts[n].KDel? :: A5_VerifierMatches(acts[n].tok, acts[n].sigOk)
  }

  lemma PrefixK(acts: seq<KAct>)
    requires |acts| > 0
    ensures A2K(acts) ==> A2K(acts[..|acts| - 1])
    ensures A5K(acts) ==> A5K(acts[..|acts| - 1])
    ensures H1K(acts) ==> H1K(acts[..|acts| - 1])
  {
    var p := acts[..|acts| - 1];
    assert forall m | 0 <= m < |p| :: p[m] == acts[m];
    if H1K(acts) {
      forall n | 0 <= n < |p| && p[n].KDel? && VerifyTag(ClaimOf(p[n].tok), p[n].tok.sig)
        ensures exists j :: 0 <= j < n && p[j].KMint? && p[j].c == ClaimOf(p[n].tok)
      {
        var j :| 0 <= j < n && acts[j].KMint? && acts[j].c == ClaimOf(acts[n].tok);
        assert p[j] == acts[j];
      }
    }
  }

  lemma A2A5KProj(acts: seq<KAct>, k: string)
    requires A2K(acts) && A5K(acts)
    ensures A2_MintOnlyOnCheck(KProj(acts, k)) && A5_VerifierMatchesAtEachDelivery(KProj(acts, k))
    decreases |acts|
  {
    if |acts| > 0 {
      var n := |acts|;
      var p := acts[..n - 1];
      PrefixK(acts);
      A2A5KProj(p, k);
      var P := KProj(p, k);
      var Lx := LiftK(KExec(p), acts[n - 1], k);
      var Q := KProj(acts, k);
      assert Q == P + Lx;
      forall i | 0 <= i < |Q| && Q[i].MintAct? && Ours(Q[i].c)
        ensures exists pre: F.Charge, t: F.Transition :: F.Authorizes(pre, t) && Q[i].c == CheckedClaim(pre, t)
      {
        if i < |P| {
          MCL.ProjPrefix(P, Lx, i);
        } else {
          assert acts[n - 1].KMint? && Q[i].c == acts[n - 1].c;
        }
      }
      forall i | 0 <= i < |Q| && Q[i].Deliver?
        ensures A5_VerifierMatches(Q[i].tok, Q[i].sigOk)
      {
        if i < |P| {
          MCL.ProjPrefix(P, Lx, i);
        } else {
          assert acts[n - 1].KDel? && Q[i].tok == acts[n - 1].tok && Q[i].sigOk == acts[n - 1].sigOk;
        }
      }
    }
  }

  lemma MintInKProj(acts: seq<KAct>, j: int, k: string)
    requires 0 <= j < |acts| && acts[j].KMint?
    ensures exists m :: 0 <= m < |KProj(acts, k)| && KProj(acts, k)[m] == MintAct(acts[j].c, acts[j].tag)
    decreases |acts|
  {
    var n := |acts|;
    var p := acts[..n - 1];
    var P := KProj(p, k);
    var Lx := LiftK(KExec(p), acts[n - 1], k);
    assert KProj(acts, k) == P + Lx;
    if j == n - 1 {
      assert KProj(acts, k)[|P|] == MintAct(acts[j].c, acts[j].tag);
    } else {
      assert p[j] == acts[j];
      MintInKProj(p, j, k);
      var m :| 0 <= m < |P| && P[m] == MintAct(p[j].c, p[j].tag);
      MCL.ProjPrefix(P, Lx, m);
    }
  }

  lemma H1KProj(acts: seq<KAct>, k: string)
    requires H1K(acts)
    ensures H1_SignatureAuthenticity(KProj(acts, k))
    decreases |acts|
  {
    if |acts| > 0 {
      var n := |acts|;
      var p := acts[..n - 1];
      PrefixK(acts);
      H1KProj(p, k);
      var P := KProj(p, k);
      var Lx := LiftK(KExec(p), acts[n - 1], k);
      var Q := KProj(acts, k);
      assert Q == P + Lx;
      forall i | 0 <= i < |Q| && Q[i].Deliver? && VerifyTag(ClaimOf(Q[i].tok), Q[i].tok.sig)
        ensures SignedBefore(Q, i, ClaimOf(Q[i].tok))
      {
        if i < |P| {
          MCL.ProjPrefix(P, Lx, i);
          assert SignedBefore(P, i, ClaimOf(P[i].tok));
          var j :| 0 <= j < i && j < |P| && P[j].MintAct? && P[j].c == ClaimOf(P[i].tok);
          MCL.ProjPrefix(P, Lx, j);
        } else {
          assert acts[n - 1].KDel? && Q[i].tok == acts[n - 1].tok && i == |P|;
          var j :| 0 <= j < n - 1 && acts[j].KMint? && acts[j].c == ClaimOf(acts[n - 1].tok);
          assert p[j] == acts[j];
          MintInKProj(p, j, k);
          var m :| 0 <= m < |P| && P[m] == MintAct(p[j].c, p[j].tag);
          MCL.ProjPrefix(P, Lx, m);
          assert Q[m].MintAct? && Q[m].c == ClaimOf(Q[i].tok);
        }
      }
    }
  }

  // THE G3 TOP LEMMA. A multi-charge store with checked creation, from the EMPTY map, any keys.
  // NO hypothesis: WellKeyed, injective charge ids, every effect carries its store's charge id, global
  // uniqueness of (chargeId, requestId). Per charge k, under H1K + A2K + A5K: the effects for charge k across ALL
  // outboxes are exactly those of k's own outbox; their sum is <= the original of k and equals the decrease of
  // k's remaining; every effect of k is approved by the spec and was signed.
  lemma KeyedTop(acts: seq<KAct>, k: string)
    requires k in KExec(acts)
    requires H1K(acts) && A2K(acts) && A5K(acts)
    ensures WellKeyed(KExec(acts)) && InjectiveChargeIds(KExec(acts))
    ensures forall k2, i | k2 in KExec(acts) && 0 <= i < |KExec(acts)[k2].outbox| && KExec(acts)[k2].outbox[i].chargeId == k ::
      k2 == k
    ensures KExec(acts)[k] == Exec(InitOfK(acts, k), KProj(acts, k)).core
    ensures InitOfK(acts, k).chargeId == k && KExec(acts)[k].charge.original == InitOfK(acts, k).original
    ensures 0 <= KExec(acts)[k].charge.remaining <= KExec(acts)[k].charge.original
    ensures 0 <= SumIntents(KExec(acts)[k].outbox) <= KExec(acts)[k].charge.original
    ensures SumIntents(KExec(acts)[k].outbox) == InitOfK(acts, k).remaining - KExec(acts)[k].charge.remaining
    ensures forall e | e in KExec(acts)[k].outbox ::
      exists i :: (0 <= i < |Exec(InitOfK(acts, k), KProj(acts, k)).core.outbox| &&
        Exec(InitOfK(acts, k), KProj(acts, k)).core.outbox[i] == e &&
        ApprovedSpec(InitOfK(acts, k), KProj(acts, k), i) && SignedInTrace(InitOfK(acts, k), KProj(acts, k), i))
  {
    var st := KExec(acts);
    var init := InitOfK(acts, k);
    var P := KProj(acts, k);
    KeyedL0(acts);
    KPerCharge(acts, k);
    assert st[k] == Exec(init, P).core;
    forall k2, i | k2 in st && 0 <= i < |st[k2].outbox| && st[k2].outbox[i].chargeId == k
      ensures k2 == k
    {
      assert st[k2].outbox[i].chargeId == k2;
    }
    A2A5KProj(acts, k);
    H1KProj(acts, k);
    KeyedTopMoney(init, P);
  }

  lemma KeyedTopMoney(init: State, P: seq<Act>)
    requires InitOk(init)
    requires A2_MintOnlyOnCheck(P) && A5_VerifierMatchesAtEachDelivery(P) && H1_SignatureAuthenticity(P)
    ensures Exec(init, P).core.charge.original == init.original
    ensures 0 <= Exec(init, P).core.charge.remaining <= Exec(init, P).core.charge.original
    ensures 0 <= SumIntents(Exec(init, P).core.outbox) <= Exec(init, P).core.charge.original
    ensures SumIntents(Exec(init, P).core.outbox) == init.remaining - Exec(init, P).core.charge.remaining
    ensures forall e | e in Exec(init, P).core.outbox ::
      exists i :: (0 <= i < |Exec(init, P).core.outbox| && Exec(init, P).core.outbox[i] == e &&
        ApprovedSpec(init, P, i) && SignedInTrace(init, P, i))
  {
    var r := Exec(init, P);
    ExecRel(init, P);
    ExecInvV3(init, P);
    RefundSliceShapeV3(init, r.core, r.s, r.toks);
    forall e | e in r.core.outbox
      ensures exists i :: (0 <= i < |r.core.outbox| && r.core.outbox[i] == e &&
        ApprovedSpec(init, P, i) && SignedInTrace(init, P, i))
    {
      var i :| 0 <= i < |r.core.outbox| && r.core.outbox[i] == e;
      PerEntryApproved(init, P, i);
    }
  }
}

// =================================================================================================
// Non-vacuity of KeyedTop under the TOTAL verifier reading of SliceWitnessV3 (conditional on SigReading()).
module KeyedWitness {
  import opened SinkCoreV3
  import opened SliceTheoremV3
  import opened SliceWitnessV3
  import opened KeyedStore
  import opened MultiCharge

  // Create ch_1 (W_PRE); a foreign-key create and a second create of ch_1 are refused; a zero-amount and a
  // positive effect commit; a replay is rejected.
  function KActs(): seq<KAct>
  {
    [KCreate("ch_1", W_PRE), KCreate("db_x", W_PRE), KCreate("ch_1", W_POST),
     KMint(ClaimOf(V0_TOK), V0_TOK.sig), KDel("ch_1", V0_TOK, true),
     KMint(ClaimOf(V_TOK), V_TOK.sig), KDel("ch_1", V_TOK, true),
     KDel("ch_1", V_TOK, true)]
  }

  lemma KTrace()
    ensures KExec(KActs()).Keys == {"ch_1"}
    ensures KExec(KActs())["ch_1"] == Core(W_POST, {"rq_0", "rq_1"}, [W0_INTENT, W_INTENT])
  {
    var A := KActs();
    assert A[..7][..6] == A[..6] && A[..6][..5] == A[..5] && A[..5][..4] == A[..4];
    assert A[..4][..3] == A[..3] && A[..3][..2] == A[..2] && A[..2][..1] == A[..1] && A[..1][..0] == [];
    var c0 := Core(W_PRE, {}, []);
    assert KExec(A[..1]) == map["ch_1" := c0];
    assert KExec(A[..2]) == map["ch_1" := c0];
    assert KExec(A[..3]) == map["ch_1" := c0];
    assert KExec(A[..4]) == map["ch_1" := c0];
    var c1 := Core(W_PRE, {"rq_0"}, [W0_INTENT]);
    assert Step(c0, V0_TOK, true).core == c1;
    assert KExec(A[..5]) == KStep(KExec(A[..4]), A[4]);
    assert KExec(A[..5]) == MStep(map["ch_1" := c0], MDelivery("ch_1", V0_TOK, true));
    assert KExec(A[..5]) == map["ch_1" := c1];
    assert KExec(A[..6]) == map["ch_1" := c1];
    assert "rq_1"[3] != "rq_0"[3];
    var c2 := Core(W_POST, {"rq_0", "rq_1"}, [W0_INTENT, W_INTENT]);
    assert Step(c1, V_TOK, true).core == c2;
    assert KExec(A[..7]) == KStep(KExec(A[..6]), A[6]);
    assert KExec(A[..7]) == map["ch_1" := c2];
    assert "rq_1" in c2.settled;
  }

  lemma KHyps()
    requires SigReading()
    ensures H1K(KActs()) && A2K(KActs()) && A5K(KActs())
  {
    var A := KActs();
    SigOf(V0_TOK);
    SigOf(V_TOK);
    assert VerifyTag(ClaimOf(V0_TOK), V0_TOK.sig);
    assert VerifyTag(ClaimOf(V_TOK), V_TOK.sig);
    var t0 := F.Transition(F.Request("rq_0", 0, "duplicate_charge"), W_PRE, W0_INTENT);
    var t1 := F.Transition(F.Request("rq_1", 40, "duplicate_charge"), W_POST, W_INTENT);
    assert W_PRE.(remaining := W_PRE.remaining - 0) == W_PRE;
    assert "duplicate_charge" in {"duplicate_charge", "service_not_delivered", "returned_item"};
    assert F.Authorizes(W_PRE, t0) && ClaimOf(V0_TOK) == CheckedClaim(W_PRE, t0);
    assert F.Authorizes(W_PRE, t1) && ClaimOf(V_TOK) == CheckedClaim(W_PRE, t1);
    forall n | 0 <= n < |A| && A[n].KMint? && Ours(A[n].c)
      ensures exists pre: F.Charge, t: F.Transition :: F.Authorizes(pre, t) && A[n].c == CheckedClaim(pre, t)
    {
      if n == 3 {
        assert F.Authorizes(W_PRE, t0) && A[n].c == CheckedClaim(W_PRE, t0);
      } else {
        assert n == 5;
        assert F.Authorizes(W_PRE, t1) && A[n].c == CheckedClaim(W_PRE, t1);
      }
    }
    forall n | 0 <= n < |A| && A[n].KDel?
      ensures A5_VerifierMatches(A[n].tok, A[n].sigOk)
    {
      assert n == 4 || n == 6 || n == 7;
    }
    forall n | 0 <= n < |A| && A[n].KDel? && VerifyTag(ClaimOf(A[n].tok), A[n].tok.sig)
      ensures exists j :: 0 <= j < n && A[j].KMint? && A[j].c == ClaimOf(A[n].tok)
    {
      if n == 4 {
        assert A[3].KMint? && A[3].c == ClaimOf(A[n].tok);
      } else {
        assert A[5].KMint? && A[5].c == ClaimOf(A[n].tok);
      }
    }
  }

  lemma KeyedWitnessMain()
    requires SigReading()
    ensures H1K(KActs()) && A2K(KActs()) && A5K(KActs())
    ensures KExec(KActs()).Keys == {"ch_1"}
    ensures KExec(KActs())["ch_1"].outbox == [W0_INTENT, W_INTENT] && W0_INTENT.amount == 0 && W_INTENT.amount == 40
    ensures SumIntents(KExec(KActs())["ch_1"].outbox) <= KExec(KActs())["ch_1"].charge.original
  {
    KHyps();
    KTrace();
    KeyedTop(KActs(), "ch_1");
  }
}
