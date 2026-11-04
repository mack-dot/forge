include "impl/Refund.dfy"
include "FlatCore.dfy"

module RefundRepresentationChecks {
  import R = Refund
  import F = FlatRefund

  // No requires: cover every typed context and every response constructor.
  method Equivalent(context: R.Context, response: R.ModelResponse)
    modifies {}
  {
    var amount := if response.Candidate? then response.amount else 0;
    var reason := if response.Candidate? then response.reason else "";
    var ok, outAmount, outReason, outCharge, outRequest, count :=
      F.AssessFlat(context.chargeId, context.requestId, context.original,
        context.remaining, context.refundEnabled, context.requestOpen,
        response.Candidate?, amount, reason);
    var decision := if ok then R.Authorized(outAmount, outReason) else R.Rejected;
    var plan := if count == 1 then [R.Intent(outCharge, outRequest, outAmount, outReason)] else [];
    var originalDecision, originalPlan := R.Assess(context, response);
    assert ok <==> R.Eligible(context, response);
    assert count == 0 || count == 1;
    assert decision == originalDecision;
    assert plan == originalPlan;
    // Full required behavior, not merely an amount bound or a termination test.
    assert decision.Authorized? ==>
      R.ValidContext(context) && R.Money(decision.amount) &&
      decision.amount <= context.remaining <= context.original;
    assert decision.Authorized? ==> R.AllowedReason(decision.reason);
    assert !R.Eligible(context, response) ==> decision == R.Rejected && plan == [];
    assert R.Eligible(context, response) ==>
      response.Candidate? && decision == R.Authorized(response.amount, response.reason) &&
      plan == [R.Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    assert decision.Authorized? <==> R.Eligible(context, response);
    assert decision.Rejected? <==> |plan| == 0;
    assert |plan| <= 1;
    assert decision.Authorized? ==>
      plan == [R.Intent(context.chargeId, context.requestId, decision.amount, decision.reason)];
  }

  method NonVacuityAndBoundaries()
    modifies {}
  {
    var ok, amount, reason, charge, request, count :=
      F.AssessFlat("charge-1", "request-1", 100, 60, true, true,
        true, 40, "duplicate_charge");
    assert ok && amount == 40 && count == 1;
    ok, amount, reason, charge, request, count :=
      F.AssessFlat("charge-1", "request-1", 100, 60, true, true,
        true, 0, "returned_item");
    assert ok && amount == 0 && count == 1;
    ok, amount, reason, charge, request, count :=
      F.AssessFlat("charge-1", "request-1", 9223372036854775807,
        9223372036854775807, true, true, true, 9223372036854775807,
        "service_not_delivered");
    assert ok && amount == 9223372036854775807 && count == 1;
    ok, amount, reason, charge, request, count :=
      F.AssessFlat("charge-1", "request-1", 100, 60, true, true,
        true, 61, "duplicate_charge");
    assert !ok && count == 0;
    ok, amount, reason, charge, request, count :=
      F.AssessFlat("charge-1", "request-1", 100, 60, true, true,
        true, 9223372036854775808, "duplicate_charge");
    assert !ok && count == 0;
  }
}
