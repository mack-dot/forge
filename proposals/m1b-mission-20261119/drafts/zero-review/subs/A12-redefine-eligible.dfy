include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  predicate Eligible(context: Context, response: ModelResponse) { false }
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  { decision := Rejected; plan := []; }
}
