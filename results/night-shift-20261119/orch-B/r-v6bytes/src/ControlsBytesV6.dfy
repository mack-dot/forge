// Night shift 2026-11-19, Orchestrator B, task b-v6bytes (G2 controls). A DRAFT in an evidence folder. NOT gate evidence.
// Controls for SliceSafetyBytesV6. It reuses the constants, the witness trace and the three V3 controls of
// ControlsBytesV3 (b-ser2, byte-equal copy) and states each CONTRAST with V3 in ONE lemma that calls the V3 control:
//   ContrastDropH1B  V3: accept-all verifier, nothing minted -> an UNAPPROVED effect commits (DropH1BBreaksApproval).
//                    V6: the same trace commits nothing; an AUTHORIZED never-minted token commits (L0 holds, L1 fails).
//   ContrastDropA2p  V3: a faulty signer's unauthorized bytes commit (DropA2pBreaksApproval).
//                    V6: the same trace commits nothing; an authorized token signed under a foreign pre-state (not an
//                    IssueBytes output) commits: Approved holds, IssuedAtStored (L2) fails.
//   ContrastDropA4   V3: a constant hash lets an unapproved effect commit (DropA4BreaksApproval).
//                    V6: the same trace commits nothing; for EVERY trace with the constant hash L0 and L2 hold.
// WitnessV6: every hypothesis of SliceSafetyBytesV6Top holds with a TOTAL byte verifier; a zero-amount and a positive
// effect commit; replay, forged tag and foreign charge are rejected. SignedUnauthorizedRejected: a signed, pinned,
// fresh, hash-matching token that HashCore.Step COMMITS is rejected by Step6 with NotAuthorized.
// No assume, no axiom, no bodiless lemma, no {:extern}, no expect in this file.
include "SliceSafetyBytesV6.dfy"
include "ControlsBytesV3.dfy"

module ControlsBytesV6 {
  import opened HashCore
  import opened HashCore6
  import opened SliceSafetyBytesV3
  import opened SliceSafetyBytesV6
  import CV3 = ControlsBytesV3
  import S3 = SliceTheoremV3

  function S0(init: F.Charge): RunSt { RunSt(Core(init, {}, []), [], [], [], 0) }

  lemma Two6(H: HashFn, init: F.Charge, acts: seq<Act>)
    requires |acts| == 2
    ensures TExec6(H, init, acts[..0]) == S0(init)
    ensures TExec6(H, init, acts[..1]) == TNext6(H, S0(init), acts[0])
    ensures TExec6(H, init, acts) == TNext6(H, TNext6(H, S0(init), acts[0]), acts[1])
  {
    assert acts[..0] == [];
    TExec6Step(H, init, acts, 0);
    TExec6Step(H, init, acts, 1);
    assert acts[..2] == acts;
  }

  lemma TransOfWit()
    ensures TransH(CV3.TK0) == CV3.T0 && TransH(CV3.TK1) == CV3.T1 && TransH(CV3.TKC) == CV3.TC
    ensures F.Authorizes(CV3.W_PRE, TransH(CV3.TK0)) && F.Authorizes(CV3.W_PRE, TransH(CV3.TK1))
  {
    CV3.Authorized();
  }

  // =============================================================================================
  // NON-VACUITY WITNESS (the V3 witness trace WActs, run with Step6).
  lemma WitSteps6()
    ensures Step6(CV3.HW, Core(CV3.W_PRE, {}, []), CV3.TK0, true) ==
            StepResult6(Core(CV3.W_PRE, {"rq_0"}, [CV3.I0]), Committed6)
    ensures Step6(CV3.HW, Core(CV3.W_PRE, {"rq_0"}, [CV3.I0]), CV3.TK0, true).out == Rejected6(Base(RequestSettled))
    ensures Step6(CV3.HW, Core(CV3.W_PRE, {"rq_0"}, [CV3.I0]), CV3.TK1, true) ==
            StepResult6(Core(CV3.W_POST, {"rq_0", "rq_1"}, [CV3.I0, CV3.I1]), Committed6)
    ensures Step6(CV3.HW, Core(CV3.W_POST, {"rq_0", "rq_1"}, [CV3.I0, CV3.I1]), CV3.FTOK, false).out ==
            Rejected6(Base(SignatureInvalid))
    ensures Step6(CV3.HW, Core(CV3.W_POST, {"rq_0", "rq_1"}, [CV3.I0, CV3.I1]), CV3.TKC, true).out ==
            Rejected6(Base(PreStateMismatch))
  {
    CV3.WitSteps();
    TransOfWit();
    AuthorizesHIs(CV3.W_PRE, CV3.TK0);
    AuthorizesHIs(CV3.W_PRE, CV3.TK1);
  }

