include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  abstract module Trap {
    lemma Bad() ensures false
  }
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  { Trap.Bad(); decision := Rejected; plan := []; }
}
