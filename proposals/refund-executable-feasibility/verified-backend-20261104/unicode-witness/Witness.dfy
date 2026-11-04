include "impl/Refund.dfy"
module UnicodeInputWitness {
  import R = Refund
  method LegitimateNonByteIdentity() {
    var context := R.ChargeContext("\u0100", "request-1", 100, 60, true, true);
    var decision, plan := R.Assess(context, R.Candidate(40, "returned_item"));
    assert ('\u0100' as int) == 256;
    assert decision == R.Authorized(40, "returned_item");
    assert plan == [R.Intent("\u0100", "request-1", 40, "returned_item")];
  }
}