  function SW2(): RunSt { RunSt(Core(CV3.W_PRE, {"rq_0"}, [CV3.I0]), [CV3.TK0], [CV3.W_PRE], [1], 2) }
  function SW5(): RunSt
  {
    RunSt(Core(CV3.W_POST, {"rq_0", "rq_1"}, [CV3.I0, CV3.I1]), [CV3.TK0, CV3.TK1], [CV3.W_PRE, CV3.W_PRE], [1, 4], 5)
  }

  lemma Wit6P2()
    ensures TExec6(CV3.HW, CV3.W_PRE, CV3.WActs()[..2]) == SW2()
    ensures TExec6(CV3.HW, CV3.W_PRE, CV3.WActs()[..2]).core == Core(CV3.W_PRE, {"rq_0"}, [CV3.I0])
  {
    var acts := CV3.WActs();
    WitSteps6();
    assert acts[..0] == [];
    TExec6Step(CV3.HW, CV3.W_PRE, acts, 0);
    TExec6Step(CV3.HW, CV3.W_PRE, acts, 1);
  }
  lemma Wit6P5()
    ensures TExec6(CV3.HW, CV3.W_PRE, CV3.WActs()[..5]) == SW5()
  {
    var acts := CV3.WActs();
    Wit6P2();
    WitSteps6();
    TExec6Step(CV3.HW, CV3.W_PRE, acts, 2);
    TExec6Step(CV3.HW, CV3.W_PRE, acts, 3);
    TExec6Step(CV3.HW, CV3.W_PRE, acts, 4);
    assert [CV3.TK0] + [CV3.TK1] == [CV3.TK0, CV3.TK1] && [CV3.W_PRE] + [CV3.W_PRE] == [CV3.W_PRE, CV3.W_PRE];
    assert [1] + [4] == [1, 4];
  }
  lemma Wit6P8()
    ensures TExec6(CV3.HW, CV3.W_PRE, CV3.WActs()[..7]).core == Core(CV3.W_POST, {"rq_0", "rq_1"}, [CV3.I0, CV3.I1])
    ensures TExec6(CV3.HW, CV3.W_PRE, CV3.WActs()) == SW5().(n := 8)
  {
    var acts := CV3.WActs();
    Wit6P5();
    WitSteps6();
    TExec6Step(CV3.HW, CV3.W_PRE, acts, 5);
    TExec6Step(CV3.HW, CV3.W_PRE, acts, 6);
    TExec6Step(CV3.HW, CV3.W_PRE, acts, 7);
    assert acts[..8] == acts;
  }

