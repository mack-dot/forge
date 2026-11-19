// Night shift 2026-11-19, Orchestrator B, review task r-restart. ADVERSARIAL lemmas against b-restart.
// A Dafny-MODEL statement only. No assume, no axiom, no bodiless lemma.
include "KeyedStore.dfy"

module AttackRestart {
  import opened SinkCoreV3
  import opened SliceTheoremV3
  import opened SliceWitnessV3
  import opened RestartV3
  import opened KeyedStore
  import opened MultiCharge
  import RestartWitness

  // ---- X1: AuditFullSpec's money bound is RELATIVE TO THE init INPUT. A forged init (original 1000) plus a
  // forged row (tag "forged", stored check result true) passes AuditFullSpec; 500 is refunded on a charge whose
  // true original is 100. With the true init the same ledger is refused. init authenticity is an ASSUMPTION.
  const FI: F.Charge := F.Charge("ch_1", 1000, 1000, true)
  const TRUE_INIT: F.Charge := F.Charge("ch_1", 100, 100, true)
  const FI_TOK: SinkToken := SinkToken(PINNED_SPEC, PINNED_CHK, FI, "rq_f", FI.(remaining := 500),
                                       R.Intent("ch_1", "rq_f", 500, "duplicate_charge"), "forged")
  function FICore(): Core { Core(FI.(remaining := 500), {"rq_f"}, [FI_TOK.intent]) }

  lemma ForgedInitPassesSpecAudit()
    ensures AuditFullSpec(FI, FICore(), [Delivery(FI_TOK, true)])
    ensures SumIntents(FICore().outbox) == 500 > TRUE_INIT.original
    ensures !AuditFullSpec(TRUE_INIT, FICore(), [Delivery(FI_TOK, true)])
  {
    var l := [Delivery(FI_TOK, true)];
    assert l[..0] == [];
    assert "duplicate_charge" in {"duplicate_charge", "service_not_delivered", "returned_item"};
    assert RowAuthorized(FI_TOK);
    SumOne(FI_TOK.intent);
    assert Step(Core(TRUE_INIT, {}, []), FI_TOK, true).out == Rejected(PreStateMismatch);
    assert Replay(TRUE_INIT, l) == (false, Core(TRUE_INIT, {}, []));
  }

  // ---- X2: ROLLBACK. A store rewound to an honest prefix (the last row and its effect dropped) passes
  // AuditFull and AuditFullSpec; the dropped token then commits AGAIN. The real world sees rq_1's effect twice:
  // 40 + 40 = 80 > 60 = the remaining amount at the start. No audit of the store alone detects it.
  function Rewound(): Core { Core(W_PRE, {"rq_0"}, [W0_INTENT]) }

  lemma RollbackPassesAuditAndReplays()
    ensures Step(Rewound(), V_TOK, true).out.Committed?          // honest history: V_TOK committed here once
    ensures Step(Rewound(), V_TOK, true).core == Core(W_POST, {"rq_0", "rq_1"}, [W0_INTENT, W_INTENT])
    ensures AuditFull(W_PRE, Rewound(), LedgerOf([V0_TOK]))
    ensures AuditFullSpec(W_PRE, Rewound(), LedgerOf([V0_TOK]))
    ensures W_INTENT.amount + W_INTENT.amount > W_PRE.remaining
  {
    var l := LedgerOf([V0_TOK]);
    assert l == [Delivery(V0_TOK, true)];
    assert l[..0] == [];
    assert W_PRE.(remaining := W_PRE.remaining - 0) == W_PRE;
    assert "duplicate_charge" in {"duplicate_charge", "service_not_delivered", "returned_item"};
    assert RowAuthorized(V0_TOK);
    assert "rq_1"[3] != "rq_0"[3];
  }

  // Under all signature hypotheses the rewound core is even Sound (it is a reachable honest core).
  lemma RewoundIsSound()
    requires SigReading()
    ensures Sound(W_PRE, Rewound())
  {
    var a0 := [MintAct(ClaimOf(V0_TOK), V0_TOK.sig), Deliver(V0_TOK, true)];
    SigOf(V0_TOK);
    assert VerifyTag(ClaimOf(V0_TOK), V0_TOK.sig);
    var t0 := F.Transition(F.Request("rq_0", 0, "duplicate_charge"), W_PRE, W0_INTENT);
    assert W_PRE.(remaining := W_PRE.remaining - 0) == W_PRE;
    assert "duplicate_charge" in {"duplicate_charge", "service_not_delivered", "returned_item"};
    assert F.Authorizes(W_PRE, t0) && ClaimOf(V0_TOK) == CheckedClaim(W_PRE, t0);
    forall k | 0 <= k < |a0| && a0[k].MintAct? && Ours(a0[k].c)
      ensures exists pre: F.Charge, t: F.Transition :: F.Authorizes(pre, t) && a0[k].c == CheckedClaim(pre, t)
    {
      assert k == 0;
      assert F.Authorizes(W_PRE, t0) && a0[k].c == CheckedClaim(W_PRE, t0);
    }
    assert a0[0].MintAct? && a0[0].c == ClaimOf(V0_TOK);
    assert SignedBefore(a0, 1, ClaimOf(V0_TOK));
    assert HypsOn(a0);
    assert a0[..1] == [a0[0]] && a0[..1][..0] == [];
    assert Exec(W_PRE, a0[..1]).core == Core(W_PRE, {}, []);
    assert Exec(W_PRE, a0).core == Rewound();
  }

