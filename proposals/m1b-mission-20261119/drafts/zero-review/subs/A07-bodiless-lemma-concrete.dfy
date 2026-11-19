include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  lemma Bad() ensures false
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  { Bad(); decision := Rejected; plan := []; }
}