  // THE WITNESS: every hypothesis of SliceSafetyBytesV6Top holds (TOTAL verifier, A6b with the proved FlatSpecFn);
  // a zero-amount (I0) and a positive (I1, 40) effect commit; replay, forged tag, foreign charge are rejected; the
  // reached run state equals the V3 run state of the same trace; the composed conclusion applies.
  lemma WitnessV6()
    ensures InitOk(CV3.W_PRE) && A2p_MintsAreIssued(CV3.HW, CV3.WActs())
    ensures H1B_ByteUnforgeability(CV3.TotalVB, CV3.WActs()) && B5_VerifierBoolean(CV3.TotalVB, CV3.WActs())
    ensures S3.A6b_ArtifactComputesFlatContractOnBytes(S3.FlatSpecFn)
    ensures TExec6(CV3.HW, CV3.W_PRE, CV3.WActs()).core == Core(CV3.W_POST, {"rq_0", "rq_1"}, [CV3.I0, CV3.I1])
    ensures |TExec6(CV3.HW, CV3.W_PRE, CV3.WActs()).toks| == 2
    ensures TExec6(CV3.HW, CV3.W_PRE, CV3.WActs()) == TExec(CV3.HW, CV3.W_PRE, CV3.WActs())
    ensures CV3.I0.amount == 0 && CV3.I1.amount == 40
    ensures Step6(CV3.HW, TExec6(CV3.HW, CV3.W_PRE, CV3.WActs()[..2]).core, CV3.TK0, true).out == Rejected6(Base(RequestSettled))
    ensures Step6(CV3.HW, TExec6(CV3.HW, CV3.W_PRE, CV3.WActs()[..5]).core, CV3.FTOK, false).out == Rejected6(Base(SignatureInvalid))
    ensures Step6(CV3.HW, TExec6(CV3.HW, CV3.W_PRE, CV3.WActs()[..7]).core, CV3.TKC, true).out == Rejected6(Base(PreStateMismatch))
    ensures var r := TExec6(CV3.HW, CV3.W_PRE, CV3.WActs());
      forall e | e in r.core.outbox :: exists i :: FullEntry6(CV3.HW, CV3.W_PRE, CV3.WActs(), S3.FlatSpecFn, r, i, e)
  {
    Wit6P2(); Wit6P5(); Wit6P8(); WitSteps6();
    CV3.WitA2p(); CV3.WitSig(); CV3.WitP8();
    S3.FlatSpecFnMeetsA6b();
    SliceSafetyBytesV6Top(CV3.HW, CV3.W_PRE, CV3.WActs(), CV3.TotalVB, S3.FlatSpecFn);
  }

  // A signed (sigOk), pinned, fresh, hash-matching, id-consistent token that HashCore.Step COMMITS: amount 21 >
  // remaining 20 of the stored W_POST. Step6 rejects it with NotAuthorized and changes nothing.
  const UTOK: HashToken := HashToken(PIN_SPEC, PIN_CHK, CV3.HX1, "rq_u", SM.ChargeState("ch_1", 100, 0, true),
                                     SM.Intent("ch_1", "rq_u", 21, CV3.DC), [])
  lemma SignedUnauthorizedRejected()
    ensures var c := Core(CV3.W_POST, {"rq_0", "rq_1"}, [CV3.I0, CV3.I1]);
      Step(CV3.HW, c, UTOK, true).out.Committed? &&
      Step6(CV3.HW, c, UTOK, true) == StepResult6(c, Rejected6(NotAuthorized)) &&
      !F.Authorizes(CV3.W_POST, TransH(UTOK))
  {
    assert "rq_u" != "rq_0" && "rq_u" != "rq_1" by { assert "rq_u"[3] != "rq_0"[3] && "rq_u"[3] != "rq_1"[3]; }
    var c := Core(CV3.W_POST, {"rq_0", "rq_1"}, [CV3.I0, CV3.I1]);
    LostExactlyUnauthorized6(CV3.HW, c, UTOK, true);
  }

  // =============================================================================================
  // CONTRAST 1 (drop H1B).
  lemma BTOKNotAuthorized()
    ensures !F.Authorizes(CV3.W_PRE, TransH(CV3.BTOK)) && !AuthorizesH(CV3.W_PRE, CV3.BTOK)
  {}

  // Any trace whose two actions are a mint and the delivery of BTOK on W_PRE commits nothing under Step6.
  lemma BTrace6(H: HashFn, acts: seq<Act>)
    requires |acts| == 2 && acts[0].MintAct? && acts[1] == Deliver(CV3.BTOK, true)
    ensures TExec6(H, CV3.W_PRE, acts).core == Core(CV3.W_PRE, {}, []) && TExec6(H, CV3.W_PRE, acts).toks == []
  {
    Two6(H, CV3.W_PRE, acts);
    BTOKNotAuthorized();
    UnauthorizedNeverCommits(H, Core(CV3.W_PRE, {}, []), CV3.BTOK, true);
  }

