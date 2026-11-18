// Slice 3: a bridge from the batch model of the certificate checker to ONE predicate of the APPROVED
// booking specification: NoDoubleBooking (spec/booking/BookingSpec.dfy, used here through its verified
// implementation module impl/Booking.dfy).
// Scope: batches in which every request needs exactly one slot and every slot has the capacity 1.
// For such a batch, an allocation that the certificate check accepts gives no slot to two requests.
// This is NOT a claim that the batch model is the approved booking contract: the approved contract
// books one request at a time at the least free slot of its allowed set. NOT gate evidence.
// How little this is (review): every slot must have the capacity exactly 1, so the lemma does not
// cover a second batch on a board that is partly used. It needs only feasibility; prices, values and
// the gap play no part. It says nothing about Decide, a token, the sink, or bookings that were made
// before the batch. ActiveOf is a map that this file defines.
include "../proposals/forge2-pillar3-dual-certificate/BookingDualCert.dfy"
include "../impl/Booking.dfy"

module BookingBridge {
  import C = BookingDualCert
  import B = Booking

  // Request j needs the one slot slotOf[j]. Row i of A is slot i, with the capacity 1.
  predicate OneSlotBatch(A: seq<seq<int>>, c: seq<int>, slotOf: seq<int>)
  {
    C.Shape(A, c, |slotOf|) &&
    (forall i | 0 <= i < |c| :: c[i] == 1) &&
    (forall j | 0 <= j < |slotOf| :: 0 <= slotOf[j] < |A|) &&
    (forall i, j | 0 <= i < |A| && 0 <= j < |slotOf| :: A[i][j] == (if slotOf[j] == i then 1 else 0))
  }

  // The active bookings that the allocation x makes: booking id j holds the slot slotOf[j].
  function ActiveOf(slotOf: seq<int>, x: seq<int>): map<int, int>
    requires |x| == |slotOf|
  {
    map j | 0 <= j < |x| && x[j] == 1 :: slotOf[j]
  }

  lemma DotFromNonNeg(a: seq<int>, x: seq<int>, k: nat)
    requires |a| == |x| && k <= |a|
    requires forall t | 0 <= t < |a| :: 0 <= a[t] && 0 <= x[t]
    ensures 0 <= C.DotFrom(a, x, k)
    decreases |a| - k
  {
    if k < |a| {
      DotFromNonNeg(a, x, k + 1);
      assert 0 <= a[k] * x[k];
    }
  }

  // The sum from k is at least the term at j plus the sum after j.
  lemma DotFromLower(a: seq<int>, x: seq<int>, k: nat, j: nat)
    requires |a| == |x| && k <= j < |a|
    requires forall t | 0 <= t < |a| :: 0 <= a[t] && 0 <= x[t]
    ensures a[j] * x[j] + C.DotFrom(a, x, j + 1) <= C.DotFrom(a, x, k)
    decreases j - k
  {
    if k < j {
      DotFromLower(a, x, k + 1, j);
      assert 0 <= a[k] * x[k];
    }
  }

  // Two chosen requests in one row with the entry 1 use at least 2 units of that row.
  lemma TwoChosen(a: seq<int>, x: seq<int>, first: nat, second: nat)
    requires |a| == |x| && first < second < |a|
    requires forall t | 0 <= t < |a| :: 0 <= a[t] && 0 <= x[t]
    requires a[first] == 1 && x[first] == 1 && a[second] == 1 && x[second] == 1
    ensures 2 <= C.Dot(a, x)
  {
    DotFromLower(a, x, 0, first);
    DotFromLower(a, x, first + 1, second);
    DotFromNonNeg(a, x, second + 1);
  }

  lemma FeasibleHasNoDoubleBooking(A: seq<seq<int>>, c: seq<int>, slotOf: seq<int>, x: seq<int>)
    requires OneSlotBatch(A, c, slotOf) && |x| == |slotOf| && C.Feasible(A, c, x)
    ensures B.NoDoubleBooking(ActiveOf(slotOf, x))
  {
    var active := ActiveOf(slotOf, x);
    forall first, second | first in active && second in active && first != second
      ensures active[first] != active[second]
    {
      if slotOf[first] == slotOf[second] {
        assert 0 <= first < |x| && x[first] == 1 && 0 <= second < |x| && x[second] == 1;
        var i := slotOf[first];
        assert 0 <= i < |A| && |A[i]| == |x|;
        forall t | 0 <= t < |x|
          ensures 0 <= A[i][t] && 0 <= x[t]
        {
          assert A[i][t] == (if slotOf[t] == i then 1 else 0);
          assert x[t] == 0 || x[t] == 1;
        }
        assert A[i][first] == 1 && A[i][second] == 1;
        if first < second {
          TwoChosen(A[i], x, first, second);
        } else {
          TwoChosen(A[i], x, second, first);
        }
        assert C.Dot(A[i], x) <= c[i];
        assert false;
      }
    }
  }

  // The bridge. For a one-slot batch, an allocation that the certificate check accepts gives an
  // `active` map that satisfies the approved NoDoubleBooking predicate.
  lemma AcceptedHasNoDoubleBooking(A: seq<seq<int>>, c: seq<int>, w: seq<int>, x: seq<int>, y: seq<int>,
                                   z: seq<int>, alphaBps: nat, slotOf: seq<int>)
    requires |w| == |slotOf| && OneSlotBatch(A, c, slotOf)
    requires C.Accepts(A, c, w, x, y, z, alphaBps)
    ensures |x| == |slotOf| && B.NoDoubleBooking(ActiveOf(slotOf, x))
  {
    FeasibleHasNoDoubleBooking(A, c, slotOf, x);
  }

  // Not vacuous: two requests for slot 0 and one for slot 1. Booking the requests 0 and 2 is feasible;
  // booking the requests 0 and 1 is not.
  lemma BridgeWitness()
    ensures OneSlotBatch([[1, 1, 0], [0, 0, 1]], [1, 1], [0, 0, 1])
    ensures C.Feasible([[1, 1, 0], [0, 0, 1]], [1, 1], [1, 0, 1])
    ensures ActiveOf([0, 0, 1], [1, 0, 1]) == map[0 := 0, 2 := 1]
    ensures !C.Feasible([[1, 1, 0], [0, 0, 1]], [1, 1], [1, 1, 0])
  {
    var A: seq<seq<int>> := [[1, 1, 0], [0, 0, 1]];
    assert A[0] == [1, 1, 0] && A[1] == [0, 0, 1];
    assert C.Dot([1, 1, 0], [1, 0, 1]) == 1 && C.Dot([0, 0, 1], [1, 0, 1]) == 1;
    assert C.Dot([1, 1, 0], [1, 1, 0]) == 2;
    assert C.Dot(A[0], [1, 1, 0]) == 2;
  }
}
