// Night shift 2026-11-19, Orchestrator B, task b-v6bytes (G2). A DRAFT in an evidence folder. NOT gate evidence.
// M1-B stays OPEN. end_to_end=false. A Dafny-MODEL statement only. It says nothing about sink.ts, minter.ts,
// Ed25519, SHA-256, SQLite, compiled code, the HOL model, CakeML or native execution.
//
// The trace model of SliceSafetyBytesV3 (b-ser2, byte-equal copy; the SAME Act, RunSt, MintedBefore, OurBytes,
// A2p_MintsAreIssued, H1B_ByteUnforgeability, B5_VerifierBoolean, Approved, FlatResultAgrees) with the sink step
// HashCore6.Step6 (= HashCore.Step plus the commit-time check of the approved relation on the STORED charge).
// Layers (each lemma has only the hypotheses it needs; every hypothesis is a NAMED predicate of SliceSafetyBytesV3):
//   L0  SliceSafetyBytesV6_L0       NO hypothesis: each commit is F.Authorizes on the STORED charge; post-state as
//                                   the relation says; original == init.original; sum equation; bounds after the
//                                   first commit; one effect per request id; charge-id binding.
//       SliceSafetyBytesV6_L0Money  InitOk only: 0 <= remaining <= original also for a run with no commit.
//   L1  SliceSafetyBytesV6_L1       H1B + B5: each committed token's exact bytes were minted before its commit.
//   L2  SliceSafetyBytesV6_L2       H1B + B5 + A2p: that mint is an output of the proved IssueBytes for the
//                                   transition TransH(tok) AND for the pre-state EQUAL to the stored charge.
//   L3  SliceSafetyBytesV6_L3       A6b only (on top of L0): the artifact's flat result agrees.
//   Composed: SliceSafetyBytesV6Top (InitOk + A2p + H1B + B5 + A6b).
// A4 (hash binding) is in NO lemma of this file: HashCore6.AuthorizesDeterminesPre replaces it in L2.
// The context of "approved" (CTX-SINK): F.Authorizes reads R.Eligible on F.ContextOf(stored charge, token request
// id) with requestOpen = TRUE. CTX-SINK names what "approved" means; it is NOT a proof hypothesis.
// No assume, no axiom, no bodiless lemma, no {:extern}, no expect in this file.
include "HashCore6.dfy"
include "SliceSafetyBytesV3.dfy"

module SliceSafetyBytesV6 {
  import opened HashCore
  import opened HashCore6
  import opened SliceSafetyBytesV3
  import S3 = SliceTheoremV3

  // =============================================================================================
  // The trace model (Act and RunSt of SliceSafetyBytesV3; only the step differs).
  function TNext6(H: HashFn, r: RunSt, a: Act): RunSt
  {
    if a.MintAct? then RunSt(r.core, r.toks, r.pres, r.ks, r.n + 1)
    else if Step6(H, r.core, a.tok, a.sigOk).out.Committed6? then
      RunSt(Step6(H, r.core, a.tok, a.sigOk).core, r.toks + [a.tok], r.pres + [r.core.charge], r.ks + [r.n], r.n + 1)
    else RunSt(r.core, r.toks, r.pres, r.ks, r.n + 1)
  }

  function TExec6(H: HashFn, init: F.Charge, acts: seq<Act>): RunSt
    decreases |acts|
  {
    if |acts| == 0 then RunSt(Core(init, {}, []), [], [], [], 0)
    else TNext6(H, TExec6(H, init, acts[..|acts| - 1]), acts[|acts| - 1])
  }

  lemma TExec6Step(H: HashFn, init: F.Charge, acts: seq<Act>, k: int)
    requires 0 <= k < |acts|
    ensures TExec6(H, init, acts[..k + 1]) == TNext6(H, TExec6(H, init, acts[..k]), acts[k])
  {
    assert acts[..k + 1][..k] == acts[..k];
    assert acts[..k + 1][k] == acts[k];
  }

