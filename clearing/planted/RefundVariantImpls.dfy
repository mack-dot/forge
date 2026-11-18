// Slice 2: every planted refund variant has an implementation. The implementation text is the body of
// impl/Refund.dfy; each module checks it against ITS OWN specification. Fixtures, not approved code.
// The clearing tool binds these modules into the instances that it writes.
include "../../proposals/forge2-pillar1-spec-determinism/fixtures/RefundSpecCapped.dfy"
include "RefundSpecRewritten.dfy"
include "RefundSpecLoose.dfy"

module RefundCappedHonest refines RefundSpecCapped {
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    if Eligible(context, response) {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}

module RefundRewrittenHonest refines RefundSpecRewritten {
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    if Eligible(context, response) {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}

module RefundLooseHonest refines RefundSpecLoose {
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    if Eligible(context, response) {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
