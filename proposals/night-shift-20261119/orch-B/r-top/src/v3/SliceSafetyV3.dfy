// Night shift 2026-11-19, Orchestrator B, task b-integrate (G2). A DRAFT in an evidence folder. NOT approved.
// NOT gate evidence. M1-B stays OPEN. end_to_end=false. A Dafny-MODEL statement only. It says nothing about
// sink.ts, minter.ts, Ed25519, compiled code, the HOL model, CakeML or native execution.
//
// Purpose. The composed slice theorem of b-signing (SliceSafetyV2OnByteStrings) over the core SinkCoreV3 (G1),
// stated in LAYERS. Each layer is a separate lemma with only the hypotheses that it needs:
//   L0 SliceSafetyV3_L0_NoAssumption  no hypothesis at all (any trace of mints and deliveries, any tokens, any sigOk)
//   L1 SliceSafetyV3_L1_A5            A5 only
//   L2 SliceSafetyV3_L2_Authentic     InitOk + H1 + A2 + A5
//   L3 SliceSafetyV3_L3_Artifact      InitOk + H1 + A2 + A5 + A6b
//   SliceSafetyV3                     all of them together (the V2 shape plus the L0 conclusions)
// No IdealMac anywhere (FinalityProtocol defines it; this file never uses it). The trace machinery (Act, Next,
// Exec, CommittedAt, ...) and the flat-artifact part are COPIES of the text of inputs/SliceTheorem.dfy,
// SliceSafetyV2.dfy and SliceSafetyV2OnBytes.dfy (b-signing), retargeted at SinkCoreV3. Difference: a delivery
// moves the model state by SinkCoreV3.ModelStep (the model's Commit, or a stutter for a token that fails the
// request-id or charge-id check), not by Commit itself.
// Uninterpreted symbol: VerifyTag. No assume, no axiom, no bodiless lemma in this file.
include "inputs/LinkedRefund.dfy"
include "SinkCoreV3.dfy"

module SliceTheoremV3 {
  import opened SinkCoreV3
  import L = LinkedRefund
  import U = RefundUnicode
  import FR = FlatRefund

  // =============================================================================================
  // The artifact boundary (copied from SliceTheorem and SliceTheoremV2B).
  datatype FlatIn = FlatIn(chargeB: string, requestB: string, original: int, remaining: int,
                           enabled: bool, requestOpen: bool, candidate: bool, amount: int, reasonB: string)
  type FlatFn = FlatIn -> L.FlatTuple

  predicate FlatContract(x: FlatIn, o: L.FlatTuple)
  {
    (o.0 <==>
      x.chargeB != "" && x.requestB != "" && x.enabled && x.requestOpen &&
      0 <= x.original <= 9223372036854775807 && 0 <= x.remaining <= x.original &&
      x.candidate && 0 <= x.amount <= x.remaining &&
      (x.reasonB == "duplicate_charge" || x.reasonB == "service_not_delivered" || x.reasonB == "returned_item")) &&
    (o.0 ==> o.1 == x.amount && o.2 == x.reasonB && o.3 == x.chargeB && o.4 == x.requestB && o.5 == 1) &&
    (!o.0 ==> o.1 == 0 && o.2 == "" && o.3 == "" && o.4 == "" && o.5 == 0)
  }

  method FlatContractFromAssessFlat(x: FlatIn) returns (o: L.FlatTuple)
    ensures FlatContract(x, o)
  {
    var ok, a, rb, cb, qb, n := FR.AssessFlat(x.chargeB, x.requestB, x.original, x.remaining, x.enabled,
                                              x.requestOpen, x.candidate, x.amount, x.reasonB);
    o := (ok, a, rb, cb, qb, n);
  }

  method FlatContractIsAssessFlat(x: FlatIn, o: L.FlatTuple) returns (o2: L.FlatTuple)
    requires FlatContract(x, o)
    ensures o2 == o
  {
    var ok, a, rb, cb, qb, n := FR.AssessFlat(x.chargeB, x.requestB, x.original, x.remaining, x.enabled,
                                              x.requestOpen, x.candidate, x.amount, x.reasonB);
    o2 := (ok, a, rb, cb, qb, n);
  }

  ghost predicate A6_ArtifactComputesFlatContract(art: FlatFn)
  {
    forall x: FlatIn :: FlatContract(x, art(x))
  }

  predicate IsByteString(s: string)
  {
    forall i | 0 <= i < |s| :: 0 <= s[i] as int < 256
  }

  predicate ByteInputs(x: FlatIn)
  {
    IsByteString(x.chargeB) && IsByteString(x.requestB) && IsByteString(x.reasonB)
  }

  // A6b: the ValidArtifact hypothesis on byte-string inputs only. NOT proved.
  ghost predicate A6b_ArtifactComputesFlatContractOnBytes(art: FlatFn)
  {
    forall x: FlatIn | ByteInputs(x) :: FlatContract(x, art(x))
  }

  lemma A6ImpliesA6b(art: FlatFn)
    requires A6_ArtifactComputesFlatContract(art)
    ensures A6b_ArtifactComputesFlatContractOnBytes(art)
  {
  }

  function FlatInputsOf(pre: F.Charge, e: R.RefundIntent): FlatIn
  {
    FlatIn(U.Encoded(pre.chargeId), U.Encoded(e.requestId), pre.original, pre.remaining, pre.refundEnabled,
           true, true, e.amount, U.Encoded(e.reason))
  }

  lemma FlatInputsAreBytes(pre: F.Charge, e: R.RefundIntent)
    ensures ByteInputs(FlatInputsOf(pre, e))
  {
    U.EncodedIsBytes(pre.chargeId);
    U.EncodedIsBytes(e.requestId);
    U.EncodedIsBytes(e.reason);
  }

  // FlatPath with A6b (the inputs are byte strings, so A6b applies).
  lemma FlatPathBytes(art: FlatFn, pre: F.Charge, req: F.Request, post: F.Charge, e: R.RefundIntent)
    requires A6b_ArtifactComputesFlatContractOnBytes(art)
    requires F.Authorizes(pre, F.Transition(req, post, e))
    ensures var o := art(FlatInputsOf(pre, e));
      L.Unflatten(o.0, o.1, o.2, o.3, o.4, o.5) ==
        (L.Authorized(e.amount, e.reason), [L.Intent(e.chargeId, e.requestId, e.amount, e.reason)])
  {
    var x := FlatInputsOf(pre, e);
    FlatInputsAreBytes(pre, e);
    var o := art(x);
    assert FlatContract(x, o);
    U.EncodedEmpty(pre.chargeId);
    U.EncodedEmpty(e.requestId);
    U.SameReasons(e.reason);
    assert o.0;
    L.DecodeEncoded(e.reason);
    L.DecodeEncoded(pre.chargeId);
    L.DecodeEncoded(e.requestId);
  }

  function FlatSpecFn(x: FlatIn): L.FlatTuple
  {
    if x.chargeB != "" && x.requestB != "" && x.enabled && x.requestOpen &&
       0 <= x.original <= 9223372036854775807 && 0 <= x.remaining <= x.original &&
       x.candidate && 0 <= x.amount <= x.remaining &&
       (x.reasonB == "duplicate_charge" || x.reasonB == "service_not_delivered" || x.reasonB == "returned_item")
    then (true, x.amount, x.reasonB, x.chargeB, x.requestB, 1)
    else (false, 0, "", "", "", 0)
  }

  lemma FlatSpecFnMeetsA6b()
    ensures A6_ArtifactComputesFlatContract(FlatSpecFn) && A6b_ArtifactComputesFlatContractOnBytes(FlatSpecFn)
  {
  }

