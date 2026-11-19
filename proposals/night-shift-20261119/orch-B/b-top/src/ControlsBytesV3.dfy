// Night shift 2026-11-19, Orchestrator B, task b-ser2 (G2 controls). A DRAFT in an evidence folder. NOT gate evidence.
// Controls for SliceSafetyBytesV3: a non-vacuity witness with a TOTAL byte verifier and real-shaped values, three
// dropped-hypothesis counterexamples, the amount -1 twin, and one-step rejections with a VALID signature.
// No assume, no axiom, no bodiless lemma, no {:extern}, no expect in this file.
include "SliceSafetyBytesV3.dfy"

// Text facts of short literals, proved in a module with a small context (in the context of ControlsBytesV3 the
// same TextSmall calls run out of resource).
module ShortTexts {
  import SM = SerModel
  lemma X0() ensures SM.Text("ch_1") { SM.TextSmall("ch_1"); }
  lemma X1() ensures SM.Text("ch_2") { SM.TextSmall("ch_2"); }
  lemma X2() ensures SM.Text("duplicate_charge") { SM.TextSmall("duplicate_charge"); }
  lemma X3() ensures SM.Text("rq_0") { SM.TextSmall("rq_0"); }
  lemma X4() ensures SM.Text("rq_1") { SM.TextSmall("rq_1"); }
  lemma X5() ensures SM.Text("rq_c") { SM.TextSmall("rq_c"); }
  lemma X6() ensures SM.Text("rq_f") { SM.TextSmall("rq_f"); }
  lemma Texts()
    ensures SM.Text("ch_1") && SM.Text("ch_2") && SM.Text("duplicate_charge")
    ensures SM.Text("rq_0") && SM.Text("rq_1") && SM.Text("rq_c") && SM.Text("rq_f")
  {
    X0(); X1(); X2(); X3(); X4(); X5(); X6();
  }
}

module ControlsBytesV3 {
  import opened HashCore
  import ShortTexts
  import opened SliceSafetyBytesV3
  import S3 = SliceTheoremV3

  // Real-shaped 64-lower-hex hash texts.
  const HX0: string := Rep('0', 64)
  const HX1: string := Rep('1', 64)
  const HX2: string := Rep('2', 64)
  const HX3: string := Rep('3', 64)
  const DC: string := "duplicate_charge"

  const W_PRE: F.Charge := F.Charge("ch_1", 100, 60, true)
  const W_POST: F.Charge := F.Charge("ch_1", 100, 20, true)
  const C2_PRE: F.Charge := F.Charge("ch_2", 100, 50, true)
  const P_COLL: F.Charge := F.Charge("ch_1", 100, 30, true)
  const I0: R.RefundIntent := R.Intent("ch_1", "rq_0", 0, DC)
  const I1: R.RefundIntent := R.Intent("ch_1", "rq_1", 40, DC)
  const T0: F.Transition := F.Transition(F.Request("rq_0", 0, DC), W_PRE, I0)
  const T1: F.Transition := F.Transition(F.Request("rq_1", 40, DC), W_POST, I1)
  const TC: F.Transition := F.Transition(F.Request("rq_c", 10, DC), F.Charge("ch_2", 100, 40, true), R.Intent("ch_2", "rq_c", 10, DC))

  // The hash in the witness: injective on the states of the run, 64-hex values.
  function HW(c: F.Charge): string
  {
    if c == W_PRE then HX0 else if c == W_POST then HX1 else if c == C2_PRE then HX2 else HX3
  }
  // A TOTAL byte verifier: every message has exactly one verifying tag, SB(m).
  function SB(m: Bytes): Tag { m + [-1] }
  function TotalVB(m: Bytes, t: Tag): bool { t == SB(m) }
  function AcceptAll(m: Bytes, t: Tag): bool { true }

  lemma TotalVBIsTotalAndUnique()
    ensures forall m: Bytes :: TotalVB(m, SB(m))
    ensures forall m: Bytes, t: Tag :: TotalVB(m, t) ==> t == SB(m)
  {}

