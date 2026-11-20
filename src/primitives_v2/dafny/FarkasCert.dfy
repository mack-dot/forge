// V1.1 primitive 9, part A: a Farkas infeasibility certificate and its check. NOT an approved specification. NOT
// part of the gate. end_to_end=false.
//
// Domain. Every value is a mathematical integer (Dafny `int`). A is an m x n integer matrix (m rows, each of length
// n), b an integer vector of length m, y an integer vector of length m (the witness that an untrusted solver supplies
// with its claim "the system  A x >= b, x >= 0  has no solution"). Bounded sizes: 1 <= m <= 64, 1 <= n <= 64, every
// entry of A, b and y in the signed 64-bit range [-2^63, 2^63 - 1] (the range that the wire format carries).
//
// Accepts(A, b, y) is a compilable, ghost-free predicate: shapes agree and sizes are in bounds; y >= 0; y^T A <= 0
// in every column; y^T b > 0.
//
// PROVED here (when `dafny verify` of this file exits 0; the run is recorded by the caller, not by this file):
//   Soundness: Accepts(A, b, y) ==> for EVERY integer vector x of length n with x >= 0, NOT (A x >= b).
//     The lemma quantifies over `seq<int>`, so it is a statement about INTEGER x only. The same algebra (weak
//     duality: 0 < y^T b <= y^T (A x) = (y^T A) x <= 0) also holds for rational or real x, but this file does NOT
//     state or prove that: no lemma here quantifies over rationals or reals. Do not read more into it.
//   CheckCert returns exactly Accepts(A, b, y).
//   Non-vacuity, both directions, on concrete systems (module FarkasCertWitness):
//     an infeasible system with an accepted certificate; a feasible system for which a wrong certificate is
//     rejected (and, from Soundness, EVERY certificate is rejected); one wrong certificate for each clause.
//   Incompleteness over the integers, on one concrete system: 2 x >= 1 and -2 x >= -1 has no integer solution
//     x >= 0 (x = 1/2 is a rational solution), and NO y is accepted for it. So "no accepted certificate" never
//     means "feasible"; the check then answers "infeasibility not proved".
//
// NOT proved: completeness (that every infeasible system HAS an accepted certificate; over the integers this is false,
// see above; over the rationals Farkas' lemma gives a rational y and, scaled, an integer y, but that theorem is not
// in this file and its witness may leave the 64-bit range); anything about any solver; anything about the Rust code
// that runs in the engine (src/primitives_v2/farkas.rs is a NATIVE CHECK that mirrors this predicate, tied to it only
// by a FINITE differential test); anything about the JSON wire parser.
//
// Some lemmas below (DotFrom, ColDotFrom, ColVecFrom, YAxFrom, SwapFrom, DotLinearFrom, DotZerosFrom, DotMonoFrom and
// the arithmetic helpers) are copied in form from proposals/forge2-pillar3-dual-certificate/BookingDualCert.dfy (that
// file is not changed and not included).
module FarkasCert {
  const MaxRows: int := 64
  const MaxCols: int := 64
  const MinEntry: int := -9223372036854775808
  const MaxEntry: int := 9223372036854775807

  function DotFrom(a: seq<int>, b: seq<int>, k: nat): int
    requires |a| == |b| && k <= |a|
    decreases |a| - k
  {
    if k == |a| then 0 else a[k] * b[k] + DotFrom(a, b, k + 1)
  }

  function Dot(a: seq<int>, b: seq<int>): int
    requires |a| == |b|
  {
    DotFrom(a, b, 0)
  }

  // Sum over rows r >= i of y[r] * A[r][j]: entry j of (y^T A), from row i.
  function ColDotFrom(A: seq<seq<int>>, y: seq<int>, j: nat, i: nat): int
    requires |A| == |y| && i <= |A| && forall r | 0 <= r < |A| :: j < |A[r]|
    decreases |A| - i
  {
    if i == |A| then 0 else y[i] * A[i][j] + ColDotFrom(A, y, j, i + 1)
  }

