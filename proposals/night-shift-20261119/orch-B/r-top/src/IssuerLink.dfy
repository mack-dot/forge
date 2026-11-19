// Night shift 2026-11-19, Orchestrator B, task b-top (T2). A DRAFT in an evidence folder. NOT gate evidence.
// M1-B stays OPEN. end_to_end=false. A Dafny-MODEL statement only. No claim about minter.ts, encoding.ts, Node,
// SHA-256, Ed25519 or compiled code.
//
// T2: connect the d-minter method IssueBytes2.IssueTokenBytes (copy; only its include path is changed, see
// copies-sha256.txt) to the trace hypothesis of SliceSafetyBytesV3.
//  - IssueTokenBytesOut(pre, t, sh, ch, ph, msg) is EXACTLY "IssueTokenBytes(pre, t, sh, ch, ph) returns Some(u) with
//    ToInts(u) == msg" (method IssueTokenBytesExactlyOut proves both directions from the method's postconditions).
//  - A2q: every mint of pinned-id bytes is such an output with ph == H(pre) (for SOME sh, ch, t).
//  - A2qImpliesA2p: A2q ==> A2p_MintsAreIssued. The pinned ids in the bytes force sh == PIN_SPEC and ch == PIN_CHK.
//  - BothIssuers: on one (pre, t), IssueBytes (b-ser2) and IssueTokenBytes(pre, t, PIN_SPEC, PIN_CHK, H(pre))
//    give the same bytes when both give bytes; IssueTokenBytes gives bytes iff IssueBytes does AND the body is WfBody.
//    The WfBody guard only REMOVES mints (for example a charge id that starts with U+0000): NulMintIsA2pNotA2q.
// No assume, no axiom, no bodiless lemma, no {:extern}, no expect in this file.
include "TopFromExport.dfy"
include "IssueBytes2.dfy"

module IssuerLink {
  import opened HashCore
  import opened SliceSafetyBytesV3
  import opened TopFromExport
  import S3 = SliceTheoremV3
  import IB = IssueBytes2

  // The postcondition of IssueTokenBytes on Some, as a predicate on the returned bytes (as ints).
  opaque ghost predicate IssueTokenBytesOut(pre: F.Charge, t: F.Transition, sh: string, ch: string, ph: string, msg: Bytes)
  {
    F.Authorizes(pre, t) && SM.WfBody(IB.BodyFor(sh, ch, ph, t)) && msg == SM.Utf8(SM.SerBody(IB.BodyFor(sh, ch, ph, t)))
  }

  // The predicate is exactly the method's output relation (both directions; the method is called, not copied).
  method IssueTokenBytesExactlyOut(pre: F.Charge, t: F.Transition, sh: string, ch: string, ph: string, msg: Bytes)
      returns (r: SM.Option<seq<IB.uint8>>)
    ensures r.Some? ==> IssueTokenBytesOut(pre, t, sh, ch, ph, IB.ToInts(r.value))
    ensures IssueTokenBytesOut(pre, t, sh, ch, ph, msg) ==> r.Some? && IB.ToInts(r.value) == msg
  {
    reveal IssueTokenBytesOut();
    r := IB.IssueTokenBytes(pre, t, sh, ch, ph);
  }

  // A2q (ASSUMPTION, organisational + proved code): every mint of pinned-id bytes is an output of
  // IssueTokenBytes(pre, t, sh, ch, H(pre)) for the mint's pre and some t, sh, ch (the shell signs only that output,
  // and passes H(pre) as preHashHex: glue G-H of IssueBytes2).
  opaque ghost predicate A2q_MintsAreIssueTokenBytesOutputs(H: HashFn, acts: seq<Act>)
  {
    forall j | 0 <= j < |acts| && acts[j].MintAct? && OurBytes(acts[j].msg) ::
      exists t: F.Transition, sh: string, ch: string :: IssueTokenBytesOut(acts[j].pre, t, sh, ch, H(acts[j].pre), acts[j].msg)
  }

  lemma BodyForIsIssueBody(H: HashFn, pre: F.Charge, t: F.Transition)
    requires MoneyNonNeg(t)
    ensures IB.BodyFor(PIN_SPEC, PIN_CHK, H(pre), t) == IssueBody(H, pre, t)
  {}

