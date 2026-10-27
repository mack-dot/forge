include "../../spec/LedgerSpec.dfy"

abstract module BookingSpec {
  import Accounting : LedgerSpec

  datatype Request = Book(allowed: set<int>) | Cancel(booking_id: int)
  datatype Outcome = Booked(slot: int) | Cancelled | Rejected
  datatype Receipt = Accepted(request: Request, outcome: Outcome)
  datatype State = BookingState(
    free: map<int, int>,
    active: map<int, int>,
    accepted: map<int, Receipt>)

  ghost predicate NoDoubleBooking(active: map<int, int>) {
    forall first, second | first in active && second in active && first != second ::
      active[first] != active[second]
  }

  ghost predicate WellFormed(state: State) {
    (forall slot | slot in state.free ::
      (state.free[slot] == 0 || state.free[slot] == 1)) &&
    (forall id | id in state.active ::
      state.active[id] in state.free &&
      id in state.accepted &&
      state.accepted[id].request.Book? &&
      state.accepted[id].outcome == Booked(state.active[id])) &&
    NoDoubleBooking(state.active) &&
    (forall slot | slot in state.free ::
      (state.free[slot] == 0 <==>
        (exists id | id in state.active :: state.active[id] == slot))) &&
    (forall id | id in state.accepted ::
      if state.accepted[id].request.Book? then
        state.accepted[id].outcome.Booked? &&
        state.accepted[id].outcome.slot in state.free &&
        state.accepted[id].outcome.slot in state.accepted[id].request.allowed
      else
        state.accepted[id].outcome == Cancelled &&
        state.accepted[id].request.booking_id in state.accepted &&
        state.accepted[state.accepted[id].request.booking_id].request.Book? &&
        state.accepted[id].request.booking_id !in state.active)
  }

  function AvailableSlots(state: State, allowed: set<int>): set<int> {
    set slot | slot in allowed && slot in state.free && state.free[slot] == 1
  }

  predicate IsRetry(state: State, id: int, request: Request) {
    id in state.accepted && state.accepted[id].request == request
  }

  predicate IsFreshBook(state: State, id: int, request: Request) {
    id !in state.accepted && request.Book? &&
    AvailableSlots(state, request.allowed) != {}
  }

  predicate IsFreshCancel(state: State, id: int, request: Request) {
    id !in state.accepted && request.Cancel? && request.booking_id in state.active
  }

  method Apply(state: State, id: int, request: Request)
      returns (next: State, outcome: Outcome)
    requires WellFormed(state)
    ensures WellFormed(next)
    ensures next.free.Keys == state.free.Keys
    // B1: no two active bookings occupy the same slot.
    ensures NoDoubleBooking(next.active)
    // B2: a fresh book with an available allowed slot succeeds at the least slot.
    ensures IsFreshBook(state, id, request) ==>
      outcome.Booked? &&
      outcome.slot in AvailableSlots(state, request.allowed) &&
      (forall other | other in AvailableSlots(state, request.allowed) ::
        outcome.slot <= other) &&
      next.free == state.free[outcome.slot := 0] &&
      next.active == state.active[id := outcome.slot] &&
      next.accepted == state.accepted[id := Accepted(request, outcome)] &&
      Accounting.Total(next.free) == Accounting.Total(state.free) - 1
    // B3: a fresh cancellation removes exactly its booking and frees its slot.
    ensures IsFreshCancel(state, id, request) ==>
      outcome == Cancelled &&
      next.free == state.free[state.active[request.booking_id] := 1] &&
      next.active == state.active - {request.booking_id} &&
      next.accepted == state.accepted[id := Accepted(request, Cancelled)] &&
      Accounting.Total(next.free) == Accounting.Total(state.free) + 1
    // B4: successful retries replay the stored outcome without changing state.
    ensures IsRetry(state, id, request) ==>
      outcome == state.accepted[id].outcome && next == state
    // Supporting rejection rule: invalid requests and ID conflicts have no effect.
    ensures (!IsRetry(state, id, request) &&
             !IsFreshBook(state, id, request) &&
             !IsFreshCancel(state, id, request)) ==>
      outcome == Rejected && next == state
}
