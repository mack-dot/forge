// Forge 2.0 master idea, Pillar I (U410). NOT part of the gate. NOT a protected file.
// The postcondition of the approved BookingSpec.Apply as a predicate, and the two-run determinism lemma.
// ApplyThenPost is checked against the approved method specification.
include "../../spec/booking/BookingSpec.dfy"

abstract module BookingDeterminism {
  import B : BookingSpec

  ghost predicate Post(state: B.State, id: int, request: B.Request, next: B.State, outcome: B.Outcome)
    requires B.WellFormed(state)
  {
    B.WellFormed(next) &&
    next.free.Keys == state.free.Keys &&
    B.NoDoubleBooking(next.active) &&
    (B.IsFreshBook(state, id, request) ==>
      outcome.Booked? &&
      outcome.slot in B.AvailableSlots(state, request.allowed) &&
      (forall other | other in B.AvailableSlots(state, request.allowed) ::
        outcome.slot <= other) &&
      next.free == state.free[outcome.slot := 0] &&
      next.active == state.active[id := outcome.slot] &&
      next.accepted == state.accepted[id := B.Accepted(request, outcome)] &&
      B.Accounting.Total(next.free) == B.Accounting.Total(state.free) - 1) &&
    (B.IsFreshCancel(state, id, request) ==>
      outcome == B.Cancelled &&
      next.free == state.free[state.active[request.booking_id] := 1] &&
      next.active == state.active - {request.booking_id} &&
      next.accepted == state.accepted[id := B.Accepted(request, B.Cancelled)] &&
      B.Accounting.Total(next.free) == B.Accounting.Total(state.free) + 1) &&
    (B.IsRetry(state, id, request) ==>
      outcome == state.accepted[id].outcome && next == state) &&
    ((!B.IsRetry(state, id, request) &&
      !B.IsFreshBook(state, id, request) &&
      !B.IsFreshCancel(state, id, request)) ==>
      outcome == B.Rejected && next == state)
  }

  method ApplyThenPost(state: B.State, id: int, request: B.Request)
      returns (next: B.State, outcome: B.Outcome)
    requires B.WellFormed(state)
    ensures Post(state, id, request, next, outcome)
  {
    next, outcome := B.Apply(state, id, request);
  }

  lemma SpecIsDeterministic(state: B.State, id: int, request: B.Request,
                            n1: B.State, o1: B.Outcome, n2: B.State, o2: B.Outcome)
    requires B.WellFormed(state)
    requires Post(state, id, request, n1, o1)
    requires Post(state, id, request, n2, o2)
    ensures n1 == n2 && o1 == o2
  {
  }
}
