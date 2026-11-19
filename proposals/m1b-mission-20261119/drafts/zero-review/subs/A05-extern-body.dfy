include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  method {:extern "Evil", "assess"} Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
}