  predicate InRange(v: int)
  {
    MinEntry <= v <= MaxEntry
  }

  predicate VecInRange(v: seq<int>)
  {
    forall k | 0 <= k < |v| :: InRange(v[k])
  }

  predicate NonNeg(a: seq<int>)
  {
    forall j | 0 <= j < |a| :: 0 <= a[j]
  }

  // Shapes agree and every size and entry is in bounds.
  predicate Shape(A: seq<seq<int>>, b: seq<int>, y: seq<int>)
  {
    1 <= |A| <= MaxRows && |b| == |A| && |y| == |A| &&
    1 <= |A[0]| <= MaxCols && (forall i | 0 <= i < |A| :: |A[i]| == |A[0]|) &&
    (forall i | 0 <= i < |A| :: VecInRange(A[i])) && VecInRange(b) && VecInRange(y)
  }

  // The executable check of the certificate.
  predicate Accepts(A: seq<seq<int>>, b: seq<int>, y: seq<int>)
  {
    Shape(A, b, y) &&
    NonNeg(y) &&
    (forall j | 0 <= j < |A[0]| :: ColDotFrom(A, y, j, 0) <= 0) &&
    Dot(y, b) > 0
  }

  // x >= 0 and A x >= b (row by row).
  predicate Feasible(A: seq<seq<int>>, b: seq<int>, x: seq<int>)
    requires |A| == |b| && forall i | 0 <= i < |A| :: |A[i]| == |x|
  {
    NonNeg(x) && forall i | 0 <= i < |A| :: Dot(A[i], x) >= b[i]
  }

  method CheckCert(A: seq<seq<int>>, b: seq<int>, y: seq<int>) returns (ok: bool)
    ensures ok == Accepts(A, b, y)
  {
    ok := Accepts(A, b, y);
  }

  lemma MulMono(k: int, a: int, b: int)
    requires 0 <= k && a <= b
    ensures k * a <= k * b
  {
  }

  lemma DistribLeft(k: int, a: int, b: int)
    ensures k * (a + b) == k * a + k * b
  {
  }

  lemma DistribRight(a: int, b: int, c: int)
    ensures (a + b) * c == a * c + b * c
  {
  }

  lemma MulAssoc(k: int, a: int, b: int)
    ensures (k * a) * b == k * (a * b)
  {
  }

  lemma DotLinearFrom(k0: int, u: seq<int>, v: seq<int>, s: seq<int>, x: seq<int>, k: nat)
    requires |u| == |v| == |s| == |x| && k <= |s|
    requires forall j | 0 <= j < |s| :: s[j] == k0 * u[j] + v[j]
    ensures DotFrom(s, x, k) == k0 * DotFrom(u, x, k) + DotFrom(v, x, k)
    decreases |s| - k
  {
    if k != |s| {
      DotLinearFrom(k0, u, v, s, x, k + 1);
      var su := DotFrom(u, x, k + 1);
      var sv := DotFrom(v, x, k + 1);
      var p := u[k] * x[k];
      var q := v[k] * x[k];
      calc {
        DotFrom(s, x, k);
        s[k] * x[k] + DotFrom(s, x, k + 1);
        (k0 * u[k] + v[k]) * x[k] + (k0 * su + sv);
        { DistribRight(k0 * u[k], v[k], x[k]); MulAssoc(k0, u[k], x[k]); }
        k0 * p + q + (k0 * su + sv);
        { DistribLeft(k0, p, su); }
        k0 * (p + su) + (q + sv);
        k0 * DotFrom(u, x, k) + DotFrom(v, x, k);
      }
    }
  }

  lemma DotZerosFrom(s: seq<int>, x: seq<int>, k: nat)
    requires |s| == |x| && k <= |s| && forall j | 0 <= j < |s| :: s[j] == 0
    ensures DotFrom(s, x, k) == 0
    decreases |s| - k
  {
    if k != |s| {
      DotZerosFrom(s, x, k + 1);
    }
  }