  function TokOf(H: HashFn, pre: F.Charge, t: F.Transition): HashToken
    requires MoneyNonNeg(t)
  {
    HashToken(PIN_SPEC, PIN_CHK, H(pre), t.request.requestId, StateOfN(t.post), IntentOfN(t.intent), SB(IssueOut(H, pre, t)))
  }
  lemma TokOfBytes(H: HashFn, pre: F.Charge, t: F.Transition)
    requires MoneyNonNeg(t)
    ensures BytesOf(TokOf(H, pre, t)) == IssueOut(H, pre, t)
    ensures TotalVB(BytesOf(TokOf(H, pre, t)), TokOf(H, pre, t).sig)
  {
    assert BodyOf(TokOf(H, pre, t)) == IssueBody(H, pre, t);
  }

  lemma HexDistinct()
    ensures HX0 != HX1 && HX0 != HX2 && HX1 != HX2 && HX0 != HX3 && HX1 != HX3 && HX2 != HX3
  {
    RepDistinct('0', '1', 64); RepDistinct('0', '2', 64); RepDistinct('1', '2', 64);
    RepDistinct('0', '3', 64); RepDistinct('1', '3', 64); RepDistinct('2', '3', 64);
  }

  lemma Authorized()
    ensures F.Authorizes(W_PRE, T0) && F.Authorizes(W_PRE, T1) && F.Authorizes(C2_PRE, TC)
    ensures MoneyNonNeg(T0) && MoneyNonNeg(T1) && MoneyNonNeg(TC)
  {
    assert W_PRE.(remaining := W_PRE.remaining - 0) == W_PRE;
    assert W_PRE.(remaining := W_PRE.remaining - 40) == W_POST;
    assert C2_PRE.(remaining := C2_PRE.remaining - 10) == F.Charge("ch_2", 100, 40, true);
  }

  // =============================================================================================
  // NON-VACUITY WITNESS. Zero-amount commit, replay, positive commit, forged tag, foreign charge.
  const M0: Bytes := IssueOut(HW, W_PRE, T0)
  const M1: Bytes := IssueOut(HW, W_PRE, T1)
  const MC: Bytes := IssueOut(HW, C2_PRE, TC)
  const TK0: HashToken := TokOf(HW, W_PRE, T0)
  const TK1: HashToken := TokOf(HW, W_PRE, T1)
  const TKC: HashToken := TokOf(HW, C2_PRE, TC)
  // Forged: pinned ids, the right hash of the stored W_POST, an amount within bounds, never minted; tag [7].
  const FTOK: HashToken := HashToken(PIN_SPEC, PIN_CHK, HX1, "rq_f", SM.ChargeState("ch_1", 100, 0, true),
                                     SM.Intent("ch_1", "rq_f", 20, DC), [7])

  function WActs(): seq<Act>
  {
    [MintAct(W_PRE, M0, SB(M0)), Deliver(TK0, true), Deliver(TK0, true),
     MintAct(W_PRE, M1, SB(M1)), Deliver(TK1, true), Deliver(FTOK, false),
     MintAct(C2_PRE, MC, SB(MC)), Deliver(TKC, true)]
  }

  lemma WitSteps()
    ensures Step(HW, Core(W_PRE, {}, []), TK0, true) == StepResult(Core(W_PRE, {"rq_0"}, [I0]), Committed)
    ensures Step(HW, Core(W_PRE, {"rq_0"}, [I0]), TK0, true).out == Rejected(RequestSettled)
    ensures Step(HW, Core(W_PRE, {"rq_0"}, [I0]), TK1, true) == StepResult(Core(W_POST, {"rq_0", "rq_1"}, [I0, I1]), Committed)
    ensures Step(HW, Core(W_POST, {"rq_0", "rq_1"}, [I0, I1]), FTOK, false).out == Rejected(SignatureInvalid)
    ensures Step(HW, Core(W_POST, {"rq_0", "rq_1"}, [I0, I1]), TKC, true).out == Rejected(PreStateMismatch)
  {
    Authorized();
    HexDistinct();
    assert "rq_1" != "rq_0" by { assert "rq_1"[3] != "rq_0"[3]; }
    assert "rq_c" != "rq_0" && "rq_c" != "rq_1" by { assert "rq_c"[3] != "rq_0"[3] && "rq_c"[3] != "rq_1"[3]; }
    assert ChargeOfState(TK0.post) == W_PRE && IntentOfSM(TK0.intent) == I0;
    assert ChargeOfState(TK1.post) == W_POST && IntentOfSM(TK1.intent) == I1;
    assert {"rq_0"} + {"rq_1"} == {"rq_0", "rq_1"};
    assert [I0] + [I1] == [I0, I1];
  }

