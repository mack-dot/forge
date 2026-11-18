// Round 3 task 3 (U430): the three approved specifications as instances of the shared skeleton.
// Each instance reuses the existing Post predicate and determinism lemma (LedgerDeterminism.dfy and so on).
include "RelationalContractAudit.dfy"
include "LedgerDeterminism.dfy"
include "BookingDeterminism.dfy"
include "RefundDeterminism.dfy"

abstract module LedgerAudit refines RelationalContractAudit {
  import D : LedgerDeterminism
  datatype Input = In(state: D.L.State, id: int, request: D.L.Request)
  datatype Result = Res(next: D.L.State, outcome: D.L.Outcome)
  ghost predicate Valid(i: Input) { D.L.WellFormed(i.state) }
  ghost predicate Post(i: Input, r: Result) { D.Post(i.state, i.id, i.request, r.next, r.outcome) }
  lemma Deterministic(i: Input, a: Result, b: Result)
  {
    D.SpecIsDeterministic(i.state, i.id, i.request, a.next, a.outcome, b.next, b.outcome);
  }
}

abstract module BookingAudit refines RelationalContractAudit {
  import D : BookingDeterminism
  datatype Input = In(state: D.B.State, id: int, request: D.B.Request)
  datatype Result = Res(next: D.B.State, outcome: D.B.Outcome)
  ghost predicate Valid(i: Input) { D.B.WellFormed(i.state) }
  ghost predicate Post(i: Input, r: Result) { D.Post(i.state, i.id, i.request, r.next, r.outcome) }
  lemma Deterministic(i: Input, a: Result, b: Result)
  {
    D.SpecIsDeterministic(i.state, i.id, i.request, a.next, a.outcome, b.next, b.outcome);
  }
}

abstract module RefundAudit refines RelationalContractAudit {
  import D : RefundDeterminism
  datatype Input = In(context: D.R.Context, response: D.R.ModelResponse)
  datatype Result = Res(decision: D.R.Decision, plan: seq<D.R.RefundIntent>)
  ghost predicate Valid(i: Input) { true }
  ghost predicate Post(i: Input, r: Result) { D.Post(i.context, i.response, r.decision, r.plan) }
  lemma Deterministic(i: Input, a: Result, b: Result)
  {
    D.SpecIsDeterministic(i.context, i.response, a.decision, a.plan, b.decision, b.plan);
  }
}
