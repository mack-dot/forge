// Stage 8 refund boundary contract. Approval is recorded separately.
abstract module RefundSpec {
  const MaxMoney: int := 9223372036854775807

  datatype Context = ChargeContext(
    chargeId: string, requestId: string,
    original: int, remaining: int,
    refundEnabled: bool, requestOpen: bool)

  // Every constructor, every mathematical integer and every finite string
  // is in the response domain. Assess has no response-validity precondition.
  datatype ModelResponse = Candidate(amount: int, reason: string)
    | Missing | TimedOut | Failed | Malformed | Oversized | Unsupported

  datatype Decision = Rejected | Authorized(amount: int, reason: string)
  datatype RefundIntent = Intent(
    chargeId: string, requestId: string, amount: int, reason: string)

  predicate Money(value: int) {
    0 <= value <= MaxMoney
  }

  predicate AllowedReason(reason: string) {
    reason in {"duplicate_charge", "service_not_delivered", "returned_item"}
  }

  predicate ValidContext(context: Context) {
    context.chargeId != "" && context.requestId != "" &&
    context.refundEnabled && context.requestOpen &&
    Money(context.original) && 0 <= context.remaining <= context.original
  }

  predicate Eligible(context: Context, response: ModelResponse) {
    ValidContext(context) && response.Candidate? &&
    0 <= response.amount <= context.remaining && AllowedReason(response.reason)
  }

  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
    modifies {}
    // R1: every authorized amount is nonnegative and within both bounds.
    ensures decision.Authorized? ==>
      ValidContext(context) && Money(decision.amount) &&
      decision.amount <= context.remaining <= context.original
    // R2: every authorized reason is in the exact approved set.
    ensures decision.Authorized? ==> AllowedReason(decision.reason)
    // R3: every ineligible context or response has the same no-intent fallback.
    ensures !Eligible(context, response) ==> decision == Rejected && plan == []
    // R4: every eligible proposal is accepted with its exact amount and reason.
    ensures Eligible(context, response) ==>
      response.Candidate? && decision == Authorized(response.amount, response.reason) &&
      plan == [Intent(context.chargeId, context.requestId, response.amount, response.reason)]
    // R5: an intent exists exactly for an authorization; its target is caller-bound.
    ensures (decision.Authorized? <==> Eligible(context, response))
    ensures (decision.Rejected? <==> |plan| == 0)
    ensures |plan| <= 1
    ensures decision.Authorized? ==>
      plan == [Intent(context.chargeId, context.requestId, decision.amount, decision.reason)]
    ensures forall intent: RefundIntent :: intent in plan ==>
      ValidContext(context) && Money(intent.amount) &&
      intent.amount <= context.remaining <= context.original &&
      AllowedReason(intent.reason) &&
      intent.chargeId == context.chargeId && intent.requestId == context.requestId
}

// Unapproved change, only in disposable negative fixture.
