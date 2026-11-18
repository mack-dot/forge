// NEGATIVE CONTROL (U410). The bound Dot(z, x) <= Sum(z) WITHOUT the 0/1 upper bound on x. False (z = [1], x = [2]).
// Verification MUST FAIL.
include "../BookingDualCert.dfy"

module NoUpperBoundOnAllocation {
  import opened BookingDualCert

  lemma DotLeSumWithoutBinary(z: seq<int>, x: seq<int>, k: nat)
    requires |z| == |x| && k <= |z| && NonNeg(z) && NonNeg(x)
    ensures DotFrom(z, x, k) <= SumFrom(z, k)
    decreases |z| - k
  {
    if k != |z| {
      DotLeSumWithoutBinary(z, x, k + 1);
    }
  }
}
