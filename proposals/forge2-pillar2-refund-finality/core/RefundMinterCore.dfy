// Round 3 task 3 (U428): the decision core of the refund minter, proved against the APPROVED refund specification.
// It calls the gate-verified implementation Refund.Assess (impl/Refund.dfy) and computes the post-state and the intent.
// NOT an approved specification. NOT part of the gate. The state update rule "remaining decreases by the authorized
// amount" is this experiment's choice; the approved refund specification has no stored state.
include "../../../impl/Refund.dfy"

module RefundMinterCore {
  import R = Refund

  datatype Charge = Charge(chargeId: string, original: int, remaining: int, refundEnabled: bool)
  datatype Request = Request(requestId: string, amount: int, reason: string)
  datatype Result = Refuse | Sign(post: Charge, intent: R.RefundIntent)

  // What a signed claim must satisfy: the approved specification makes the request eligible for this charge
  // (with the request open), the post-state is the pre-state minus the amount, and the intent is the caller-bound one.
  ghost predicate Authorizes(pre: Charge, req: Request, post: Charge, intent: R.RefundIntent)
  {
    R.Eligible(R.ChargeContext(pre.chargeId, req.requestId, pre.original, pre.remaining, pre.refundEnabled, true),
               R.Candidate(req.amount, req.reason)) &&
    post == pre.(remaining := pre.remaining - req.amount) &&
    intent == R.Intent(pre.chargeId, req.requestId, req.amount, req.reason)
  }

  method Decide(pre: Charge, req: Request) returns (r: Result)
    // Soundness: a Sign result is authorized.
    ensures r.Sign? ==> Authorizes(pre, req, r.post, r.intent)
    // Completeness: Refuse only when NO post-state and intent are authorized.
    ensures r.Refuse? ==> forall post: Charge, intent: R.RefundIntent :: !Authorizes(pre, req, post, intent)
    // Consequences of the approved specification for a signed result.
    ensures r.Sign? ==> 0 <= r.post.remaining <= pre.remaining <= pre.original
    ensures r.Sign? ==> r.intent.amount == req.amount && 0 <= req.amount && R.AllowedReason(req.reason)
  {
    var ctx := R.ChargeContext(pre.chargeId, req.requestId, pre.original, pre.remaining, pre.refundEnabled, true);
    var decision, plan := R.Assess(ctx, R.Candidate(req.amount, req.reason));
    if decision.Authorized? && |plan| == 1 {
      r := Sign(pre.(remaining := pre.remaining - decision.amount), plan[0]);
    } else {
      r := Refuse;
    }
  }

  // Non-vacuity and rejection witnesses.
  lemma Witnesses()
    ensures Authorizes(Charge("ch_1", 1000, 1000, true), Request("rq_1", 100, "duplicate_charge"),
                       Charge("ch_1", 1000, 900, true), R.Intent("ch_1", "rq_1", 100, "duplicate_charge"))
    ensures forall post: Charge, intent: R.RefundIntent ::
              !Authorizes(Charge("ch_1", 1000, 500, true), Request("rq_2", 501, "duplicate_charge"), post, intent)
    ensures forall post: Charge, intent: R.RefundIntent ::
              !Authorizes(Charge("ch_1", 1000, 500, false), Request("rq_3", 10, "duplicate_charge"), post, intent)
    ensures forall post: Charge, intent: R.RefundIntent ::
              !Authorizes(Charge("ch_1", 1000, 500, true), Request("rq_4", 10, "goodwill"), post, intent)
  {
  }
}
