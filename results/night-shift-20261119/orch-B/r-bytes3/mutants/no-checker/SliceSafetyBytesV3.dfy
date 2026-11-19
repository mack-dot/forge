// Night shift 2026-11-19, Orchestrator B, task b-ser2 (G2). A DRAFT in an evidence folder. NOT gate evidence.
// M1-B stays OPEN. end_to_end=false. A Dafny-MODEL statement only. It says nothing about sink.ts, minter.ts,
// Ed25519, SHA-256, SQLite, compiled code, the HOL model, CakeML or native execution.
//
// The composed byte-level theorem over HashCore. Actions: MintAct(pre, msg, tag) (the issuer signs the bytes msg;
// pre is the pre-state VALUE the issuer hashed) and Deliver(tok, sigOk) (the sink runs HashCore.Step).
// Layers (each lemma has only the hypotheses it needs; every hypothesis is a NAMED predicate):
//   L0 SliceSafetyBytesV3_L0  no hypothesis
//   L2 SliceSafetyBytesV3_L2  InitOk + A2p_MintsAreIssued + H1B_ByteUnforgeability + B5_VerifierBoolean +
//                             A4_HashBindsInRun
//   L3 SliceSafetyBytesV3_L3  L2 + S3.A6b_ArtifactComputesFlatContractOnBytes
// GONE compared with RepairedBytes.SliceSafetyV2BytesRepaired: H3a (lemma), H3b (the sink's bytes are BytesOf of
// the delivered token by definition), H3c (no uninterpreted VerifyTag: the boolean is the byte verifier), H3d (not
// needed: injectivity holds on all bodies), B6 (money fields are naturals by type; no clamp; no other decoder
// fact is used), A4b (merged into A4), the id-encoding injectivity (ids are hex TEXTS).
// No assume, no axiom, no bodiless lemma, no {:extern}, no expect in this file.
include "HashCore.dfy"
include "/Users/mackianni/forge/results/night-shift-20261119/orch-B/r-bytes3/work/v3/SliceSafetyV3.dfy"

module SliceSafetyBytesV3 {
  import opened HashCore
  import S3 = SliceTheoremV3
  import LR = LinkedRefund

  type ByteVerifier = (Bytes, Tag) -> bool

  // =============================================================================================
  // The trace model.
  datatype Act = MintAct(pre: F.Charge, msg: Bytes, tag: Tag) | Deliver(tok: HashToken, sigOk: bool)
  // toks: committed tokens; pres: the STORED charge at each commit; ks: the action index of each commit.
  datatype RunSt = RunSt(core: Core, toks: seq<HashToken>, pres: seq<F.Charge>, ks: seq<int>, n: int)

  function TNext(H: HashFn, r: RunSt, a: Act): RunSt
  {
    if a.MintAct? then RunSt(r.core, r.toks, r.pres, r.ks, r.n + 1)
    else if Step(H, r.core, a.tok, a.sigOk).out.Committed? then
      RunSt(Step(H, r.core, a.tok, a.sigOk).core, r.toks + [a.tok], r.pres + [r.core.charge], r.ks + [r.n], r.n + 1)
    else RunSt(r.core, r.toks, r.pres, r.ks, r.n + 1)
  }

  function TExec(H: HashFn, init: F.Charge, acts: seq<Act>): RunSt
    decreases |acts|
  {
    if |acts| == 0 then RunSt(Core(init, {}, []), [], [], [], 0)
    else TNext(H, TExec(H, init, acts[..|acts| - 1]), acts[|acts| - 1])
  }

  lemma TExecStep(H: HashFn, init: F.Charge, acts: seq<Act>, k: int)
    requires 0 <= k < |acts|
    ensures TExec(H, init, acts[..k + 1]) == TNext(H, TExec(H, init, acts[..k]), acts[k])
  {
    assert acts[..k + 1][..k] == acts[..k];
    assert acts[..k + 1][k] == acts[k];
  }

