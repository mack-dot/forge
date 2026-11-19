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
    var picked :| picked in values;
    value := picked;
    var rest := values - {picked};
    if rest != {} {
      var other := Least(rest);
      if other < value {
        value := other;
      }
    }
    forall other | other in values
      ensures value <= other
    {
      if other != picked {
        assert other in rest;
      }
    }
  }

  method {:isolate_assertions} Apply ... {
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
      forall s | s in next.free
        ensures next.free[s] == 0 <==>
          (exists bid | bid in next.active :: next.active[bid] == s)
      {
        if s == slot {
          assert next.active[id] == s;
        } else {
          if next.free[s] == 0 {
            var bid :| bid in state.active && state.active[bid] == s;
            assert bid in next.active && next.active[bid] == s;
          }
          if exists bid | bid in next.active :: next.active[bid] == s {
            var bid :| bid in next.active && next.active[bid] == s;
            assert bid != id;
            assert state.active[bid] == s;
          }
        }
      }
    } else if IsFreshCancel(state, id, request) {
      var slot := state.active[request.booking_id];
      Accounting.TotalReplace(state.free, slot, 1);
      outcome := Cancelled;
      next := BookingState(
        state.free[slot := 1],
        state.active - {request.booking_id},
        state.accepted[id := Accepted(request, outcome)]);
      forall s | s in next.free
        ensures next.free[s] == 0 <==>
          (exists bid | bid in next.active :: next.active[bid] == s)
      {
        if next.free[s] == 0 {
          assert s != slot;
          var bid :| bid in state.active && state.active[bid] == s;
          assert bid != request.booking_id;
          assert bid in next.active && next.active[bid] == s;
        }
        if exists bid | bid in next.active :: next.active[bid] == s {
          var bid :| bid in next.active && next.active[bid] == s;
          assert bid in state.active && bid != request.booking_id;
          assert s != slot;
          assert state.free[s] == 0;
        }
      }
    } else {
      next := state;
      outcome := Rejected;
    }
  }
}
