// Forge 2.0 master idea, Pillar III, first check (U410). NOT an approved specification. NOT part of the gate.
// Batch booking: maximise Dot(w, x) subject to A x <= c, x in {0,1}^n. All arithmetic is over mathematical integers.
// An untrusted solver supplies x and dual values (y, z). Accepts is an executable check. Quality is the theorem:
// an accepted x is within the stated factor of EVERY feasible allocation. The proof is weak duality only.
// No linear-programming theory, no solver and no total-unimodularity fact is trusted or used.
// What this does NOT show: that a certificate exists for a given instance; anything about the solver; anything about
// the deployed program that runs this check.
module BookingDualCert {
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

  function SumFrom(a: seq<int>, k: nat): int
    requires k <= |a|
    decreases |a| - k
  {
    if k == |a| then 0 else a[k] + SumFrom(a, k + 1)
  }

  function Sum(a: seq<int>): int
  {
    SumFrom(a, 0)
  }

  predicate Shape(A: seq<seq<int>>, c: seq<int>, n: nat)
  {
    |A| == |c| && forall i | 0 <= i < |A| :: |A[i]| == n
  }

  predicate NonNeg(a: seq<int>)
  {
    forall j | 0 <= j < |a| :: 0 <= a[j]
  }

  predicate Binary(x: seq<int>)
  {
    forall j | 0 <= j < |x| :: x[j] == 0 || x[j] == 1
  }

  // B1: x is a 0/1 allocation and no slot is used above its capacity.
  predicate Feasible(A: seq<seq<int>>, c: seq<int>, x: seq<int>)
    requires Shape(A, c, |x|)
  {
    Binary(x) && forall i | 0 <= i < |A| :: Dot(A[i], x) <= c[i]
  }

  // Sum over rows r >= i of y[r] * A[r][j]: entry j of (A^T y), from row i.
  function ColDotFrom(A: seq<seq<int>>, y: seq<int>, j: nat, i: nat): int
    requires |A| == |y| && i <= |A| && forall r | 0 <= r < |A| :: j < |A[r]|
    decreases |A| - i
  {
    if i == |A| then 0 else y[i] * A[i][j] + ColDotFrom(A, y, j, i + 1)
  }

  // B2: y >= 0, z >= 0 and A^T y + z >= w.
  predicate DualFeasible(A: seq<seq<int>>, w: seq<int>, y: seq<int>, z: seq<int>)
    requires |A| == |y| && |w| == |z| && forall i | 0 <= i < |A| :: |A[i]| == |w|
  {
    NonNeg(y) && NonNeg(z) && forall j | 0 <= j < |w| :: w[j] <= ColDotFrom(A, y, j, 0) + z[j]
  }

  // The executable check. alpha_bps is the allowed gap in basis points (0 = exact optimum).
  predicate Accepts(A: seq<seq<int>>, c: seq<int>, w: seq<int>, x: seq<int>, y: seq<int>, z: seq<int>, alpha_bps: nat)
  {
    Shape(A, c, |w|) && |x| == |w| && |y| == |A| && |z| == |w| && alpha_bps <= 10000 &&
    Feasible(A, c, x) && DualFeasible(A, w, y, z) &&
    (10000 - alpha_bps) * (Dot(y, c) + Sum(z)) <= 10000 * Dot(w, x)
  }