  // A componentwise non-positive vector has a non-positive product with a non-negative x.
  lemma DotNonPosFrom(s: seq<int>, x: seq<int>, k: nat)
    requires |s| == |x| && k <= |s| && NonNeg(x) && forall j | 0 <= j < |s| :: s[j] <= 0
    ensures DotFrom(s, x, k) <= 0
    decreases |s| - k
  {
    if k != |s| {
      DotNonPosFrom(s, x, k + 1);
      MulMono(x[k], s[k], 0);
      assert s[k] * x[k] == x[k] * s[k];
    }
  }

  function ColVecFrom(A: seq<seq<int>>, y: seq<int>, n: nat, i: nat): seq<int>
    requires |A| == |y| && i <= |A| && forall r | 0 <= r < |A| :: |A[r]| == n
  {
    seq(n, j requires 0 <= j < n => ColDotFrom(A, y, j, i))
  }

  // Sum over rows r >= i of y[r] * (A[r] . x): y . (A x), from row i.
  function YAxFrom(A: seq<seq<int>>, y: seq<int>, x: seq<int>, i: nat): int
    requires |A| == |y| && i <= |A| && forall r | 0 <= r < |A| :: |A[r]| == |x|
    decreases |A| - i
  {
    if i == |A| then 0 else y[i] * Dot(A[i], x) + YAxFrom(A, y, x, i + 1)
  }

  // (y^T A) . x == y . (A x)
  lemma SwapFrom(A: seq<seq<int>>, y: seq<int>, x: seq<int>, i: nat)
    requires |A| == |y| && i <= |A| && forall r | 0 <= r < |A| :: |A[r]| == |x|
    ensures Dot(ColVecFrom(A, y, |x|, i), x) == YAxFrom(A, y, x, i)
    decreases |A| - i
  {
    if i == |A| {
      DotZerosFrom(ColVecFrom(A, y, |x|, i), x, 0);
    } else {
      SwapFrom(A, y, x, i + 1);
      DotLinearFrom(y[i], A[i], ColVecFrom(A, y, |x|, i + 1), ColVecFrom(A, y, |x|, i), x, 0);
    }
  }

  // y >= 0 and A x >= b give y . (A x) >= y . b.
  lemma YAxLowerFrom(A: seq<seq<int>>, y: seq<int>, b: seq<int>, x: seq<int>, i: nat)
    requires |A| == |y| == |b| && i <= |A| && forall r | 0 <= r < |A| :: |A[r]| == |x|
    requires NonNeg(y) && forall r | 0 <= r < |A| :: Dot(A[r], x) >= b[r]
    ensures YAxFrom(A, y, x, i) >= DotFrom(y, b, i)
    decreases |A| - i
  {
    if i != |A| {
      YAxLowerFrom(A, y, b, x, i + 1);
      MulMono(y[i], b[i], Dot(A[i], x));
    }
  }

  // One integer x: an accepted certificate excludes it.
  lemma ExcludesOne(A: seq<seq<int>>, b: seq<int>, y: seq<int>, x: seq<int>)
    requires Accepts(A, b, y) && |x| == |A[0]|
    ensures !Feasible(A, b, x)
  {
    if Feasible(A, b, x) {
      var n := |x|;
      var u := ColVecFrom(A, y, n, 0);
      SwapFrom(A, y, x, 0);
      DotNonPosFrom(u, x, 0);
      YAxLowerFrom(A, y, b, x, 0);
      assert YAxFrom(A, y, x, 0) <= 0;
      assert false;
    }
  }

  // SOUNDNESS: an accepted certificate proves that NO non-negative INTEGER vector x satisfies A x >= b.
  lemma Soundness(A: seq<seq<int>>, b: seq<int>, y: seq<int>)
    requires Accepts(A, b, y)
    ensures forall x: seq<int> | |x| == |A[0]| :: !Feasible(A, b, x)
  {
    forall x: seq<int> | |x| == |A[0]|
      ensures !Feasible(A, b, x)
    {
      ExcludesOne(A, b, y, x);
    }
  }
}

