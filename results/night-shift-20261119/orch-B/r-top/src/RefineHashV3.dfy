// Night shift 2026-11-19, Orchestrator B, task b-ser2 (G3). A DRAFT in an evidence folder. NOT gate evidence.
// Refinement note, PROVED: HashCore.Step agrees with SinkCoreV3.Step (b-integrate) on related tokens when the hash
// decides as the value would (H(stored) == H(tok.pre) <==> stored == tok.pre). Then the outcome (including the
// rejection reason) and the next core are the same. So value-level results about SinkCoreV3 transfer to a HashCore
// delivery at which this equivalence holds; under A4_HashBindsInRun it holds at each delivery whose value pre-state
// is an earlier mint's pre-state (the "==>" direction of the equivalence is A4; "<==" is trivial).
// No assume, no axiom, no bodiless lemma, no {:extern}, no expect in this file.
include "HashCore.dfy"
include "v3/SinkCoreV3.dfy"

module RefineHashV3 {
  import HC = HashCore
  import V = SinkCoreV3
  import F = RefundFinality

  // A HashToken and a value token are related when the hex ids are pinned exactly when the int ids are pinned, the
  // hash text is the hash of the value pre-state, and the other fields are the same.
  ghost predicate TokRel(H: HC.HashFn, th: HC.HashToken, tv: V.SinkToken)
  {
    ((th.specHex == HC.PIN_SPEC && th.checkerHex == HC.PIN_CHK) <==> (tv.specId == V.PINNED_SPEC && tv.checkerId == V.PINNED_CHK)) &&
    th.preHash == H(tv.pre) && th.requestId == tv.requestId &&
    HC.ChargeOfState(th.post) == tv.post && HC.IntentOfSM(th.intent) == tv.intent
  }
  predicate CoreRel(c: HC.Core, d: V.Core)
  {
    c.charge == d.charge && c.settled == d.settled && c.outbox == d.outbox
  }
  function WhyOf(w: HC.Why): V.Why
  {
    match w
    case ReqIdMismatch => V.ReqIdMismatch
    case IdsNotPinned => V.IdsNotPinned
    case SignatureInvalid => V.SignatureInvalid
    case RequestSettled => V.RequestSettled
    case PreStateMismatch => V.PreStateMismatch
    case ChargeIdMismatch => V.ChargeIdMismatch
  }

  lemma StepAgrees(H: HC.HashFn, c: HC.Core, d: V.Core, th: HC.HashToken, tv: V.SinkToken, sigOk: bool)
    requires TokRel(H, th, tv) && CoreRel(c, d)
    requires H(c.charge) == H(tv.pre) <==> c.charge == tv.pre
    ensures HC.Step(H, c, th, sigOk).out.Committed? <==> V.Step(d, tv, sigOk).out.Committed?
    ensures HC.Step(H, c, th, sigOk).out.Rejected? ==>
      V.Step(d, tv, sigOk).out == V.Rejected(WhyOf(HC.Step(H, c, th, sigOk).out.why))
    ensures CoreRel(HC.Step(H, c, th, sigOk).core, V.Step(d, tv, sigOk).core)
  {
    assert HC.Match(th) <==> V.Match(tv);
    assert HC.ChargeOk(c.charge, th) <==> V.ChargeOk(d.charge, tv);
  }

  // The "==>" direction of the side condition is exactly what A4_HashBindsInRun gives at a delivery when the value
  // pre-state is an earlier mint's pre-state; the "<==" direction holds for every H.
  lemma SideConditionFromBinding(H: HC.HashFn, stored: F.Charge, pre: F.Charge)
    requires H(stored) == H(pre) ==> stored == pre
    ensures H(stored) == H(pre) <==> stored == pre
  {}
}
