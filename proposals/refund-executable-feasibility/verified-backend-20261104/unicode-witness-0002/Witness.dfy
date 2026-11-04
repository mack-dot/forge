include "impl/Refund.dfy"
module UnicodeInputWitness {
  import R = Refund
  method LegitimateNonByteIdentity() {
    var context := R.ChargeContext("Ā", "request-1", 100, 60, true, true);
    var decision, plan := R.Assess(context, R.Candidate(40, "returned_item"));
    assert ('Ā' as int) == 256;
    assert decision == R.Authorized(40, "returned_item");
    assert plan == [R.Intent("Ā", "request-1", 40, "returned_item")];
  }
}