  function S0(): RunSt { RunSt(Core(W_PRE, {}, []), [], [], [], 0) }
  function S2(): RunSt { RunSt(Core(W_PRE, {"rq_0"}, [I0]), [TK0], [W_PRE], [1], 2) }
  function S5(): RunSt { RunSt(Core(W_POST, {"rq_0", "rq_1"}, [I0, I1]), [TK0, TK1], [W_PRE, W_PRE], [1, 4], 5) }

  lemma WitP2()
    ensures TExec(HW, W_PRE, WActs()[..0]) == S0()
    ensures TExec(HW, W_PRE, WActs()[..1]) == RunSt(Core(W_PRE, {}, []), [], [], [], 1)
    ensures TExec(HW, W_PRE, WActs()[..2]) == S2()
  {
    var acts := WActs();
    WitSteps();
    assert acts[..0] == [];
    TExecStep(HW, W_PRE, acts, 0);
    TExecStep(HW, W_PRE, acts, 1);
  }
  lemma WitP5()
    ensures TExec(HW, W_PRE, WActs()[..3]) == RunSt(Core(W_PRE, {"rq_0"}, [I0]), [TK0], [W_PRE], [1], 3)
    ensures TExec(HW, W_PRE, WActs()[..4]) == RunSt(Core(W_PRE, {"rq_0"}, [I0]), [TK0], [W_PRE], [1], 4)
    ensures TExec(HW, W_PRE, WActs()[..5]) == S5()
  {
    var acts := WActs();
    WitP2();
    WitSteps();
    TExecStep(HW, W_PRE, acts, 2);
    TExecStep(HW, W_PRE, acts, 3);
    TExecStep(HW, W_PRE, acts, 4);
    assert [TK0] + [TK1] == [TK0, TK1] && [W_PRE] + [W_PRE] == [W_PRE, W_PRE] && [1] + [4] == [1, 4];
  }
  lemma WitP8()
    ensures TExec(HW, W_PRE, WActs()[..6]) == RunSt(Core(W_POST, {"rq_0", "rq_1"}, [I0, I1]), [TK0, TK1], [W_PRE, W_PRE], [1, 4], 6)
    ensures TExec(HW, W_PRE, WActs()[..7]) == RunSt(Core(W_POST, {"rq_0", "rq_1"}, [I0, I1]), [TK0, TK1], [W_PRE, W_PRE], [1, 4], 7)
    ensures TExec(HW, W_PRE, WActs()) == RunSt(Core(W_POST, {"rq_0", "rq_1"}, [I0, I1]), [TK0, TK1], [W_PRE, W_PRE], [1, 4], 8)
  {
    var acts := WActs();
    WitP5();
    WitSteps();
    TExecStep(HW, W_PRE, acts, 5);
    TExecStep(HW, W_PRE, acts, 6);
    TExecStep(HW, W_PRE, acts, 7);
    assert acts[..8] == acts;
  }
  lemma WitPrefixes()
    ensures TExec(HW, W_PRE, WActs()[..1]).core.charge == W_PRE && TExec(HW, W_PRE, WActs()[..2]).core.charge == W_PRE
    ensures TExec(HW, W_PRE, WActs()[..4]).core.charge == W_PRE && TExec(HW, W_PRE, WActs()[..5]).core.charge == W_POST
    ensures TExec(HW, W_PRE, WActs()[..7]).core.charge == W_POST
    ensures TExec(HW, W_PRE, WActs()[..2]).core == Core(W_PRE, {"rq_0"}, [I0])
    ensures TExec(HW, W_PRE, WActs()[..5]).core == Core(W_POST, {"rq_0", "rq_1"}, [I0, I1])
    ensures TExec(HW, W_PRE, WActs()[..7]).core == Core(W_POST, {"rq_0", "rq_1"}, [I0, I1])
    ensures TExec(HW, W_PRE, WActs()).core == Core(W_POST, {"rq_0", "rq_1"}, [I0, I1])
  {
    WitP2(); WitP5(); WitP8();
  }

