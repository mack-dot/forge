// Night shift 2026-11-19, Orchestrator B, task b-top (T4). A DRAFT in an evidence folder. NOT gate evidence.
// M1-B stays OPEN. end_to_end=false. A Dafny-MODEL statement only.
//
// T4: lift RefineHashV3.StepAgrees (b-ser2 copy) from one step to traces.
//  - StepAgreesWeak: the one-step agreement needs the hash side condition ONLY when the step reaches the pre-state
//    check (ids pinned, sigOk, request ids match, request not settled). Earlier rejections agree for ANY value pre.
//  - ValueRunExists: for every SliceSafetyBytesV3 trace that meets A2p, H1B, B5 and A4, there is a sequence of
//    value tokens (one per action) such that the SinkCoreV3 run over them has the SAME core (charge, settled set,
//    outbox) as the HashCore run, step by step, with the same outcome at each delivery.
// LIMIT (stated, not proved): this is a CORE-LEVEL simulation. A theorem over SinkCoreV3 traces (for example
// Restart.dfy) also needs ITS hypotheses (A2/A5/H1 over Claim and VerifyTag) on the constructed value trace. They are
// NOT derived here; the value signature model (VerifyTag on Claims) and the byte model (vb on BytesOf) differ.
// No assume, no axiom, no bodiless lemma, no {:extern}, no expect in this file.
include "RefineHashV3.dfy"
include "SliceSafetyBytesV3.dfy"
include "ControlsBytesV3.dfy"

module RefineTraceV3 {
  import opened HashCore
  import opened SliceSafetyBytesV3
  import V = SinkCoreV3
  import RH = RefineHashV3

  predicate Pinned(th: HashToken) { th.specHex == PIN_SPEC && th.checkerHex == PIN_CHK }

  // The weak relation: no pre-state condition.
  predicate TokRelW(th: HashToken, tv: V.SinkToken)
  {
    (Pinned(th) <==> (tv.specId == V.PINNED_SPEC && tv.checkerId == V.PINNED_CHK)) &&
    th.requestId == tv.requestId && ChargeOfState(th.post) == tv.post && IntentOfSM(th.intent) == tv.intent
  }
  // The step reaches the pre-state check.
  predicate ReachesPre(c: Core, th: HashToken, sigOk: bool)
  {
    Pinned(th) && sigOk && Match(th) && th.requestId !in c.settled
  }

  function ValTok(th: HashToken, pre: F.Charge): V.SinkToken
  {
    V.SinkToken(if Pinned(th) then V.PINNED_SPEC else V.PINNED_SPEC + 1, V.PINNED_CHK, pre, th.requestId,
                ChargeOfState(th.post), IntentOfSM(th.intent), [])
  }
  lemma ValTokRel(th: HashToken, pre: F.Charge)
    ensures TokRelW(th, ValTok(th, pre)) && ValTok(th, pre).pre == pre
  {}

  lemma StepAgreesWeak(H: HashFn, c: Core, d: V.Core, th: HashToken, tv: V.SinkToken, sigOk: bool)
    requires TokRelW(th, tv) && RH.CoreRel(c, d)
    requires ReachesPre(c, th, sigOk) ==> th.preHash == H(tv.pre) && (H(c.charge) == H(tv.pre) <==> c.charge == tv.pre)
    ensures Step(H, c, th, sigOk).out.Committed? <==> V.Step(d, tv, sigOk).out.Committed?
    ensures Step(H, c, th, sigOk).out.Rejected? ==>
      V.Step(d, tv, sigOk).out == V.Rejected(RH.WhyOf(Step(H, c, th, sigOk).out.why))
    ensures RH.CoreRel(Step(H, c, th, sigOk).core, V.Step(d, tv, sigOk).core)
  {
    assert Match(th) <==> V.Match(tv);
    assert ChargeOk(c.charge, th) <==> V.ChargeOk(d.charge, tv);
  }

  // The value run over the same actions, with one value token per action (ignored at a mint).
  function VExec(init: F.Charge, acts: seq<Act>, tvs: seq<V.SinkToken>): V.Core
    requires |tvs| == |acts|
    decreases |acts|
  {
    if |acts| == 0 then V.Core(init, {}, [])
    else
      var d := VExec(init, acts[..|acts| - 1], tvs[..|acts| - 1]);
      var a := acts[|acts| - 1];
      if a.MintAct? then d else V.Step(d, tvs[|acts| - 1], a.sigOk).core
  }

  // The value token of delivery k carries the pre-state of an earlier mint of exactly the delivered bytes, the one
  // the issuer checked (IssuedFrom), and the hash text binds it (RefineHashV3.TokRel). Without this condition a
  // core simulation is trivial (pick tv.pre := the stored charge); with it, the value token is the issued one.
  ghost predicate IssuedValTok(H: HashFn, acts: seq<Act>, k: int, tv: V.SinkToken)
    requires 0 <= k < |acts| && acts[k].Deliver?
  {
    RH.TokRel(H, acts[k].tok, tv) &&
    exists j :: 0 <= j < k && acts[j].MintAct? && acts[j].msg == BytesOf(acts[k].tok) && acts[j].pre == tv.pre &&
      exists t: F.Transition :: IssuedFrom(H, tv.pre, t, acts[j].msg)
  }

