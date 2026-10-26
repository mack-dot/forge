# Booking matcher: Stage 6 intent proposal

Status: **PENDING HUMAN APPROVAL**. This is a proposal, not an approved contract.
No booking implementation, proof, benchmark, or Stage 6 EXIT has run.

## Decision requested

Approve the exact two additions below: `spec/booking/BookingSpec.dfy` and
`spec/booking/spec.lock`. The candidate files are stored under
[booking/](booking/). Their bytes will be copied without alteration after approval.
The existing ledger spec, root lock, policy, and gate remain the current baseline.
A separate decision record will bind approval to this proposal's public revision.
The proposed lock binds identity; it does not itself grant approval.

The roadmap requires four booking claims, but does not define slot selection,
cancellation identity, or retries after cancellation. Those choices affect intent.
This proposal makes them explicit before implementation. The hard rule in
[ROADMAP.md](../ROADMAP.md#hard-rules) requires an exact spec diff and human approval.

## Proposed behavior

A slot is one indivisible unit of capacity. Slot IDs and request IDs are mathematical
integers. Different slot IDs are independent. An allowed set describes slots that
can satisfy one booking request. The model does not derive these sets from dates,
interval overlap, rooms, staff schedules, or user preferences.

| Topic | Required behavior |
| --- | --- |
| State | A fixed finite map of slot IDs to free-capacity flags; active bookings map booking IDs to slots; accepted receipts map operation IDs to full requests and outcomes. |
| Capacity | Each flag is 0 or 1. A slot has flag 0 exactly when an active booking occupies it. Distinct active bookings must occupy distinct slots. |
| Initial state | All configured slots are free; active bookings and accepted receipts are empty. The caller must supply a well-formed state. |
| Book request | `Book(allowed)` asks for one slot in a finite allowed set. The successful operation ID becomes its booking ID. |
| Matching | For a fresh ID, select the lowest integer slot ID that is both allowed and currently free. Unknown allowed IDs are ignored. An empty set or no matching free slot is rejected. |
| Exact booking effect | Set that slot's flag to 0, add exactly one active booking under the operation ID, and store the request and `Booked(slot)` receipt. Preserve all other state. |
| Cancel request | `Cancel(booking_id)` with a fresh operation ID succeeds only when that booking is active. |
| Exact cancellation effect | Free exactly the target slot, remove exactly the target active booking, and store `Cancelled` under the cancellation operation ID. Retain the original booking receipt and all other state. |
| Successful retry | The same operation ID and identical full request return the stored outcome and leave all state unchanged. Book and cancel use one ID namespace. |
| Conflicting ID | An accepted operation ID with any different request is rejected without a state change. Changing a book's allowed set is a different request. |
| Failed operation | Return `Rejected`; do not change capacity, active bookings, or receipts. Failed operation IDs are not reserved. A later retry can succeed after state changes. |
| Repeated cancellation | An identical retry with its accepted cancellation ID replays `Cancelled`. A fresh cancellation ID for an inactive booking is rejected. |
| Termination | `Apply` must terminate for all well-formed states and finite requests. No termination opt-out is allowed. |

**A retry reports the original operation result. It does not report current occupancy.**
After cancellation, retrying the original book returns its historical `Booked(slot)`
receipt without recreating the booking. After another request reuses that slot,
retrying the old cancellation leaves the new booking intact. A consumer must read
current active state to determine whether a booking is still active.

All specified updates concern these three state maps. Output streams, external
messages, database writes, payments, and other side effects are outside this model.

## Claim mapping and legitimate reuse

- B1: no two active bookings occupy the same slot; preserve well-formed state.
- B2: a fresh book succeeds whenever an allowed free slot exists. Select the least
  slot and apply the exact update. The sum of free-capacity flags decreases by one.
- B3: a fresh cancellation of an active booking frees exactly its slot. The sum of
  free-capacity flags increases by one.
- B4: every accepted identical retry returns its original outcome with no state change.
- Supporting clauses: preserve slot keys and reject invalid requests and conflicts
  without changing any of the three maps.

The proposed spec imports the approved `LedgerSpec` through an abstract module
import for its existing `Total(map<int,int>)` definition. The concrete booking
refinement can bind that import to the existing checked `Ledger` module. Its
`TotalReplace` lemma applies when the updated key already exists; `TotalRemove`
is the lemma's dependency. Both booking and cancellation satisfy the key premise
when their validity checks pass. Reuse must be checked by Dafny with the complete
dependency closure. No claim of successful reuse is made at proposal time.

Dafny supports abstract imports and checks their concrete refinements. See the
[pinned Dafny 4.11.0 module-abstraction reference](https://dafny.org/v4.11.0/DafnyRef/DafnyRef#46-module-abstraction).
The existing lemmas remain unchanged. They concern integer-map sums, not booking
identity, matching, or cancellation. New proofs must establish those properties.
Source sharing alone supplies no cached proof result and no measured speedup.

## Illustrative trace — requirements, not executed tests

Start with slots 10 and 20 free and both other maps empty.

| Operation | Required outcome and effect |
| --- | --- |
| ID 100: `Book({10,20})` | `Booked(10)`; only booking 100 occupies slot 10. |
| ID 101: `Book({10})` | `Rejected`; no state change. ID 101 remains available. |
| ID 200: `Cancel(100)` | `Cancelled`; slot 10 becomes free and booking 100 becomes inactive. |
| ID 101: retry `Book({10})` | `Booked(10)`; booking 101 now occupies slot 10. |
| ID 100: retry `Book({10,20})` | Historical `Booked(10)`; state stays unchanged; booking 100 remains inactive. |
| ID 200: retry `Cancel(100)` | Historical `Cancelled`; state stays unchanged; booking 101 remains active. |
| ID 201: `Cancel(100)` | `Rejected`; target booking 100 is inactive. |
| ID 100: `Book({20})` | `Rejected`; ID 100 already records a different request. |

## Scope and assumptions

This is a sequential source-level state transition. The caller supplies a
well-formed state. The contract does not prove the history of externally supplied
state, durable storage, crash recovery, concurrency, locking, network delivery,
authentication, authorization, or external exactly-once execution. In particular,
the cancellation API trusts the caller's authority to name a booking ID.

Receipts grow without bound in the mathematical model. Expiring receipts or
reusing accepted IDs would change the retry guarantee and need a new proposal.
A finite implementation needs a separately stated resource policy. No machine
integer overflow, compiler, binary, container, or deployment proof is claimed.
The formal slot model must also match the application's real allocation units.
`end_to_end=false` remains mandatory.

## Stage 6 measurement protocol

Implement the benchmark only after intent approval. Freeze all source variants
and hashes before collecting comparative results. Use the pinned local Dafny,
Z3, Python, solver resource limit, single worker, and disabled verification time
limit. Record CPU, memory, OS, tool hashes, actual commands, process exit codes,
resource counts, complete obligations, cache state, and wall-clock verifier time.
Timing records are operational measurements, outside canonical proof evidence.

Compare these three conditions on the same booking behavior and revision cases:

| Condition | Source arrangement and verification |
| --- | --- |
| Cold | Materialize the same approved declarations and proof bodies in one self-contained input; run each baseline and candidate with a fresh verifier and empty proof cache. Record any required layout-only transformation. |
| Shared files | Use the checked ledger module as a shared source dependency. Verify the complete closure for each baseline and candidate with a fresh verifier and empty proof cache. No unchecked dependency is omitted. |
| Dependency graph | Use the same shared-file sources and the pinned Dafny/Boogie native snapshot cache. Fully verify the baseline in the same process before candidate reuse. Charge that baseline cost. Forge does not compute a custom proof dependency graph. |

The conditions share contracts, implementation behavior, solver settings, and
case order within a paired run. Physical source layout differs between cold and
shared-file conditions; publish that difference and compare full obligation sets.
If the flattened condition cannot preserve this scope, report the problem before
changing the experiment. Do not treat source layout as proof reuse.

Use five repetitions per condition. Rotate condition order across repetitions.
Include unchanged input, an equivalent booking-body edit, an equivalent helper-body
edit, and negative controls for a broken shared helper and reject-all booking.
Freeze exact mutations after a correct implementation exists. All conditions must
agree with fresh full verification on each candidate. A crash, syntax error,
resource exhaustion, or missing obligation is an error, not a killed bug or a
successful speedup. Retain every failed run and every attempt. Stop a failing
proof after five attempts. State sample counts and denominators in the report.

Count shared preparation separately from each measured condition. Include module
construction, failed proofs, fixture setup, audits, warm-up, and reporting. Record
all authoring prompts, responses, available provider token categories, and human
interventions with provenance. The available goal counter at Stage 6 entry was
778672 tokens for the whole goal; that is a cumulative boundary, not a Stage 6
cost or a per-condition measurement. Token categories or transcripts that cannot
be recovered are unknown, never zero. Do not invent an allocation of common
preparation costs across conditions. Do not claim complete token accounting until
its coverage is checked. A verifier-only replay has no model-generation calls;
that does not make the original authoring cost zero or measure LLM productivity.

Keep fixed-output proof evidence separate from fresh timing runs. The report
checker must recompute totals from actual recorded runs. A fresh experiment can
produce different times and cache counts. It must report its own measurements.
No extrapolation to other programs, model quality, developer productivity, or
whole-project cost is permitted. Missing required accounting remains an explicit
Stage 6 completion blocker; this proposal does not waive the roadmap's requirements.

## Validation already run

Command: `.toolchain/dafny-4.11.0/dafny/dafny resolve proposals/booking/BookingSpec.dfy`

| Attempt | Real exit code | Result |
| --- | --- | --- |
| 1 | 0 | Syntax and type check passed. Dafny explicitly reported that verification was not attempted. |

The actual output and bound candidate digest are in
[resolve-attempt1.json](../results/stage6/proposal/resolve-attempt1.json) and its
[raw log](../results/stage6/proposal/resolve-attempt1.log). This is not a Stage 6 EXIT.
The abstract method declaration is a proposed contract, not an accepted bodiless
implementation or a checked proof.

## Exact proposed additions

- `spec/booking/BookingSpec.dfy`: SHA-256 `6d10e909fc685eb28fc1d582dcb37b61294bf5ac2466236b06447a82a60d2319`.
- `spec/booking/spec.lock`: SHA-256 `c6ff76b98ef844d08e4255938414477d21c2be2dcb7e83ae7d8165c05061b88e`.

```diff
--- /dev/null
+++ b/spec/booking/BookingSpec.dfy
@@ -0,0 +1,92 @@
+include "../../spec/LedgerSpec.dfy"
+
+abstract module BookingSpec {
+  import Accounting : LedgerSpec
+
+  datatype Request = Book(allowed: set<int>) | Cancel(booking_id: int)
+  datatype Outcome = Booked(slot: int) | Cancelled | Rejected
+  datatype Receipt = Accepted(request: Request, outcome: Outcome)
+  datatype State = BookingState(
+    free: map<int, int>,
+    active: map<int, int>,
+    accepted: map<int, Receipt>)
+
+  ghost predicate NoDoubleBooking(active: map<int, int>) {
+    forall first, second | first in active && second in active && first != second ::
+      active[first] != active[second]
+  }
+
+  ghost predicate WellFormed(state: State) {
+    (forall slot | slot in state.free ::
+      (state.free[slot] == 0 || state.free[slot] == 1)) &&
+    (forall id | id in state.active ::
+      state.active[id] in state.free &&
+      id in state.accepted &&
+      state.accepted[id].request.Book? &&
+      state.accepted[id].outcome == Booked(state.active[id])) &&
+    NoDoubleBooking(state.active) &&
+    (forall slot | slot in state.free ::
+      (state.free[slot] == 0 <==>
+        (exists id | id in state.active :: state.active[id] == slot))) &&
+    (forall id | id in state.accepted ::
+      if state.accepted[id].request.Book? then
+        state.accepted[id].outcome.Booked? &&
+        state.accepted[id].outcome.slot in state.free &&
+        state.accepted[id].outcome.slot in state.accepted[id].request.allowed
+      else
+        state.accepted[id].outcome == Cancelled &&
+        state.accepted[id].request.booking_id in state.accepted &&
+        state.accepted[state.accepted[id].request.booking_id].request.Book? &&
+        state.accepted[id].request.booking_id !in state.active)
+  }
+
+  function AvailableSlots(state: State, allowed: set<int>): set<int> {
+    set slot | slot in allowed && slot in state.free && state.free[slot] == 1
+  }
+
+  predicate IsRetry(state: State, id: int, request: Request) {
+    id in state.accepted && state.accepted[id].request == request
+  }
+
+  predicate IsFreshBook(state: State, id: int, request: Request) {
+    id !in state.accepted && request.Book? &&
+    AvailableSlots(state, request.allowed) != {}
+  }
+
+  predicate IsFreshCancel(state: State, id: int, request: Request) {
+    id !in state.accepted && request.Cancel? && request.booking_id in state.active
+  }
+
+  method Apply(state: State, id: int, request: Request)
+      returns (next: State, outcome: Outcome)
+    requires WellFormed(state)
+    ensures WellFormed(next)
+    ensures next.free.Keys == state.free.Keys
+    // B1: no two active bookings occupy the same slot.
+    ensures NoDoubleBooking(next.active)
+    // B2: a fresh book with an available allowed slot succeeds at the least slot.
+    ensures IsFreshBook(state, id, request) ==>
+      outcome.Booked? &&
+      outcome.slot in AvailableSlots(state, request.allowed) &&
+      (forall other | other in AvailableSlots(state, request.allowed) ::
+        outcome.slot <= other) &&
+      next.free == state.free[outcome.slot := 0] &&
+      next.active == state.active[id := outcome.slot] &&
+      next.accepted == state.accepted[id := Accepted(request, outcome)] &&
+      Accounting.Total(next.free) == Accounting.Total(state.free) - 1
+    // B3: a fresh cancellation removes exactly its booking and frees its slot.
+    ensures IsFreshCancel(state, id, request) ==>
+      outcome == Cancelled &&
+      next.free == state.free[state.active[request.booking_id] := 1] &&
+      next.active == state.active - {request.booking_id} &&
+      next.accepted == state.accepted[id := Accepted(request, Cancelled)] &&
+      Accounting.Total(next.free) == Accounting.Total(state.free) + 1
+    // B4: successful retries replay the stored outcome without changing state.
+    ensures IsRetry(state, id, request) ==>
+      outcome == state.accepted[id].outcome && next == state
+    // Supporting rejection rule: invalid requests and ID conflicts have no effect.
+    ensures (!IsRetry(state, id, request) &&
+             !IsFreshBook(state, id, request) &&
+             !IsFreshCancel(state, id, request)) ==>
+      outcome == Rejected && next == state
+}

--- /dev/null
+++ b/spec/booking/spec.lock
@@ -0,0 +1,13 @@
+{
+  "dafny_build": "4.11.0+fcb2042d6d043a2634f0854338c08feeaaaf4ae2",
+  "dafny_version": "4.11.0",
+  "dependencies": {
+    "spec.lock": "32cf117f5bcaec2fb0c072650ceb9b535576ab409579a56c00979ed151b03b69",
+    "spec/LedgerSpec.dfy": "2ad0742dcbf81bf24f9235ed88f9728c7b078dfa6ed55632a90b6aa847b35940"
+  },
+  "domain": "booking",
+  "intent_proposal": "proposals/booking.md",
+  "schema_version": 1,
+  "spec_file": "spec/booking/BookingSpec.dfy",
+  "spec_sha256": "6d10e909fc685eb28fc1d582dcb37b61294bf5ac2466236b06447a82a60d2319"
+}
```

## After approval

Copy the exact candidate bytes to their proposed protected paths. Record the
user decision against the frozen public proposal revision. Build the concrete
refinement and booking evidence path with existing established tools. Check
B1–B4, successful execution, invalid requests, retry/cancellation interleavings,
and dependency failure controls. Preserve the ledger checks and run both Stage 6
EXIT commands. Any changed intent needs a new proposal and approval.

Approval is an intent decision. It is not a source proof, benchmark result,
license selection, or approval of later roadmap stages.