// Non-vacuity and rejection witnesses on concrete systems.
module FarkasCertWitness {
  import opened FarkasCert

  // System 1, infeasible: x1 >= 1 and -x1 >= 0. Certificate y = [1, 1]: y^T A = [0], y^T b = 1.
  const A1: seq<seq<int>> := [[1], [-1]]
  const B1: seq<int> := [1, 0]

  lemma InfeasibleSystemAccepted()
    ensures Accepts(A1, B1, [1, 1])
    ensures forall x: seq<int> | |x| == 1 :: !Feasible(A1, B1, x)
  {
    assert ColDotFrom(A1, [1, 1], 0, 0) == 0;
    Soundness(A1, B1, [1, 1]);
  }

  // One wrong certificate per clause, on the infeasible system 1.
  lemma WrongCertificatesRejected()
    ensures Accepts(A1, B1, [1, 2])         // also valid: y^T A = [-1] <= 0, y^T b = 1 > 0
    ensures !Accepts(A1, B1, [2, 1])        // y^T A = [1] > 0
    ensures !Accepts(A1, B1, [-1, -1])      // y < 0
    ensures !Accepts(A1, B1, [0, 1])        // y^T b = 0, not > 0
    ensures !Accepts(A1, B1, [1])           // shape: |y| != |A|
    ensures !Accepts(A1, B1, [9223372036854775808, 9223372036854775808])   // out of the 64-bit range
  {
    assert ColDotFrom(A1, [2, 1], 0, 0) == 1;
    assert Dot([0, 1], B1) == 0;
    assert !InRange(9223372036854775808);
  }

  // System 2, feasible: x1 >= 1 (x = [1] solves it). A wrong certificate is rejected, and by Soundness EVERY
  // certificate is rejected.
  const A2: seq<seq<int>> := [[1]]
  const B2: seq<int> := [1]

  lemma FeasibleSystemRejectsEveryCertificate()
    ensures Feasible(A2, B2, [1])
    ensures !Accepts(A2, B2, [1])
    ensures forall y: seq<int> :: !Accepts(A2, B2, y)
  {
    assert Dot(A2[0], [1]) == 1;
    assert ColDotFrom(A2, [1], 0, 0) == 1;
    forall y: seq<int>
      ensures !Accepts(A2, B2, y)
    {
      if Accepts(A2, B2, y) {
        ExcludesOne(A2, B2, y, [1]);
      }
    }
  }

  // System 3: 2 x >= 1 and -2 x >= -1. Integer-infeasible (x = 1/2 is its only rational solution), and no
  // certificate is accepted: incompleteness over the integers.
  const A3: seq<seq<int>> := [[2], [-2]]
  const B3: seq<int> := [1, -1]

  lemma IntegerInfeasibleWithoutCertificate()
    ensures forall x: seq<int> | |x| == 1 :: !Feasible(A3, B3, x)
    ensures forall y: seq<int> :: !Accepts(A3, B3, y)
  {
    forall x: seq<int> | |x| == 1
      ensures !Feasible(A3, B3, x)
    {
      assert Dot(A3[0], x) == 2 * x[0];
      assert Dot(A3[1], x) == -2 * x[0];
    }
    forall y: seq<int>
      ensures !Accepts(A3, B3, y)
    {
      if Accepts(A3, B3, y) {
        assert ColDotFrom(A3, y, 0, 0) == 2 * y[0] - 2 * y[1];
        assert DotFrom(y, B3, 2) == 0;
        assert DotFrom(y, B3, 1) == y[1] * -1;
        assert Dot(y, B3) == y[0] * 1 + y[1] * -1;
        assert false;
      }
    }
  }
}
