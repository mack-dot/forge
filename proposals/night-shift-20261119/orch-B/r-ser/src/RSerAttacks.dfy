// Night shift 2026-11-19, Orchestrator B, review r-ser. Adversarial checks of b-ser/RepairedBytes.dfy. A DRAFT.
// No assume, no axiom, no bodiless lemma, no {:extern}, no expect in this file.
//  1. B6Control: drop B6 => a delivered token with intent.amount = -1 has the SAME RealSer bytes as a minted
//     zero-amount claim (IntentOf clamps negatives with Nat). Every other checkable hypothesis holds; the sink
//     commits; the money conclusion of SliceSafetyV2BytesRepaired is false. So B6 is necessary in the model.
//  2. IssueNotParseable: F.Authorizes holds for a claim that is NOT ParseableClaim (U+0000 in chargeId).
//     IssueBytes returns Some for it. So IssueBytes does not give H3d.
//  3. AuthorizedIsMoneyClaim: for an authorized transition the money and request-structure conjuncts of
//     ParseableClaim hold (from F.Authorizes alone).
//  4. ClaimInjectiveMoneyOnly: ClaimInjective without the Text conjuncts (they are not used).
//  5. MintFromIssue: the exact extra hypotheses that turn "the signed bytes are an IssueBytes output" into A2.
include "RepairedBytes.dfy"

module RSerAttacks {
  import opened SinkCore
  import opened SliceTheorem
  import opened SliceTheoremV2
  import opened SliceTheoremV2B
  import SW = SliceWitness
  import SM = SerModel
  import opened RepairedBytes

  // ---------------------------------------------------------------- 1. B6 is necessary
  const N_INTENT: R.RefundIntent := R.Intent("ch_1", "rq_0", -1, "duplicate_charge")
  const N_TOK: SinkToken := Z_TOK.(intent := N_INTENT)
  function NActs(): seq<Act>
  {
    [MintAct(ClaimOf(Z_TOK), TagW(Z_TOK)), Deliver(N_TOK.(sig := TagW(Z_TOK)), true)]
  }
  lemma NSameBody()
    ensures BodyOfClaim(HW, IdC, ClaimOf(N_TOK)) == BodyOfClaim(HW, IdC, ClaimOf(Z_TOK))
  {}
  lemma NSameBytes(sg: Tag)
    ensures RebuildW(N_TOK.(sig := sg)) == RebuildW(Z_TOK)
  {
    assert ClaimOf(N_TOK.(sig := sg)) == ClaimOf(N_TOK);
    NSameBody();
    RealSerOfSameBody(HW, IdC, ClaimOf(N_TOK), ClaimOf(Z_TOK));
  }
  lemma NNotParseable()
    ensures !ParseableTok(N_TOK.(sig := TagW(Z_TOK)))
  { reveal ParseableTok(); }