  lemma WitA2p()
    ensures A2p_MintsAreIssued(HW, WActs())
  {
    reveal A2p_MintsAreIssued();
    var acts := WActs();
    Authorized();
    assert IssuedFrom(HW, W_PRE, T0, M0) && IssuedFrom(HW, W_PRE, T1, M1) && IssuedFrom(HW, C2_PRE, TC, MC);
    forall j | 0 <= j < |acts| && acts[j].MintAct? && OurBytes(acts[j].msg)
      ensures exists t: F.Transition :: IssuedFrom(HW, acts[j].pre, t, acts[j].msg)
    {
      if j == 0 { assert IssuedFrom(HW, acts[j].pre, T0, acts[j].msg); }
      else if j == 3 { assert IssuedFrom(HW, acts[j].pre, T1, acts[j].msg); }
      else { assert j == 6; assert IssuedFrom(HW, acts[j].pre, TC, acts[j].msg); }
    }
  }

  lemma ForgedRejected()
    ensures !TotalVB(BytesOf(FTOK), FTOK.sig)
  {
    var s := SB(BytesOf(FTOK));
    assert s[|s| - 1] == -1;
  }

  lemma WitSig()
    ensures H1B_ByteUnforgeability(TotalVB, WActs()) && B5_VerifierBoolean(TotalVB, WActs())
  {
    reveal H1B_ByteUnforgeability(), B5_VerifierBoolean();
    var acts := WActs();
    Authorized();
    TokOfBytes(HW, W_PRE, T0); TokOfBytes(HW, W_PRE, T1); TokOfBytes(HW, C2_PRE, TC);
    ForgedRejected();
    forall k | 0 <= k < |acts| && acts[k].Deliver?
      ensures acts[k].sigOk == TotalVB(BytesOf(acts[k].tok), acts[k].tok.sig)
    {
      assert k == 1 || k == 2 || k == 4 || k == 5 || k == 7;
    }
    forall k | 0 <= k < |acts| && acts[k].Deliver? && TotalVB(BytesOf(acts[k].tok), acts[k].tok.sig)
      ensures MintedBefore(acts, k, BytesOf(acts[k].tok))
    {
      if k == 1 || k == 2 { assert acts[0].MintAct? && acts[0].msg == BytesOf(acts[k].tok); }
      else if k == 4 { assert acts[3].MintAct? && acts[3].msg == BytesOf(acts[k].tok); }
      else { assert k == 7; assert acts[6].MintAct? && acts[6].msg == BytesOf(acts[k].tok); }
    }
  }

  lemma WitA4()
    ensures A4_HashBindsInRun(HW, W_PRE, WActs())
  {
    reveal A4_HashBindsInRun();
    var acts := WActs();
    WitPrefixes();
    HexDistinct();
    forall j, k | 0 <= j < k < |acts| && acts[j].MintAct? && acts[k].Deliver?
      ensures HW(TExec(HW, W_PRE, acts[..k]).core.charge) == HW(acts[j].pre) ==> TExec(HW, W_PRE, acts[..k]).core.charge == acts[j].pre
    {
      assert j == 0 || j == 3 || j == 6;
      assert k == 1 || k == 2 || k == 4 || k == 5 || k == 7;
      assert acts[j].pre == W_PRE || acts[j].pre == C2_PRE;
      assert TExec(HW, W_PRE, acts[..k]).core.charge == W_PRE || TExec(HW, W_PRE, acts[..k]).core.charge == W_POST;
    }
  }