  // =============================================================================================
  // The conclusions.
  // Entry i was committed by delivery ks[i] from the stored charge pres[i] (sigOk true).
  ghost predicate CommittedAt6(H: HashFn, init: F.Charge, acts: seq<Act>, r: RunSt, i: int)
  {
    Shape(r) && 0 <= i < |r.toks| && 0 <= r.ks[i] < |acts| && acts[r.ks[i]].Deliver? &&
    acts[r.ks[i]].tok == r.toks[i] && acts[r.ks[i]].sigOk &&
    TExec6(H, init, acts[..r.ks[i]]).core.charge == r.pres[i] &&
    Step6(H, TExec6(H, init, acts[..r.ks[i]]).core, r.toks[i], true).out.Committed6?
  }

  // L0 per entry. Approved (SliceSafetyBytesV3) = request-id and charge-id binding, R.Eligible on
  // F.ContextOf(pres[i], request id) (requestOpen = TRUE: CTX-SINK), and F.Authorizes(pres[i], transition).
  ghost predicate EntryL0v6(H: HashFn, init: F.Charge, r: RunSt, i: int)
  {
    Shape(r) && 0 <= i < |r.toks| &&
    r.core.outbox[i] == IntentOfSM(r.toks[i].intent) &&
    r.toks[i].specHex == PIN_SPEC && r.toks[i].checkerHex == PIN_CHK && H(r.pres[i]) == r.toks[i].preHash &&
    r.pres[i].chargeId == init.chargeId && r.core.outbox[i].chargeId == init.chargeId &&
    Approved(r.pres[i], r.toks[i], r.core.outbox[i]) &&
    ChargeOfState(r.toks[i].post) == r.pres[i].(remaining := r.pres[i].remaining - r.core.outbox[i].amount) &&
    0 <= r.core.outbox[i].amount <= r.pres[i].remaining <= r.pres[i].original &&
    r.pres[i] == (if i == 0 then init else ChargeOfState(r.toks[i - 1].post))
  }

  // The store totals (no hypothesis): the original never changes; the sum equation; bounds once something committed.
  ghost predicate MoneyL0(init: F.Charge, r: RunSt)
  {
    r.core.charge.original == init.original &&
    SumIntents(r.core.outbox) == init.remaining - r.core.charge.remaining &&
    (|r.toks| > 0 ==> 0 <= r.core.charge.remaining <= r.core.charge.original)
  }

  // =============================================================================================
  // L0: invariant with no hypothesis.
  ghost predicate InvL0v6(H: HashFn, init: F.Charge, acts: seq<Act>, k: int, r: RunSt)
  {
    Shape(r) && r.n == k && GoodV3(r.core) && r.core.charge.chargeId == init.chargeId &&
    r.core.charge == (if |r.toks| == 0 then init else ChargeOfState(r.toks[|r.toks| - 1].post)) &&
    MoneyL0(init, r) &&
    (forall i | 0 <= i < |r.toks| :: r.ks[i] < k && CommittedAt6(H, init, acts, r, i) && EntryL0v6(H, init, r, i))
  }

  lemma Step6KeepsGoodV3(H: HashFn, c: Core, tok: HashToken, sigOk: bool)
    requires GoodV3(c)
    ensures GoodV3(Step6(H, c, tok, sigOk).core)
    ensures Step6(H, c, tok, sigOk).core.charge.chargeId == c.charge.chargeId
  {
    if Step6(H, c, tok, sigOk).out.Committed6? {
      Step6CommitIsStepCommit(H, c, tok, sigOk);
      StepKeepsGoodV3(H, c, tok, sigOk);
    }
  }

  // The approved relation on the token's transition gives Approved (SliceSafetyBytesV3) on the token's intent.
  lemma ApprovedOfAuthorizes(pre: F.Charge, tok: HashToken)
    requires F.Authorizes(pre, TransH(tok))
    ensures var e := IntentOfSM(tok.intent);
      Approved(pre, tok, e) &&
      ChargeOfState(tok.post) == pre.(remaining := pre.remaining - e.amount) &&
      0 <= e.amount <= pre.remaining <= pre.original && e.chargeId == pre.chargeId
  {
    var e := IntentOfSM(tok.intent);
    assert F.Transition(F.Request(e.requestId, e.amount, e.reason), ChargeOfState(tok.post), e) == TransH(tok);
  }