  lemma NA2()
    ensures A2_MintOnlyOnCheck(NActs())
  {
    var acts := NActs();
    assert F.Authorizes(SW.W_PRE, SW.CheckedTransition(Z_TOK)) by {
      assert SW.W_PRE.(remaining := SW.W_PRE.remaining - 0) == SW.W_PRE;
    }
    assert ClaimOf(Z_TOK) == CheckedClaim(Z_TOK.pre, SW.CheckedTransition(Z_TOK));
    forall k | 0 <= k < |acts| && acts[k].MintAct? && Ours(acts[k].c)
      ensures exists pre: F.Charge, t2: F.Transition :: F.Authorizes(pre, t2) && acts[k].c == CheckedClaim(pre, t2)
    {
      assert k == 0;
      assert F.Authorizes(SW.W_PRE, SW.CheckedTransition(Z_TOK)) && acts[k].c == CheckedClaim(Z_TOK.pre, SW.CheckedTransition(Z_TOK));
    }
  }
  lemma NBytes()
    ensures H3b_SinkRebuildsSignedBytes(RealSer(HW, IdC), RebuildW, NActs())
    ensures H1B_ByteUnforgeability(RealSer(HW, IdC), TotalVB, RebuildW, NActs())
    ensures B5_ByteVerifierMatchesAtEachDelivery(TotalVB, RebuildW, NActs())
  {
    var acts := NActs();
    var ser := RealSer(HW, IdC);
    NSameBytes(TagW(Z_TOK));
    TagWDef(Z_TOK);
    forall k | 0 <= k < |acts| && acts[k].Deliver?
      ensures acts[k].sigOk == TotalVB(RebuildW(acts[k].tok), acts[k].tok.sig)
    { assert k == 1; }
    forall k | 0 <= k < |acts| && acts[k].Deliver? && TotalVB(RebuildW(acts[k].tok), acts[k].tok.sig)
      ensures BytesSignedBefore(ser, acts, k, RebuildW(acts[k].tok))
    {
      assert k == 1;
      assert acts[0].MintAct? && ser(acts[0].c) == RebuildW(acts[k].tok);
    }
  }
  lemma NParseMints()
    ensures H3d_MintsParseable(NActs())
  {
    var acts := NActs();
    PT_Z();
    ParseableTokClaim(Z_TOK);
    forall j | 0 <= j < |acts| && acts[j].MintAct? ensures ParseableClaim(acts[j].c) { assert j == 0; }
  }
  lemma NA4()
    ensures A4_NoCollisionInRun(HW, IdC, NActs())
  {
    var acts := NActs();
    forall j, k | 0 <= j < |acts| && 0 <= k < |acts| && acts[j].MintAct? && acts[k].Deliver?
      ensures (HW(acts[j].c.pre) == HW(acts[k].tok.pre) ==> acts[j].c.pre == acts[k].tok.pre)
      ensures (IdC(acts[j].c.specId) == IdC(acts[k].tok.specId) ==> acts[j].c.specId == acts[k].tok.specId)
      ensures (IdC(acts[j].c.checkerId) == IdC(acts[k].tok.checkerId) ==> acts[j].c.checkerId == acts[k].tok.checkerId)
    { assert j == 0 && k == 1; }
  }
  lemma NTrace()
    ensures Exec(SW.W_PRE, NActs()).core.outbox == [N_INTENT]
    ensures Exec(SW.W_PRE, NActs()).core.charge == SW.W_PRE
    ensures SumIntents(Exec(SW.W_PRE, NActs()).core.outbox) != SW.W_PRE.remaining - Exec(SW.W_PRE, NActs()).core.charge.remaining
  {
    var acts := NActs();
    var init := SW.W_PRE;
    SW_ExecStep(init, acts, 0);
    SW_ExecStep(init, acts, 1);
    assert acts[..0] == [];
    assert acts[..2] == acts;
    var r1 := Exec(init, acts[..1]);
    assert r1.core == Core(init, {}, []);
    var r := Exec(init, acts);
    assert r.core == Core(SW.W_PRE, {"rq_0"}, [N_INTENT]);
    assert SumIntents([N_INTENT]) == SumIntents([]) + N_INTENT.amount;
  }
  lemma B6Control()
    ensures InitOk(SW.W_PRE) && A2_MintOnlyOnCheck(NActs())
    ensures H3b_SinkRebuildsSignedBytes(RealSer(HW, IdC), RebuildW, NActs())
    ensures H1B_ByteUnforgeability(RealSer(HW, IdC), TotalVB, RebuildW, NActs())
    ensures B5_ByteVerifierMatchesAtEachDelivery(TotalVB, RebuildW, NActs())
    ensures H3d_MintsParseable(NActs()) && A4_NoCollisionInRun(HW, IdC, NActs())
    ensures !B6_DeliveriesParseable(NActs())
    ensures SumIntents(Exec(SW.W_PRE, NActs()).core.outbox) != SW.W_PRE.remaining - Exec(SW.W_PRE, NActs()).core.charge.remaining
  {
    assert InitOk(SW.W_PRE);
    NA2(); NBytes(); NParseMints(); NA4(); NTrace();
    var acts := NActs();
    NNotParseable();
    assert acts[1].Deliver? && !ParseableTok(acts[1].tok);
  }