  // =============================================================================================
  // Reachability (copied from SliceTheorem; a delivery moves the model by ModelStep).
  datatype Act = MintAct(c: Claim, tag: Tag) | Deliver(tok: SinkToken, sigOk: bool)
  datatype RunSt = RunSt(core: Core, s: System, toks: seq<SinkToken>)

  function CheckedClaim(pre: F.Charge, t: F.Transition): Claim
  {
    ClaimOf(SinkToken(PINNED_SPEC, PINNED_CHK, pre, t.request.requestId, t.post, t.intent, ""))
  }

  ghost function Next(r: RunSt, a: Act): RunSt
  {
    match a
    case MintAct(c, tag) => RunSt(r.core, r.s.(minted := r.s.minted + {(c, tag)}), r.toks)
    case Deliver(tok, sigOk) =>
      var res := Step(r.core, tok, sigOk);
      RunSt(res.core, ModelStep(r.s, tok), NextToks(r.toks, tok, res.out))
  }

  ghost function Exec(init: State, acts: seq<Act>): RunSt
    decreases |acts|
  {
    if |acts| == 0 then RunSt(Core(init, {}, []), Sys(init, [], {}, [], {}), [])
    else Next(Exec(init, acts[..|acts| - 1]), acts[|acts| - 1])
  }

  lemma ExecStep(init: State, acts: seq<Act>, k: int)
    requires 0 <= k < |acts|
    ensures Exec(init, acts[..k + 1]) == Next(Exec(init, acts[..k]), acts[k])
  {
    assert acts[..k + 1][..k] == acts[..k];
    assert acts[..k + 1][k] == acts[k];
  }

  // ---- the named hypotheses over a trace ----
  ghost predicate A2_MintOnlyOnCheck(acts: seq<Act>)
  {
    forall k | 0 <= k < |acts| && acts[k].MintAct? && Ours(acts[k].c) ::
      exists pre: F.Charge, t: F.Transition :: F.Authorizes(pre, t) && acts[k].c == CheckedClaim(pre, t)
  }

  ghost predicate A5_VerifierMatchesAtEachDelivery(acts: seq<Act>)
  {
    forall k | 0 <= k < |acts| && acts[k].Deliver? :: A5_VerifierMatches(acts[k].tok, acts[k].sigOk)
  }

  ghost predicate SignedBefore(acts: seq<Act>, k: int, c: Claim)
  {
    exists j :: 0 <= j < k && j < |acts| && acts[j].MintAct? && acts[j].c == c
  }

  ghost predicate H1_SignatureAuthenticity(acts: seq<Act>)
  {
    forall k | 0 <= k < |acts| && acts[k].Deliver? ::
      VerifyTag(ClaimOf(acts[k].tok), acts[k].tok.sig) ==> SignedBefore(acts, k, ClaimOf(acts[k].tok))
  }

  // ---- the conclusions ----
  ghost predicate CommittedEffect(init: State, acts: seq<Act>, e: R.RefundIntent)
  {
    e in Exec(init, acts).core.outbox
  }

  ghost predicate CommittedAt(init: State, acts: seq<Act>, k: int, i: int)
  {
    0 <= k < |acts| && acts[k].Deliver? &&
    var before := Exec(init, acts[..k]);
    |before.toks| == i &&
    Step(before.core, acts[k].tok, acts[k].sigOk).out.Committed? &&
    before.core.charge == acts[k].tok.pre &&
    acts[k].tok.requestId !in before.core.settled &&
    i < |Exec(init, acts).toks| && Exec(init, acts).toks[i] == acts[k].tok
  }

  ghost predicate HasCommitWitness(init: State, acts: seq<Act>, i: int)
  {
    exists k :: CommittedAt(init, acts, k, i)
  }

  // L0 conclusion: unique authorization at the CORE level (no signature part).
  ghost predicate UniqueAuthorizationCore(init: State, acts: seq<Act>, i: int)
  {
    var r := Exec(init, acts);
    0 <= i < |r.toks| && |r.toks| == |r.core.outbox| &&
    HasCommitWitness(init, acts, i) &&
    r.core.outbox[i] == r.toks[i].intent &&
    r.core.outbox[i].requestId == r.toks[i].requestId && r.toks[i].requestId in r.core.settled &&
    r.core.outbox[i].chargeId == init.chargeId && r.toks[i].pre.chargeId == init.chargeId &&
    r.toks[i].post.chargeId == init.chargeId && r.core.charge.chargeId == init.chargeId &&
    (forall j | 0 <= j < |r.core.outbox| && j != i ::
       r.core.outbox[j].requestId != r.core.outbox[i].requestId && r.toks[j] != r.toks[i])
  }

  // L1 conclusion: the committed claim is the claim of its token and its tag verifies.
  ghost predicate TagVerifies(init: State, acts: seq<Act>, i: int)
  {
    var r := Exec(init, acts);
    0 <= i < |r.toks| && |r.toks| == |r.s.log| &&
    r.s.log[i] == ClaimOf(r.toks[i]) && VerifyTag(r.s.log[i], r.toks[i].sig)
  }