  lemma InvL0v6NextCommit(H: HashFn, init: F.Charge, acts: seq<Act>, k: int)
    requires 0 <= k < |acts| && acts[k].Deliver?
    requires InvL0v6(H, init, acts, k, TExec6(H, init, acts[..k]))
    requires Step6(H, TExec6(H, init, acts[..k]).core, acts[k].tok, acts[k].sigOk).out.Committed6?
    ensures InvL0v6(H, init, acts, k + 1, TNext6(H, TExec6(H, init, acts[..k]), acts[k]))
  {
    var r := TExec6(H, init, acts[..k]);
    var tok := acts[k].tok;
    var sigOk := acts[k].sigOk;
    Step6Exact(H, r.core, tok, sigOk);
    Step6KeepsGoodV3(H, r.core, tok, sigOk);
    ApprovedOfAuthorizes(r.core.charge, tok);
    var r' := TNext6(H, r, acts[k]);
    var m := |r.toks|;
    var e := IntentOfSM(tok.intent);
    assert r' == RunSt(Step6(H, r.core, tok, sigOk).core, r.toks + [tok], r.pres + [r.core.charge], r.ks + [k], k + 1);
    assert r'.core.outbox == r.core.outbox + [e];
    assert sigOk;
    SumAppend(r.core.outbox, e);
    assert MoneyL0(init, r');
    forall i | 0 <= i < |r'.toks|
      ensures r'.ks[i] < k + 1 && CommittedAt6(H, init, acts, r', i) && EntryL0v6(H, init, r', i)
    {
      if i < m {
        assert r'.toks[i] == r.toks[i] && r'.pres[i] == r.pres[i] && r'.ks[i] == r.ks[i];
        assert r'.core.outbox[i] == r.core.outbox[i];
        assert CommittedAt6(H, init, acts, r, i) && EntryL0v6(H, init, r, i);
        if i > 0 { assert r'.toks[i - 1] == r.toks[i - 1]; }
      } else {
        assert i == m && r'.toks[i] == tok && r'.pres[i] == r.core.charge && r'.ks[i] == k;
        assert acts[..k] == acts[..r'.ks[i]];
        assert r'.core.outbox[i] == e;
        if i > 0 { assert r'.toks[i - 1] == r.toks[m - 1]; }
      }
    }
  }

  lemma InvL0v6Next(H: HashFn, init: F.Charge, acts: seq<Act>, k: int)
    requires 0 <= k < |acts|
    requires InvL0v6(H, init, acts, k, TExec6(H, init, acts[..k]))
    ensures InvL0v6(H, init, acts, k + 1, TNext6(H, TExec6(H, init, acts[..k]), acts[k]))
  {
    var r := TExec6(H, init, acts[..k]);
    if acts[k].Deliver? && Step6(H, r.core, acts[k].tok, acts[k].sigOk).out.Committed6? {
      InvL0v6NextCommit(H, init, acts, k);
    } else {
      var r' := TNext6(H, r, acts[k]);
      assert r' == RunSt(r.core, r.toks, r.pres, r.ks, k + 1);
      forall i | 0 <= i < |r'.toks|
        ensures r'.ks[i] < k + 1 && CommittedAt6(H, init, acts, r', i) && EntryL0v6(H, init, r', i)
      {
        assert CommittedAt6(H, init, acts, r, i) && EntryL0v6(H, init, r, i);
      }
    }
  }

  lemma InvL0v6Holds(H: HashFn, init: F.Charge, acts: seq<Act>, k: int)
    requires 0 <= k <= |acts|
    ensures InvL0v6(H, init, acts, k, TExec6(H, init, acts[..k]))
    decreases k
  {
    if k == 0 {
      assert acts[..0] == [];
      assert SumIntents([]) == 0;
    } else {
      InvL0v6Holds(H, init, acts, k - 1);
      TExec6Step(H, init, acts, k - 1);
      InvL0v6Next(H, init, acts, k - 1);
    }
  }

  // L0 THEOREM: any H (also a constant one), any tokens, any sigOk, any mints. NO hypothesis.
  lemma SliceSafetyBytesV6_L0(H: HashFn, init: F.Charge, acts: seq<Act>)
    ensures var r := TExec6(H, init, acts);
      Shape(r) && GoodV3(r.core) && r.core.charge.chargeId == init.chargeId && MoneyL0(init, r) &&
      (forall i | 0 <= i < |r.toks| :: CommittedAt6(H, init, acts, r, i) && EntryL0v6(H, init, r, i))
  {
    InvL0v6Holds(H, init, acts, |acts|);
    assert acts[..|acts|] == acts;
  }

  // L0 with InitOk: the bounds hold also for a run with no commit.
  lemma SliceSafetyBytesV6_L0Money(H: HashFn, init: F.Charge, acts: seq<Act>)
    requires InitOk(init)
    ensures var r := TExec6(H, init, acts);
      0 <= r.core.charge.remaining <= r.core.charge.original && r.core.charge.original == init.original &&
      SumIntents(r.core.outbox) == init.remaining - r.core.charge.remaining
  {
    InvL0v6Holds(H, init, acts, |acts|);
    assert acts[..|acts|] == acts;
  }

  // =============================================================================================
  // L1: H1B + B5. No A2p, no A4.
  lemma SliceSafetyBytesV6_L1(H: HashFn, init: F.Charge, acts: seq<Act>, vb: ByteVerifier)
    requires H1B_ByteUnforgeability(vb, acts)
    requires B5_VerifierBoolean(vb, acts)
    ensures var r := TExec6(H, init, acts);
      Shape(r) && forall i | 0 <= i < |r.toks| :: MintedBefore(acts, r.ks[i], BytesOf(r.toks[i]))
  {
    SliceSafetyBytesV6_L0(H, init, acts);
    var r := TExec6(H, init, acts);
    forall i | 0 <= i < |r.toks| ensures MintedBefore(acts, r.ks[i], BytesOf(r.toks[i]))
    {
      assert CommittedAt6(H, init, acts, r, i);
      var k := r.ks[i];
      reveal H1B_ByteUnforgeability(), B5_VerifierBoolean();
      assert acts[k].sigOk && acts[k].tok == r.toks[i];
      assert vb(BytesOf(acts[k].tok), acts[k].tok.sig);
    }
  }

  // =============================================================================================
  // L2: + A2p. The mint of the committed bytes came from the proved IssueBytes on EXACTLY the stored charge.
  ghost predicate IssuedAtStored(H: HashFn, acts: seq<Act>, r: RunSt, i: int)
  {
    Shape(r) && 0 <= i < |r.toks| &&
    exists j :: 0 <= j < r.ks[i] && j < |acts| && acts[j].MintAct? && acts[j].msg == BytesOf(r.toks[i]) &&
      acts[j].pre == r.pres[i] && IssuedFrom(H, acts[j].pre, TransH(r.toks[i]), acts[j].msg)
  }

  // The issued transition read back from the bytes is the token's transition.
  lemma IssuedIsTransH(H: HashFn, p: F.Charge, t: F.Transition, tok: HashToken)
    requires IssuedFrom(H, p, t, BytesOf(tok))
    ensures t == TransH(tok) && F.Authorizes(p, TransH(tok)) && tok.preHash == H(p)
  {
    IssuedTokenFields(H, p, t, tok);
  }

  lemma EntryIssuedAtStored(H: HashFn, init: F.Charge, acts: seq<Act>, r: RunSt, i: int)
    requires A2p_MintsAreIssued(H, acts)
    requires 0 <= i < |r.toks| && EntryL0v6(H, init, r, i) && CommittedAt6(H, init, acts, r, i)
    requires MintedBefore(acts, r.ks[i], BytesOf(r.toks[i]))
    ensures IssuedAtStored(H, acts, r, i)
  {
    var tok := r.toks[i];
    var j :| 0 <= j < r.ks[i] && j < |acts| && acts[j].MintAct? && acts[j].msg == BytesOf(tok);
    assert OurBytes(acts[j].msg) by {
      assert SM.SignedBytes(BodyOf(tok)) == acts[j].msg && BodyOf(tok).specLockSha256 == PIN_SPEC &&
             BodyOf(tok).checkerSha256 == PIN_CHK;
    }
    reveal A2p_MintsAreIssued();
    var t :| IssuedFrom(H, acts[j].pre, t, acts[j].msg);
    IssuedIsTransH(H, acts[j].pre, t, tok);
    var e := r.core.outbox[i];
    assert e == IntentOfSM(tok.intent);
    assert F.Transition(F.Request(e.requestId, e.amount, e.reason), ChargeOfState(tok.post), e) == TransH(tok);
    AuthorizesDeterminesPre(acts[j].pre, r.pres[i], TransH(tok));
  }

  lemma SliceSafetyBytesV6_L2(H: HashFn, init: F.Charge, acts: seq<Act>, vb: ByteVerifier)
    requires A2p_MintsAreIssued(H, acts)
    requires H1B_ByteUnforgeability(vb, acts)
    requires B5_VerifierBoolean(vb, acts)
    ensures var r := TExec6(H, init, acts);
      forall i | 0 <= i < |r.toks| :: IssuedAtStored(H, acts, r, i)
  {
    SliceSafetyBytesV6_L0(H, init, acts);
    SliceSafetyBytesV6_L1(H, init, acts, vb);
    var r := TExec6(H, init, acts);
    forall i | 0 <= i < |r.toks| ensures IssuedAtStored(H, acts, r, i)
    {
      EntryIssuedAtStored(H, init, acts, r, i);
    }
  }

  // =============================================================================================
  // L3: A6b only (L0 gives Approved, which is all FlatPathBytes needs).
  lemma SliceSafetyBytesV6_L3(H: HashFn, init: F.Charge, acts: seq<Act>, art: S3.FlatFn)
    requires S3.A6b_ArtifactComputesFlatContractOnBytes(art)
    ensures var r := TExec6(H, init, acts);
      forall i | 0 <= i < |r.toks| :: FlatResultAgrees(art, r, i)
  {
    SliceSafetyBytesV6_L0(H, init, acts);
    var r := TExec6(H, init, acts);
    forall i | 0 <= i < |r.toks| ensures FlatResultAgrees(art, r, i)
    {
      assert EntryL0v6(H, init, r, i);
      var e := r.core.outbox[i];
      S3.FlatPathBytes(art, r.pres[i], F.Request(e.requestId, e.amount, e.reason), ChargeOfState(r.toks[i].post), e);
    }
  }

  // =============================================================================================
  ghost predicate FullEntry6(H: HashFn, init: F.Charge, acts: seq<Act>, art: S3.FlatFn, r: RunSt, i: int, e: R.RefundIntent)
  {
    Shape(r) && 0 <= i < |r.toks| && r.core.outbox[i] == e &&
    CommittedAt6(H, init, acts, r, i) && EntryL0v6(H, init, r, i) &&
    MintedBefore(acts, r.ks[i], BytesOf(r.toks[i])) && IssuedAtStored(H, acts, r, i) && FlatResultAgrees(art, r, i)
  }

  // The composed statement. NO A4.
  lemma SliceSafetyBytesV6Top(H: HashFn, init: F.Charge, acts: seq<Act>, vb: ByteVerifier, art: S3.FlatFn)
    requires InitOk(init)
    requires A2p_MintsAreIssued(H, acts)
    requires H1B_ByteUnforgeability(vb, acts)
    requires B5_VerifierBoolean(vb, acts)
    requires S3.A6b_ArtifactComputesFlatContractOnBytes(art)
    ensures var r := TExec6(H, init, acts);
      Shape(r) &&
      (forall e | e in r.core.outbox :: exists i :: FullEntry6(H, init, acts, art, r, i, e)) &&
      GoodV3(r.core) && r.core.charge.chargeId == init.chargeId &&
      0 <= r.core.charge.remaining <= r.core.charge.original && r.core.charge.original == init.original &&
      SumIntents(r.core.outbox) == init.remaining - r.core.charge.remaining
  {
    SliceSafetyBytesV6_L0(H, init, acts);
    SliceSafetyBytesV6_L0Money(H, init, acts);
    SliceSafetyBytesV6_L1(H, init, acts, vb);
    SliceSafetyBytesV6_L2(H, init, acts, vb);
    SliceSafetyBytesV6_L3(H, init, acts, art);
    var r := TExec6(H, init, acts);
    forall e | e in r.core.outbox
      ensures exists i :: FullEntry6(H, init, acts, art, r, i, e)
    {
      var i :| 0 <= i < |r.core.outbox| && r.core.outbox[i] == e;
      assert FullEntry6(H, init, acts, art, r, i, e);
    }
  }
}
