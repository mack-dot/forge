// DRAFT (M1-B step I.1b, worker W2). NOT CHECKED BY ANY TOOL.
// Optional second Dafny file: the string/byte step of the eligibility link.
//
// Run it inside a byte copy of the U295 Dafny input tree
// (backup branch: proposals/refund-executable-feasibility/byte-boundary-20261104/
//  records/dafny-repeat/inputs/), whose root holds Library.dfy and
// UnicodeRelation.dfy and whose transport/ folder holds FlatCore.dfy,
// impl/Refund.dfy and spec/refund/RefundSpec.dfy. Put EligibleFlat.dfy into
// transport/ so its own includes resolve to the same files. See RUN_PLAN.md D3.
//
// It uses the unchanged U262 functions RefundUnicode.Encoded (UTF-8 bytes of a
// Dafny string, one char per byte value) and the lemmas EncodedEmpty,
// SameReasons and EncodedIsBytes. It defines no encoder or decoder.

include "UnicodeRelation.dfy"
include "transport/EligibleFlat.dfy"

module RefundEligibleUtf8 {
  import R = Refund
  import U = RefundUnicode
  import L = RefundEligibleLink

  // U1: for EVERY approved context and response, the approved Eligible
  // equals EligibleFlat evaluated on the UTF-8 byte strings of the three
  // string fields. No precondition. All Unicode strings stay in the domain.
  lemma EligibleUnderUtf8(context: R.Context, response: R.ModelResponse)
    ensures R.Eligible(context, response) ==
      L.EligibleFlat(U.Encoded(context.chargeId), U.Encoded(context.requestId),
        context.original, context.remaining, context.refundEnabled,
        context.requestOpen, response.Candidate?, L.FlatAmount(response),
        U.Encoded(L.FlatReason(response)))
  {
    U.EncodedEmpty(context.chargeId);
    U.EncodedEmpty(context.requestId);
    U.SameReasons(L.FlatReason(response));
    L.EligibleFlatMatchesApproved(context, response);
  }

  // U2: every character of an encoded field is one byte value.
  lemma EncodedFieldsAreBytes(context: R.Context, response: R.ModelResponse)
    ensures forall i | 0 <= i < |U.Encoded(context.chargeId)| ::
      U.Encoded(context.chargeId)[i] as int < 256
    ensures forall i | 0 <= i < |U.Encoded(context.requestId)| ::
      U.Encoded(context.requestId)[i] as int < 256
    ensures forall i | 0 <= i < |U.Encoded(L.FlatReason(response))| ::
      U.Encoded(L.FlatReason(response))[i] as int < 256
  {
    U.EncodedIsBytes(context.chargeId);
    U.EncodedIsBytes(context.requestId);
    U.EncodedIsBytes(L.FlatReason(response));
  }
}