  lemma WfCommon()
    ensures SM.Hex64(PIN_SPEC) && SM.Hex64(PIN_CHK) && SM.Hex64(HX0) && SM.Hex64(HX1) && SM.Hex64(HX2)
    ensures SM.Text("ch_1") && SM.Text("ch_2") && SM.Text(DC)
  {
    RepHex64('a'); RepHex64('b'); RepHex64('0'); RepHex64('1'); RepHex64('2');
    ShortTexts.Texts();
  }
  lemma WfTK0() ensures SM.WfBody(BodyOf(TK0))
  {
    WfCommon(); ShortTexts.Texts();
    assert BodyOf(TK0) == SM.TokenBody(SM.DOMAIN, PIN_SPEC, PIN_CHK, HX0, "rq_0", SM.ChargeState("ch_1", 100, 60, true), SM.Intent("ch_1", "rq_0", 0, DC));
  }
  lemma WfTK1() ensures SM.WfBody(BodyOf(TK1))
  {
    WfCommon(); ShortTexts.Texts();
    assert BodyOf(TK1) == SM.TokenBody(SM.DOMAIN, PIN_SPEC, PIN_CHK, HX0, "rq_1", SM.ChargeState("ch_1", 100, 20, true), SM.Intent("ch_1", "rq_1", 40, DC));
  }
  lemma WfTKC() ensures SM.WfBody(BodyOf(TKC))
  {
    WfCommon(); ShortTexts.Texts();
    assert BodyOf(TKC) == SM.TokenBody(SM.DOMAIN, PIN_SPEC, PIN_CHK, HX2, "rq_c", SM.ChargeState("ch_2", 100, 40, true), SM.Intent("ch_2", "rq_c", 10, DC));
  }
  lemma WfFTOK() ensures SM.WfBody(BodyOf(FTOK))
  {
    WfCommon(); ShortTexts.Texts();
    var b := BodyOf(FTOK);
    assert b.domain == SM.DOMAIN;
    assert SM.Hex64(b.specLockSha256) && SM.Hex64(b.checkerSha256) && SM.Hex64(b.preStateSha256);
    assert SM.Text(b.requestId);
    assert SM.Money(100) && SM.Money(0) && SM.Money(20);
    assert SM.IsState(b.post);
    assert SM.IsIntent(b.intent);
  }
  lemma WitBodiesWf()
    ensures SM.WfBody(BodyOf(TK0)) && SM.WfBody(BodyOf(TK1)) && SM.WfBody(BodyOf(TKC)) && SM.WfBody(BodyOf(FTOK))
  {
    WfTK0(); WfTK1(); WfTKC(); WfFTOK();
  }

  // THE WITNESS: every hypothesis of the composed theorem holds (A6b with the proved FlatSpecFn); a zero-amount
  // and a positive effect commit; replay, forged tag and foreign charge are rejected; the conclusions apply.
  lemma Witness()
    ensures InitOk(W_PRE) && A2p_MintsAreIssued(HW, WActs()) && H1B_ByteUnforgeability(TotalVB, WActs())
    ensures B5_VerifierBoolean(TotalVB, WActs()) && A4_HashBindsInRun(HW, W_PRE, WActs())
    ensures S3.A6b_ArtifactComputesFlatContractOnBytes(S3.FlatSpecFn)
    ensures TExec(HW, W_PRE, WActs()).core == Core(W_POST, {"rq_0", "rq_1"}, [I0, I1])
    ensures I0.amount == 0 && I1.amount == 40
    ensures SM.WfBody(BodyOf(TK0)) && SM.WfBody(BodyOf(TK1)) && SM.WfBody(BodyOf(TKC)) && SM.WfBody(BodyOf(FTOK))
    ensures Step(HW, TExec(HW, W_PRE, WActs()[..2]).core, TK0, true).out == Rejected(RequestSettled)
    ensures Step(HW, TExec(HW, W_PRE, WActs()[..5]).core, FTOK, false).out == Rejected(SignatureInvalid)
    ensures Step(HW, TExec(HW, W_PRE, WActs()[..7]).core, TKC, true).out == Rejected(PreStateMismatch)
    ensures var r := TExec(HW, W_PRE, WActs());
      forall e | e in r.core.outbox :: exists i :: FullEntry(HW, W_PRE, WActs(), S3.FlatSpecFn, r, i, e)
  {
    WitPrefixes(); WitSteps(); WitA2p(); WitSig(); WitA4(); WitBodiesWf();
    S3.FlatSpecFnMeetsA6b();
    SliceSafetyBytesV3.SliceSafetyBytesV3(HW, W_PRE, WActs(), TotalVB, S3.FlatSpecFn);
  }

