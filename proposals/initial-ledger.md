# Initial ledger contract: intent approval

Status: approved as written by the user and applied. Stage 1 checks are complete.

Approval: the user explicitly said “approve as written” for candidate SHA-256
`e9bdfd511d3cffb04c533dcc62252cabf84a825d5577ea5999d18bc25e0bda0f`.
The exact candidate bytes are now in `spec/LedgerSpec.dfy`; `spec.lock` records
that digest and the pinned Dafny version. The contract and proposed diff below
are preserved as the approval record. Approval itself makes no proof claim.
Subsequent implementation results are in [../results/stage1.json](../results/stage1.json)
and [../evidence.json](../evidence.json). The approved spec bytes are unchanged.

This proposal establishes the first protected ledger specification. Approval
authorized initial creation of the spec and lock. The exact approved addition
appears below. The user approved behavior and scope. No implementation existed
when this proposal was submitted.

## Reason for this proposal

The mission defines C1–C5, but several input and retry rules remain open in
`../unsure.md` U001. These choices affect which transfers must succeed and what
“no effect” means. Freeze them before an agent repairs code against the spec.

A success outcome also needs exact movement requirements. Returning `Ok` without
the requested debit and credit must fail C4. The draft makes those amounts,
accounts, and the accepted-request record explicit.

## Proposed behavior

| Topic | Contract |
| --- | --- |
| State | A finite map of account IDs to integer balances, plus a finite map of accepted request IDs to complete transfer payloads. |
| Amounts | Positive integers in the application's smallest accounting unit. Zero and negative amounts are rejected. |
| Account IDs | Integer keys. Both accounts must already exist and must differ. Self-transfers are rejected. |
| Initial balances | Non-negative. No fixed machine-integer maximum is imposed by this source model. |
| Fresh valid transfer | A new request ID, valid accounts, positive amount, and amount less than or equal to the sender's balance. |
| Successful effect | Subtract exactly the amount from the sender; add it to the recipient; retain every other balance and account; store the ID and complete payload. No fee. |
| Accepted retry | The same ID and identical sender, recipient, and amount return `Ok` and leave the entire state unchanged, even if the sender can no longer fund a new transfer. |
| ID conflict | Reusing an accepted ID with any changed payload returns `Rejected` and leaves the entire state unchanged. |
| Invalid request | Return `Rejected`; change neither balances nor accepted-request records. |
| Retry after rejection | Rejected requests are not cached. A later retry may succeed if intervening valid transfers make it valid. |
| Completion | `Apply` must terminate. The concrete refinement may not opt out of termination checking. |

The caller supplies a well-formed state. Balances must be non-negative. Existing
accepted records must describe positive transfers between distinct existing
accounts. A fresh ledger has no accepted records. This contract does not establish
the history of an externally supplied state.

## Claim mapping

- C1: preserve the sum of all balances.
- C2: preserve non-negative balances.
- C3: an accepted request has no additional effect on an identical retry.
- C4: every fresh valid transfer succeeds with the exact specified movement.
- C5: every request that is neither an accepted retry nor a fresh valid transfer
  is rejected with no change to either state map.

Account membership and well-formed state are preserved as supporting obligations.
These conditions exclude silently creating accounts, changing unrelated balances,
or deleting prior accepted request records.

## Illustrative examples — not test results

Start with balances `{0: 10, 1: 0}` and no accepted requests.

| Request | Required outcome |
| --- | --- |
| New ID 7: send 10 from 0 to 1 | `Ok`; balances become `{0: 0, 1: 10}`; record ID 7 and its payload. |
| Retry ID 7 with the same payload | `Ok`; balances and accepted records stay unchanged. |
| Reuse accepted ID 7 with amount 9 | `Rejected`; all state stays unchanged. |
| New ID: send from an account to itself | `Rejected`; all state stays unchanged. |
| New ID: amount 0, negative, or above available funds | `Rejected`; all state stays unchanged. |
| New ID: unknown sender or recipient | `Rejected`; all state stays unchanged. |

Only accepted IDs are reserved. For example, a rejected insufficient-funds
request can later succeed after another valid transfer funds its sender.
If rejected results must instead remain permanent, that is a different contract:
we must decide whether storing a rejection is permitted under C5's “no effect.”

## Scope and assumptions