  // A never-minted but AUTHORIZED token, accept-all verifier.
  function AuthNoMintActs(): seq<Act> { [MintAct(CV3.W_PRE, [], []), Deliver(CV3.TK1, true)] }

  lemma AuthNoMintTrace(H: HashFn)
    requires H(CV3.W_PRE) == CV3.HX0
    ensures TExec6(H, CV3.W_PRE, AuthNoMintActs()) ==
            RunSt(Core(CV3.W_POST, {"rq_1"}, [CV3.I1]), [CV3.TK1], [CV3.W_PRE], [1], 2)
  {
    var acts := AuthNoMintActs();
    Two6(H, CV3.W_PRE, acts);
    TransOfWit();
    Step6Exact(H, Core(CV3.W_PRE, {}, []), CV3.TK1, true);
    assert CV3.TK1.preHash == CV3.HX0;
    assert ChargeOfState(CV3.TK1.post) == CV3.W_POST && IntentOfSM(CV3.TK1.intent) == CV3.I1;
    assert {} + {"rq_1"} == {"rq_1"};
  }

  lemma ContrastDropH1B()
    // V3 (ControlsBytesV3.DropH1BBreaksApproval): the trace NoAuthActs commits the UNAPPROVED effect IB.
    ensures var r := TExec(CV3.HW, CV3.W_PRE, CV3.NoAuthActs());
      r.core.outbox == [CV3.IB] && r.pres == [CV3.W_PRE] && |r.toks| == 1 && !Approved(r.pres[0], r.toks[0], r.core.outbox[0])
    // V6: the same trace commits nothing.
    ensures TExec6(CV3.HW, CV3.W_PRE, CV3.NoAuthActs()).core.outbox == []
    // V6, H1B dropped (accept-all verifier; B5 and A2p hold): a never-minted token commits, and it is APPROVED.
    ensures B5_VerifierBoolean(CV3.AcceptAll, AuthNoMintActs()) && A2p_MintsAreIssued(CV3.HW, AuthNoMintActs())
    ensures !H1B_ByteUnforgeability(CV3.AcceptAll, AuthNoMintActs())
    ensures var r := TExec6(CV3.HW, CV3.W_PRE, AuthNoMintActs());
      r.core.outbox == [CV3.I1] && r.pres == [CV3.W_PRE] && r.toks == [CV3.TK1] && r.ks == [1] &&
      Approved(r.pres[0], r.toks[0], r.core.outbox[0]) && !MintedBefore(AuthNoMintActs(), r.ks[0], BytesOf(r.toks[0]))
  {
    CV3.DropH1BBreaksApproval();
    BTrace6(CV3.HW, CV3.NoAuthActs());
    AuthNoMintTrace(CV3.HW);
    var acts := AuthNoMintActs();
    reveal A2p_MintsAreIssued(), H1B_ByteUnforgeability(), B5_VerifierBoolean();
    assert !OurBytes(acts[0].msg) by {
      forall b: SM.TokenBody ensures SM.SignedBytes(b) != [] { CV3.SignedBytesNonEmpty(b); }
    }
    assert BytesOf(CV3.TK1) != [] by { CV3.SignedBytesNonEmpty(BodyOf(CV3.TK1)); }
    assert !MintedBefore(acts, 1, BytesOf(CV3.TK1));
    assert acts[1].Deliver? && CV3.AcceptAll(BytesOf(acts[1].tok), acts[1].tok.sig);
    SliceSafetyBytesV6_L0(CV3.HW, CV3.W_PRE, acts);
    var r := TExec6(CV3.HW, CV3.W_PRE, acts);
    assert EntryL0v6(CV3.HW, CV3.W_PRE, r, 0);
  }

  // =============================================================================================
  // CONTRAST 2 (drop A2p).
  // A faulty signer signs the issued bytes of TK1 (pre-state hash of W_PRE) but under a FOREIGN pre-state P_COLL:
  // no IssueBytes(P_COLL, t) output has these bytes, so A2p fails. TK1 is authorized on the stored W_PRE.
  function UnreqActs(): seq<Act> { [MintAct(CV3.P_COLL, CV3.M1, CV3.SB(CV3.M1)), Deliver(CV3.TK1, true)] }