  // One-step rejections with a VALID signature (sigOk = true; no hypothesis): the core itself refuses them.
  const MTOK: HashToken := HashToken(PIN_SPEC, PIN_CHK, HX1, "rq_m", SM.ChargeState("ch_1", 100, 10, true),
                                     SM.Intent("ch_1", "rq_1", 10, DC), [])
  const XTOK: HashToken := HashToken(PIN_SPEC, PIN_CHK, HX1, "rq_x", SM.ChargeState("ch_2", 100, 10, true),
                                     SM.Intent("ch_2", "rq_x", 10, DC), [])
  lemma ValidSigStillRejected()
    ensures Step(HW, Core(W_POST, {"rq_0", "rq_1"}, [I0, I1]), MTOK, true).out == Rejected(ReqIdMismatch)
    ensures Step(HW, Core(W_POST, {"rq_0", "rq_1"}, [I0, I1]), XTOK, true).out == Rejected(ChargeIdMismatch)
  {
    assert "rq_m" != "rq_1" by { assert "rq_m"[3] != "rq_1"[3]; }
    assert "rq_x" != "rq_0" && "rq_x" != "rq_1" by { assert "rq_x"[3] != "rq_0"[3] && "rq_x"[3] != "rq_1"[3]; }
    assert "ch_1" != "ch_2" by { assert "ch_1"[3] != "ch_2"[3]; }
  }

  // =============================================================================================
  // The amount -1 twin of r-ser B6Control is impossible: a token whose bytes equal TK0's bytes carries exactly
  // TK0's fields (amount 0), and no decoded token carries amount -1.
  lemma NoNegativeTwinOfZeroClaim(tok: HashToken)
    requires BytesOf(tok) == BytesOf(TK0)
    ensures IntentOfSM(tok.intent) == I0 && IntentOfSM(tok.intent).amount == 0
    ensures IntentOfSM(tok.intent) != R.Intent("ch_1", "rq_0", -1, DC)
  {
    BytesInjective(tok, TK0);
    assert tok.intent == TK0.intent;
  }

  // =============================================================================================
  // CONTROL 1 (drop A4): a constant 64-hex hash. The stored P_COLL (remaining 30) hashes like the minted pre-state
  // W_PRE (remaining 60). Everything but A4 holds; an unapproved effect commits; the sum equation fails.
  function HC(c: F.Charge): string { HX0 }
  const MCOLL: Bytes := IssueOut(HC, W_PRE, T1)
  const TCOLL: HashToken := TokOf(HC, W_PRE, T1)
  function CollActs(): seq<Act> { [MintAct(W_PRE, MCOLL, SB(MCOLL)), Deliver(TCOLL, true)] }

  lemma CollTrace()
    ensures TExec(HC, P_COLL, CollActs()[..1]) == RunSt(Core(P_COLL, {}, []), [], [], [], 1)
    ensures TExec(HC, P_COLL, CollActs()) == RunSt(Core(W_POST, {"rq_1"}, [I1]), [TCOLL], [P_COLL], [1], 2)
  {
    var acts := CollActs();
    Authorized();
    assert acts[..0] == [];
    TExecStep(HC, P_COLL, acts, 0);
    TExecStep(HC, P_COLL, acts, 1);
    assert acts[..2] == acts;
    assert ChargeOfState(TCOLL.post) == W_POST && IntentOfSM(TCOLL.intent) == I1;
    assert {} + {"rq_1"} == {"rq_1"};
  }

