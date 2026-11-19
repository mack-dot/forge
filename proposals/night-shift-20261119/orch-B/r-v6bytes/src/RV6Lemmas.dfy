// Night shift 2026-11-19, Orchestrator B, task r-v6bytes (review of b-v6bytes). Reviewer lemmas. NOT gate evidence.
// No assume, no axiom, no bodiless lemma, no {:extern}, no expect in this file.
include "ControlsBytesV6.dfy"
include "KeyedV6.dfy"

module RV6Lemmas {
  import opened HashCore
  import opened HashCore6
  import opened SliceSafetyBytesV3
  import opened SliceSafetyBytesV6
  import opened KeyedV6
  import ControlsBytesV3

  // ---- Attack 2: L0 and the initial charge ----
  // V1: one commit implies InitOk(init). So a bad initial charge never commits (no hypothesis).
  lemma CommitImpliesInitOk(H: HashFn, init: F.Charge, acts: seq<Act>)
    requires |TExec6(H, init, acts).toks| > 0
    ensures InitOk(init) && R.Money(init.original) && init.refundEnabled
  {
    SliceSafetyBytesV6_L0(H, init, acts);
    var r := TExec6(H, init, acts);
    assert EntryL0v6(H, init, r, 0);
    assert r.pres[0] == init;
    ApprovedGivesValid(r.pres[0], r.toks[0], r.core.outbox[0]);
  }

  lemma ApprovedGivesValid(pre: F.Charge, tok: HashToken, e: R.RefundIntent)
    requires Approved(pre, tok, e)
    ensures 0 <= pre.remaining <= pre.original && R.Money(pre.original) && pre.refundEnabled
  {}

  lemma BadInitNeverCommits(H: HashFn, init: F.Charge, acts: seq<Act>)
    requires !InitOk(init)
    ensures TExec6(H, init, acts).toks == [] && TExec6(H, init, acts).core.charge == init &&
            TExec6(H, init, acts).core.outbox == []
  {
    SliceSafetyBytesV6_L0(H, init, acts);
    if |TExec6(H, init, acts).toks| > 0 { CommitImpliesInitOk(H, init, acts); }
  }

  // V2: the sum equation with NEGATIVE initial money (integer semantics): no commit, sum 0 == init.remaining - remaining.
  lemma NegativeInitSum(H: HashFn, acts: seq<Act>)
    ensures var init := F.Charge("c", -5, -7, true); var r := TExec6(H, init, acts);
      r.toks == [] && SumIntents(r.core.outbox) == 0 && SumIntents(r.core.outbox) == init.remaining - r.core.charge.remaining
  {
    BadInitNeverCommits(H, F.Charge("c", -5, -7, true), acts);
  }

  // ---- Attack 3: a hash collision never makes Step6 commit ----
  // V3: a token whose bytes the issuer produced for pre-state p, delivered when the stored charge is q != p, with
  // H(q) == H(p): Step6 rejects. No hypothesis on H.
  lemma CollisionRejected(H: HashFn, p: F.Charge, t: F.Transition, tok: HashToken, core: Core, sigOk: bool)
    requires IssuedFrom(H, p, t, BytesOf(tok))
    requires core.charge != p && H(core.charge) == H(p)
    ensures !Step6(H, core, tok, sigOk).out.Committed6? && Step6(H, core, tok, sigOk).core == core
  {
    IssuedIsTransH(H, p, t, tok);
    if Step6(H, core, tok, sigOk).out.Committed6? {
      Step6CommitIsStepCommit(H, core, tok, sigOk);
      AuthorizesDeterminesPre(p, core.charge, TransH(tok));
    }
  }