  method VerifyCertifiedBooking(A: seq<seq<int>>, c: seq<int>, w: seq<int>, x: seq<int>, y: seq<int>, z: seq<int>,
                                alpha_bps: nat) returns (ok: bool)
    ensures ok == Accepts(A, c, w, x, y, z, alpha_bps)
  {
    ok := Accepts(A, c, w, x, y, z, alpha_bps);
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

  lemma DotMonoFrom(a: seq<int>, b: seq<int>, x: seq<int>, k: nat)
    requires |a| == |b| == |x| && k <= |a| && NonNeg(x)
    requires forall j | 0 <= j < |a| :: a[j] <= b[j]
    ensures DotFrom(a, x, k) <= DotFrom(b, x, k)
    decreases |a| - k
  {
    if k != |a| {
      DotMonoFrom(a, b, x, k + 1);
      MulMono(x[k], a[k], b[k]);
      assert a[k] * x[k] == x[k] * a[k] && b[k] * x[k] == x[k] * b[k];
    }
  }

  lemma DotLeSumFrom(z: seq<int>, x: seq<int>, k: nat)
    requires |z| == |x| && k <= |z| && NonNeg(z) && Binary(x)
    ensures DotFrom(z, x, k) <= SumFrom(z, k)
    decreases |z| - k
  {
    if k != |z| {
      DotLeSumFrom(z, x, k + 1);
      assert x[k] == 0 || x[k] == 1;
      assert z[k] * x[k] <= z[k];
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

  // (A^T y) . x == y . (A x)
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

  lemma YAxBoundFrom(A: seq<seq<int>>, y: seq<int>, c: seq<int>, x: seq<int>, i: nat)
    requires |A| == |y| == |c| && i <= |A| && forall r | 0 <= r < |A| :: |A[r]| == |x|
    requires NonNeg(y) && forall r | 0 <= r < |A| :: Dot(A[r], x) <= c[r]
    ensures YAxFrom(A, y, x, i) <= DotFrom(y, c, i)
    decreases |A| - i
  {
    if i != |A| {
      YAxBoundFrom(A, y, c, x, i + 1);
      MulMono(y[i], Dot(A[i], x), c[i]);
    }
  }

  // B3: weak duality. Every feasible allocation earns at most the dual bound.
  lemma WeakDuality(A: seq<seq<int>>, c: seq<int>, w: seq<int>, y: seq<int>, z: seq<int>, x: seq<int>)
    requires Shape(A, c, |w|) && |y| == |A| && |z| == |w| && |x| == |w|
    requires DualFeasible(A, w, y, z) && Feasible(A, c, x)
    ensures Dot(w, x) <= Dot(y, c) + Sum(z)
  {
    var n := |w|;
    var u := ColVecFrom(A, y, n, 0);
    var s := seq(n, j requires 0 <= j < n => u[j] + z[j]);
    assert NonNeg(x);
    DotMonoFrom(w, s, x, 0);
    DotLinearFrom(1, u, z, s, x, 0);
    SwapFrom(A, y, x, 0);
    YAxBoundFrom(A, y, c, x, 0);
    DotLeSumFrom(z, x, 0);
  }

  // B4: certified quality of an accepted allocation against one feasible alternative.
  lemma Quality(A: seq<seq<int>>, c: seq<int>, w: seq<int>, x: seq<int>, y: seq<int>, z: seq<int>, alpha_bps: nat,
                alt: seq<int>)
    requires Accepts(A, c, w, x, y, z, alpha_bps)
    requires |alt| == |w| && Feasible(A, c, alt)
    ensures (10000 - alpha_bps) * Dot(w, alt) <= 10000 * Dot(w, x)
  {
    WeakDuality(A, c, w, y, z, alt);
    MulMono(10000 - alpha_bps, Dot(w, alt), Dot(y, c) + Sum(z));
  }

  // B4, quantified: against every feasible alternative. With alpha_bps == 0, x is a global optimum.
  lemma QualityAll(A: seq<seq<int>>, c: seq<int>, w: seq<int>, x: seq<int>, y: seq<int>, z: seq<int>, alpha_bps: nat)
    requires Accepts(A, c, w, x, y, z, alpha_bps)
    ensures Feasible(A, c, x)
    ensures forall alt: seq<int> | |alt| == |w| && Feasible(A, c, alt) ::
      (10000 - alpha_bps) * Dot(w, alt) <= 10000 * Dot(w, x)
  {
    forall alt: seq<int> | |alt| == |w| && Feasible(A, c, alt)
      ensures (10000 - alpha_bps) * Dot(w, alt) <= 10000 * Dot(w, x)
    {
      Quality(A, c, w, x, y, z, alpha_bps, alt);
    }
  }
}

// B5: non-vacuity and rejection witnesses on one instance with a real conflict.
// Two slots of capacity 1. Request 0 (value 3) needs both slots. Requests 1 and 2 (value 2 each) need one slot each.
// Optimum: requests 1 and 2, value 4. Dual: y = [2, 2], z = [0, 0, 0], bound 4.
module BookingDualCertWitness {
  import opened BookingDualCert

  const A0: seq<seq<int>> := [[1, 1, 0], [1, 0, 1]]
  const C0: seq<int> := [1, 1]
  const W0: seq<int> := [3, 2, 2]

  lemma OptimumAcceptedWithZeroGap()
    ensures Accepts(A0, C0, W0, [0, 1, 1], [2, 2], [0, 0, 0], 0)
  {
  }

  lemma OverbookingRejected()
    ensures !Accepts(A0, C0, W0, [1, 1, 0], [2, 2], [0, 0, 0], 0)
    ensures !Accepts(A0, C0, W0, [1, 1, 0], [2, 2], [0, 0, 0], 10000)
  {
    assert Dot(A0[0], [1, 1, 0]) == 2;
  }

  lemma InvalidDualRejected()
    ensures !Accepts(A0, C0, W0, [0, 1, 1], [1, 1], [0, 0, 0], 0)
    ensures !Accepts(A0, C0, W0, [0, 1, 1], [2, -1], [0, 0, 1], 0)
  {
    assert ColDotFrom(A0, [1, 1], 0, 0) == 2;
  }

  lemma SuboptimalRejectedAtZeroGapAcceptedAtQuarterGap()
    ensures !Accepts(A0, C0, W0, [1, 0, 0], [2, 2], [0, 0, 0], 0)
    ensures Accepts(A0, C0, W0, [1, 0, 0], [2, 2], [0, 0, 0], 2500)
    ensures !Accepts(A0, C0, W0, [1, 0, 0], [2, 2], [0, 0, 0], 2499)
  {
  }

  lemma FractionalAllocationRejected()
    ensures !Accepts(A0, C0, W0, [0, 2, 0], [2, 2], [0, 0, 0], 0)
  {
  }
}
