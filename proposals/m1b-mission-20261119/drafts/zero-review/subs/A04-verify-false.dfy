include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  method {:verify false} Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  { decision := Rejected; plan := []; }
}