  function SumIntents(o: seq<R.RefundIntent>): int
    decreases |o|
  {
    if |o| == 0 then 0 else SumIntents(o[..|o| - 1]) + o[|o| - 1].amount
  }

  // =============================================================================================
  // The named hypotheses.
  // InitOk (organisational: the deployment starts from a sane stored state).
  ghost predicate InitOk(init: F.Charge) { 0 <= init.remaining <= init.original }

  // Bytes that read as a body with the pinned ids.
  ghost predicate OurBytes(msg: Bytes)
  {
    exists b: SM.TokenBody :: SM.SignedBytes(b) == msg && b.specLockSha256 == PIN_SPEC && b.checkerSha256 == PIN_CHK
  }
  // A2' (organisational + proved code): every mint for our ids is an output of IssueBytes(pre, t) (the issuer key
  // signs nothing else with the pinned ids). IssueBytes itself is PROVED (HashCore.IssueBytes).
  opaque ghost predicate A2p_MintsAreIssued(H: HashFn, acts: seq<Act>)
  {
    forall j | 0 <= j < |acts| && acts[j].MintAct? && OurBytes(acts[j].msg) ::
      exists t: F.Transition :: IssuedFrom(H, acts[j].pre, t, acts[j].msg)
  }
  ghost predicate MintedBefore(acts: seq<Act>, k: int, m: Bytes)
  {
    exists j :: 0 <= j < k && j < |acts| && acts[j].MintAct? && acts[j].msg == m
  }
  // H1B (cryptographic, Ed25519 EUF-CMA read per trace): bytes that verify at a delivery were signed earlier.
  // The bytes are BytesOf(tok): the REAL serialization model (SerModel) of the delivered token.
  opaque ghost predicate H1B_ByteUnforgeability(vb: ByteVerifier, acts: seq<Act>)
  {
    forall k | 0 <= k < |acts| && acts[k].Deliver? && vb(BytesOf(acts[k].tok), acts[k].tok.sig) ::
      MintedBefore(acts, k, BytesOf(acts[k].tok))
  }
  // B5 (glue, sink.ts:71-75 verified(); sink.ts:74 signedBytes(token.body)): the boolean is the verifier on the bytes.
  opaque ghost predicate B5_VerifierBoolean(vb: ByteVerifier, acts: seq<Act>)
  {
    forall k | 0 <= k < |acts| && acts[k].Deliver? :: acts[k].sigOk == vb(BytesOf(acts[k].tok), acts[k].tok.sig)
  }
  // A4 (cryptographic, SHA-256 collision resistance read per trace): at each delivery, the hash of the STORED
  // charge equals the hash of an earlier mint's pre-state only if they are equal. It covers both the signature
  // binding (old A4) and the sink's hash compare (old A4b).
  opaque ghost predicate A4_HashBindsInRun(H: HashFn, init: F.Charge, acts: seq<Act>)
  {
    forall j, k | 0 <= j < k < |acts| && acts[j].MintAct? && acts[k].Deliver? ::
      H(TExec(H, init, acts[..k]).core.charge) == H(acts[j].pre) ==> TExec(H, init, acts[..k]).core.charge == acts[j].pre
  }

