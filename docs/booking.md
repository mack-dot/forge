# Booking: checked source behavior

The [approved contract](../spec/booking/BookingSpec.dfy) covers a sequential
matcher for independent slots. A booking gets the lowest free slot in its allowed
set. Cancellation frees exactly its target booking's slot. Accepted retries replay
the original receipt without another state change.

The [approval record](../proposals/booking-decision.md) binds the user's decision
to the exact published proposal. The contract and its separate lock retain their
approved bytes. The existing ledger contract and policy remain unchanged.

| Claim | What the source proof establishes |
| --- | --- |
| B1 | Distinct active bookings occupy distinct slots; the state stays well formed. |
| B2 | A fresh request with an allowed free slot succeeds at the least slot and makes the exact update. |
| B3 | A fresh cancellation of an active booking removes only that booking and frees its slot. |
| B4 | An accepted identical retry returns its historical outcome without changing state. |

The contract also preserves the slot set and rejects invalid requests and ID
conflicts without changing capacity, bookings, or receipts. Rejected IDs are not
reserved. A later retry may succeed after another operation frees a slot.

An old `Booked(slot)` receipt is not a statement that the booking is still active.
For example, after cancellation and slot reuse, an old book retry does not restore
the old booking. An old cancellation retry does not cancel the new booking. The
[checked trace](../tests/booking/SuccessfulExecution.dfy) exercises this sequence
through the real implementation.

## Run the source gate

```sh
python3 gate/booking.py --evidence build/booking-evidence.json
```

The gate checks the approved spec/lock digests, exact dependency closure, pinned
tools, forbidden-assumption audit, and required verification coverage. It runs
Dafny with included-file verification, one worker, and the pinned solver resource
limit. Assertion isolation gives each isolated batch that resource budget. It
does not skip a check. See the [Dafny assertion-batch reference](https://dafny.org/v4.11.0/DafnyRef/DafnyRef#13731-controlling-assertion-batches).

The gate then uses the existing backend-independent schema and evidence-policy
checks. The new [booking policy](../policy/booking.yaml) requires `source_proof`
for B1–B4. This is a separate domain entry point; the existing ledger gate keeps
its own claims and policy. Supplied evidence always needs a fresh checker run:

```sh
python3 gate/booking.py --check-evidence results/stage6/source-evidence.json \
  --evidence build/booking-replayed.json
```

The existing GitHub PR workflow reports ledger C1–C5. Booking uses the explicit
command above; this stage does not claim automatic B1–B4 PR enforcement.

## Reuse and trust

Booking capacity uses a finite integer map with flags 0 or 1. The implementation
calls the existing `Ledger.TotalReplace` lemma when it changes a known slot.
`Ledger.TotalRemove` is that lemma's dependency. The checked map-sum result applies
to this capacity update. It does not establish booking identity or cancellation
rules; the booking proof establishes those separately.

The source gate checks the full closure without a result cache. The benchmark
separately compares a flattened input, shared files with fresh verification, and
native Dafny/Boogie snapshot reuse. Cache hits alone never accept a candidate whose
dependency failed. Cached timing/resource statistics describe earlier work and
must not be charged again as new solver work.

This is a source proof under the recorded trusted-base assumptions. It uses
mathematical integers and finite state. It does not prove concurrent operations,
durable storage, crash recovery, authorization, external side effects, compilation,
or deployment. The caller supplies a well-formed state and must have authority to
cancel the named booking. Receipts do not expire in this model. `end_to_end=false`.
