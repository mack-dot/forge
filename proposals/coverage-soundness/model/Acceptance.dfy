// Formal model of the ledger PR gate's acceptance state machine (COVERAGE.md section 6).
// The model is a sequence of checks; each check either passes, or ends the run in a
// terminal outcome. The theorem Safety states that the only path to Verified passes
// every check. This is a theorem about the model. Conformance of gate/incremental.py
// to the model is tested separately and is not proved.
module Acceptance {
  datatype Outcome = Verified | Rejected | NotEstablished | Unsupported

  // Facts about one run, as the checks observe them.
  datatype Run = Run(
    toolsOk: bool,          // pins, toolchain, revisions, I/O all readable and matching
    authorizationOk: bool,  // protected inputs unchanged, or changed exactly per a bound approval
    proofOk: bool,          // audit, verifier, obligations, cold baseline, two snapshots
    artifactBound: bool,    // evidence validates; every input re-hashes identically
    coverageOk: bool)       // Changed ⊆ Established and no dependent left un-re-established

  // Check order of gate/incremental.py: tools, authorization, proof, (coverage assessed),
  // artifact re-hash, then the coverage decision.
  datatype State = Start | ToolsChecked | Authorized | Proved | Bound | Done(outcome: Outcome)

  function Step(s: State, r: Run): State
  {
    match s
    case Start => if r.toolsOk then ToolsChecked else Done(NotEstablished)
    case ToolsChecked => if r.authorizationOk then Authorized else Done(Rejected)
    case Authorized => if r.proofOk then Proved else Done(Rejected)
    case Proved => if r.artifactBound then Bound else Done(Rejected)
    case Bound => if r.coverageOk then Done(Verified) else Done(Unsupported)
    case Done(o) => Done(o)
  }

  function Decide(r: Run): Outcome
  {
    Step(Step(Step(Step(Step(Start, r), r), r), r), r).outcome
  }

  // Every run reaches a terminal outcome within five steps.
  lemma Terminates(r: Run)
    ensures Step(Step(Step(Step(Step(Start, r), r), r), r), r).Done?
  {
  }

  // Safety: a Verified outcome implies every check passed.
  lemma Safety(r: Run)
    ensures Decide(r) == Verified ==>
      r.toolsOk && r.authorizationOk && r.proofOk && r.artifactBound && r.coverageOk
  {
  }

  // Fail-closed: an unsupported outcome still rests on a complete, successful proof,
  // and a tool failure never becomes Unsupported or Verified.
  lemma UnsupportedRestsOnProof(r: Run)
    ensures Decide(r) == Unsupported ==> r.toolsOk && r.authorizationOk && r.proofOk && r.artifactBound
  {
  }

  lemma ToolFailureIsNotEstablished(r: Run)
    ensures !r.toolsOk ==> Decide(r) == NotEstablished
  {
  }

  // Inductive invariant: no reachable state except Done(Verified) carries a verified
  // claim, and Done(Verified) is reachable only from Bound with coverageOk.
  predicate Inv(s: State, r: Run)
  {
    (s == ToolsChecked ==> r.toolsOk) &&
    (s == Authorized ==> r.toolsOk && r.authorizationOk) &&
    (s == Proved ==> r.toolsOk && r.authorizationOk && r.proofOk) &&
    (s == Bound ==> r.toolsOk && r.authorizationOk && r.proofOk && r.artifactBound) &&
    (s == Done(Verified) ==> r.toolsOk && r.authorizationOk && r.proofOk && r.artifactBound && r.coverageOk)
  }

  lemma InvInit(r: Run)
    ensures Inv(Start, r)
  {
  }

  lemma InvStep(s: State, r: Run)
    requires Inv(s, r)
    ensures Inv(Step(s, r), r)
  {
  }

  // Exit code mapping used by the implementation.
  function ExitCode(o: Outcome): int
  {
    match o case Verified => 0 case Rejected => 1 case NotEstablished => 2 case Unsupported => 3
  }

  lemma ExitCodesDistinct(a: Outcome, b: Outcome)
    ensures ExitCode(a) == ExitCode(b) ==> a == b
  {
  }
}
