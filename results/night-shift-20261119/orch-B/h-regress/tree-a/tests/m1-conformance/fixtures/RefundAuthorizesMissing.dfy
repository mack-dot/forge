// NEGATIVE CONTROL for the M1 conformance check (Wave Gate 1). A WRONG refund decision.
// It authorizes 0 with a fixed reason when the response is Missing.
// It is NOT verified: the pinned Dafny rejects it against the approved specification. The EXIT script
// copies it to <work>/impl/Refund.dfy and compiles it with --no-verify. The conformance comparison
// with the M1 executable MUST report a disagreement for it.
include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    if ValidContext(context) && response.Missing? {
      decision := Authorized(0, "duplicate_charge");
      plan := [Intent(context.chargeId, context.requestId, 0, "duplicate_charge")];
    } else if Eligible(context, response) {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
