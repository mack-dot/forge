include "../../impl/Booking.dfy"

module BookingSuccessfulExecution {
  import B = Booking

  function Initial(): B.State {
    B.BookingState(map[10 := 1, 20 := 1], map[], map[])
  }

  function Occupied(): B.State {
    B.BookingState(map[10 := 0, 20 := 1], map[100 := 10],
      map[100 := B.Accepted(B.Book({10, 20}), B.Booked(10))])
  }

  function Freed(): B.State {
    B.BookingState(map[10 := 1, 20 := 1], map[],
      Occupied().accepted[200 := B.Accepted(B.Cancel(100), B.Cancelled)])
  }

  function Reused(): B.State {
    B.BookingState(map[10 := 0, 20 := 1], map[101 := 10],
      Freed().accepted[101 := B.Accepted(B.Book({10}), B.Booked(10))])
  }

  lemma SingleOccupancy(state: B.State, id: int)
    requires state.free == map[10 := 0, 20 := 1]
    requires state.active == map[id := 10]
    ensures forall slot | slot in state.free ::
      (state.free[slot] == 0 <==>
        (exists bid | bid in state.active :: state.active[bid] == slot))
  {
    forall slot | slot in state.free
      ensures state.free[slot] == 0 <==>
        (exists bid | bid in state.active :: state.active[bid] == slot)
    {
      if slot == 10 {
        assert state.active[id] == slot;
      } else {
        assert slot == 20;
        forall bid | bid in state.active
          ensures state.active[bid] != slot
        {
          assert bid == id;
        }
      }
    }
  }

  method {:isolate_assertions} First(state: B.State) returns (next: B.State)
    requires state == Initial()
    ensures next == Occupied()
  {
    assert B.WellFormed(state);
    assert B.AvailableSlots(state, {10, 20}) == {10, 20};
    assert B.IsFreshBook(state, 100, B.Book({10, 20}));
    var outcome;
    next, outcome := B.Apply(state, 100, B.Book({10, 20}));
    assert outcome.Booked?;
    assert outcome.slot in {10, 20};
    assert outcome.slot <= 10;
    assert outcome == B.Booked(10);
  }

  method {:isolate_assertions} Unavailable(state: B.State) returns (next: B.State)
    requires state == Occupied()
    ensures next == Occupied()
  {
    SingleOccupancy(state, 100);
    assert B.WellFormed(state);
    assert B.AvailableSlots(state, {10}) == {};
    assert !B.IsFreshBook(state, 101, B.Book({10}));
    var outcome;
    next, outcome := B.Apply(state, 101, B.Book({10}));
    assert outcome == B.Rejected;
  }

  method {:isolate_assertions} CancelFirst(state: B.State) returns (next: B.State)
    requires state == Occupied()
    ensures next == Freed()
  {
    SingleOccupancy(state, 100);
    assert B.WellFormed(state);
    assert B.IsFreshCancel(state, 200, B.Cancel(100));
    var outcome;
    next, outcome := B.Apply(state, 200, B.Cancel(100));
    assert outcome == B.Cancelled;
  }

  method {:isolate_assertions} BookAgain(state: B.State) returns (next: B.State)
    requires state == Freed()
    ensures next == Reused()
  {
    assert B.WellFormed(state);
    assert B.AvailableSlots(state, {10}) == {10};
    assert B.IsFreshBook(state, 101, B.Book({10}));
    var outcome;
    next, outcome := B.Apply(state, 101, B.Book({10}));
    assert outcome == B.Booked(10);
  }

  method {:isolate_assertions} OldBook(state: B.State) returns (next: B.State)
    requires state == Reused()
    ensures next == state
  {
    SingleOccupancy(state, 101);
    assert B.WellFormed(state);
    assert B.IsRetry(state, 100, B.Book({10, 20}));
    var outcome;
    next, outcome := B.Apply(state, 100, B.Book({10, 20}));
    assert outcome == B.Booked(10);
    assert 100 !in next.active;
  }

  method {:isolate_assertions} OldCancel(state: B.State) returns (next: B.State)
    requires state == Reused()
    ensures next == state
  {
    SingleOccupancy(state, 101);
    assert B.WellFormed(state);
    assert B.IsRetry(state, 200, B.Cancel(100));
    var outcome;
    next, outcome := B.Apply(state, 200, B.Cancel(100));
    assert outcome == B.Cancelled;
    assert next.active[101] == 10;
  }

  method {:isolate_assertions} NewCancel(state: B.State) returns (next: B.State)
    requires state == Reused()
    ensures next == state
  {
    SingleOccupancy(state, 101);
    assert B.WellFormed(state);
    assert !B.IsFreshCancel(state, 201, B.Cancel(100));
    var outcome;
    next, outcome := B.Apply(state, 201, B.Cancel(100));
    assert outcome == B.Rejected;
  }

  method {:isolate_assertions} Conflict(state: B.State) returns (next: B.State)
    requires state == Reused()
    ensures next == state
  {
    SingleOccupancy(state, 101);
    assert B.WellFormed(state);
    assert !B.IsRetry(state, 100, B.Book({20}));
    assert !B.IsFreshBook(state, 100, B.Book({20}));
    var outcome;
    next, outcome := B.Apply(state, 100, B.Book({20}));
    assert outcome == B.Rejected;
  }

  method Scenario() {
    var a := First(Initial());
    var b := Unavailable(a);
    var c := CancelFirst(b);
    var d := BookAgain(c);
    var e := OldBook(d);
    var f := OldCancel(e);
    var g := NewCancel(f);
    var h := Conflict(g);
    assert h == Reused();
    assert h.active == map[101 := 10];
    assert h.free == map[10 := 0, 20 := 1];
    assert h.accepted.Keys == {100, 101, 200};
  }
}
