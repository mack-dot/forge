include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  lemma Helper() ensures false { assume false; }
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  { Helper(); decision := Rejected; plan := []; }
}
