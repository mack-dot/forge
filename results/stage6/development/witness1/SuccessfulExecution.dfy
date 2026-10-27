include "../../impl/Booking.dfy"

module BookingSuccessfulExecution {
  import B = Booking

  method {:isolate_assertions} Scenario() {
    var initial := B.BookingState(map[10 := 1, 20 := 1], map[], map[]);
    assert B.WellFormed(initial);
    var booked, first := B.Apply(initial, 100, B.Book({10, 20}));
    assert first == B.Booked(10);
    assert booked.active == map[100 := 10];
    var unavailable, rejected := B.Apply(booked, 101, B.Book({10}));
    assert rejected == B.Rejected && unavailable == booked;
    var cancelled, cancellation := B.Apply(unavailable, 200, B.Cancel(100));
    assert cancellation == B.Cancelled;
    assert cancelled.active == map[] && cancelled.free[10] == 1;
    var reused, second := B.Apply(cancelled, 101, B.Book({10}));
    assert second == B.Booked(10);
    assert reused.active == map[101 := 10];
    var oldBook, oldBookResult := B.Apply(reused, 100, B.Book({10, 20}));
    assert oldBookResult == B.Booked(10) && oldBook == reused;
    assert 100 !in oldBook.active;
    var oldCancel, oldCancelResult := B.Apply(oldBook, 200, B.Cancel(100));
    assert oldCancelResult == B.Cancelled && oldCancel == reused;
    assert oldCancel.active[101] == 10;
    var newCancel, newCancelResult := B.Apply(oldCancel, 201, B.Cancel(100));
    assert newCancelResult == B.Rejected && newCancel == reused;
    var conflict, conflictResult := B.Apply(newCancel, 100, B.Book({20}));
    assert conflictResult == B.Rejected && conflict == reused;
    assert conflict.free == map[10 := 0, 20 := 1];
    assert conflict.active == map[101 := 10];
    assert conflict.accepted.Keys == {100, 101, 200};
  }
}
