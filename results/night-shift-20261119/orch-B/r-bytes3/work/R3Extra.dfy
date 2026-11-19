// Night shift 2026-11-19, Orchestrator B, task r-bytes3 (adversarial review of b-ser2). A DRAFT. NOT gate evidence.
// Extra lemmas of the reviewer. No assume, no axiom, no bodiless lemma, no {:extern}, no expect in this file.
include "ControlsBytesV3.dfy"
include "RefineHashV3.dfy"

module R3Extra {
  import opened HashCore
  import opened SliceSafetyBytesV3
  import opened ControlsBytesV3
  import RH = RefineHashV3
  import V = SinkCoreV3

  // (1) A4 holds for EVERY trace when H is injective: the hypothesis is not tied to the single witness.
  lemma A4FromInjective(H: HashFn, init: F.Charge, acts: seq<Act>)
    requires forall a: F.Charge, b: F.Charge :: H(a) == H(b) ==> a == b
    ensures A4_HashBindsInRun(H, init, acts)
  {
    reveal A4_HashBindsInRun();
  }

  // (2) A4 is stronger than needed: a mint-mint collision (two minted pre-states, same hash) with a later delivery
  // while the stored charge is one of them falsifies A4, even when the colliding mint is never delivered.
  lemma MintMintCollisionFalsifiesA4(H: HashFn, init: F.Charge, acts: seq<Act>, j1: int, j2: int, k: int)
    requires 0 <= j1 < k && 0 <= j2 < k && k < |acts|
    requires acts[j1].MintAct? && acts[j2].MintAct? && acts[k].Deliver?
    requires acts[j1].pre != acts[j2].pre && H(acts[j1].pre) == H(acts[j2].pre)
    requires TExec(H, init, acts[..k]).core.charge == acts[j1].pre
    ensures !A4_HashBindsInRun(H, init, acts)
  {
    reveal A4_HashBindsInRun();
  }

  // (3) Zero amount: a SECOND zero-amount token with a fresh request id commits after the first one (state unchanged,
  // so the same pre-state hash), and the issuer would issue it (Authorizes holds).
  const IZ: R.RefundIntent := R.Intent("ch_1", "rq_z", 0, DC)
  const TZ: F.Transition := F.Transition(F.Request("rq_z", 0, DC), W_PRE, IZ)
  lemma SecondZeroCommits()
    ensures F.Authorizes(W_PRE, TZ) && MoneyNonNeg(TZ)
    ensures Step(HW, Core(W_PRE, {}, []), TK0, true) == StepResult(Core(W_PRE, {"rq_0"}, [I0]), Committed)
    ensures Step(HW, Core(W_PRE, {"rq_0"}, [I0]), TokOf(HW, W_PRE, TZ), true) ==
            StepResult(Core(W_PRE, {"rq_0", "rq_z"}, [I0, IZ]), Committed)
  {
    assert W_PRE.(remaining := W_PRE.remaining - 0) == W_PRE;
    WitSteps();
    assert "rq_z" != "rq_0" by { assert "rq_z"[3] != "rq_0"[3]; }
    assert {"rq_0"} + {"rq_z"} == {"rq_0", "rq_z"};
  }

  // (4) StepAgrees is not vacuous: a related pair where both cores COMMIT, and a related pair where both refuse
  // with the same reason (pre-state mismatch).
  const TV0: V.SinkToken := V.SinkToken(V.PINNED_SPEC, V.PINNED_CHK, W_PRE, "rq_0", W_PRE, I0, [])
  lemma StepAgreesInstance()
    ensures RH.TokRel(HW, TK0, TV0) && RH.CoreRel(Core(W_PRE, {}, []), V.Core(W_PRE, {}, []))
    ensures Step(HW, Core(W_PRE, {}, []), TK0, true).out.Committed?
    ensures V.Step(V.Core(W_PRE, {}, []), TV0, true).out.Committed?
    ensures RH.TokRel(HW, TK0, TV0) && RH.CoreRel(Core(W_POST, {}, []), V.Core(W_POST, {}, []))
    ensures V.Step(V.Core(W_POST, {}, []), TV0, true).out == V.Rejected(V.PreStateMismatch)
  {
    Authorized();
    WitSteps();
    assert TK0.preHash == HW(W_PRE);
    assert ChargeOfState(TK0.post) == W_PRE && IntentOfSM(TK0.intent) == I0;
    HexDistinct();
    RH.StepAgrees(HW, Core(W_PRE, {}, []), V.Core(W_PRE, {}, []), TK0, TV0, true);
    RH.StepAgrees(HW, Core(W_POST, {}, []), V.Core(W_POST, {}, []), TK0, TV0, true);
    assert Step(HW, Core(W_POST, {}, []), TK0, true).out == Rejected(PreStateMismatch);
  }
}
