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
    next := state;
    outcome := Rejected;
  }
}
