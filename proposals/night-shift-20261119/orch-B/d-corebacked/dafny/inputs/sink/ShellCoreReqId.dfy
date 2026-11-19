// d-corebacked (night shift 2026-11-19, Orchestrator B). A DRAFT. NOT gate evidence. NOT about sink.ts.
// The shell-facing core over the request-id-patched SinkCoreReqId. The token that the shell holds has
// ONLY a pre-state HASH, not the pre-state value. So the shell computes ONE boolean preOk (stored hash
// equals the token's hash), as it computes sigOk. StepP takes preOk in place of the value compare.
// StepPAgrees: StepP with preOk := (core.charge == pre) IS SinkCoreReqId.Step on the full token. So
// every proved property of Step transfers, under the NEW named input assumption
//   A4' PreOkMatches: preOk == (core.charge == pre), for the pre-state value `pre` that the signer hashed.
// A4' is A4 (SHA-256 collision resistance, canon injective, faithful store) in a boolean form.
include "SinkCoreReqId.dfy"

module ShellCoreReqId {
  import C = SinkCoreReqId
  import F = RefundFinality
  import R = Refund

  datatype ShellToken = ShellToken(specId: int, checkerId: int, requestId: string,
                                   post: F.Charge, intent: R.RefundIntent, sig: string)

  function Full(t: ShellToken, pre: F.Charge): C.SinkToken
  {
    C.SinkToken(t.specId, t.checkerId, pre, t.requestId, t.post, t.intent, t.sig)
  }

  function StepP(core: C.Core, t: ShellToken, sigOk: bool, preOk: bool): C.StepResult
  {
    if t.specId != C.PINNED_SPEC || t.checkerId != C.PINNED_CHK then C.StepResult(core, C.Rejected(C.IdsNotPinned))
    else if !sigOk then C.StepResult(core, C.Rejected(C.SignatureInvalid))
    else if t.intent.requestId != t.requestId then C.StepResult(core, C.Rejected(C.ReqIdMismatch))
    else if t.requestId in core.settled then C.StepResult(core, C.Rejected(C.RequestSettled))
    else if !preOk then C.StepResult(core, C.Rejected(C.PreStateMismatch))
    else C.StepResult(C.Core(t.post, core.settled + {t.requestId}, core.outbox + [t.intent]), C.Committed)
  }

  lemma StepPAgrees(core: C.Core, t: ShellToken, sigOk: bool, pre: F.Charge)
    ensures StepP(core, t, sigOk, core.charge == pre) == C.Step(core, Full(t, pre), sigOk)
  {
  }

  // The write set that the shell performs: exactly this, or nothing.
  lemma StepPShape(core: C.Core, t: ShellToken, sigOk: bool, preOk: bool)
    ensures StepP(core, t, sigOk, preOk).out.Committed? ==>
      StepP(core, t, sigOk, preOk).core == C.Core(t.post, core.settled + {t.requestId}, core.outbox + [t.intent])
    ensures !StepP(core, t, sigOk, preOk).out.Committed? ==> StepP(core, t, sigOk, preOk).core == core
  {
  }

  // The refinement of SinkCoreReqId (A5 only) carries over to StepP under A4'.
  lemma StepPRefinesModelStep(core: C.Core, s: C.System, toks: seq<C.SinkToken>, t: ShellToken,
                              sigOk: bool, preOk: bool, pre: F.Charge)
    requires C.A5_VerifierMatches(Full(t, pre), sigOk)
    requires preOk == (core.charge == pre)                     // A4'
    requires C.Rel(core, s, toks)
    ensures StepP(core, t, sigOk, preOk).out.Committed? <==>
            C.SinkAccepts(s, C.ClaimOf(Full(t, pre)), t.sig) && C.Match(Full(t, pre))
    ensures C.Rel(StepP(core, t, sigOk, preOk).core, C.ModelStep(s, Full(t, pre)),
                  C.NextToks(toks, Full(t, pre), StepP(core, t, sigOk, preOk).out))
  {
    StepPAgrees(core, t, sigOk, pre);
    C.StepRefinesModelStep(core, s, toks, Full(t, pre), sigOk);
  }

  // Non-vacuity: a concrete honest step commits.
  lemma Witness()
    ensures var c := F.Charge("ch_1", 1000, 1000, true);
            var t := ShellToken(C.PINNED_SPEC, C.PINNED_CHK, "rq_1", F.Charge("ch_1", 1000, 900, true),
                                R.Intent("ch_1", "rq_1", 100, "returned_item"), "");
            StepP(C.Core(c, {}, []), t, true, true).out.Committed?
  {
  }
}
