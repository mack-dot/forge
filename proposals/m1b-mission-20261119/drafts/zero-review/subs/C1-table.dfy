include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  const Reasons: seq<string> := ["duplicate_charge", "service_not_delivered", "returned_item"]

  method InTable(r: string) returns (b: bool)
    ensures b <==> AllowedReason(r)
  {
    b := false;
    var i := 0;
    while i < |Reasons|
      invariant 0 <= i <= |Reasons|
      invariant b <==> r in Reasons[..i]
    {
      if Reasons[i] == r { b := true; }
      i := i + 1;
    }
    assert Reasons[..|Reasons|] == Reasons;
  }

  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    decision, plan := Rejected, [];
    if !response.Candidate? { return; }
    var ok := InTable(response.reason);
    var c := context;
    if ok && c.chargeId != "" && c.requestId != "" && c.refundEnabled && c.requestOpen
       && 0 <= c.original <= MaxMoney && 0 <= c.remaining <= c.original
       && 0 <= response.amount <= c.remaining {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(c.chargeId, c.requestId, decision.amount, decision.reason)];
    }
  }
}
