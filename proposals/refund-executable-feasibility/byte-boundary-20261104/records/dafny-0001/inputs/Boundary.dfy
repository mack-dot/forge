include "UnicodeRelation.dfy"

// Type projection only. The existing UTF-8 implementation is unchanged.
module RefundByteBoundary {
  import R = Refund
  import U = RefundUnicode
  import T = RefundUtf8Transport
  import F = FlatRefund
  import E = Std.Unicode.Utf8EncodingForm

  function Codes(s: string): seq<nat> {
    seq(|s|, i requires 0 <= i < |s| => s[i] as int)
  }

  lemma CodesIdentity(s: string, t: string)
    ensures Codes(s) == Codes(t) <==> s == t
    ensures Codes(s) == [] <==> s == ""
  {
    if Codes(s) == Codes(t) {
      forall i | 0 <= i < |s|
        ensures s[i] == t[i]
      {
        assert s[i] as int == t[i] as int;
      }
    }
  }

  lemma EncodedCodes(s: string)
    ensures forall i | 0 <= i < |Codes(U.Encoded(s))| :: Codes(U.Encoded(s))[i] < 256
    ensures Codes(U.Encoded(s)) ==
      seq(|E.EncodeScalarSequence(U.Scalars(s))|,
        i requires 0 <= i < |E.EncodeScalarSequence(U.Scalars(s))| =>
          E.EncodeScalarSequence(U.Scalars(s))[i] as int)
  {
    U.EncodedIsBytes(s);
    U.ByteViewIdentity(s);
  }

  lemma ReasonCodes(s: string)
    ensures (Codes(U.Encoded(s)) == Codes("duplicate_charge") <==> s == "duplicate_charge")
    ensures (Codes(U.Encoded(s)) == Codes("service_not_delivered") <==> s == "service_not_delivered")
    ensures (Codes(U.Encoded(s)) == Codes("returned_item") <==> s == "returned_item")
    ensures (s == "duplicate_charge" || s == "service_not_delivered" || s == "returned_item") ==>
      Codes(U.Encoded(s)) == Codes(s)
  {
    U.SameReasons(s);
    CodesIdentity(U.Encoded(s), "duplicate_charge");
    CodesIdentity(U.Encoded(s), "service_not_delivered");
    CodesIdentity(U.Encoded(s), "returned_item");
  }

  // No domain precondition. This consumes the complete approved source relation.
  method Boundary(context: R.Context, response: R.ModelResponse)
    returns (ok: bool, amount: int, reason: seq<nat>, charge: seq<nat>,
             request: seq<nat>, count: int)
    modifies {}
    ensures ok <==> R.Eligible(context, response)
    ensures var cb := Codes(U.Encoded(context.chargeId));
            var qb := Codes(U.Encoded(context.requestId));
            var rb := Codes(U.Encoded(if response.Candidate? then response.reason else ""));
            var a := if response.Candidate? then response.amount else 0;
      (ok <==> cb != [] && qb != [] && context.refundEnabled && context.requestOpen &&
        0 <= context.original <= 9223372036854775807 && 0 <= context.remaining <= context.original &&
        response.Candidate? && 0 <= a <= context.remaining &&
        (rb == Codes("duplicate_charge") || rb == Codes("service_not_delivered") || rb == Codes("returned_item"))) &&
      amount == (if ok then a else 0) && reason == (if ok then rb else []) &&
      charge == (if ok then cb else []) && request == (if ok then qb else []) &&
      count == (if ok then 1 else 0)
    ensures forall i | 0 <= i < |Codes(U.Encoded(context.chargeId))| :: Codes(U.Encoded(context.chargeId))[i] < 256
    ensures forall i | 0 <= i < |Codes(U.Encoded(context.requestId))| :: Codes(U.Encoded(context.requestId))[i] < 256
    ensures forall i | 0 <= i < |Codes(U.Encoded(if response.Candidate? then response.reason else ""))| ::
      Codes(U.Encoded(if response.Candidate? then response.reason else ""))[i] < 256
  {
    var sr := if response.Candidate? then response.reason else "";
    EncodedCodes(context.chargeId);
    EncodedCodes(context.requestId);
    EncodedCodes(sr);
    U.EncodedEmpty(context.chargeId);
    U.EncodedEmpty(context.requestId);
    CodesIdentity(U.Encoded(context.chargeId), "");
    CodesIdentity(U.Encoded(context.requestId), "");
    ReasonCodes(sr);
    var outReason, outCharge, outRequest;
    ok, amount, outReason, outCharge, outRequest, count := T.Equivalent(context, response);
    reason := Codes(outReason);
    charge := Codes(outCharge);
    request := Codes(outRequest);
  }
}