  ghost predicate Sim(H: HashFn, init: F.Charge, acts: seq<Act>, n: int, tvs: seq<V.SinkToken>)
    requires 0 <= n <= |acts|
  {
    |tvs| == n &&
    RH.CoreRel(TExec(H, init, acts[..n]).core, VExec(init, acts[..n], tvs)) &&
    forall k | 0 <= k < n && acts[k].Deliver? :: TokRelW(acts[k].tok, tvs[k]) &&
      (ReachesPre(TExec(H, init, acts[..k]).core, acts[k].tok, acts[k].sigOk) ==> IssuedValTok(H, acts, k, tvs[k]))
  }

  // (The value signature is left empty: the value Step reads only sigOk.)
  // The value token for delivery n: the pre-state of the mint that the hypotheses provide (or any value).
  lemma PickValTok(H: HashFn, init: F.Charge, acts: seq<Act>, vb: ByteVerifier, n: int) returns (tv: V.SinkToken)
    requires 0 <= n < |acts| && acts[n].Deliver?
    requires A2p_MintsAreIssued(H, acts) && H1B_ByteUnforgeability(vb, acts) && B5_VerifierBoolean(vb, acts)
    requires A4_HashBindsInRun(H, init, acts)
    ensures TokRelW(acts[n].tok, tv)
    ensures var c := TExec(H, init, acts[..n]).core;
      ReachesPre(c, acts[n].tok, acts[n].sigOk) ==>
        acts[n].tok.preHash == H(tv.pre) && (H(c.charge) == H(tv.pre) <==> c.charge == tv.pre) &&
        IssuedValTok(H, acts, n, tv)
  {
    var c := TExec(H, init, acts[..n]).core;
    var th := acts[n].tok;
    if ReachesPre(c, th, acts[n].sigOk) {
      reveal A2p_MintsAreIssued(), H1B_ByteUnforgeability(), B5_VerifierBoolean(), A4_HashBindsInRun();
      assert vb(BytesOf(th), th.sig);
      assert MintedBefore(acts, n, BytesOf(th));
      var j :| 0 <= j < n && j < |acts| && acts[j].MintAct? && acts[j].msg == BytesOf(th);
      assert OurBytes(acts[j].msg) by {
        assert SM.SignedBytes(BodyOf(th)) == acts[j].msg && BodyOf(th).specLockSha256 == PIN_SPEC &&
               BodyOf(th).checkerSha256 == PIN_CHK;
      }
      var t :| IssuedFrom(H, acts[j].pre, t, acts[j].msg);
      IssuedTokenFields(H, acts[j].pre, t, th);
      tv := ValTok(th, acts[j].pre);
      ValTokRel(th, acts[j].pre);
      assert IssuedFrom(H, tv.pre, t, acts[j].msg);
    } else {
      tv := ValTok(th, c.charge);
      ValTokRel(th, c.charge);
    }
  }