  // =============================================================================================
  // The conclusions.
  ghost predicate Shape(r: RunSt)
  {
    |r.toks| == |r.pres| && |r.pres| == |r.ks| && |r.ks| == |r.core.outbox|
  }
  // Entry i was committed by delivery ks[i] from the stored charge pres[i] (sigOk true).
  ghost predicate CommittedAt(H: HashFn, init: F.Charge, acts: seq<Act>, r: RunSt, i: int)
  {
    Shape(r) && 0 <= i < |r.toks| && 0 <= r.ks[i] < |acts| && acts[r.ks[i]].Deliver? &&
    acts[r.ks[i]].tok == r.toks[i] && acts[r.ks[i]].sigOk &&
    TExec(H, init, acts[..r.ks[i]]).core.charge == r.pres[i] &&
    Step(H, TExec(H, init, acts[..r.ks[i]]).core, r.toks[i], true).out.Committed?
  }
  // L0 per entry.
  ghost predicate EntryL0(H: HashFn, init: F.Charge, r: RunSt, i: int)
  {
    Shape(r) && 0 <= i < |r.toks| &&
    r.core.outbox[i] == IntentOfSM(r.toks[i].intent) &&
    r.toks[i].specHex == PIN_SPEC && r.toks[i].checkerHex == PIN_CHK &&
    H(r.pres[i]) == r.toks[i].preHash && r.core.outbox[i].requestId == r.toks[i].requestId &&
    r.pres[i].chargeId == init.chargeId && r.core.outbox[i].chargeId == init.chargeId &&
    ChargeOfState(r.toks[i].post).chargeId == init.chargeId && r.core.outbox[i].amount >= 0 &&
    r.pres[i] == (if i == 0 then init else ChargeOfState(r.toks[i - 1].post))
  }
  // L2 per entry: the spec approves the effect FROM THE STORED CHARGE at commit time.
  ghost predicate Approved(pre: F.Charge, tok: HashToken, e: R.RefundIntent)
  {
    e.requestId == tok.requestId && e.chargeId == pre.chargeId &&
    R.Eligible(F.ContextOf(pre, e.requestId), R.Candidate(e.amount, e.reason)) &&
    F.Authorizes(pre, F.Transition(F.Request(e.requestId, e.amount, e.reason), ChargeOfState(tok.post), e))
  }
  ghost predicate EntryL2(acts: seq<Act>, r: RunSt, i: int)
  {
    Shape(r) && 0 <= i < |r.toks| &&
    Approved(r.pres[i], r.toks[i], r.core.outbox[i]) && MintedBefore(acts, r.ks[i], BytesOf(r.toks[i]))
  }
  // L3 per entry.
  ghost predicate FlatResultAgrees(art: S3.FlatFn, r: RunSt, i: int)
  {
    Shape(r) && 0 <= i < |r.toks| &&
    var e := r.core.outbox[i];
    var o := art(S3.FlatInputsOf(r.pres[i], e));
    LR.Unflatten(o.0, o.1, o.2, o.3, o.4, o.5) ==
      (LR.Authorized(e.amount, e.reason), [LR.Intent(e.chargeId, e.requestId, e.amount, e.reason)])
  }

  // =============================================================================================
  // L0: invariant with no hypothesis.
  ghost predicate InvL0(H: HashFn, init: F.Charge, acts: seq<Act>, k: int, r: RunSt)
  {
    Shape(r) && r.n == k && GoodV3(r.core) && r.core.charge.chargeId == init.chargeId &&
    r.core.charge == (if |r.toks| == 0 then init else ChargeOfState(r.toks[|r.toks| - 1].post)) &&
    (forall i | 0 <= i < |r.toks| :: r.ks[i] < k && CommittedAt(H, init, acts, r, i) && EntryL0(H, init, r, i))
  }

  lemma StepKeepsGoodV3(H: HashFn, c: Core, tok: HashToken, sigOk: bool)
    requires GoodV3(c)
    ensures GoodV3(Step(H, c, tok, sigOk).core)
    ensures Step(H, c, tok, sigOk).core.charge.chargeId == c.charge.chargeId
  {
    var ds := [Delivery(tok, sigOk)];
    RunKeepsGoodV3(H, c, ds);
    assert ds[1..] == [];
    assert Run(H, c, ds) == Step(H, c, tok, sigOk).core;
  }