  // ---- Attack 4: what A2p adds in V6 ----
  // V4: with NO hypothesis, each committed token's bytes ARE the output of IssueOut on the STORED charge for its
  // transition (IssuedFrom(H, pres[i], TransH(tok), BytesOf(tok))).
  lemma IssuedOnStoredNoHyp(H: HashFn, init: F.Charge, acts: seq<Act>)
    ensures var r := TExec6(H, init, acts);
      Shape(r) && forall i | 0 <= i < |r.toks| :: IssuedFrom(H, r.pres[i], TransH(r.toks[i]), BytesOf(r.toks[i]))
  {
    SliceSafetyBytesV6_L0(H, init, acts);
    var r := TExec6(H, init, acts);
    forall i | 0 <= i < |r.toks| ensures IssuedFrom(H, r.pres[i], TransH(r.toks[i]), BytesOf(r.toks[i]))
    {
      assert CommittedAt6(H, init, acts, r, i) && EntryL0v6(H, init, r, i);
      var tok := r.toks[i];
      var k := r.ks[i];
      var c := TExec6(H, init, acts[..k]).core;
      Step6CommitIsStepCommit(H, c, tok, true);
      Commit6Binds(H, c, tok, true);
      assert StateOfN(ChargeOfState(tok.post)) == tok.post;
      assert IntentOfN(IntentOfSM(tok.intent)) == tok.intent;
      assert IssueBody(H, r.pres[i], TransH(tok)) == BodyOf(tok);
    }
  }

  // V5: L2 WITHOUT A2p, except the ghost label: with H1B + B5 only, each committed token's bytes were minted earlier
  // and those minted bytes are IssuedFrom on the STORED charge. A2p adds only "acts[j].pre == stored".
  lemma L2WithoutA2p(H: HashFn, init: F.Charge, acts: seq<Act>, vb: ByteVerifier)
    requires H1B_ByteUnforgeability(vb, acts) && B5_VerifierBoolean(vb, acts)
    ensures var r := TExec6(H, init, acts);
      Shape(r) && forall i | 0 <= i < |r.toks| ::
        (exists j :: 0 <= j < r.ks[i] && j < |acts| && acts[j].MintAct? &&
           acts[j].msg == BytesOf(r.toks[i]) && IssuedFrom(H, r.pres[i], TransH(r.toks[i]), acts[j].msg))
  {
    SliceSafetyBytesV6_L1(H, init, acts, vb);
    IssuedOnStoredNoHyp(H, init, acts);
  }

  // ---- Attack 7/8: SEMANTIC controls (direct evaluation of Step6; no Step6Exact, no HashCore6 lemma) ----
  const ST: F.Charge := F.Charge("ch_1", 100, 60, true)
  function HC0(c: F.Charge): string { "h" }
  // Zero amount, FOREIGN post-state (remaining 90 > 60): Step commits it; Step6 must reject.
  const ZF: HashToken := HashToken(PIN_SPEC, PIN_CHK, "h", "rq_z", SM.ChargeState("ch_1", 100, 90, true),
                                   SM.Intent("ch_1", "rq_z", 0, CV3Reason()), [])
  function CV3Reason(): string { ControlsBytesV3.DC }
  // Zero amount, correct post-state.
  const ZG: HashToken := HashToken(PIN_SPEC, PIN_CHK, "h", "rq_z", SM.ChargeState("ch_1", 100, 60, true),
                                   SM.Intent("ch_1", "rq_z", 0, CV3Reason()), [])
  // Positive amount 10, correct post-state.
  const PG: HashToken := HashToken(PIN_SPEC, PIN_CHK, "h", "rq_p", SM.ChargeState("ch_1", 100, 50, true),
                                   SM.Intent("ch_1", "rq_p", 10, CV3Reason()), [])

  lemma SemZeroForeignPostRejected()
    ensures Step(HC0, Core(ST, {}, []), ZF, true).out.Committed?
    ensures Step6(HC0, Core(ST, {}, []), ZF, true) == StepResult6(Core(ST, {}, []), Rejected6(NotAuthorized))
  {
    ControlsBytesV3.Authorized();
  }

