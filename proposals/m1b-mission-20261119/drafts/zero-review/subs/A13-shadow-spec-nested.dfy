include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  module RefundSpec {
    predicate Eligible(c: int, r: int) { false }
  }
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  { decision := Rejected; plan := []; }
}
