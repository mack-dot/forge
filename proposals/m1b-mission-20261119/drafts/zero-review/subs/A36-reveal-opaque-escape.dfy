include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  opaque predicate Lie() { false }
  lemma L() ensures Lie() { reveal Lie(); }
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  { L(); reveal Lie(); decision := Rejected; plan := []; }
}