This is a sequential, mathematical state-transition contract. It does not prove
concurrent access, durable storage, crash recovery, authentication, serialization,
network delivery, or exactly-once effects in an external system. Those concerns
cannot be inferred from the source proof. `end_to_end` remains false.

The source model uses unbounded integers. A later JavaScript or TypeScript
integration must preserve that domain or record its tested boundary explicitly.

## Validation already run

Command: `.toolchain/dafny-4.11.0/dafny/dafny resolve proposals/initial-ledger/LedgerSpec.dfy`

| Attempt | Actual exit code | Observation |
| --- | --- | --- |
| 1 | 2 | Parser rejected the attempted postcondition-label syntax. |
| 2 | 2 | Resolver reported an indentation warning in the C5 implication. |
| 3 | 0 | Final draft parsed and type-checked; no verification was attempted. |

Only the reported syntax and indentation issues were corrected. Resolving an
abstract specification proves no implementation claim. At that point, none of
the Stage 1 EXIT commands had run. Later results are linked above.

## Exact proposed addition

Candidate: `initial-ledger/LedgerSpec.dfy`.

SHA-256: `e9bdfd511d3cffb04c533dcc62252cabf84a825d5577ea5999d18bc25e0bda0f`.

```diff
--- /dev/null
+++ b/spec/LedgerSpec.dfy
@@ -0,0 +1,65 @@
+abstract module LedgerSpec {
+  datatype Request = TransferRequest(sender: int, recipient: int, amount: int)
+  datatype Outcome = Ok | Rejected
+  datatype State = LedgerState(
+    balances: map<int, int>,
+    accepted: map<int, Request>)
+
+  ghost predicate NonNegative(balances: map<int, int>) {
+    forall account | account in balances :: 0 <= balances[account]
+  }
+
+  ghost predicate WellFormed(state: State) {
+    NonNegative(state.balances) &&
+    (forall id | id in state.accepted ::
+      state.accepted[id].sender in state.balances &&
+      state.accepted[id].recipient in state.balances &&
+      state.accepted[id].sender != state.accepted[id].recipient &&
+      0 < state.accepted[id].amount)
+  }
+
+  ghost function Total(balances: map<int, int>): int
+    decreases |balances|
+  {
+    if balances == map[] then 0
+    else
+      var account :| account in balances;
+      balances[account] + Total(balances - {account})
+  }
+
+  predicate IsRetry(state: State, id: int, request: Request) {
+    id in state.accepted && state.accepted[id] == request
+  }
+
+  predicate IsFreshValid(state: State, id: int, request: Request) {
+    id !in state.accepted &&
+    request.sender in state.balances &&
+    request.recipient in state.balances &&
+    request.sender != request.recipient &&
+    0 < request.amount <= state.balances[request.sender]
+  }
+
+  method Apply(state: State, id: int, request: Request)
+      returns (next: State, outcome: Outcome)
+    requires WellFormed(state)
+    ensures WellFormed(next)
+    ensures next.balances.Keys == state.balances.Keys
+    // C1: conservation.
+    ensures Total(next.balances) == Total(state.balances)
+    // C2: non-negative balances.
+    ensures NonNegative(next.balances)
+    // C3: accepted retries return Ok and do not repeat the effect.
+    ensures IsRetry(state, id, request) ==>
+      outcome == Ok && next == state
+    // C4: a valid new request succeeds with the exact debit and credit.
+    ensures IsFreshValid(state, id, request) ==>
+      outcome == Ok &&
+      next.balances ==
+        state.balances[
+          request.sender := state.balances[request.sender] - request.amount][
+          request.recipient := state.balances[request.recipient] + request.amount] &&
+      next.accepted == state.accepted[id := request]
+    // C5: every other request is rejected with no state change.
+    ensures (!IsRetry(state, id, request) && !IsFreshValid(state, id, request)) ==>
+      outcome == Rejected && next == state
+}
```

## After intent approval

Copy the approved candidate bytes to `spec/LedgerSpec.dfy`. Create `spec.lock`
from that exact spec digest and the pinned Dafny version. Freeze that baseline.
Then implement its concrete refinement, the gate, and the four rejection
fixtures. Any later change to the approved behavior requires a new proposal.

Approval of this proposal does not claim that an implementation is correct,
that the spec captures every desired behavior, or that a Stage 1 EXIT has passed.
