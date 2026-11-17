// NEGATIVE CONTROL (U410). A check that skips dual feasibility must not give the quality theorem.
// Verification MUST FAIL.
include "../BookingDualCert.dfy"

module QualityWithoutDualCheck {
  import opened BookingDualCert

  predicate WeakAccepts(A: seq<seq<int>>, c: seq<int>, w: seq<int>, x: seq<int>, y: seq<int>, z: seq<int>, alpha_bps: nat)
  {
    Shape(A, c, |w|) && |x| == |w| && |y| == |A| && |z| == |w| && alpha_bps <= 10000 &&
    Feasible(A, c, x) &&
    (10000 - alpha_bps) * (Dot(y, c) + Sum(z)) <= 10000 * Dot(w, x)
  }

  lemma QualityFromWeakCheck(A: seq<seq<int>>, c: seq<int>, w: seq<int>, x: seq<int>, y: seq<int>, z: seq<int>,
                             alpha_bps: nat, alt: seq<int>)
    requires WeakAccepts(A, c, w, x, y, z, alpha_bps)
    requires |alt| == |w| && Feasible(A, c, alt)
    ensures (10000 - alpha_bps) * Dot(w, alt) <= 10000 * Dot(w, x)
  {
  }
}