  lemma UnreqNotIssued(t: F.Transition)
    ensures !IssuedFrom(CV3.HW, CV3.P_COLL, t, CV3.M1)
  {
    if IssuedFrom(CV3.HW, CV3.P_COLL, t, CV3.M1) {
      CV3.Authorized();
      CV3.TokOfBytes(CV3.HW, CV3.W_PRE, CV3.T1);
      IssuedIsTransH(CV3.HW, CV3.P_COLL, t, CV3.TK1);
      TransOfWit();
      AuthorizesDeterminesPre(CV3.P_COLL, CV3.W_PRE, CV3.T1);
      assert false;
    }
  }

  // The hypotheses of the unrequested trace: H1B and B5 hold, A2p fails.
  lemma UnreqHyps()
    ensures H1B_ByteUnforgeability(CV3.TotalVB, UnreqActs()) && B5_VerifierBoolean(CV3.TotalVB, UnreqActs())
    ensures !A2p_MintsAreIssued(CV3.HW, UnreqActs())
    ensures MintedBefore(UnreqActs(), 1, BytesOf(CV3.TK1))
  {
    var acts := UnreqActs();
    CV3.Authorized();
    CV3.TokOfBytes(CV3.HW, CV3.W_PRE, CV3.T1);
    reveal A2p_MintsAreIssued(), H1B_ByteUnforgeability(), B5_VerifierBoolean();
    assert BytesOf(CV3.TK1) == CV3.M1;
    assert OurBytes(acts[0].msg) by {
      assert SM.SignedBytes(BodyOf(CV3.TK1)) == acts[0].msg && BodyOf(CV3.TK1).specLockSha256 == PIN_SPEC;
    }
    forall t: F.Transition ensures !IssuedFrom(CV3.HW, acts[0].pre, t, acts[0].msg) { UnreqNotIssued(t); }
    assert acts[0].MintAct? && acts[0].msg == BytesOf(CV3.TK1);
    assert MintedBefore(acts, 1, BytesOf(CV3.TK1));
    forall k | 0 <= k < |acts| && acts[k].Deliver? && CV3.TotalVB(BytesOf(acts[k].tok), acts[k].tok.sig)
      ensures MintedBefore(acts, k, BytesOf(acts[k].tok))
    { assert k == 1; }
  }

  // The unrequested trace commits TK1; the entry is Approved; it is NOT issued on the stored charge.
  lemma UnreqCommitsApproved()
    ensures var r := TExec6(CV3.HW, CV3.W_PRE, UnreqActs());
      r.core.outbox == [CV3.I1] && r.pres == [CV3.W_PRE] && r.toks == [CV3.TK1] && r.ks == [1] &&
      Approved(r.pres[0], r.toks[0], r.core.outbox[0]) && !IssuedAtStored(CV3.HW, UnreqActs(), r, 0)
  {
    AuthNoMintTrace(CV3.HW);
    var acts := UnreqActs();
    Two6(CV3.HW, CV3.W_PRE, acts);
    Two6(CV3.HW, CV3.W_PRE, AuthNoMintActs());
    var r := TExec6(CV3.HW, CV3.W_PRE, acts);
    assert r == TExec6(CV3.HW, CV3.W_PRE, AuthNoMintActs());
    SliceSafetyBytesV6_L0(CV3.HW, CV3.W_PRE, acts);
    assert EntryL0v6(CV3.HW, CV3.W_PRE, r, 0);
    assert CV3.P_COLL != CV3.W_PRE;
  }

