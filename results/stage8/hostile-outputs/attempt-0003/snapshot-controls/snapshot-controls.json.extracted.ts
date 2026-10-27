const MAX = 9223372036854775807n;
const reasons = ["duplicate_charge", "service_not_delivered", "returned_item"] as const;
const rejected = (): Outcome => ({ decision: { kind: "Rejected" }, plan: [] });
function expected(context: Context, response: Response): Outcome {
  if (!context.chargeId || !context.requestId || !context.refundEnabled || !context.requestOpen ||
      context.original < 0n || context.original > MAX || context.remaining < 0n ||
      context.remaining > context.original || response.kind !== "Candidate" ||
      response.amount < 0n || response.amount > context.remaining ||
      !reasons.some(reason => reason === response.reason)) return rejected();
  return { decision: { kind: "Authorized", amount: response.amount, reason: response.reason },
    plan: [{ chargeId: context.chargeId, requestId: context.requestId,
      amount: response.amount, reason: response.reason }] };
}
function model(modulePath: string): Assess {
  // The gate just compiled this exact module with Dafny and added its fixed
  // visibility footer. BigNumber and Unicode conversions are tested, not proved.
  const { Refund: R, runtime } = require(resolve(modulePath));
  const number = (n: bigint) => new BigNumber(String(n));
  const string = (s: string) => runtime.Seq.UnicodeFromString(s);
  const integer = (n: BigNumber): bigint => {
    assert(n.isInteger(), "generated model returned noninteger");
    return BigInt(n.toFixed());
  };
  return (c, r) => {
    const context = R.Context.create_ChargeContext(string(c.chargeId), string(c.requestId),
      number(c.original), number(c.remaining), c.refundEnabled, c.requestOpen);
    const response = r.kind === "Candidate"
      ? R.ModelResponse.create_Candidate(number(r.amount), string(r.reason))
      : R.ModelResponse["create_" + r.kind]();
    const [decision, plan] = R.__default.Assess(context, response);
    assert.notEqual(decision.is_Authorized, decision.is_Rejected);
    return {
      decision: decision.is_Authorized
        ? { kind: "Authorized", amount: integer(decision.dtor_amount), reason: decision.dtor_reason.toVerbatimString(false) }
        : { kind: "Rejected" },
      plan: Array.from(plan, (intent: any) => ({ chargeId: intent.dtor_chargeId.toVerbatimString(false),
        requestId: intent.dtor_requestId.toVerbatimString(false), amount: integer(intent.dtor_amount),
        reason: intent.dtor_reason.toVerbatimString(false) })),
    };
  };
}
({ model, property: (assess) => (async (c, r) => {
        // These records have only primitive fields. Preserve their prototypes
        // as well as field values; structuredClone normalizes null prototypes.
        const before = {
          c: Object.assign(Object.create(Object.getPrototypeOf(c)), c),
          r: Object.assign(Object.create(Object.getPrototypeOf(r)), r),
        };
        assert.deepEqual(assess(c, r), expected(c, r));
        assert.deepEqual({ c, r }, before);
      }) });