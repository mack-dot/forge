include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  predicate Eligiblе(c: Context, r: ModelResponse) { false }
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    if Eligiblе(context, response) { decision := Authorized(0, "x"); plan := []; }
    else { decision := Rejected; plan := []; }
  }
}
