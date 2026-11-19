// Night shift 2026-11-19, Orchestrator B, task r-integrate. A DRAFT. NOT gate evidence. Dafny-model statement about
// SliceSafetyV3 (b-integrate, copied to ../src, SHA-256 e841d570...). No assume, no axiom, no bodiless lemma.
//
// The worker wrote "under H1 + A2 + A5 the two new checks never fire" as an argument only. This file PROVES it on
// the trace semantics Exec: at every delivery of a trace that meets H1, A2 and A5, if the V2 core (no request-id
// check, no charge-id check) would commit, the V3 core commits, and the model takes its real Commit (no stutter).
include "../src/SliceSafetyV3.dfy"

module AttackTrace {
  import opened SinkCoreV3
  import opened SliceTheoremV3

  predicate V2Accepts(core: Core, tok: SinkToken, sigOk: bool)
  {
    tok.specId == PINNED_SPEC && tok.checkerId == PINNED_CHK && sigOk &&
    tok.requestId !in core.settled && core.charge == tok.pre
  }

  lemma CheckedClaimShape(pre: F.Charge, t: F.Transition)
    ensures CheckedClaim(pre, t) == Claim(PINNED_SPEC, PINNED_CHK, pre, Enc(t.request.requestId),
                                         F.Request(t.request.requestId, t.intent.amount, t.intent.reason), t.post, t.intent)
  {
  }

  lemma HonestPasses(tok: SinkToken, pre: F.Charge, t: F.Transition)
    requires F.Authorizes(pre, t) && ClaimOf(tok) == CheckedClaim(pre, t)
    ensures Match(tok) && ChargeOk(pre, tok) && tok.pre == pre
  {
    CheckedClaimShape(pre, t);
    EncInjective(tok.requestId, t.request.requestId);
  }

  // THE COMPLETENESS LEMMA (V3 loses no honest commit; no new denial of service; zero amount included).
  lemma NoHonestCommitLost(init: State, acts: seq<Act>, k: int)
    requires A2_MintOnlyOnCheck(acts) && A5_VerifierMatchesAtEachDelivery(acts) && H1_SignatureAuthenticity(acts)
    requires 0 <= k < |acts| && acts[k].Deliver?
    requires V2Accepts(Exec(init, acts[..k]).core, acts[k].tok, acts[k].sigOk)
    ensures Step(Exec(init, acts[..k]).core, acts[k].tok, acts[k].sigOk).out.Committed?
    ensures Match(acts[k].tok) && ChargeOk(Exec(init, acts[..k]).core.charge, acts[k].tok)
  {
    var tok := acts[k].tok;
    var c := ClaimOf(tok);
    assert A5_VerifierMatches(tok, acts[k].sigOk);
    assert VerifyTag(c, tok.sig);
    assert SignedBefore(acts, k, c);
    var j :| 0 <= j < k && j < |acts| && acts[j].MintAct? && acts[j].c == c;
    assert Ours(acts[j].c);
    var pre: F.Charge, t: F.Transition :| F.Authorizes(pre, t) && acts[j].c == CheckedClaim(pre, t);
    HonestPasses(tok, pre, t);
  }

  // The same at the model: for such a delivery, ModelStep is the model's Commit (the stutter branch is not taken).
  lemma NoStutterOnHonest(init: State, acts: seq<Act>, k: int)
    requires A2_MintOnlyOnCheck(acts) && A5_VerifierMatchesAtEachDelivery(acts) && H1_SignatureAuthenticity(acts)
    requires 0 <= k < |acts| && acts[k].Deliver?
    requires V2Accepts(Exec(init, acts[..k]).core, acts[k].tok, acts[k].sigOk)
    ensures ModelStep(Exec(init, acts[..k]).s, acts[k].tok) ==
            Commit(Exec(init, acts[..k]).s, ClaimOf(acts[k].tok), acts[k].tok.sig)
  {
    NoHonestCommitLost(init, acts, k);
    var p := acts[..k];
    forall m | 0 <= m < |p| ensures p[m] == acts[m] {}
    assert A5_VerifierMatchesAtEachDelivery(p);
    ExecRel(init, p);
  }

  // Under H1 + A2 + A5 the V3 core and the V2 acceptance agree EXACTLY on every delivery of the trace.
  lemma V3EqualsV2UnderHyps(init: State, acts: seq<Act>, k: int)
    requires A2_MintOnlyOnCheck(acts) && A5_VerifierMatchesAtEachDelivery(acts) && H1_SignatureAuthenticity(acts)
    requires 0 <= k < |acts| && acts[k].Deliver?
    ensures Step(Exec(init, acts[..k]).core, acts[k].tok, acts[k].sigOk).out.Committed? <==>
            V2Accepts(Exec(init, acts[..k]).core, acts[k].tok, acts[k].sigOk)
  {
    StepExact(Exec(init, acts[..k]).core, acts[k].tok, acts[k].sigOk);
    if V2Accepts(Exec(init, acts[..k]).core, acts[k].tok, acts[k].sigOk) {
      NoHonestCommitLost(init, acts, k);
    }
  }

  // Every core reached by Exec passes the executable AuditStart (closure on the trace semantics).
  lemma ExecAuditStartTrue(init: State, acts: seq<Act>)
    ensures AuditStart(Exec(init, acts).core)
  {
    ExecCore(init, acts);
    AuditStartIsGoodStart(Exec(init, acts).core);
  }
}
