include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  const Reasons: seq<string> := ["duplicate_charge", "service_not_delivered", "returned_item"]

  predicate InList(r: string, xs: seq<string>)
    decreases |xs|
  {
    |xs| > 0 && (xs[0] == r || InList(r, xs[1..]))
  }

  lemma InListReasons(r: string)
    ensures InList(r, Reasons) <==> AllowedReason(r)
  {
    var t1 := Reasons[1..];
    var t2 := t1[1..];
    var t3 := t2[1..];
    assert t1 == ["service_not_delivered", "returned_item"];
    assert t2 == ["returned_item"];
    assert t3 == [];
    assert !InList(r, t3);
    assert InList(r, t2) <==> r == "returned_item";
    assert InList(r, t1) <==> r == "service_not_delivered" || r == "returned_item";
  }

  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    if ValidContext(context) && response.Candidate? && 0 <= response.amount <= context.remaining &&
       InList(response.reason, Reasons) {
      InListReasons(response.reason);
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      if response.Candidate? { InListReasons(response.reason); }
      decision := Rejected;
      plan := [];
    }
  }
}