  // ---------------------------------------------------------------- 2. IssueBytes does not give H3d
  const NUL1: string := [0 as char]
  const X_PRE: F.Charge := F.Charge(NUL1, 100, 60, true)
  const X_T: F.Transition := F.Transition(F.Request("rq_1", 40, "duplicate_charge"), X_PRE.(remaining := 20),
                                          R.Intent(NUL1, "rq_1", 40, "duplicate_charge"))
  lemma IssueNotParseable()
    ensures F.Authorizes(X_PRE, X_T)
    ensures !ParseableClaim(CheckedClaim(X_PRE, X_T))
  {
    reveal ParseableClaim();
    assert !SM.Text(NUL1) by { assert NUL1[0] as int == 0; }
  }

  // ---------------------------------------------------------------- 3. what F.Authorizes does give
  predicate MoneyClaim(c: Claim)
  {
    c.reqId == Enc(c.req.requestId) && c.req == F.Request(c.req.requestId, c.eff.amount, c.eff.reason) &&
    MoneyOk(c.post.original) && MoneyOk(c.post.remaining) && MoneyOk(c.eff.amount)
  }
  lemma AuthorizedIsMoneyClaim(pre: F.Charge, t: F.Transition)
    requires F.Authorizes(pre, t)
    ensures MoneyClaim(CheckedClaim(pre, t))
  {
    assert R.MaxMoney < SM.MONEY_BOUND;
  }

  // ---------------------------------------------------------------- 4. the Text conjuncts are not used
  lemma ClaimInjectiveMoneyOnly(H: HashFn, idHex: IdFn, c1: Claim, c2: Claim)
    requires MoneyClaim(c1) && MoneyClaim(c2)
    requires H(c1.pre) == H(c2.pre) ==> c1.pre == c2.pre
    requires idHex(c1.specId) == idHex(c2.specId) ==> c1.specId == c2.specId
    requires idHex(c1.checkerId) == idHex(c2.checkerId) ==> c1.checkerId == c2.checkerId
    requires RealSerOf(H, idHex, c1) == RealSerOf(H, idHex, c2)
    ensures c1 == c2
  {
    RealSerBodyInjective(H, idHex, c1, c2);
    var b1 := BodyOfClaim(H, idHex, c1);
    var b2 := BodyOfClaim(H, idHex, c2);
    assert b1.post == b2.post && b1.intent == b2.intent && b1.requestId == b2.requestId;
    assert c1.post == c2.post;
    assert c1.eff == c2.eff;
    assert c1.req == c2.req;
  }

  // ---------------------------------------------------------------- 5. from issued bytes to A2 (one mint)
  // The obstacle: the claim c in MintAct needs MoneyClaim(c) (or H3d) and a NEW pairwise no-collision
  // hypothesis between c.pre and the checked pre (A4 is mint-vs-delivery, not this).
  lemma MintFromIssue(H: HashFn, idHex: IdFn, c: Claim, pre: F.Charge, t: F.Transition)
    requires F.Authorizes(pre, t)
    requires MoneyClaim(c)
    requires H(c.pre) == H(pre) ==> c.pre == pre
    requires idHex(c.specId) == idHex(PINNED_SPEC) ==> c.specId == PINNED_SPEC
    requires idHex(c.checkerId) == idHex(PINNED_CHK) ==> c.checkerId == PINNED_CHK
    requires RealSerOf(H, idHex, c) == RealSerOf(H, idHex, CheckedClaim(pre, t))
    ensures c == CheckedClaim(pre, t)
  {
    AuthorizedIsMoneyClaim(pre, t);
    ClaimInjectiveMoneyOnly(H, idHex, c, CheckedClaim(pre, t));
  }
}
