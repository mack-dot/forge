// NEGATIVE CONTROL (U430): the planted no-frame ledger specification as an instance of the skeleton.
// Its Deterministic obligation is FALSE (two different allowed results exist with five accounts), so the
// instance must be REJECTED. The body tries the only available route and Dafny must not accept it.
include "../RelationalContractAudit.dfy"
include "NoFrameDeterminism.dfy"

abstract module NoFrameAudit refines RelationalContractAudit {
  import D : NoFrameDeterminism
  datatype Input = In(state: D.L.State, id: int, request: D.L.Request)
  datatype Result = Res(next: D.L.State, outcome: D.L.Outcome)
  ghost predicate Valid(i: Input) { D.L.WellFormed(i.state) }
  ghost predicate Post(i: Input, r: Result) { D.Post(i.state, i.id, i.request, r.next, r.outcome) }
  lemma Deterministic(i: Input, a: Result, b: Result)
  {
  }
}