  lemma InvL0NextCommit(H: HashFn, init: F.Charge, acts: seq<Act>, k: int)
    requires 0 <= k < |acts| && acts[k].Deliver?
    requires InvL0(H, init, acts, k, TExec(H, init, acts[..k]))
    requires Step(H, TExec(H, init, acts[..k]).core, acts[k].tok, acts[k].sigOk).out.Committed?
    ensures InvL0(H, init, acts, k + 1, TNext(H, TExec(H, init, acts[..k]), acts[k]))
  {
    var r := TExec(H, init, acts[..k]);
    var tok := acts[k].tok;
    var sigOk := acts[k].sigOk;
    StepExact(H, r.core, tok, sigOk);
    StepKeepsGoodV3(H, r.core, tok, sigOk);
    var r' := TNext(H, r, acts[k]);
    var m := |r.toks|;
    assert r' == RunSt(Step(H, r.core, tok, sigOk).core, r.toks + [tok], r.pres + [r.core.charge], r.ks + [k], k + 1);
    assert sigOk;
    forall i | 0 <= i < |r'.toks|
      ensures r'.ks[i] < k + 1 && CommittedAt(H, init, acts, r', i) && EntryL0(H, init, r', i)
    {
      if i < m {
        assert r'.toks[i] == r.toks[i] && r'.pres[i] == r.pres[i] && r'.ks[i] == r.ks[i];
        assert r'.core.outbox[i] == r.core.outbox[i];
        assert CommittedAt(H, init, acts, r, i) && EntryL0(H, init, r, i);
        if i > 0 { assert r'.toks[i - 1] == r.toks[i - 1]; }
      } else {
        assert i == m && r'.toks[i] == tok && r'.pres[i] == r.core.charge && r'.ks[i] == k;
        assert acts[..k] == acts[..r'.ks[i]];
        assert r'.core.outbox[i] == IntentOfSM(tok.intent);
        if i > 0 { assert r'.toks[i - 1] == r.toks[m - 1]; }
      }
    }
  }

  lemma InvL0Next(H: HashFn, init: F.Charge, acts: seq<Act>, k: int)
    requires 0 <= k < |acts|
    requires InvL0(H, init, acts, k, TExec(H, init, acts[..k]))
    ensures InvL0(H, init, acts, k + 1, TNext(H, TExec(H, init, acts[..k]), acts[k]))
  {
    var r := TExec(H, init, acts[..k]);
    if acts[k].Deliver? && Step(H, r.core, acts[k].tok, acts[k].sigOk).out.Committed? {
      InvL0NextCommit(H, init, acts, k);
    } else {
      var r' := TNext(H, r, acts[k]);
      assert r' == RunSt(r.core, r.toks, r.pres, r.ks, k + 1);
      forall i | 0 <= i < |r'.toks|
        ensures r'.ks[i] < k + 1 && CommittedAt(H, init, acts, r', i) && EntryL0(H, init, r', i)
      {
        assert CommittedAt(H, init, acts, r, i) && EntryL0(H, init, r, i);
      }
    }
  }

  lemma InvL0Holds(H: HashFn, init: F.Charge, acts: seq<Act>, k: int)
    requires 0 <= k <= |acts|
    ensures InvL0(H, init, acts, k, TExec(H, init, acts[..k]))
    decreases k
  {
    if k == 0 {
      assert acts[..0] == [];
    } else {
      InvL0Holds(H, init, acts, k - 1);
      TExecStep(H, init, acts, k - 1);
      InvL0Next(H, init, acts, k - 1);
    }
  }

  // L0 THEOREM: any H, any tokens, any sigOk, no hypothesis.
  lemma SliceSafetyBytesV3_L0(H: HashFn, init: F.Charge, acts: seq<Act>)
    ensures var r := TExec(H, init, acts);
      Shape(r) && GoodV3(r.core) && r.core.charge.chargeId == init.chargeId &&
      (forall i | 0 <= i < |r.toks| :: CommittedAt(H, init, acts, r, i) && EntryL0(H, init, r, i))
  {
    InvL0Holds(H, init, acts, |acts|);
    assert acts[..|acts|] == acts;
  }

  // =============================================================================================
  // L2.
  ghost predicate InvL2(H: HashFn, init: F.Charge, acts: seq<Act>, k: int, r: RunSt)
  {
    InvL0(H, init, acts, k, r) &&
    (forall i | 0 <= i < |r.toks| :: EntryL2(acts, r, i)) &&
    SumIntents(r.core.outbox) == init.remaining - r.core.charge.remaining &&
    0 <= r.core.charge.remaining <= r.core.charge.original && r.core.charge.original == init.original
  }

  // The heart: one committed delivery under the hypotheses is approved from the STORED charge.
  lemma CommitApproved(H: HashFn, init: F.Charge, acts: seq<Act>, vb: ByteVerifier, k: int)
    requires 0 <= k < |acts| && acts[k].Deliver?
    requires A2p_MintsAreIssued(H, acts) && H1B_ByteUnforgeability(vb, acts) && B5_VerifierBoolean(vb, acts)
    requires A4_HashBindsInRun(H, init, acts)
    requires Step(H, TExec(H, init, acts[..k]).core, acts[k].tok, acts[k].sigOk).out.Committed?
    ensures Approved(TExec(H, init, acts[..k]).core.charge, acts[k].tok, IntentOfSM(acts[k].tok.intent))
    ensures MintedBefore(acts, k, BytesOf(acts[k].tok))
    ensures ChargeOfState(acts[k].tok.post) ==
            TExec(H, init, acts[..k]).core.charge.(remaining := TExec(H, init, acts[..k]).core.charge.remaining - acts[k].tok.intent.amount)
    ensures 0 <= acts[k].tok.intent.amount <= TExec(H, init, acts[..k]).core.charge.remaining
  {
    reveal A2p_MintsAreIssued(), H1B_ByteUnforgeability(), B5_VerifierBoolean(), A4_HashBindsInRun();
    var r := TExec(H, init, acts[..k]);
    var tok := acts[k].tok;
    StepExact(H, r.core, tok, acts[k].sigOk);
    assert vb(BytesOf(tok), tok.sig);
    assert MintedBefore(acts, k, BytesOf(tok));
    var j :| 0 <= j < k && j < |acts| && acts[j].MintAct? && acts[j].msg == BytesOf(tok);
    assert OurBytes(acts[j].msg) by {
      assert SM.SignedBytes(BodyOf(tok)) == acts[j].msg && BodyOf(tok).specLockSha256 == PIN_SPEC &&
             BodyOf(tok).checkerSha256 == PIN_CHK;
    }
    var t :| IssuedFrom(H, acts[j].pre, t, acts[j].msg);
    IssuedTokenFields(H, acts[j].pre, t, tok);
    assert H(r.core.charge) == H(acts[j].pre);
    assert r.core.charge == acts[j].pre;
    AuthorizedMoneyNonNeg(acts[j].pre, t);
    var e := IntentOfSM(tok.intent);
    assert e == t.intent;
    assert F.Request(e.requestId, e.amount, e.reason) == t.request;
    assert F.Transition(F.Request(e.requestId, e.amount, e.reason), ChargeOfState(tok.post), e) == t;
  }

  lemma SumAppend(o: seq<R.RefundIntent>, e: R.RefundIntent)
    ensures SumIntents(o + [e]) == SumIntents(o) + e.amount
  {
    assert (o + [e])[..|o|] == o;
  }

  lemma InvL2NextCommit(H: HashFn, init: F.Charge, acts: seq<Act>, vb: ByteVerifier, k: int)
    requires 0 <= k < |acts| && acts[k].Deliver?
    requires A2p_MintsAreIssued(H, acts) && H1B_ByteUnforgeability(vb, acts) && B5_VerifierBoolean(vb, acts)
    requires A4_HashBindsInRun(H, init, acts)
    requires InvL2(H, init, acts, k, TExec(H, init, acts[..k]))
    requires Step(H, TExec(H, init, acts[..k]).core, acts[k].tok, acts[k].sigOk).out.Committed?
    ensures InvL2(H, init, acts, k + 1, TNext(H, TExec(H, init, acts[..k]), acts[k]))
  {
    var r := TExec(H, init, acts[..k]);
    var tok := acts[k].tok;
    InvL0NextCommit(H, init, acts, k);
    CommitApproved(H, init, acts, vb, k);
    StepExact(H, r.core, tok, acts[k].sigOk);
    var r' := TNext(H, r, acts[k]);
    var m := |r.toks|;
    var e := IntentOfSM(tok.intent);
    assert r' == RunSt(Step(H, r.core, tok, acts[k].sigOk).core, r.toks + [tok], r.pres + [r.core.charge], r.ks + [k], k + 1);
    assert r'.core.outbox == r.core.outbox + [e];
    SumAppend(r.core.outbox, e);
    forall i | 0 <= i < |r'.toks|
      ensures EntryL2(acts, r', i)
    {
      if i < m {
        assert r'.toks[i] == r.toks[i] && r'.pres[i] == r.pres[i] && r'.ks[i] == r.ks[i];
        assert r'.core.outbox[i] == r.core.outbox[i];
        assert EntryL2(acts, r, i);
      } else {
        assert r'.toks[i] == tok && r'.pres[i] == r.core.charge && r'.ks[i] == k && r'.core.outbox[i] == e;
      }
    }
  }

  lemma InvL2Next(H: HashFn, init: F.Charge, acts: seq<Act>, vb: ByteVerifier, k: int)
    requires 0 <= k < |acts|
    requires A2p_MintsAreIssued(H, acts) && H1B_ByteUnforgeability(vb, acts) && B5_VerifierBoolean(vb, acts)
    requires A4_HashBindsInRun(H, init, acts)
    requires InvL2(H, init, acts, k, TExec(H, init, acts[..k]))
    ensures InvL2(H, init, acts, k + 1, TNext(H, TExec(H, init, acts[..k]), acts[k]))
  {
    var r := TExec(H, init, acts[..k]);
    if acts[k].Deliver? && Step(H, r.core, acts[k].tok, acts[k].sigOk).out.Committed? {
      InvL2NextCommit(H, init, acts, vb, k);
    } else {
      InvL0Next(H, init, acts, k);
      var r' := TNext(H, r, acts[k]);
      assert r' == RunSt(r.core, r.toks, r.pres, r.ks, k + 1);
      forall i | 0 <= i < |r'.toks| ensures EntryL2(acts, r', i) { assert EntryL2(acts, r, i); }
    }
  }

  lemma InvL2Base(H: HashFn, init: F.Charge, acts: seq<Act>)
    requires InitOk(init)
    ensures InvL2(H, init, acts, 0, TExec(H, init, acts[..0]))
  {
    assert acts[..0] == [];
    InvL0Holds(H, init, acts, 0);
    assert TExec(H, init, acts[..0]) == RunSt(Core(init, {}, []), [], [], [], 0);
  }

  lemma InvL2Holds(H: HashFn, init: F.Charge, acts: seq<Act>, vb: ByteVerifier, k: int)
    requires 0 <= k <= |acts|
    requires InitOk(init)
    requires A2p_MintsAreIssued(H, acts) && H1B_ByteUnforgeability(vb, acts) && B5_VerifierBoolean(vb, acts)
    requires A4_HashBindsInRun(H, init, acts)
    ensures InvL2(H, init, acts, k, TExec(H, init, acts[..k]))
    decreases k
  {
    if k == 0 {
      InvL2Base(H, init, acts);
    } else {
      InvL2Holds(H, init, acts, vb, k - 1);
      TExecStep(H, init, acts, k - 1);
      InvL2Next(H, init, acts, vb, k - 1);
    }
  }

  // L2 THEOREM. Each committed effect is approved by the spec FROM THE STORED CHARGE at its commit, its exact
  // signed bytes were minted before the commit, the money stays in bounds and the sum equation holds.
  lemma SliceSafetyBytesV3_L2(H: HashFn, init: F.Charge, acts: seq<Act>, vb: ByteVerifier)
    requires InitOk(init)
    requires A2p_MintsAreIssued(H, acts)
    requires H1B_ByteUnforgeability(vb, acts)
    requires B5_VerifierBoolean(vb, acts)
    requires A4_HashBindsInRun(H, init, acts)
    ensures var r := TExec(H, init, acts);
      Shape(r) &&
      (forall i | 0 <= i < |r.toks| :: CommittedAt(H, init, acts, r, i) && EntryL0(H, init, r, i) && EntryL2(acts, r, i)) &&
      0 <= r.core.charge.remaining <= r.core.charge.original && r.core.charge.original == init.original &&
      SumIntents(r.core.outbox) == init.remaining - r.core.charge.remaining
  {
    InvL2Holds(H, init, acts, vb, |acts|);
    assert acts[..|acts|] == acts;
  }

  // L3 THEOREM: plus the artifact boundary.
  lemma SliceSafetyBytesV3_L3(H: HashFn, init: F.Charge, acts: seq<Act>, vb: ByteVerifier, art: S3.FlatFn)
    requires InitOk(init)
    requires A2p_MintsAreIssued(H, acts)
    requires H1B_ByteUnforgeability(vb, acts)
    requires B5_VerifierBoolean(vb, acts)
    requires A4_HashBindsInRun(H, init, acts)
    requires S3.A6b_ArtifactComputesFlatContractOnBytes(art)
    ensures var r := TExec(H, init, acts);
      forall i | 0 <= i < |r.toks| :: FlatResultAgrees(art, r, i)
  {
    SliceSafetyBytesV3_L2(H, init, acts, vb);
    var r := TExec(H, init, acts);
    forall i | 0 <= i < |r.toks| ensures FlatResultAgrees(art, r, i)
    {
      assert EntryL2(acts, r, i);
      var e := r.core.outbox[i];
      S3.FlatPathBytes(art, r.pres[i], F.Request(e.requestId, e.amount, e.reason), ChargeOfState(r.toks[i].post), e);
    }
  }

  ghost predicate FullEntry(H: HashFn, init: F.Charge, acts: seq<Act>, art: S3.FlatFn, r: RunSt, i: int, e: R.RefundIntent)
  {
    Shape(r) && 0 <= i < |r.toks| && r.core.outbox[i] == e &&
    CommittedAt(H, init, acts, r, i) && EntryL0(H, init, r, i) && EntryL2(acts, r, i) && FlatResultAgrees(art, r, i)
  }

  // The composed statement in one lemma: every effect in the outbox has an approved, signed, committed entry.
  lemma SliceSafetyBytesV3(H: HashFn, init: F.Charge, acts: seq<Act>, vb: ByteVerifier, art: S3.FlatFn)
    requires InitOk(init)
    requires A2p_MintsAreIssued(H, acts)
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
    SliceSafetyBytesV3_L0(H, init, acts);
    SliceSafetyBytesV3_L2(H, init, acts, vb);
    SliceSafetyBytesV3_L3(H, init, acts, vb, art);
    var r := TExec(H, init, acts);
    forall e | e in r.core.outbox
      ensures exists i :: FullEntry(H, init, acts, art, r, i, e)
    {
      var i :| 0 <= i < |r.core.outbox| && r.core.outbox[i] == e;
      assert CommittedAt(H, init, acts, r, i) && EntryL0(H, init, r, i) && EntryL2(acts, r, i) && FlatResultAgrees(art, r, i);
      assert FullEntry(H, init, acts, art, r, i, e);
    }
  }
}