  // One mint: an IssueTokenBytes output with pinned ids in its bytes is an IssueBytes output (IssuedFrom).
  lemma OutIsIssuedFrom(H: HashFn, pre: F.Charge, t: F.Transition, sh: string, ch: string, msg: Bytes)
    requires IssueTokenBytesOut(pre, t, sh, ch, H(pre), msg)
    requires OurBytes(msg)
    ensures sh == PIN_SPEC && ch == PIN_CHK
    ensures IssuedFrom(H, pre, t, msg)
  {
    reveal IssueTokenBytesOut();
    AuthorizedMoneyNonNeg(pre, t);
    var b: SM.TokenBody :| SM.SignedBytes(b) == msg && b.specLockSha256 == PIN_SPEC && b.checkerSha256 == PIN_CHK;
    SM.SignedBytesInjective(b, IB.BodyFor(sh, ch, H(pre), t));
    BodyForIsIssueBody(H, pre, t);
  }

  lemma A2qImpliesA2p(H: HashFn, acts: seq<Act>)
    requires A2q_MintsAreIssueTokenBytesOutputs(H, acts)
    ensures A2p_MintsAreIssued(H, acts)
  {
    reveal A2q_MintsAreIssueTokenBytesOutputs(), A2p_MintsAreIssued();
    forall j | 0 <= j < |acts| && acts[j].MintAct? && OurBytes(acts[j].msg)
      ensures exists t: F.Transition :: IssuedFrom(H, acts[j].pre, t, acts[j].msg)
    {
      var t: F.Transition, sh: string, ch: string :| IssueTokenBytesOut(acts[j].pre, t, sh, ch, H(acts[j].pre), acts[j].msg);
      OutIsIssuedFrom(H, acts[j].pre, t, sh, ch, acts[j].msg);
    }
  }

  // The two issuer methods on the same (pre, t): equal bytes on the common domain; the d-minter domain is the
  // b-ser2 domain cut by WfBody.
  method BothIssuers(H: HashFn, pre: F.Charge, t: F.Transition)
      returns (a: SM.Option<Bytes>, b: SM.Option<seq<IB.uint8>>)
    ensures b.Some? ==> a.Some? && IB.ToInts(b.value) == a.value
    ensures a.Some? ==> MoneyNonNeg(t) && (b.Some? <==> SM.WfBody(IssueBody(H, pre, t)))
  {
    a := IssueBytes(H, pre, t);
    b := IB.IssueTokenBytes(pre, t, PIN_SPEC, PIN_CHK, H(pre));
    if a.Some? {
      BodyForIsIssueBody(H, pre, t);
    }
  }

  // T2 LEMMA (A2q in place of A2p; artifact hypothesis on the export as in T1).
  lemma SliceSafetyBytesTop(H: HashFn, init: F.Charge, acts: seq<Act>, vb: ByteVerifier, art: S3.FlatFn)
    requires InitOk(init)
    requires A2q_MintsAreIssueTokenBytesOutputs(H, acts)
    requires H1B_ByteUnforgeability(vb, acts)
    requires B5_VerifierBoolean(vb, acts)
    requires A4_HashBindsInRun(H, init, acts)
    requires A6x_ArtifactMeetsExportedContractOnBytes(art)
    ensures var r := TExec(H, init, acts);
      Shape(r) &&
      (forall e | e in r.core.outbox :: exists i :: FullEntry(H, init, acts, art, r, i, e)) &&
      GoodV3(r.core) &&
      0 <= r.core.charge.remaining <= r.core.charge.original && r.core.charge.original == init.original &&
      SumIntents(r.core.outbox) == init.remaining - r.core.charge.remaining
  {
    A2qImpliesA2p(H, acts);
    SliceSafetyBytesFromExport(H, init, acts, vb, art);
  }

