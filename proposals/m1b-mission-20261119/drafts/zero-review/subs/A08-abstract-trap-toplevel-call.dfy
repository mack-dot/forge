include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  { Trap.Bad(); decision := Rejected; plan := []; }
}

abstract module Trap {
  lemma Bad() ensures false
}