  lemma SemZeroGoodCommits()
    ensures Step6(HC0, Core(ST, {}, []), ZG, true) == StepResult6(Core(ST, {"rq_z"}, [R.Intent("ch_1", "rq_z", 0, CV3Reason())]), Committed6)
  {
    ControlsBytesV3.Authorized();
  }

  lemma SemPositiveCommits()
    ensures Step6(HC0, Core(ST, {}, []), PG, true) ==
      StepResult6(Core(ST.(remaining := 50), {"rq_p"}, [R.Intent("ch_1", "rq_p", 10, CV3Reason())]), Committed6)
  {
    ControlsBytesV3.Authorized();
  }

  // ---- Attack 6: the same signed bytes commit at most once across all stores (KeyedV6, NO hypothesis) ----
  lemma Mono6(H: HashFn, acts: seq<KAct6>, a: int, b: int, k: string)
    requires 0 <= a <= b <= |acts|
    requires k in KExec6(H, acts[..a])
    ensures k in KExec6(H, acts[..b])
    ensures KExec6(H, acts[..a])[k].settled <= KExec6(H, acts[..b])[k].settled
    decreases b
  {
    if b > a {
      Mono6(H, acts, a, b - 1, k);
      KExec6Step(H, acts, b - 1);
      var st := KExec6(H, acts[..b - 1]);
      match acts[b - 1]
      case KMint6(_, _, _) =>
      case KCreate6(_, _) =>
      case KDel6(key, tok, s) =>
        if key == k { Step6Exact(H, st[k], tok, s); }
    }
  }

  lemma CommitKey6(H: HashFn, acts: seq<KAct6>, g: int)
    requires CommitsAt6(H, acts, g)
    ensures acts[g].key == acts[g].tok.intent.chargeId
    ensures acts[g].key in KExec6(H, acts[..g + 1])
    ensures acts[g].tok.requestId in KExec6(H, acts[..g + 1])[acts[g].key].settled
  {
    KExec6WellKeyed(H, acts[..g]);
    KExec6Step(H, acts, g);
    var st := KExec6(H, acts[..g]);
    Step6Exact(H, st[acts[g].key], acts[g].tok, acts[g].sigOk);
    Commit6Binds(H, st[acts[g].key], acts[g].tok, acts[g].sigOk);
  }

  lemma NoDoubleCommit6(H: HashFn, acts: seq<KAct6>, g1: int, g2: int)
    requires g1 < g2 && CommitsAt6(H, acts, g1) && CommitsAt6(H, acts, g2)
    ensures acts[g1].tok.requestId != acts[g2].tok.requestId ||
            acts[g1].tok.intent.chargeId != acts[g2].tok.intent.chargeId
  {
    CommitKey6(H, acts, g1);
    CommitKey6(H, acts, g2);
    if acts[g1].tok.requestId == acts[g2].tok.requestId && acts[g1].tok.intent.chargeId == acts[g2].tok.intent.chargeId {
      var k := acts[g1].key;
      Mono6(H, acts, g1 + 1, g2, k);
      Step6Exact(H, KExec6(H, acts[..g2])[k], acts[g2].tok, acts[g2].sigOk);
      assert false;
    }
  }

  lemma SameBytesCommitOnce6(H: HashFn, acts: seq<KAct6>, g1: int, g2: int)
    requires g1 != g2 && CommitsAt6(H, acts, g1) && CommitsAt6(H, acts, g2)
    ensures BytesOf(acts[g1].tok) != BytesOf(acts[g2].tok)
  {
    if BytesOf(acts[g1].tok) == BytesOf(acts[g2].tok) {
      BytesInjective(acts[g1].tok, acts[g2].tok);
      assert acts[g1].tok.(sig := []).requestId == acts[g2].tok.(sig := []).requestId;
      assert acts[g1].tok.(sig := []).intent == acts[g2].tok.(sig := []).intent;
      if g1 < g2 { NoDoubleCommit6(H, acts, g1, g2); } else { NoDoubleCommit6(H, acts, g2, g1); }
    }
  }
}