  // The same with A6b (the b-ser2 form of the artifact hypothesis).
  lemma SliceSafetyBytesFromIssuer(H: HashFn, init: F.Charge, acts: seq<Act>, vb: ByteVerifier, art: S3.FlatFn)
    requires InitOk(init)
    requires A2q_MintsAreIssueTokenBytesOutputs(H, acts)
    requires H1B_ByteUnforgeability(vb, acts)
    requires B5_VerifierBoolean(vb, acts)
    requires A4_HashBindsInRun(H, init, acts)
    requires S3.A6b_ArtifactComputesFlatContractOnBytes(art)
    ensures var r := TExec(H, init, acts);
      Shape(r) &&
      (forall e | e in r.core.outbox :: exists i :: FullEntry(H, init, acts, art, r, i, e)) &&
      GoodV3(r.core) &&
      0 <= r.core.charge.remaining <= r.core.charge.original && r.core.charge.original == init.original &&
      SumIntents(r.core.outbox) == init.remaining - r.core.charge.remaining
  {
    A2qImpliesA2p(H, acts);
    SliceSafetyBytesV3.SliceSafetyBytesV3(H, init, acts, vb, art);
  }
}

module IssuerLinkControls {
  import opened HashCore
  import opened SliceSafetyBytesV3
  import opened TopFromExport
  import opened IssuerLink
  import S3 = SliceTheoremV3
  import C = ControlsBytesV3
  import IB = IssueBytes2
  import TC = TopFromExportControls

  lemma OutOfIssued(H: HashFn, pre: F.Charge, t: F.Transition, msg: Bytes)
    requires IssuedFrom(H, pre, t, msg) && SM.WfBody(IssueBody(H, pre, t))
    ensures IssueTokenBytesOut(pre, t, PIN_SPEC, PIN_CHK, H(pre), msg)
  {
    reveal IssueTokenBytesOut();
    BodyForIsIssueBody(H, pre, t);
  }

  lemma Out0() ensures IssueTokenBytesOut(C.W_PRE, C.T0, PIN_SPEC, PIN_CHK, C.HW(C.W_PRE), C.M0)
  {
    C.Authorized(); C.WfTK0();
    assert BodyOf(C.TK0) == IssueBody(C.HW, C.W_PRE, C.T0);
    OutOfIssued(C.HW, C.W_PRE, C.T0, C.M0);
  }
  lemma Out1() ensures IssueTokenBytesOut(C.W_PRE, C.T1, PIN_SPEC, PIN_CHK, C.HW(C.W_PRE), C.M1)
  {
    C.Authorized(); C.WfTK1();
    assert BodyOf(C.TK1) == IssueBody(C.HW, C.W_PRE, C.T1);
    OutOfIssued(C.HW, C.W_PRE, C.T1, C.M1);
  }
  lemma OutC() ensures IssueTokenBytesOut(C.C2_PRE, C.TC, PIN_SPEC, PIN_CHK, C.HW(C.C2_PRE), C.MC)
  {
    C.Authorized(); C.WfTKC();
    assert BodyOf(C.TKC) == IssueBody(C.HW, C.C2_PRE, C.TC);
    OutOfIssued(C.HW, C.C2_PRE, C.TC, C.MC);
  }

  lemma WitA2q()
    ensures A2q_MintsAreIssueTokenBytesOutputs(C.HW, C.WActs())
  {
    reveal A2q_MintsAreIssueTokenBytesOutputs();
    var acts := C.WActs();
    Out0(); Out1(); OutC();
    forall j | 0 <= j < |acts| && acts[j].MintAct? && OurBytes(acts[j].msg)
      ensures exists t: F.Transition, sh: string, ch: string ::
        IssueTokenBytesOut(acts[j].pre, t, sh, ch, C.HW(acts[j].pre), acts[j].msg)
    {
      if j == 0 { assert acts[j].pre == C.W_PRE && acts[j].msg == C.M0; }
      else if j == 3 { assert acts[j].pre == C.W_PRE && acts[j].msg == C.M1; }
      else { assert j == 6; assert acts[j].pre == C.C2_PRE && acts[j].msg == C.MC; }
    }
  }

