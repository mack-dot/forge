include "../spec/refund/RefundSpecWeak.dfy"

module Refund refines RefundSpec {
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  { decision := Rejected; plan := []; }
}
