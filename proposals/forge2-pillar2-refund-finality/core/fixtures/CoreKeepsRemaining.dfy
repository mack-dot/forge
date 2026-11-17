// NEGATIVE CONTROL (U428): a decision core that authorizes correctly but does not reduce the remaining amount.
// Verification MUST FAIL.
include "../RefundMinterCore.dfy"

module CoreKeepsRemaining {
  import C = RefundMinterCore
  import R = Refund

  method Decide(pre: C.Charge, req: C.Request) returns (r: C.Result)
    ensures r.Sign? ==> C.Authorizes(pre, req, r.post, r.intent)
  {
    var ctx := R.ChargeContext(pre.chargeId, req.requestId, pre.original, pre.remaining, pre.refundEnabled, true);
    var decision, plan := R.Assess(ctx, R.Candidate(req.amount, req.reason));
    if decision.Authorized? && |plan| == 1 {
      r := C.Sign(pre, plan[0]);
    } else {
      r := C.Refuse;
    }
  }
}
