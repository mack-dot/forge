include "impl/Refund.dfy"
include "FlatCore.dfy"

// Conditional transport obligation. No encoder or decoder is implemented here.
// The requires clauses concern a representation relation, not the refund domain.
// A concrete byte representation must still prove these clauses for every input.
module RefundStringTransport {
  import R = Refund
  import F = FlatRefund

  predicate Bytes(s: string) {
    forall i | 0 <= i < |s| :: (s[i] as int) < 256
  }

  predicate SameAllowedReason(a: string, b: string) {
    (a == "duplicate_charge" <==> b == "duplicate_charge") &&
    (a == "service_not_delivered" <==> b == "service_not_delivered") &&
    (a == "returned_item" <==> b == "returned_item")
  }

  method Transport(context: R.Context, response: R.ModelResponse,
      encodedCharge: string, encodedRequest: string, encodedReason: string)
    returns (ok: bool, amount: int, reason: string, charge: string,
             request: string, count: int)
    requires Bytes(encodedCharge) && Bytes(encodedRequest) && Bytes(encodedReason)
    requires (encodedCharge == "" <==> context.chargeId == "")
    requires (encodedRequest == "" <==> context.requestId == "")
    requires SameAllowedReason(
      if response.Candidate? then response.reason else "", encodedReason)
    modifies {}
    ensures ok <==> R.Eligible(context, response)
    ensures ok ==> (response.Candidate? && amount == response.amount &&
      reason == response.reason && charge == encodedCharge &&
      request == encodedRequest && count == 1)
    ensures !ok ==> (amount == 0 && reason == "" && charge == "" &&
      request == "" && count == 0)
  {
    var inputAmount := if response.Candidate? then response.amount else 0;
    ok, amount, reason, charge, request, count :=
      F.AssessFlat(encodedCharge, encodedRequest, context.original,
        context.remaining, context.refundEnabled, context.requestOpen,
        response.Candidate?, inputAmount, encodedReason);
    var originalDecision, originalPlan := R.Assess(context, response);
    assert ok <==> originalDecision.Authorized?;
    assert ok ==> reason == response.reason;
    assert ok ==> originalDecision == R.Authorized(amount, reason);
    assert ok ==> (originalPlan ==
      [R.Intent(context.chargeId, context.requestId, amount, reason)]);
    assert !ok ==> originalDecision == R.Rejected && originalPlan == [];
    // Encoded charge/request are copied exactly. Recovering the original IDs
    // still needs an injective, checked encoding and a checked API boundary.
  }

  method NonByteWitnesses()
    modifies {}
  {
    var c := R.ChargeContext("Ā", "\U{10FFFF}", 100, 60, true, true);
    var ok, amount, reason, charge, request, count :=
      Transport(c, R.Candidate(40, "returned_item"),
        "\U{C4}\U{80}", "\U{F4}\U{8F}\U{BF}\U{BF}", "returned_item");
    assert ok && amount == 40 && count == 1;
    assert charge == "\U{C4}\U{80}" && request == "\U{F4}\U{8F}\U{BF}\U{BF}";
    assert reason == "returned_item";
    ok, amount, reason, charge, request, count :=
      Transport(c, R.Candidate(0, "returned_item"),
        "\U{C4}\U{80}", "\U{F4}\U{8F}\U{BF}\U{BF}", "returned_item");
    assert ok && amount == 0 && count == 1;
  }
}