  // Non-vacuity: the b-ser2 witness run meets A2q and A6x; the T2 lemma covers a zero-amount and a positive effect.
  lemma WitnessTop()
    ensures A2q_MintsAreIssueTokenBytesOutputs(C.HW, C.WActs())
    ensures InitOk(C.W_PRE) && H1B_ByteUnforgeability(C.TotalVB, C.WActs())
    ensures B5_VerifierBoolean(C.TotalVB, C.WActs()) && A4_HashBindsInRun(C.HW, C.W_PRE, C.WActs())
    ensures A6x_ArtifactMeetsExportedContractOnBytes(S3.FlatSpecFn)
    ensures TExec(C.HW, C.W_PRE, C.WActs()).core.outbox == [C.I0, C.I1] && C.I0.amount == 0 && C.I1.amount == 40
    ensures var r := TExec(C.HW, C.W_PRE, C.WActs());
      forall e | e in r.core.outbox :: exists i :: FullEntry(C.HW, C.W_PRE, C.WActs(), S3.FlatSpecFn, r, i, e)
  {
    WitA2q();
    TC.WitnessFromExport();
    SliceSafetyBytesTop(C.HW, C.W_PRE, C.WActs(), C.TotalVB, S3.FlatSpecFn);
  }

  // Control: the key signs pinned-id bytes that are NOT an IssueTokenBytes output (amount 61 > remaining 60).
  // Every other hypothesis holds; A2q fails; an unapproved effect commits.
  lemma DropA2qBreaksApproval()
    ensures !A2q_MintsAreIssueTokenBytesOutputs(C.HW, C.BadMintActs())
    ensures InitOk(C.W_PRE)
    ensures H1B_ByteUnforgeability(C.TotalVB, C.BadMintActs()) && B5_VerifierBoolean(C.TotalVB, C.BadMintActs())
    ensures A4_HashBindsInRun(C.HW, C.W_PRE, C.BadMintActs())
    ensures var r := TExec(C.HW, C.W_PRE, C.BadMintActs());
      r.core.outbox == [C.IB] && r.pres == [C.W_PRE] && |r.toks| == 1 && !Approved(r.pres[0], r.toks[0], r.core.outbox[0])
  {
    C.DropA2pBreaksApproval();
    if A2q_MintsAreIssueTokenBytesOutputs(C.HW, C.BadMintActs()) {
      A2qImpliesA2p(C.HW, C.BadMintActs());
    }
  }

  // The WfBody guard only removes mints: a checker-authorized transition of a charge id that starts with U+0000
  // gives an IssueBytes output with pinned ids that NO IssueTokenBytes call outputs. So A2q is strictly stronger
  // per mint than A2p, and A2q ==> A2p (above) loses nothing.
  lemma NulMintIsA2pNotA2q(H: HashFn)
    ensures F.Authorizes(IB.NUL_PRE, IB.T(IB.NUL_PRE, "rq_1", 40))
    ensures MoneyNonNeg(IB.T(IB.NUL_PRE, "rq_1", 40))
    ensures var msg := IssueOut(H, IB.NUL_PRE, IB.T(IB.NUL_PRE, "rq_1", 40));
      IssuedFrom(H, IB.NUL_PRE, IB.T(IB.NUL_PRE, "rq_1", 40), msg) && OurBytes(msg) &&
      forall t: F.Transition, sh: string, ch: string :: !IssueTokenBytesOut(IB.NUL_PRE, t, sh, ch, H(IB.NUL_PRE), msg)
  {
    var t0 := IB.T(IB.NUL_PRE, "rq_1", 40);
    assert F.Authorizes(IB.NUL_PRE, t0);
    AuthorizedMoneyNonNeg(IB.NUL_PRE, t0);
    var msg := IssueOut(H, IB.NUL_PRE, t0);
    var b0 := IssueBody(H, IB.NUL_PRE, t0);
    assert SM.SignedBytes(b0) == msg && b0.specLockSha256 == PIN_SPEC && b0.checkerSha256 == PIN_CHK;
    assert b0.post.chargeId == IB.NUL_PRE.chargeId == [0 as char] + "ch_1";
    assert |b0.post.chargeId| == 5 && b0.post.chargeId[0] as int == 0;
    assert !SM.Text(b0.post.chargeId);
    assert !SM.WfBody(b0);
    forall t: F.Transition, sh: string, ch: string
      ensures !IssueTokenBytesOut(IB.NUL_PRE, t, sh, ch, H(IB.NUL_PRE), msg)
    {
      reveal IssueTokenBytesOut();
      if IssueTokenBytesOut(IB.NUL_PRE, t, sh, ch, H(IB.NUL_PRE), msg) {
        SM.SignedBytesInjective(b0, IB.BodyFor(sh, ch, H(IB.NUL_PRE), t));
      }
    }
  }
}