  // ---- X3: LOSSY RESTART (settled set lost, charge and outbox kept). ----
  // (a) A positive replay is still refused by the pre-state check (the state moved on).
  // (b) A ZERO-amount replay commits again: a duplicate (chargeId, requestId) effect.
  // (c) No audit accepts the lossy core: settled is derived by replay (ReplayShape), and it is not Sound.
  function LossyAfterPositive(): Core { Core(W_POST, {}, [W0_INTENT, W_INTENT]) }
  function LossyAfterZero(): Core { Core(W_PRE, {}, [W0_INTENT]) }

  lemma LossyRestart()
    ensures Step(LossyAfterPositive(), V_TOK, true).out == Rejected(PreStateMismatch)
    ensures Step(LossyAfterPositive(), V0_TOK, true).out == Rejected(PreStateMismatch)
    ensures Step(LossyAfterZero(), V0_TOK, true).out.Committed?
    ensures Step(LossyAfterZero(), V0_TOK, true).core.outbox == [W0_INTENT, W0_INTENT]
  {
  }

  lemma ReplayShape(init: F.Charge, l: seq<Delivery>)
    requires Replay(init, l).0
    ensures |Replay(init, l).1.outbox| == |l|
    ensures |l| > 0 ==> Replay(init, l).1.settled != {}
    decreases |l|
  {
    if |l| > 0 {
      var p := l[..|l| - 1];
      ReplayShape(init, p);
      var d := l[|l| - 1];
      StepExact(Replay(init, p).1, d.tok, d.sigOk);
      assert d.tok.requestId in Replay(init, l).1.settled;
    }
  }

  lemma LossyRefused(init: F.Charge, l: seq<Delivery>)
    ensures !AuditFull(init, LossyAfterZero(), l)
    ensures !AuditFull(init, LossyAfterPositive(), l)
  {
    if AuditFull(init, LossyAfterZero(), l) { ReplayShape(init, l); }
    if AuditFull(init, LossyAfterPositive(), l) { ReplayShape(init, l); }
  }

  lemma LossyNotSound(init: State)
    ensures !Sound(init, LossyAfterZero())
  {
    if Sound(init, LossyAfterZero()) {
      var a0 :| LossyAfterZero() == Exec(init, a0).core && HypsOn(a0);
      AuditComplete(init, a0);
      LossyRefused(init, LedgerOf(Exec(init, a0).toks));
    }
  }

  // ---- X4: zero amount after a restart: a zero-amount effect commits on the restarted core Core1. ----
  const Z3_TOK: SinkToken := SinkToken(PINNED_SPEC, PINNED_CHK, F.Charge("ch_1", 100, 15, true), "rq_3",
                                       F.Charge("ch_1", 100, 15, true), R.Intent("ch_1", "rq_3", 0, "returned_item"), "sig_rq_3")
  lemma ZeroAfterRestart()
    ensures Step(RestartWitness.Core1(), Z3_TOK, true).out.Committed?
  {
    assert "rq_3"[3] != "rq_0"[3] && "rq_3"[3] != "rq_1"[3] && "rq_3"[3] != "rq_2"[3];
  }

  // ---- X5: the reviewer's NotWellKeyed start store is NOT reachable by KExec (any run). ----
  function DupStoreK(): Store
  {
    map["db_a" := Core(F.Charge("ch_1", 100, 100, true), {}, []), "db_b" := Core(F.Charge("ch_1", 100, 100, true), {}, [])]
  }

  lemma DupStoreUnreachable(acts: seq<KAct>)
    ensures KExec(acts) != DupStoreK()
  {
    KExecWellKeyed(acts);
    if KExec(acts) == DupStoreK() {
      assert "db_a" in KExec(acts) && "db_b" in KExec(acts);
      assert KExec(acts)["db_a"].charge.chargeId == KExec(acts)["db_b"].charge.chargeId;
    }
  }

  // ---- X6: DELETE + RE-CREATE. KStep has no delete. With a delete (a removed database file), "key not
  // present" is met again; the same signed token commits twice for ch_1: 40 + 40 = 80 > 60. ----
  datatype DAct = DK(a: KAct) | DDelete(key: string)

  function DStep(st: Store, a: DAct): Store
  {
    match a
    case DK(x) => KStep(st, x)
    case DDelete(key) => st - {key}
  }

  lemma DeleteRecreateDoubleRefund()
    ensures var s1 := KStep(map[], KCreate("ch_1", W_PRE));
            var s2 := KStep(s1, KMint(ClaimOf(V_TOK), V_TOK.sig));
            var s3 := KStep(s2, KDel("ch_1", V_TOK, true));
            var s4 := DStep(s3, DDelete("ch_1"));
            var s5 := KStep(s4, KCreate("ch_1", W_PRE));
            var s6 := KStep(s5, KDel("ch_1", V_TOK, true));
            s3["ch_1"].outbox == [W_INTENT] && s6["ch_1"].outbox == [W_INTENT] &&
            W_INTENT.amount + W_INTENT.amount > W_PRE.remaining
    ensures SigReading() ==> VerifyTag(ClaimOf(V_TOK), V_TOK.sig)
  {
    if SigReading() { SigOf(V_TOK); }
  }
}