  // L2 conclusions.
  ghost predicate ClaimHasSig(s: System, c: Claim)
  {
    exists t' :: (c, t') in s.minted
  }

  ghost predicate SignedInTrace(init: State, acts: seq<Act>, i: int)
  {
    var r := Exec(init, acts);
    0 <= i < |r.s.log| && ClaimHasSig(r.s, r.s.log[i]) && SignedBefore(acts, |acts|, r.s.log[i])
  }

  ghost predicate ApprovedSpec(init: State, acts: seq<Act>, i: int)
  {
    var r := Exec(init, acts);
    0 <= i < |r.toks| && i < |r.core.outbox| &&
    var tok := r.toks[i];
    var e := r.core.outbox[i];
    HasCommitWitness(init, acts, i) &&
    e == tok.intent && e.requestId == tok.requestId && e.chargeId == tok.pre.chargeId &&
    R.Eligible(F.ContextOf(tok.pre, e.requestId), R.Candidate(e.amount, e.reason)) &&
    F.Authorizes(tok.pre, F.Transition(F.Request(e.requestId, e.amount, e.reason), tok.post, e))
  }

  // L3 conclusion.
  ghost predicate FlatResultAgrees(art: FlatFn, init: State, acts: seq<Act>, i: int)
  {
    var r := Exec(init, acts);
    0 <= i < |r.toks| && i < |r.core.outbox| &&
    var e := r.core.outbox[i];
    var o := art(FlatInputsOf(r.toks[i].pre, e));
    L.Unflatten(o.0, o.1, o.2, o.3, o.4, o.5) ==
      (L.Authorized(e.amount, e.reason), [L.Intent(e.chargeId, e.requestId, e.amount, e.reason)])
  }

  // =============================================================================================
  // L0 proofs: no hypothesis.
  ghost predicate CoreInv(init: State, r: RunSt)
  {
    GoodV3(r.core) && r.core.charge.chargeId == init.chargeId &&
    |r.toks| == |r.core.outbox| &&
    (forall i | 0 <= i < |r.toks| ::
       r.core.outbox[i] == r.toks[i].intent && Match(r.toks[i]) &&
       r.toks[i].pre.chargeId == init.chargeId && r.toks[i].post.chargeId == init.chargeId)
  }

  lemma NextKeepsCoreInv(init: State, r: RunSt, a: Act)
    requires CoreInv(init, r)
    ensures CoreInv(init, Next(r, a))
  {
    match a
    case MintAct(c, tag) =>
    case Deliver(tok, sigOk) =>
      StepExact(r.core, tok, sigOk);
      StepKeepsGoodV3(r.core, tok, sigOk);
      var r' := Next(r, a);
      if Step(r.core, tok, sigOk).out.Committed? {
        assert r'.toks == r.toks + [tok] && r'.core.outbox == r.core.outbox + [tok.intent];
        forall i | 0 <= i < |r'.toks|
          ensures r'.core.outbox[i] == r'.toks[i].intent && Match(r'.toks[i]) &&
                  r'.toks[i].pre.chargeId == init.chargeId && r'.toks[i].post.chargeId == init.chargeId
        {
          if i < |r.toks| {
            assert r'.toks[i] == r.toks[i] && r'.core.outbox[i] == r.core.outbox[i];
          } else {
            assert r'.toks[i] == tok && r'.core.outbox[i] == tok.intent;
          }
        }
      }
  }

  lemma ExecCore(init: State, acts: seq<Act>)
    ensures CoreInv(init, Exec(init, acts))
    decreases |acts|
  {
    if |acts| == 0 {
      InitGood(init);
    } else {
      ExecCore(init, acts[..|acts| - 1]);
      NextKeepsCoreInv(init, Exec(init, acts[..|acts| - 1]), acts[|acts| - 1]);
    }
  }

  lemma ExecCommitWitness(init: State, acts: seq<Act>)
    ensures forall i | 0 <= i < |Exec(init, acts).toks| :: HasCommitWitness(init, acts, i)
    decreases |acts|
  {
    if |acts| > 0 {
      var n := |acts|;
      var p := acts[..n - 1];
      ExecCommitWitness(init, p);
      var r := Exec(init, p);
      var r' := Exec(init, acts);
      assert r' == Next(r, acts[n - 1]);
      assert |r.toks| <= |r'.toks| && r'.toks[..|r.toks|] == r.toks;
      forall i | 0 <= i < |r'.toks|
        ensures HasCommitWitness(init, acts, i)
      {
        if i < |r.toks| {
          assert HasCommitWitness(init, p, i);
          var k :| CommittedAt(init, p, k, i);
          assert acts[..k] == p[..k];
          assert acts[k] == p[k];
          assert r'.toks[i] == r.toks[i];
          assert CommittedAt(init, acts, k, i);
        } else {
          assert acts[n - 1].Deliver?;
          assert acts[..n - 1] == p;
          assert CommittedAt(init, acts, n - 1, i);
        }
      }
    }
  }

  lemma PerEntryCore(init: State, acts: seq<Act>, i: int)
    requires 0 <= i < |Exec(init, acts).core.outbox|
    ensures UniqueAuthorizationCore(init, acts, i)
  {
    var r := Exec(init, acts);
    ExecCore(init, acts);
    ExecCommitWitness(init, acts);
    assert r.toks[i].requestId == r.core.outbox[i].requestId;
    assert r.core.outbox[i].requestId in r.core.settled;
    forall j | 0 <= j < |r.core.outbox| && j != i
      ensures r.core.outbox[j].requestId != r.core.outbox[i].requestId && r.toks[j] != r.toks[i]
    {
      if j < i {
        assert r.core.outbox[j].requestId != r.core.outbox[i].requestId;
      } else {
        assert r.core.outbox[i].requestId != r.core.outbox[j].requestId;
      }
      assert r.core.outbox[j] == r.toks[j].intent;
    }
  }

  lemma RejectedDeliveryChangesNothing(init: State, acts: seq<Act>, k: int)
    requires 0 <= k < |acts| && acts[k].Deliver?
    requires !Step(Exec(init, acts[..k]).core, acts[k].tok, acts[k].sigOk).out.Committed?
    ensures Exec(init, acts[..k + 1]).core == Exec(init, acts[..k]).core
    ensures Exec(init, acts[..k + 1]).toks == Exec(init, acts[..k]).toks
  {
    ExecStep(init, acts, k);
    StepExact(Exec(init, acts[..k]).core, acts[k].tok, acts[k].sigOk);
  }

  // THE L0 THEOREM. No hypothesis: any init, any trace of mints and deliveries, any tokens, any sigOk.
  lemma SliceSafetyV3_L0_NoAssumption(init: State, acts: seq<Act>)
    ensures forall e | CommittedEffect(init, acts, e) ::
      exists i :: 0 <= i < |Exec(init, acts).core.outbox| && Exec(init, acts).core.outbox[i] == e &&
        UniqueAuthorizationCore(init, acts, i)
    ensures forall e | CommittedEffect(init, acts, e) :: e.chargeId == init.chargeId
    ensures GoodV3(Exec(init, acts).core) && Exec(init, acts).core.charge.chargeId == init.chargeId
    ensures forall k | 0 <= k < |acts| && acts[k].Deliver? &&
        !Step(Exec(init, acts[..k]).core, acts[k].tok, acts[k].sigOk).out.Committed? ::
      Exec(init, acts[..k + 1]).core == Exec(init, acts[..k]).core
  {
    var r := Exec(init, acts);
    ExecCore(init, acts);
    forall e | CommittedEffect(init, acts, e)
      ensures exists i :: 0 <= i < |r.core.outbox| && r.core.outbox[i] == e && UniqueAuthorizationCore(init, acts, i)
      ensures e.chargeId == init.chargeId
    {
      var i :| 0 <= i < |r.core.outbox| && r.core.outbox[i] == e;
      PerEntryCore(init, acts, i);
    }
    forall k | 0 <= k < |acts| && acts[k].Deliver? &&
        !Step(Exec(init, acts[..k]).core, acts[k].tok, acts[k].sigOk).out.Committed?
      ensures Exec(init, acts[..k + 1]).core == Exec(init, acts[..k]).core
    {
      RejectedDeliveryChangesNothing(init, acts, k);
    }
  }

  // =============================================================================================
  // L1 proofs: A5 only.
  lemma PrefixA5(acts: seq<Act>)
    requires |acts| > 0 && A5_VerifierMatchesAtEachDelivery(acts)
    ensures A5_VerifierMatchesAtEachDelivery(acts[..|acts| - 1])
  {
    var p := acts[..|acts| - 1];
    forall k | 0 <= k < |p|
      ensures p[k] == acts[k]
    {
    }
  }

  lemma ExecRel(init: State, acts: seq<Act>)
    requires A5_VerifierMatchesAtEachDelivery(acts)
    ensures Rel(Exec(init, acts).core, Exec(init, acts).s, Exec(init, acts).toks)
    decreases |acts|
  {
    if |acts| == 0 {
      InitRel(init);
    } else {
      var n := |acts|;
      var p := acts[..n - 1];
      PrefixA5(acts);
      ExecRel(init, p);
      var r := Exec(init, p);
      assert Exec(init, acts) == Next(r, acts[n - 1]);
      match acts[n - 1]
      case MintAct(c, tag) =>
        MintKeepsRel(r.core, r.s, r.toks, c, tag);
      case Deliver(tok, sigOk) =>
        assert acts[n - 1].Deliver?;
        assert A5_VerifierMatches(tok, sigOk);
        StepRefinesModelStep(r.core, r.s, r.toks, tok, sigOk);
    }
  }

  // THE L1 THEOREM. A5 only: every committed effect is the effect of a claim whose tag verifies, and the core
  // refines the model (Rel).
  lemma SliceSafetyV3_L1_A5(init: State, acts: seq<Act>)
    requires A5_VerifierMatchesAtEachDelivery(acts)
    ensures Rel(Exec(init, acts).core, Exec(init, acts).s, Exec(init, acts).toks)
    ensures forall i | 0 <= i < |Exec(init, acts).core.outbox| :: TagVerifies(init, acts, i)
  {
    ExecRel(init, acts);
    ExecCore(init, acts);
  }

  // =============================================================================================
  // L2 proofs: InitOk + H1 + A2 + A5. (Copied from SliceSafetyV2; Commit replaced by ModelStep.)
  ghost function MintsOf(acts: seq<Act>): set<(Claim, Tag)>
    decreases |acts|
  {
    if |acts| == 0 then {}
    else MintsOf(acts[..|acts| - 1]) +
         (if acts[|acts| - 1].MintAct? then {(acts[|acts| - 1].c, acts[|acts| - 1].tag)} else {})
  }

  lemma ModelStepKeepsMinted(s: System, tok: SinkToken)
    ensures ModelStep(s, tok).minted == s.minted
  {
  }

  lemma OnlyMintActionsSign(init: State, acts: seq<Act>)
    ensures Exec(init, acts).s.minted == MintsOf(acts)
    decreases |acts|
  {
    if |acts| > 0 {
      var p := acts[..|acts| - 1];
      OnlyMintActionsSign(init, p);
      var r := Exec(init, p);
      assert Exec(init, acts) == Next(r, acts[|acts| - 1]);
      match acts[|acts| - 1]
      case MintAct(c, tag) =>
      case Deliver(tok, sigOk) =>
        ModelStepKeepsMinted(r.s, tok);
    }
  }

  lemma MintInMintsOf(acts: seq<Act>, j: int)
    requires 0 <= j < |acts| && acts[j].MintAct?
    ensures (acts[j].c, acts[j].tag) in MintsOf(acts)
    decreases |acts|
  {
    if j < |acts| - 1 {
      var p := acts[..|acts| - 1];
      assert p[j] == acts[j];
      MintInMintsOf(p, j);
    }
  }

  lemma MintsOfHasSource(acts: seq<Act>, c: Claim, t: Tag)
    requires (c, t) in MintsOf(acts)
    ensures exists j :: 0 <= j < |acts| && acts[j] == MintAct(c, t)
    decreases |acts|
  {
    var n := |acts|;
    var p := acts[..n - 1];
    if (c, t) in MintsOf(p) {
      MintsOfHasSource(p, c, t);
      var j :| 0 <= j < |p| && p[j] == MintAct(c, t);
      assert acts[j] == p[j];
    } else {
      assert acts[n - 1] == MintAct(c, t);
    }
  }

  ghost predicate LocalClaimSigned(s: System, c: Claim, t: Tag)
  {
    VerifyTag(c, t) ==> ClaimHasSig(s, c)
  }

  ghost predicate ClaimsSigned(s: System)
  {
    forall i | 0 <= i < |s.log| :: ClaimHasSig(s, s.log[i])
  }

  lemma LocalClaimSignedKeepsInv(init: State, s: System, c: Claim, t: Tag)
    requires Inv(init, s)
    requires LocalClaimSigned(s, c, t)
    ensures Inv(init, Commit(s, c, t))
  {
    CommitKeepsChain(init, s, c, t);
    CommitKeepsDistinctIds(s, c, t);
    CommitKeepsSettledIsLog(s, c, t);
    CommitKeepsOutboxIsLog(s, c, t);
    if SinkAccepts(s, c, t) {
      var t' :| (c, t') in s.minted;
      assert Ours(c) && SpecRel(c.pre, c.req, c.post, c.eff);
      var log' := s.log + [c];
      forall i | 0 <= i < |log'|
        ensures Ours(log'[i]) && SpecRel(log'[i].pre, log'[i].req, log'[i].post, log'[i].eff)
      {
        if i < |s.log| {
          assert log'[i] == s.log[i];
        } else {
          assert log'[i] == c;
        }
      }
    }
  }

  lemma CommitKeepsClaimsSigned(s: System, c: Claim, t: Tag)
    requires ClaimsSigned(s) && LocalClaimSigned(s, c, t)
    ensures ClaimsSigned(Commit(s, c, t))
  {
    if SinkAccepts(s, c, t) {
      var s' := Commit(s, c, t);
      assert s'.minted == s.minted && s'.log == s.log + [c];
      var tc :| (c, tc) in s.minted;
      forall i | 0 <= i < |s'.log|
        ensures ClaimHasSig(s', s'.log[i])
      {
        if i < |s.log| {
          assert s'.log[i] == s.log[i];
          var t' :| (s.log[i], t') in s.minted;
          assert (s'.log[i], t') in s'.minted;
        } else {
          assert s'.log[i] == c;
          assert (s'.log[i], tc) in s'.minted;
        }
      }
      assert ClaimsSigned(s');
    }
  }

  lemma MintKeepsClaimsSigned(s: System, c: Claim, t: Tag)
    requires ClaimsSigned(s)
    ensures ClaimsSigned(s.(minted := s.minted + {(c, t)}))
  {
    var s' := s.(minted := s.minted + {(c, t)});
    assert s'.log == s.log;
    forall i | 0 <= i < |s'.log|
      ensures ClaimHasSig(s', s'.log[i])
    {
      assert s'.log[i] == s.log[i];
      var t' :| (s.log[i], t') in s.minted;
      assert (s'.log[i], t') in s'.minted;
    }
    assert ClaimsSigned(s');
  }

  lemma CheckedClaimAllowed(pre: F.Charge, t: F.Transition)
    requires F.Authorizes(pre, t)
    ensures MintAllowed(CheckedClaim(pre, t)) && Ours(CheckedClaim(pre, t))
  {
    assert F.Request(t.request.requestId, t.intent.amount, t.intent.reason) == t.request;
    assert F.Transition(t.request, t.post, t.intent) == t;
  }

  lemma PrefixHyps(acts: seq<Act>)
    requires |acts| > 0
    requires A2_MintOnlyOnCheck(acts) && H1_SignatureAuthenticity(acts)
    ensures var p := acts[..|acts| - 1]; A2_MintOnlyOnCheck(p) && H1_SignatureAuthenticity(p)
  {
    var p := acts[..|acts| - 1];
    forall k | 0 <= k < |p|
      ensures p[k] == acts[k]
    {
    }
    forall k | 0 <= k < |p| && p[k].Deliver? && VerifyTag(ClaimOf(p[k].tok), p[k].tok.sig)
      ensures SignedBefore(p, k, ClaimOf(p[k].tok))
    {
      assert acts[k] == p[k];
      var j :| 0 <= j < k && j < |acts| && acts[j].MintAct? && acts[j].c == ClaimOf(acts[k].tok);
      assert p[j] == acts[j];
    }
  }

  // The model invariant needs H1 + A2 only (no A5, no IdealMac).
  lemma ExecInvV3(init: State, acts: seq<Act>)
    requires A2_MintOnlyOnCheck(acts) && H1_SignatureAuthenticity(acts)
    ensures Inv(init, Exec(init, acts).s)
    ensures ClaimsSigned(Exec(init, acts).s)
    decreases |acts|
  {
    if |acts| == 0 {
      InitInv(init);
    } else {
      var n := |acts|;
      var p := acts[..n - 1];
      PrefixHyps(acts);
      ExecInvV3(init, p);
      OnlyMintActionsSign(init, p);
      var r := Exec(init, p);
      assert Exec(init, acts) == Next(r, acts[n - 1]);
      match acts[n - 1]
      case MintAct(c, tag) =>
        if Ours(c) {
          assert acts[n - 1].MintAct? && Ours(acts[n - 1].c);
          var pre: F.Charge, t: F.Transition :| F.Authorizes(pre, t) && c == CheckedClaim(pre, t);
          CheckedClaimAllowed(pre, t);
        }
        assert MintAllowed(c);
        MintPreservesInv(init, r.s, c, tag);
        assert Mint(r.s, c, tag) == r.s.(minted := r.s.minted + {(c, tag)});
        MintKeepsClaimsSigned(r.s, c, tag);
      case Deliver(tok, sigOk) =>
        assert acts[n - 1].Deliver?;
        var cl := ClaimOf(tok);
        if VerifyTag(cl, tok.sig) {
          assert SignedBefore(acts, n - 1, cl);
          var j :| 0 <= j < n - 1 && j < |acts| && acts[j].MintAct? && acts[j].c == cl;
          assert p[j] == acts[j];
          MintInMintsOf(p, j);
          assert (cl, acts[j].tag) in r.s.minted;
        }
        assert LocalClaimSigned(r.s, cl, tok.sig);
        if Match(tok) && ChargeOk(r.s.store, tok) {
          LocalClaimSignedKeepsInv(init, r.s, cl, tok.sig);
          CommitKeepsClaimsSigned(r.s, cl, tok.sig);
        }
    }
  }

  lemma RefundSliceShapeV3(init: State, core: Core, s: System, toks: seq<SinkToken>)
    requires Rel(core, s, toks) && Inv(init, s) && InitOk(init)
    ensures |toks| == |s.log| == |core.outbox|
    ensures forall i | 0 <= i < |toks| ::
      core.outbox[i] == toks[i].intent && toks[i].intent.requestId == toks[i].requestId && 0 <= core.outbox[i].amount
    ensures 0 <= core.charge.remaining <= core.charge.original == init.original
    ensures SumIntents(core.outbox) == init.remaining - core.charge.remaining
    ensures 0 <= SumIntents(core.outbox) <= init.original
  {
    InvMeaning(init, s);
    forall i | 0 <= i < |toks|
      ensures toks[i].intent.requestId == toks[i].requestId && 0 <= toks[i].intent.amount
    {
      assert SpecRel(s.log[i].pre, s.log[i].req, s.log[i].post, s.log[i].eff);
    }
    SumsAgree(core.outbox, s.log);
    ChainSum(init, s.log, s.store);
  }

  lemma PerEntryApproved(init: State, acts: seq<Act>, i: int)
    requires InitOk(init)
    requires A2_MintOnlyOnCheck(acts) && A5_VerifierMatchesAtEachDelivery(acts) && H1_SignatureAuthenticity(acts)
    requires 0 <= i < |Exec(init, acts).core.outbox|
    ensures ApprovedSpec(init, acts, i) && SignedInTrace(init, acts, i)
    ensures F.Authorizes(Exec(init, acts).toks[i].pre,
      F.Transition(F.Request(Exec(init, acts).toks[i].requestId, Exec(init, acts).toks[i].intent.amount,
                             Exec(init, acts).toks[i].intent.reason),
                   Exec(init, acts).toks[i].post, Exec(init, acts).toks[i].intent))
  {
    var r := Exec(init, acts);
    ExecRel(init, acts);
    ExecInvV3(init, acts);
    ExecCommitWitness(init, acts);
    OnlyMintActionsSign(init, acts);
    InvMeaning(init, r.s);
    RefundSliceShapeV3(init, r.core, r.s, r.toks);
    var tok := r.toks[i];
    assert r.s.log[i] == ClaimOf(tok);
    assert SpecRel(r.s.log[i].pre, r.s.log[i].req, r.s.log[i].post, r.s.log[i].eff);
    var t' :| (r.s.log[i], t') in r.s.minted;
    MintsOfHasSource(acts, r.s.log[i], t');
    var j :| 0 <= j < |acts| && acts[j] == MintAct(r.s.log[i], t');
    assert acts[j].MintAct? && acts[j].c == r.s.log[i];
    assert SignedBefore(acts, |acts|, r.s.log[i]);
  }

  // THE L2 THEOREM. InitOk + H1 + A2 + A5: every committed effect is approved and was signed; money bounds; sum.
  lemma SliceSafetyV3_L2_Authentic(init: State, acts: seq<Act>)
    requires InitOk(init)
    requires A2_MintOnlyOnCheck(acts)
    requires A5_VerifierMatchesAtEachDelivery(acts)
    requires H1_SignatureAuthenticity(acts)
    ensures forall e | CommittedEffect(init, acts, e) ::
      exists i :: 0 <= i < |Exec(init, acts).core.outbox| && Exec(init, acts).core.outbox[i] == e &&
        ApprovedSpec(init, acts, i) && SignedInTrace(init, acts, i)
    ensures 0 <= Exec(init, acts).core.charge.remaining <= Exec(init, acts).core.charge.original == init.original
    ensures SumIntents(Exec(init, acts).core.outbox) == init.remaining - Exec(init, acts).core.charge.remaining
    ensures 0 <= SumIntents(Exec(init, acts).core.outbox) <= init.original
  {
    var r := Exec(init, acts);
    ExecRel(init, acts);
    ExecInvV3(init, acts);
    RefundSliceShapeV3(init, r.core, r.s, r.toks);
    forall e | CommittedEffect(init, acts, e)
      ensures exists i :: (0 <= i < |r.core.outbox| && r.core.outbox[i] == e &&
        ApprovedSpec(init, acts, i) && SignedInTrace(init, acts, i))
    {
      var i :| 0 <= i < |r.core.outbox| && r.core.outbox[i] == e;
      PerEntryApproved(init, acts, i);
    }
  }

  // =============================================================================================
  // L3: + A6b.
  lemma PerEntryFlat(init: State, acts: seq<Act>, art: FlatFn, i: int)
    requires InitOk(init)
    requires A2_MintOnlyOnCheck(acts) && A5_VerifierMatchesAtEachDelivery(acts) && H1_SignatureAuthenticity(acts)
    requires A6b_ArtifactComputesFlatContractOnBytes(art)
    requires 0 <= i < |Exec(init, acts).core.outbox|
    ensures FlatResultAgrees(art, init, acts, i)
  {
    var r := Exec(init, acts);
    PerEntryApproved(init, acts, i);
    ExecCore(init, acts);
    var tok := r.toks[i];
    FlatPathBytes(art, tok.pre, F.Request(tok.requestId, tok.intent.amount, tok.intent.reason), tok.post, tok.intent);
  }

  lemma SliceSafetyV3_L3_Artifact(init: State, acts: seq<Act>, art: FlatFn)
    requires InitOk(init)
    requires A2_MintOnlyOnCheck(acts)
    requires A5_VerifierMatchesAtEachDelivery(acts)
    requires H1_SignatureAuthenticity(acts)
    requires A6b_ArtifactComputesFlatContractOnBytes(art)
    ensures forall e | CommittedEffect(init, acts, e) ::
      exists i :: 0 <= i < |Exec(init, acts).core.outbox| && Exec(init, acts).core.outbox[i] == e &&
        FlatResultAgrees(art, init, acts, i)
  {
    var r := Exec(init, acts);
    forall e | CommittedEffect(init, acts, e)
      ensures exists i :: 0 <= i < |r.core.outbox| && r.core.outbox[i] == e && FlatResultAgrees(art, init, acts, i)
    {
      var i :| 0 <= i < |r.core.outbox| && r.core.outbox[i] == e;
      PerEntryFlat(init, acts, art, i);
    }
  }

  // =============================================================================================
  // THE COMPOSED THEOREM V3 (all layers). Every conclusion holds for the SAME index i of the effect.
  lemma PerEntryAll(init: State, acts: seq<Act>, art: FlatFn, i: int)
    requires InitOk(init)
    requires A2_MintOnlyOnCheck(acts) && A5_VerifierMatchesAtEachDelivery(acts) && H1_SignatureAuthenticity(acts)
    requires A6b_ArtifactComputesFlatContractOnBytes(art)
    requires 0 <= i < |Exec(init, acts).core.outbox|
    ensures UniqueAuthorizationCore(init, acts, i) && TagVerifies(init, acts, i)
    ensures ApprovedSpec(init, acts, i) && SignedInTrace(init, acts, i) && FlatResultAgrees(art, init, acts, i)
  {
    PerEntryCore(init, acts, i);
    SliceSafetyV3_L1_A5(init, acts);
    PerEntryApproved(init, acts, i);
    PerEntryFlat(init, acts, art, i);
  }

  lemma SliceSafetyV3(init: State, acts: seq<Act>, art: FlatFn)
    requires InitOk(init)
    requires A2_MintOnlyOnCheck(acts)
    requires A5_VerifierMatchesAtEachDelivery(acts)
    requires H1_SignatureAuthenticity(acts)
    requires A6b_ArtifactComputesFlatContractOnBytes(art)
    ensures forall e | CommittedEffect(init, acts, e) ::
      exists i :: 0 <= i < |Exec(init, acts).core.outbox| && Exec(init, acts).core.outbox[i] == e &&
        UniqueAuthorizationCore(init, acts, i) && TagVerifies(init, acts, i) &&
        ApprovedSpec(init, acts, i) && SignedInTrace(init, acts, i) && FlatResultAgrees(art, init, acts, i)
    ensures 0 <= Exec(init, acts).core.charge.remaining <= Exec(init, acts).core.charge.original == init.original
    ensures SumIntents(Exec(init, acts).core.outbox) == init.remaining - Exec(init, acts).core.charge.remaining
  {
    var r := Exec(init, acts);
    SliceSafetyV3_L2_Authentic(init, acts);
    forall e | CommittedEffect(init, acts, e)
      ensures exists i :: (0 <= i < |r.core.outbox| && r.core.outbox[i] == e &&
        UniqueAuthorizationCore(init, acts, i) && TagVerifies(init, acts, i) &&
        ApprovedSpec(init, acts, i) && SignedInTrace(init, acts, i) && FlatResultAgrees(art, init, acts, i))
    {
      var i :| 0 <= i < |r.core.outbox| && r.core.outbox[i] == e;
      PerEntryAll(init, acts, art, i);
    }
  }
}

// =================================================================================================
// Non-vacuity and refutations under a TOTAL verifier reading (as SliceWitnessV2). Each lemma is CONDITIONAL on
// SigReading(): VerifyTag(c, t) <==> t == SigFn(c). b-signing/TotalReading.dfy shows the reading is realizable
// for a refinement of FinalityProtocol with the same types and SpecRel (SinkCoreV3 has the same types and SpecRel).
module SliceWitnessV3 {
  import opened SinkCoreV3
  import opened SliceTheoremV3

  function SigFn(c: Claim): Tag { "sig_" + c.req.requestId }

  ghost predicate SigReading()
  {
    forall c: Claim, t: Tag :: VerifyTag(c, t) <==> t == SigFn(c)
  }

  lemma SigOf(tok: SinkToken)
    ensures SigFn(ClaimOf(tok)) == "sig_" + tok.requestId
  {
  }

  const W_PRE: F.Charge := F.Charge("ch_1", 100, 60, true)
  const W_POST: F.Charge := F.Charge("ch_1", 100, 20, true)
  const W_INTENT: R.RefundIntent := R.Intent("ch_1", "rq_1", 40, "duplicate_charge")
  const W0_INTENT: R.RefundIntent := R.Intent("ch_1", "rq_0", 0, "duplicate_charge")
  const WB_INTENT: R.RefundIntent := R.Intent("ch_1", "rq_b", 61, "duplicate_charge")

  const V_TOK: SinkToken := SinkToken(PINNED_SPEC, PINNED_CHK, W_PRE, "rq_1", W_POST, W_INTENT, "sig_rq_1")
  const V0_TOK: SinkToken := SinkToken(PINNED_SPEC, PINNED_CHK, W_PRE, "rq_0", W_PRE, W0_INTENT, "sig_rq_0")
  // Forgery: an unapproved claim with the tag of ANOTHER claim.
  const VF_TOK: SinkToken := SinkToken(PINNED_SPEC, PINNED_CHK, W_PRE, "rq_b", F.Charge("ch_1", 100, -1, true),
                                       WB_INTENT, "sig_rq_1")
  // The unapproved claim with the tag that verifies for it (refutations only).
  const VB_TOK: SinkToken := SinkToken(PINNED_SPEC, PINNED_CHK, W_PRE, "rq_b", F.Charge("ch_1", 100, -1, true),
                                       WB_INTENT, "sig_rq_b")
  // Request-id mismatch: body "rq_m", intent "rq_1" (the victim id). Tag: verifies (faulty signer) or not.
  const VM_INTENT: R.RefundIntent := R.Intent("ch_1", "rq_1", 10, "duplicate_charge")
  const VM_TOK: SinkToken := SinkToken(PINNED_SPEC, PINNED_CHK, W_PRE, "rq_m", W_PRE.(remaining := 50), VM_INTENT, "sig_rq_m")
  const VMX_TOK: SinkToken := VM_TOK.(sig := "forged_m")
  // Wrong charge id: intent and post for ch_2, routed to the ch_1 store, pre = the stored ch_1 charge.
  const VC_INTENT: R.RefundIntent := R.Intent("ch_2", "rq_c", 10, "duplicate_charge")
  const VC_TOK: SinkToken := SinkToken(PINNED_SPEC, PINNED_CHK, W_PRE, "rq_c", F.Charge("ch_2", 100, 50, true),
                                       VC_INTENT, "sig_rq_c")
  const VCX_TOK: SinkToken := VC_TOK.(sig := "forged_c")

  // ---- the main witness (all hypotheses, TOTAL verifier) ----
  function MainActs(): seq<Act>
  {
    [MintAct(ClaimOf(V0_TOK), V0_TOK.sig), Deliver(V0_TOK, true),
     MintAct(ClaimOf(V_TOK), V_TOK.sig), Deliver(V_TOK, true),
     Deliver(VF_TOK, false),     // forged tag: rejected
     Deliver(V_TOK, true),       // replay: rejected
     Deliver(VMX_TOK, false),    // request-id mismatch, unsigned: rejected
     Deliver(VCX_TOK, false)]    // wrong charge id, unsigned: rejected
  }

  lemma MainTraceFirst()
    ensures Exec(W_PRE, MainActs()[..4]).core == Core(W_POST, {"rq_0", "rq_1"}, [W0_INTENT, W_INTENT])
    ensures Exec(W_PRE, MainActs()[..4]).toks == [V0_TOK, V_TOK]
  {
    var acts := MainActs();
    var init := W_PRE;
    ExecStep(init, acts, 0);
    ExecStep(init, acts, 1);
    ExecStep(init, acts, 2);
    ExecStep(init, acts, 3);
    assert acts[..0] == [];
    var r1 := Exec(init, acts[..1]);
    assert r1.core == Core(init, {}, []) && r1.toks == [];
    var r2 := Exec(init, acts[..2]);
    assert r2.core == Core(init, {"rq_0"}, [W0_INTENT]) && r2.toks == [V0_TOK];
    var r3 := Exec(init, acts[..3]);
    assert r3.core == r2.core && r3.toks == r2.toks;
    assert "rq_1" !in {"rq_0"};
  }

  lemma MainTraceRejects(k: int)
    requires 4 <= k < 8
    requires Exec(W_PRE, MainActs()[..k]).core == Core(W_POST, {"rq_0", "rq_1"}, [W0_INTENT, W_INTENT])
    ensures !Step(Exec(W_PRE, MainActs()[..k]).core, MainActs()[k].tok, MainActs()[k].sigOk).out.Committed?
    ensures Exec(W_PRE, MainActs()[..k + 1]).core == Exec(W_PRE, MainActs()[..k]).core
    ensures Exec(W_PRE, MainActs()[..k + 1]).toks == Exec(W_PRE, MainActs()[..k]).toks
    ensures k == 4 ==> Step(Exec(W_PRE, MainActs()[..k]).core, VF_TOK, false).out == Rejected(SignatureInvalid)
    ensures k == 5 ==> Step(Exec(W_PRE, MainActs()[..k]).core, V_TOK, true).out == Rejected(RequestSettled)
  {
    ExecStep(W_PRE, MainActs(), k);
  }

  lemma MainTrace()
    ensures Exec(W_PRE, MainActs()).core == Core(W_POST, {"rq_0", "rq_1"}, [W0_INTENT, W_INTENT])
    ensures Exec(W_PRE, MainActs()).toks == [V0_TOK, V_TOK]
    ensures Step(Exec(W_PRE, MainActs()[..4]).core, VF_TOK, false).out == Rejected(SignatureInvalid)
    ensures Step(Exec(W_PRE, MainActs()[..5]).core, V_TOK, true).out == Rejected(RequestSettled)
    ensures !Step(Exec(W_PRE, MainActs()[..6]).core, VMX_TOK, false).out.Committed?
    ensures !Step(Exec(W_PRE, MainActs()[..7]).core, VCX_TOK, false).out.Committed?
  {
    var acts := MainActs();
    MainTraceFirst();
    MainTraceRejects(4);
    MainTraceRejects(5);
    MainTraceRejects(6);
    MainTraceRejects(7);
    assert acts[..8] == acts;
  }

  lemma MainHypsA2()
    ensures A2_MintOnlyOnCheck(MainActs())
  {
    var acts := MainActs();
    assert W_PRE.(remaining := W_PRE.remaining - 0) == W_PRE;
    var t0 := F.Transition(F.Request("rq_0", 0, "duplicate_charge"), W_PRE, W0_INTENT);
    var t1 := F.Transition(F.Request("rq_1", 40, "duplicate_charge"), W_POST, W_INTENT);
    assert F.Authorizes(W_PRE, t0) && ClaimOf(V0_TOK) == CheckedClaim(W_PRE, t0);
    assert F.Authorizes(W_PRE, t1) && ClaimOf(V_TOK) == CheckedClaim(W_PRE, t1);
    forall k | 0 <= k < |acts| && acts[k].MintAct? && Ours(acts[k].c)
      ensures exists pre: F.Charge, t2: F.Transition :: F.Authorizes(pre, t2) && acts[k].c == CheckedClaim(pre, t2)
    {
      if k == 0 {
        assert F.Authorizes(W_PRE, t0) && acts[k].c == CheckedClaim(W_PRE, t0);
      } else {
        assert k == 2;
        assert F.Authorizes(W_PRE, t1) && acts[k].c == CheckedClaim(W_PRE, t1);
      }
    }
  }

  lemma MainHypsSig()
    requires SigReading()
    ensures A5_VerifierMatchesAtEachDelivery(MainActs())
    ensures H1_SignatureAuthenticity(MainActs())
    ensures !VerifyTag(ClaimOf(VF_TOK), VF_TOK.sig)
    ensures !VerifyTag(ClaimOf(VMX_TOK), VMX_TOK.sig) && !VerifyTag(ClaimOf(VCX_TOK), VCX_TOK.sig)
  {
    var acts := MainActs();
    SigOf(V0_TOK);
    SigOf(V_TOK);
    SigOf(VF_TOK);
    SigOf(VMX_TOK);
    SigOf(VCX_TOK);
    assert "sig_rq_1" != "sig_rq_b";
    assert "forged_m" != "sig_rq_m" by { assert "forged_m"[0] != "sig_rq_m"[0]; }
    assert "forged_c" != "sig_rq_c" by { assert "forged_c"[0] != "sig_rq_c"[0]; }
    assert VerifyTag(ClaimOf(V0_TOK), V0_TOK.sig);
    assert VerifyTag(ClaimOf(V_TOK), V_TOK.sig);
    forall k | 0 <= k < |acts| && acts[k].Deliver?
      ensures A5_VerifierMatches(acts[k].tok, acts[k].sigOk)
    {
      assert k == 1 || k == 3 || k == 4 || k == 5 || k == 6 || k == 7;
    }
    forall k | 0 <= k < |acts| && acts[k].Deliver? && VerifyTag(ClaimOf(acts[k].tok), acts[k].tok.sig)
      ensures SignedBefore(acts, k, ClaimOf(acts[k].tok))
    {
      if k == 1 {
        assert acts[0].MintAct? && acts[0].c == ClaimOf(acts[k].tok);
      } else {
        assert k == 3 || k == 5;
        assert acts[2].MintAct? && acts[2].c == ClaimOf(acts[k].tok);
      }
    }
  }

  // NON-VACUITY. All hypotheses of SliceSafetyV3 hold; the verifier is total; a zero-amount and a positive effect
  // commit; a forged tag, a replay, a request-id mismatch and a wrong charge id are rejected.
  lemma MainWitness()
    requires SigReading()
    ensures InitOk(W_PRE)
    ensures A2_MintOnlyOnCheck(MainActs()) && A5_VerifierMatchesAtEachDelivery(MainActs())
    ensures H1_SignatureAuthenticity(MainActs())
    ensures A6b_ArtifactComputesFlatContractOnBytes(FlatSpecFn)
    ensures Exec(W_PRE, MainActs()).core.outbox == [W0_INTENT, W_INTENT]
    ensures W0_INTENT.amount == 0 && W_INTENT.amount == 40
    ensures CommittedEffect(W_PRE, MainActs(), W0_INTENT) && CommittedEffect(W_PRE, MainActs(), W_INTENT)
    ensures Step(Exec(W_PRE, MainActs()[..4]).core, VF_TOK, false).out == Rejected(SignatureInvalid)
    ensures Step(Exec(W_PRE, MainActs()[..5]).core, V_TOK, true).out == Rejected(RequestSettled)
    ensures !Step(Exec(W_PRE, MainActs()[..6]).core, VMX_TOK, false).out.Committed?
    ensures !Step(Exec(W_PRE, MainActs()[..7]).core, VCX_TOK, false).out.Committed?
  {
    MainHypsA2();
    MainHypsSig();
    MainTrace();
    FlatSpecFnMeetsA6b();
    SliceSafetyV3(W_PRE, MainActs(), FlatSpecFn);
  }

  // ---- the FAULTY-SIGNER witness: A2 is dropped (the key holder signs a mismatched claim and a wrong-charge
  // claim). H1 and A5 hold. The two new checks reject them (ReqIdMismatch, ChargeIdMismatch); the honest zero-amount
  // token commits; the L0 conclusions still hold (SliceSafetyV3_L0_NoAssumption has no hypothesis). ----
  function FaultyActs(): seq<Act>
  {
    [MintAct(ClaimOf(VM_TOK), VM_TOK.sig), Deliver(VM_TOK, true),
     MintAct(ClaimOf(VC_TOK), VC_TOK.sig), Deliver(VC_TOK, true),
     MintAct(ClaimOf(V0_TOK), V0_TOK.sig), Deliver(V0_TOK, true)]
  }

  lemma FaultyTrace()
    ensures Step(Exec(W_PRE, FaultyActs()[..1]).core, VM_TOK, true).out == Rejected(ReqIdMismatch)
    ensures Step(Exec(W_PRE, FaultyActs()[..3]).core, VC_TOK, true).out == Rejected(ChargeIdMismatch)
    ensures Exec(W_PRE, FaultyActs()).core == Core(W_PRE, {"rq_0"}, [W0_INTENT])
  {
    var acts := FaultyActs();
    var init := W_PRE;
    ExecStep(init, acts, 0);
    ExecStep(init, acts, 1);
    ExecStep(init, acts, 2);
    ExecStep(init, acts, 3);
    ExecStep(init, acts, 4);
    ExecStep(init, acts, 5);
    assert acts[..0] == [];
    assert acts[..6] == acts;
    var r1 := Exec(init, acts[..1]);
    assert r1.core == Core(init, {}, []);
    var r2 := Exec(init, acts[..2]);
    assert r2.core == r1.core;
    var r3 := Exec(init, acts[..3]);
    assert r3.core == r2.core;
    var r4 := Exec(init, acts[..4]);
    assert r4.core == r3.core;
    var r5 := Exec(init, acts[..5]);
    assert r5.core == r4.core;
  }

  lemma FaultySignerWitness()
    requires SigReading()
    ensures A5_VerifierMatchesAtEachDelivery(FaultyActs()) && H1_SignatureAuthenticity(FaultyActs())
    ensures !A2_MintOnlyOnCheck(FaultyActs())
    ensures VerifyTag(ClaimOf(VM_TOK), VM_TOK.sig) && VerifyTag(ClaimOf(VC_TOK), VC_TOK.sig)
    ensures Step(Exec(W_PRE, FaultyActs()[..1]).core, VM_TOK, true).out == Rejected(ReqIdMismatch)
    ensures Step(Exec(W_PRE, FaultyActs()[..3]).core, VC_TOK, true).out == Rejected(ChargeIdMismatch)
    ensures Exec(W_PRE, FaultyActs()).core.outbox == [W0_INTENT]
    ensures forall e | CommittedEffect(W_PRE, FaultyActs(), e) :: e.chargeId == W_PRE.chargeId
  {
    var acts := FaultyActs();
    SigOf(VM_TOK);
    SigOf(VC_TOK);
    SigOf(V0_TOK);
    forall k | 0 <= k < |acts| && acts[k].Deliver?
      ensures A5_VerifierMatches(acts[k].tok, acts[k].sigOk)
    {
      assert k == 1 || k == 3 || k == 5;
    }
    forall k | 0 <= k < |acts| && acts[k].Deliver? && VerifyTag(ClaimOf(acts[k].tok), acts[k].tok.sig)
      ensures SignedBefore(acts, k, ClaimOf(acts[k].tok))
    {
      assert acts[k - 1].MintAct? && acts[k - 1].c == ClaimOf(acts[k].tok);
    }
    assert acts[0].MintAct? && Ours(acts[0].c);
    forall pre: F.Charge, t: F.Transition | acts[0].c == CheckedClaim(pre, t)
      ensures !F.Authorizes(pre, t)
    {
      assert t.request.requestId == "rq_m" && t.intent == VM_INTENT;
    }
    FaultyTrace();
    SliceSafetyV3_L0_NoAssumption(W_PRE, acts);
  }

  // ---- refutations: drop one hypothesis, the others hold, the conclusion fails ----
  // Drop H1: an UNSIGNED, unapproved claim with a tag that verifies for it. A2 (no mint), A5, A6b hold.
  function NoAuthActs(): seq<Act> { [Deliver(VB_TOK, true)] }

  lemma DropH1BreaksApprovedSpec()
    requires SigReading()
    ensures A2_MintOnlyOnCheck(NoAuthActs()) && A5_VerifierMatchesAtEachDelivery(NoAuthActs())
    ensures !H1_SignatureAuthenticity(NoAuthActs())
    ensures CommittedEffect(W_PRE, NoAuthActs(), WB_INTENT)
    ensures forall i :: !ApprovedSpec(W_PRE, NoAuthActs(), i)
  {
    var acts := NoAuthActs();
    var init := W_PRE;
    SigOf(VB_TOK);
    assert VerifyTag(ClaimOf(VB_TOK), VB_TOK.sig);
    assert A5_VerifierMatches(acts[0].tok, acts[0].sigOk);
    assert !SignedBefore(acts, 0, ClaimOf(VB_TOK));
    ExecStep(init, acts, 0);
    assert acts[..0] == [];
    assert acts[..1] == acts;
    var r0 := Exec(init, acts[..0]);
    assert Step(r0.core, VB_TOK, true).out.Committed?;
    var r := Exec(init, acts);
    assert r.core.outbox == [WB_INTENT] && r.toks == [VB_TOK];
    forall i
      ensures !ApprovedSpec(init, acts, i)
    {
      if 0 <= i < |r.toks| {
        assert i == 0;
        assert !R.Eligible(F.ContextOf(VB_TOK.pre, "rq_b"), R.Candidate(61, "duplicate_charge"));
      }
    }
  }

  // Drop A2: the issuer signs a claim that Check never issues. H1, A5 hold.
  function BadMintActs(): seq<Act> { [MintAct(ClaimOf(VB_TOK), VB_TOK.sig), Deliver(VB_TOK, true)] }

  lemma DropA2BreaksApprovedSpec()
    requires SigReading()
    ensures H1_SignatureAuthenticity(BadMintActs()) && A5_VerifierMatchesAtEachDelivery(BadMintActs())
    ensures !A2_MintOnlyOnCheck(BadMintActs())
    ensures CommittedEffect(W_PRE, BadMintActs(), WB_INTENT)
    ensures forall i :: !ApprovedSpec(W_PRE, BadMintActs(), i)
  {
    var acts := BadMintActs();
    var init := W_PRE;
    SigOf(VB_TOK);
    assert VerifyTag(ClaimOf(VB_TOK), VB_TOK.sig);
    assert A5_VerifierMatches(acts[1].tok, acts[1].sigOk);
    forall k | 0 <= k < |acts| && acts[k].Deliver? && VerifyTag(ClaimOf(acts[k].tok), acts[k].tok.sig)
      ensures SignedBefore(acts, k, ClaimOf(acts[k].tok))
    {
      assert k == 1 && acts[0].MintAct? && acts[0].c == ClaimOf(acts[1].tok);
    }
    assert acts[0].MintAct? && Ours(acts[0].c);
    forall pre: F.Charge, t: F.Transition | acts[0].c == CheckedClaim(pre, t)
      ensures !F.Authorizes(pre, t)
    {
      assert pre == W_PRE && t.intent == WB_INTENT && t.request.requestId == "rq_b";
    }
    ExecStep(init, acts, 0);
    ExecStep(init, acts, 1);
    assert acts[..0] == [];
    assert acts[..2] == acts;
    var r1 := Exec(init, acts[..1]);
    assert r1.core == Core(init, {}, []);
    assert Step(r1.core, VB_TOK, true).out.Committed?;
    var r := Exec(init, acts);
    assert r.core.outbox == [WB_INTENT] && r.toks == [VB_TOK];
    forall i
      ensures !ApprovedSpec(init, acts, i)
    {
      if 0 <= i < |r.toks| {
        assert i == 0;
        assert !R.Eligible(F.ContextOf(VB_TOK.pre, "rq_b"), R.Candidate(61, "duplicate_charge"));
      }
    }
  }

  // Drop A6b: H1, A2, A5 hold on MainActs; an artifact that rejects everything fails A6b and FlatResultAgrees.
  function RejectAll(x: FlatIn): L.FlatTuple { (false, 0, "", "", "", 0) }

  lemma DropA6bBreaksFlatPath()
    requires SigReading()
    ensures !A6b_ArtifactComputesFlatContractOnBytes(RejectAll)
    ensures !FlatResultAgrees(RejectAll, W_PRE, MainActs(), 1)
  {
    MainTrace();
    var x := FlatInputsOf(W_PRE, W_INTENT);
    FlatInputsAreBytes(W_PRE, W_INTENT);
    assert !FlatContract(x, RejectAll(x)) by {
      U.EncodedEmpty("ch_1");
      U.EncodedEmpty("rq_1");
      U.SameReasons("duplicate_charge");
    }
  }
}
