// NEGATIVE CONTROL for the M1 conformance check (Wave Gate 1). A WRONG refund decision.
// It rejects every proposal.
// It is NOT verified: the pinned Dafny rejects it against the approved specification. The EXIT script
// copies it to <work>/impl/Refund.dfy and compiles it with --no-verify. The conformance comparison
// with the M1 executable MUST report a disagreement for it.
include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    decision := Rejected;
    plan := [];
  }
}
