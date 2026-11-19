// NEGATIVE CONTROL for the M1 conformance check (Wave Gate 1). A WRONG refund decision.
// It authorizes the remaining amount when the proposed amount is larger (a clamp).
// It is NOT verified: the pinned Dafny rejects it against the approved specification. The EXIT script
// copies it to <work>/impl/Refund.dfy and compiles it with --no-verify. The conformance comparison
// with the M1 executable MUST report a disagreement for it.
include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    if ValidContext(context) && response.Candidate? && 0 <= response.amount && AllowedReason(response.reason) {
      var amount := if response.amount <= context.remaining then response.amount else context.remaining;
      decision := Authorized(amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