  lemma ContrastDropA2p()
    // V3 (ControlsBytesV3.DropA2pBreaksApproval): the trace BadMintActs commits the UNAPPROVED effect IB.
    ensures var r := TExec(CV3.HW, CV3.W_PRE, CV3.BadMintActs());
      r.core.outbox == [CV3.IB] && r.pres == [CV3.W_PRE] && |r.toks| == 1 && !Approved(r.pres[0], r.toks[0], r.core.outbox[0])
    ensures !A2p_MintsAreIssued(CV3.HW, CV3.BadMintActs())
    ensures H1B_ByteUnforgeability(CV3.TotalVB, CV3.BadMintActs()) && B5_VerifierBoolean(CV3.TotalVB, CV3.BadMintActs())
    // V6: the same trace commits nothing: the faulty signer's unauthorized token is REJECTED.
    ensures TExec6(CV3.HW, CV3.W_PRE, CV3.BadMintActs()).core.outbox == []
    // V6, A2p dropped: an authorized token that the issuer never decided (signed under a foreign pre-state) commits.
    ensures H1B_ByteUnforgeability(CV3.TotalVB, UnreqActs()) && B5_VerifierBoolean(CV3.TotalVB, UnreqActs())
    ensures !A2p_MintsAreIssued(CV3.HW, UnreqActs())
    ensures var r := TExec6(CV3.HW, CV3.W_PRE, UnreqActs());
      r.core.outbox == [CV3.I1] && r.pres == [CV3.W_PRE] && r.toks == [CV3.TK1] && r.ks == [1] &&
      Approved(r.pres[0], r.toks[0], r.core.outbox[0]) && MintedBefore(UnreqActs(), 1, BytesOf(CV3.TK1)) &&
      !IssuedAtStored(CV3.HW, UnreqActs(), r, 0)
  {
    CV3.DropA2pBreaksApproval();
    BTrace6(CV3.HW, CV3.BadMintActs());
    UnreqHyps();
    UnreqCommitsApproved();
  }

  // =============================================================================================
  // CONTRAST 3 (drop A4: the constant hash CV3.HC).
  lemma ContrastDropA4()
    // V3 (ControlsBytesV3.DropA4BreaksApproval): the trace CollActs (stored P_COLL) commits the UNAPPROVED effect I1.
    ensures var r := TExec(CV3.HC, CV3.P_COLL, CV3.CollActs());
      r.core.outbox == [CV3.I1] && r.pres == [CV3.P_COLL] && |r.toks| == 1 && !Approved(r.pres[0], r.toks[0], r.core.outbox[0])
    ensures !A4_HashBindsInRun(CV3.HC, CV3.P_COLL, CV3.CollActs())
    // V6: the same trace commits nothing.
    ensures TExec6(CV3.HC, CV3.P_COLL, CV3.CollActs()).core.outbox == []
  {
    CV3.DropA4BreaksApproval();
    var acts := CV3.CollActs();
    Two6(CV3.HC, CV3.P_COLL, acts);
    CV3.Authorized();
    assert TransH(CV3.TCOLL) == CV3.T1;
    if F.Authorizes(CV3.P_COLL, CV3.T1) { AuthorizesDeterminesPre(CV3.P_COLL, CV3.W_PRE, CV3.T1); }
    UnauthorizedNeverCommits(CV3.HC, Core(CV3.P_COLL, {}, []), CV3.TCOLL, true);
  }

  // With the constant hash, for EVERY trace and EVERY initial charge: each commit is approved on the stored charge,
  // and (with A2p, H1B, B5) issued on exactly the stored charge. No A4.
  lemma ConstHashKeepsL0L2(init: F.Charge, acts: seq<Act>, vb: ByteVerifier)
    requires A2p_MintsAreIssued(CV3.HC, acts) && H1B_ByteUnforgeability(vb, acts) && B5_VerifierBoolean(vb, acts)
    ensures var r := TExec6(CV3.HC, init, acts);
      Shape(r) && forall i | 0 <= i < |r.toks| ::
        Approved(r.pres[i], r.toks[i], r.core.outbox[i]) && IssuedAtStored(CV3.HC, acts, r, i)
  {
    SliceSafetyBytesV6_L0(CV3.HC, init, acts);
    SliceSafetyBytesV6_L2(CV3.HC, init, acts, vb);
    var r := TExec6(CV3.HC, init, acts);
    forall i | 0 <= i < |r.toks| ensures Approved(r.pres[i], r.toks[i], r.core.outbox[i])
    { assert EntryL0v6(CV3.HC, init, r, i); }
  }
}
