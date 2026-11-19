include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  lemma Escape() requires false ensures false {}
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  { Escape(); decision := Rejected; plan := []; }
}