  lemma DropA4BreaksApproval()
    ensures InitOk(P_COLL) && A2p_MintsAreIssued(HC, CollActs())
    ensures H1B_ByteUnforgeability(TotalVB, CollActs()) && B5_VerifierBoolean(TotalVB, CollActs())
    ensures !A4_HashBindsInRun(HC, P_COLL, CollActs())
    ensures var r := TExec(HC, P_COLL, CollActs());
      r.core.outbox == [I1] && r.pres == [P_COLL] && |r.toks| == 1 && !Approved(r.pres[0], r.toks[0], r.core.outbox[0]) &&
      SumIntents(r.core.outbox) != P_COLL.remaining - r.core.charge.remaining
  {
    var acts := CollActs();
    Authorized();
    CollTrace();
    TokOfBytes(HC, W_PRE, T1);
    reveal A2p_MintsAreIssued(), H1B_ByteUnforgeability(), B5_VerifierBoolean(), A4_HashBindsInRun();
    assert IssuedFrom(HC, W_PRE, T1, MCOLL);
    forall j | 0 <= j < |acts| && acts[j].MintAct? && OurBytes(acts[j].msg)
      ensures exists t: F.Transition :: IssuedFrom(HC, acts[j].pre, t, acts[j].msg)
    { assert j == 0; assert IssuedFrom(HC, acts[j].pre, T1, acts[j].msg); }
    forall k | 0 <= k < |acts| && acts[k].Deliver? && TotalVB(BytesOf(acts[k].tok), acts[k].tok.sig)
      ensures MintedBefore(acts, k, BytesOf(acts[k].tok))
    { assert k == 1 && acts[0].MintAct? && acts[0].msg == BytesOf(acts[k].tok); }
    assert acts[0].MintAct? && acts[1].Deliver? && TExec(HC, P_COLL, acts[..1]).core.charge == P_COLL;
    assert HC(P_COLL) == HC(W_PRE) && P_COLL != W_PRE;
    var r := TExec(HC, P_COLL, acts);
    assert SumIntents([I1]) == SumIntents([]) + 40;
  }

  // =============================================================================================
  // CONTROL 2 (drop A2'): the key signs bytes that are not an IssueBytes output (amount 61 > remaining 60).
  const BT0: HashToken := HashToken(PIN_SPEC, PIN_CHK, HX0, "rq_b", SM.ChargeState("ch_1", 100, 0, true),
                                    SM.Intent("ch_1", "rq_b", 61, DC), [])
  const BMSG: Bytes := BytesOf(BT0)
  const BTOK: HashToken := HashToken(PIN_SPEC, PIN_CHK, HX0, "rq_b", SM.ChargeState("ch_1", 100, 0, true),
                                     SM.Intent("ch_1", "rq_b", 61, DC), SB(BMSG))
  const IB: R.RefundIntent := R.Intent("ch_1", "rq_b", 61, DC)
  function BadMintActs(): seq<Act> { [MintAct(W_PRE, BMSG, SB(BMSG)), Deliver(BTOK, true)] }

  lemma BTrace(H: HashFn, acts: seq<Act>)
    requires H(W_PRE) == HX0 && |acts| == 2 && acts[1] == Deliver(BTOK, true)
    ensures TExec(H, W_PRE, acts) == RunSt(Core(F.Charge("ch_1", 100, 0, true), {"rq_b"}, [IB]), [BTOK], [W_PRE], [1], 2)
  {
    assert acts[..0] == [];
    TExecStep(H, W_PRE, acts, 0);
    TExecStep(H, W_PRE, acts, 1);
    assert acts[..2] == acts;
    assert TExec(H, W_PRE, acts[..1]).core == Core(W_PRE, {}, []);
    assert {} + {"rq_b"} == {"rq_b"};
  }

  lemma BNotApproved()
    ensures !Approved(W_PRE, BTOK, IB)
  {}

  lemma BNotIssued(t: F.Transition)
    ensures !IssuedFrom(HW, W_PRE, t, BMSG)
  {
    if IssuedFrom(HW, W_PRE, t, BMSG) {
      assert BytesOf(BTOK) == BMSG by { assert BodyOf(BTOK) == BodyOf(BT0); }
      IssuedTokenFields(HW, W_PRE, t, BTOK);
      AuthorizedMoneyNonNeg(W_PRE, t);
      assert t.intent.amount == 61;
    }
  }

