include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  function Pick(c: Context, r: ModelResponse): Decision
    ensures Pick(c, r) == Rejected && Pick(c, r).Authorized?
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  { decision := Pick(context, response); plan := []; }
}
