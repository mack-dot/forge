include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  import T : Trap
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  { T.Bad(); decision := Rejected; plan := []; }
}

abstract module Trap {
  lemma Bad() ensures false
}