  lemma DropA2pBreaksApproval()
    ensures InitOk(W_PRE) && !A2p_MintsAreIssued(HW, BadMintActs())
    ensures H1B_ByteUnforgeability(TotalVB, BadMintActs()) && B5_VerifierBoolean(TotalVB, BadMintActs())
    ensures A4_HashBindsInRun(HW, W_PRE, BadMintActs())
    ensures var r := TExec(HW, W_PRE, BadMintActs());
      r.core.outbox == [IB] && r.pres == [W_PRE] && |r.toks| == 1 && !Approved(r.pres[0], r.toks[0], r.core.outbox[0])
  {
    var acts := BadMintActs();
    BTrace(HW, acts);
    assert BytesOf(BTOK) == BMSG by { assert BodyOf(BTOK) == BodyOf(BT0); }
    reveal A2p_MintsAreIssued(), H1B_ByteUnforgeability(), B5_VerifierBoolean(), A4_HashBindsInRun();
    assert OurBytes(acts[0].msg) by { assert SM.SignedBytes(BodyOf(BT0)) == acts[0].msg; }
    forall t: F.Transition ensures !IssuedFrom(HW, acts[0].pre, t, acts[0].msg) { BNotIssued(t); }
    forall k | 0 <= k < |acts| && acts[k].Deliver? && TotalVB(BytesOf(acts[k].tok), acts[k].tok.sig)
      ensures MintedBefore(acts, k, BytesOf(acts[k].tok))
    { assert k == 1 && acts[0].MintAct? && acts[0].msg == BytesOf(acts[k].tok); }
    assert acts[..1] == [acts[0]];
    assert TExec(HW, W_PRE, acts[..1]).core.charge == W_PRE by {
      assert acts[..1][..0] == [];
    }
    BNotApproved();
  }

  // =============================================================================================
  // CONTROL 3 (drop H1B): an accept-all verifier; the token was never signed. B5 holds; A2' and A4 hold vacuously.
  function NoAuthActs(): seq<Act> { [MintAct(W_PRE, [], []), Deliver(BTOK, true)] }

  lemma DropH1BBreaksApproval()
    ensures InitOk(W_PRE) && A2p_MintsAreIssued(HW, NoAuthActs())
    ensures !H1B_ByteUnforgeability(AcceptAll, NoAuthActs()) && B5_VerifierBoolean(AcceptAll, NoAuthActs())
    ensures A4_HashBindsInRun(HW, W_PRE, NoAuthActs())
    ensures var r := TExec(HW, W_PRE, NoAuthActs());
      r.core.outbox == [IB] && r.pres == [W_PRE] && |r.toks| == 1 && !Approved(r.pres[0], r.toks[0], r.core.outbox[0])
  {
    var acts := NoAuthActs();
    BTrace(HW, acts);
    reveal A2p_MintsAreIssued(), H1B_ByteUnforgeability(), B5_VerifierBoolean(), A4_HashBindsInRun();
    assert !OurBytes(acts[0].msg) by {
      forall b: SM.TokenBody ensures SM.SignedBytes(b) != [] {
        SignedBytesNonEmpty(b);
      }
    }
    assert BytesOf(BTOK) != [] by { SignedBytesNonEmpty(BodyOf(BTOK)); }
    assert !MintedBefore(acts, 1, BytesOf(BTOK));
    assert acts[..1] == [acts[0]];
    assert TExec(HW, W_PRE, acts[..1]).core.charge == W_PRE by { assert acts[..1][..0] == []; }
    BNotApproved();
  }

  lemma SignedBytesNonEmpty(b: SM.TokenBody)
    ensures SM.SignedBytes(b) != []
  {
    reveal SM.SerBody();
    var s := SM.SerBody(b);
    assert s[0] == '{';
    assert SM.Utf8(s) == SM.Utf8Char(s[0]) + SM.Utf8(s[1..]);
  }
}
