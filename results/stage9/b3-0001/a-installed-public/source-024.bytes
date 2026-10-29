// Passed beside impl/Refund.dfy. No include paths or optional proof selection.
abstract module RequiredRefund {
  import R : RefundSpec
}

module BoundRefund refines RequiredRefund {
  import R = Refund
}

module RefundChecks {
  import R = Refund

  // Arbitrary inputs, no requires: a strengthened precondition cannot hide
  // unsafe responses or exclude valid proposals from the required boundary.
  method Universal(context: R.Context, response: R.ModelResponse)
    modifies {}
  {
    var decision, plan := R.Assess(context, response);
    assert decision.Authorized? <==> R.Eligible(context, response);
    assert decision.Authorized? ==>
      R.ValidContext(context) && R.Money(decision.amount) &&
      decision.amount <= context.remaining <= context.original &&
      R.AllowedReason(decision.reason);
    assert !R.Eligible(context, response) ==> decision == R.Rejected && plan == [];
    assert R.Eligible(context, response) ==>
      response.Candidate? && decision == R.Authorized(response.amount, response.reason) &&
      plan == [R.Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    assert decision.Rejected? <==> |plan| == 0;
    assert |plan| <= 1;
    assert decision.Authorized? ==>
      plan == [R.Intent(context.chargeId, context.requestId, decision.amount, decision.reason)];
    assert forall intent: R.RefundIntent :: intent in plan ==>
      R.ValidContext(context) && R.Money(intent.amount) &&
      intent.amount <= context.remaining <= context.original &&
      R.AllowedReason(intent.reason) &&
      intent.chargeId == context.chargeId && intent.requestId == context.requestId;
  }

  method SuccessfulWitness()
    modifies {}
  {
    var context := R.ChargeContext("charge-1", "request-1", 100, 60, true, true);
    var response := R.Candidate(40, "duplicate_charge");
    assert R.Eligible(context, response);
    var decision, plan := R.Assess(context, response);
    assert decision == R.Authorized(40, "duplicate_charge");
    assert plan == [R.Intent("charge-1", "request-1", 40, "duplicate_charge")];
  }
}
