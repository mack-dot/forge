include "../spec/booking/BookingSpec.dfy"
include "Ledger.dfy"

module Booking refines BookingSpec {
  import Accounting = Ledger

  method Least(values: set<int>) returns (value: int)
    requires values != {}
    ensures value in values
    ensures forall other | other in values :: value <= other
    decreases |values|
  {
    value :| value in values;
    if values - {value} != {} {
      var other := Least(values - {value});
      if other < value {
        value := other;
      }
    }
  }

  method Apply ... {
    if IsRetry(state, id, request) {
      next := state;
      outcome := state.accepted[id].outcome;
    } else if IsFreshBook(state, id, request) {
      var slot := Least(AvailableSlots(state, request.allowed));
      Accounting.TotalReplace(state.free, slot, 0);
      outcome := Booked(slot);
      next := BookingState(
        state.free[slot := 0],
        state.active[id := slot],
        state.accepted[id := Accepted(request, outcome)]);
    } else if IsFreshCancel(state, id, request) {
      var slot := state.active[request.booking_id];
      Accounting.TotalReplace(state.free, slot, 1);
      outcome := Cancelled;
      next := BookingState(
        state.free[slot := 1],
        state.active - {request.booking_id},
        state.accepted[id := Accepted(request, outcome)]);
    } else {
      next := state;
      outcome := Rejected;
    }
  }
}
