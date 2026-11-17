// NEGATIVE CONTROL (U428): a decision core that signs every request. Verification MUST FAIL.
include "../RefundMinterCore.dfy"

module CoreSignsEverything {
  import C = RefundMinterCore
  import R = Refund

  method Decide(pre: C.Charge, req: C.Request) returns (r: C.Result)
    ensures r.Sign? ==> C.Authorizes(pre, req, r.post, r.intent)
  {
    r := C.Sign(pre.(remaining := pre.remaining - req.amount), R.Intent(pre.chargeId, req.requestId, req.amount, req.reason));
  }
}