  lemma SimNext(H: HashFn, init: F.Charge, acts: seq<Act>, vb: ByteVerifier, n: int, tvs: seq<V.SinkToken>)
      returns (tvs': seq<V.SinkToken>)
    requires 0 <= n < |acts|
    requires A2p_MintsAreIssued(H, acts) && H1B_ByteUnforgeability(vb, acts) && B5_VerifierBoolean(vb, acts)
    requires A4_HashBindsInRun(H, init, acts)
    requires Sim(H, init, acts, n, tvs)
    ensures Sim(H, init, acts, n + 1, tvs')
    ensures tvs'[..n] == tvs
  {
    TExecStep(H, init, acts, n);
    var c := TExec(H, init, acts[..n]).core;
    var d := VExec(init, acts[..n], tvs);
    var tv: V.SinkToken;
    if acts[n].Deliver? {
      tv := PickValTok(H, init, acts, vb, n);
      StepAgreesWeak(H, c, d, acts[n].tok, tv, acts[n].sigOk);
    } else {
      tv := ValTok(HashToken("", "", "", "", SM.ChargeState("", 0, 0, false), SM.Intent("", "", 0, ""), []), init);
    }
    tvs' := tvs + [tv];
    assert tvs'[..n] == tvs;
    assert acts[..n + 1][..n] == acts[..n];
    assert VExec(init, acts[..n + 1], tvs') ==
      (if acts[n].MintAct? then d else V.Step(d, tv, acts[n].sigOk).core);
    forall k | 0 <= k < n + 1 && acts[k].Deliver?
      ensures TokRelW(acts[k].tok, tvs'[k]) &&
        (ReachesPre(TExec(H, init, acts[..k]).core, acts[k].tok, acts[k].sigOk) ==> IssuedValTok(H, acts, k, tvs'[k]))
    {
      if k < n { assert tvs'[k] == tvs[k]; }
    }
  }

  lemma SimHolds(H: HashFn, init: F.Charge, acts: seq<Act>, vb: ByteVerifier, n: int) returns (tvs: seq<V.SinkToken>)
    requires 0 <= n <= |acts|
    requires A2p_MintsAreIssued(H, acts) && H1B_ByteUnforgeability(vb, acts) && B5_VerifierBoolean(vb, acts)
    requires A4_HashBindsInRun(H, init, acts)
    ensures Sim(H, init, acts, n, tvs)
    decreases n
  {
    if n == 0 {
      assert acts[..0] == [];
      tvs := [];
    } else {
      var p := SimHolds(H, init, acts, vb, n - 1);
      tvs := SimNext(H, init, acts, vb, n - 1, p);
    }
  }

  // T4 STATEMENT: a value run with the same core exists for every hash run that meets the byte hypotheses.
  lemma ValueRunExists(H: HashFn, init: F.Charge, acts: seq<Act>, vb: ByteVerifier)
    requires A2p_MintsAreIssued(H, acts) && H1B_ByteUnforgeability(vb, acts) && B5_VerifierBoolean(vb, acts)
    requires A4_HashBindsInRun(H, init, acts)
    ensures exists tvs: seq<V.SinkToken> :: (|tvs| == |acts| &&
      RH.CoreRel(TExec(H, init, acts).core, VExec(init, acts, tvs)) &&
      forall k | 0 <= k < |acts| && acts[k].Deliver? :: TokRelW(acts[k].tok, tvs[k]) &&
        (ReachesPre(TExec(H, init, acts[..k]).core, acts[k].tok, acts[k].sigOk) ==> IssuedValTok(H, acts, k, tvs[k])))
  {
    var tvs := SimHolds(H, init, acts, vb, |acts|);
    assert acts[..|acts|] == acts;
  }
}

// T4 witness and control.
module RefineTraceControls {
  import opened HashCore
  import opened SliceSafetyBytesV3
  import opened RefineTraceV3
  import V = SinkCoreV3
  import RH = RefineHashV3
  import C = ControlsBytesV3

  // Non-vacuity: the b-ser2 witness run (zero-amount and positive commits) meets the hypotheses.
  lemma WitnessSim()
    ensures exists tvs: seq<V.SinkToken> :: (|tvs| == |C.WActs()| &&
      RH.CoreRel(TExec(C.HW, C.W_PRE, C.WActs()).core, VExec(C.W_PRE, C.WActs(), tvs)))
    ensures TExec(C.HW, C.W_PRE, C.WActs()).core.outbox == [C.I0, C.I1]
  {
    C.Witness();
    ValueRunExists(C.HW, C.W_PRE, C.WActs(), C.TotalVB);
  }

  // Control (drop A4): the constant-hash collision run of b-ser2. Every other hypothesis holds; NO value token
  // sequence with issued value tokens simulates the hash run (the hash core commits from P_COLL; the value core
  // must use the minted pre-state W_PRE and rejects).
  lemma DropA4BreaksSim(tvs: seq<V.SinkToken>)
    requires |tvs| == 2
    requires forall k | 0 <= k < 2 && C.CollActs()[k].Deliver? :: (TokRelW(C.CollActs()[k].tok, tvs[k]) &&
      (ReachesPre(TExec(C.HC, C.P_COLL, C.CollActs()[..k]).core, C.CollActs()[k].tok, C.CollActs()[k].sigOk) ==>
        IssuedValTok(C.HC, C.CollActs(), k, tvs[k])))
    ensures !A4_HashBindsInRun(C.HC, C.P_COLL, C.CollActs())
    ensures A2p_MintsAreIssued(C.HC, C.CollActs()) && H1B_ByteUnforgeability(C.TotalVB, C.CollActs())
    ensures B5_VerifierBoolean(C.TotalVB, C.CollActs())
    ensures !RH.CoreRel(TExec(C.HC, C.P_COLL, C.CollActs()).core, VExec(C.P_COLL, C.CollActs(), tvs))
  {
    C.DropA4BreaksApproval();
    C.CollTrace();
    C.Authorized();
    var acts := C.CollActs();
    var th := acts[1].tok;
    assert th == C.TCOLL;
    assert Pinned(th) && Match(th);
    assert ReachesPre(TExec(C.HC, C.P_COLL, acts[..1]).core, th, true);
    assert IssuedValTok(C.HC, acts, 1, tvs[1]);
    assert tvs[1].pre == C.W_PRE;
    assert C.P_COLL != C.W_PRE;
    assert acts[..1] == [acts[0]] && tvs[..1] == [tvs[0]];
    assert VExec(C.P_COLL, acts[..1], tvs[..1]) == V.Core(C.P_COLL, {}, []) by {
      assert acts[..1][..0] == [];
    }
    assert acts[..2] == acts && tvs[..2] == tvs;
    assert V.Step(V.Core(C.P_COLL, {}, []), tvs[1], true).core == V.Core(C.P_COLL, {}, []);
    assert VExec(C.P_COLL, acts, tvs).outbox == [];
  }
}
