// Formal model of the Stage 11 incremental PR gate's acceptance state machine (CONTRACT.md §3).
// Theorems are about this model only; implementation conformance is tested separately.
module Acceptance {
  datatype Outcome = Verified | Rejected | NotEstablished | Unsupported

  datatype Run = Run(
    toolsOk: bool,          // pins, toolchain, revisions, verification-tree copy, I/O
    authorizationOk: bool,  // protected inputs unchanged, or changed exactly per a bound approval
    proofOk: bool,          // the ledger snapshot proof on the candidate bytes
    obligationsOk: bool,    // every affected dependent obligation established on the candidate
    obligationsTooling: bool, // no affected obligation stopped on a tool error
    artifactBound: bool,    // evidence validates; every input and the verification tree re-hash identically
    pathsCovered: bool,     // every changed path is an input of some obligation (checked before obligations run)
    dependenciesOk: bool)   // no reader of a changed path lacks an obligation that depends on both

  datatype State = Start | ToolsChecked | Authorized | Proved | Covered | Obligated | Bound | Done(outcome: Outcome)

  function Step(s: State, r: Run): State
  {
    match s
    case Start => if r.toolsOk then ToolsChecked else Done(NotEstablished)
    case ToolsChecked => if r.authorizationOk then Authorized else Done(Rejected)
    case Authorized => if r.proofOk then Proved else Done(Rejected)
    case Proved => if r.pathsCovered then Covered else Done(Unsupported)   // no obligation runs on an uncovered change
    case Covered =>
      if !r.obligationsTooling then Done(NotEstablished)
      else if r.obligationsOk then Obligated else Done(Rejected)
    case Obligated => if r.artifactBound then Bound else Done(Rejected)
    case Bound => if r.dependenciesOk then Done(Verified) else Done(Unsupported)
    case Done(o) => Done(o)
  }

  function Decide(r: Run): Outcome
  {
    Step(Step(Step(Step(Step(Step(Step(Start, r), r), r), r), r), r), r).outcome
  }

  lemma Terminates(r: Run)
    ensures Step(Step(Step(Step(Step(Step(Step(Start, r), r), r), r), r), r), r).Done?
  {
  }

  // Safety: Verified implies proof, approval, every affected obligation, binding and coverage.
  lemma Safety(r: Run)
    ensures Decide(r) == Verified ==>
      r.toolsOk && r.authorizationOk && r.proofOk && r.pathsCovered && r.obligationsTooling && r.obligationsOk
      && r.artifactBound && r.dependenciesOk
  {
  }

  // An unsupported verdict still rests on a complete, successful ledger proof.
  lemma UnsupportedRestsOnProof(r: Run)
    ensures Decide(r) == Unsupported ==> r.toolsOk && r.authorizationOk && r.proofOk
  {
  }

  // Obligations run only on fully covered changes; an uncovered change is Unsupported at once.
  lemma UncoveredNeverRunsObligations(r: Run)
    ensures r.toolsOk && r.authorizationOk && r.proofOk && !r.pathsCovered ==> Decide(r) == Unsupported
  {
  }

  // A failing dependent obligation on a covered change is a rejection, never unsupported or verified.
  lemma StaleDependencyRejected(r: Run)
    ensures r.toolsOk && r.authorizationOk && r.proofOk && r.pathsCovered && r.obligationsTooling && !r.obligationsOk
      ==> Decide(r) == Rejected
  {
  }

  lemma ToolFailureIsNotEstablished(r: Run)
    ensures (!r.toolsOk || (r.authorizationOk && r.proofOk && r.pathsCovered && !r.obligationsTooling))
      ==> Decide(r) == NotEstablished
  {
  }

  predicate Inv(s: State, r: Run)
  {
    (s == ToolsChecked ==> r.toolsOk) &&
    (s == Authorized ==> r.toolsOk && r.authorizationOk) &&
    (s == Proved ==> r.toolsOk && r.authorizationOk && r.proofOk) &&
    (s == Covered ==> r.toolsOk && r.authorizationOk && r.proofOk && r.pathsCovered) &&
    (s == Obligated ==> r.toolsOk && r.authorizationOk && r.proofOk && r.pathsCovered && r.obligationsTooling && r.obligationsOk) &&
    (s == Bound ==> r.toolsOk && r.authorizationOk && r.proofOk && r.pathsCovered && r.obligationsTooling && r.obligationsOk
                    && r.artifactBound) &&
    (s == Done(Verified) ==> r.toolsOk && r.authorizationOk && r.proofOk && r.pathsCovered && r.obligationsTooling
                             && r.obligationsOk && r.artifactBound && r.dependenciesOk)
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

  function ExitCode(o: Outcome): int
  {
    match o case Verified => 0 case Rejected => 1 case NotEstablished => 2 case Unsupported => 3
  }

  lemma ExitCodesDistinct(a: Outcome, b: Outcome)
    ensures ExitCode(a) == ExitCode(b) ==> a == b
  {
  }
}
