# Fee proposal: one unit per fresh accepted transfer

**Status: PENDING HUMAN APPROVAL. No proposed spec or lock change is applied.**

This proposal completes the intent-definition part of Stage 4. It changes the
ledger's required behavior. It is not a proof result. Review the rules and the
exact diff below. Approval must name this proposal and its candidate spec digest.

## Reason

The ledger currently moves the requested amount without a fee. Introduce a
fixed fee to demonstrate an intentional requirement change through the change
loop. The sender pays one additional unit. Account `0` receives that unit.
Keeping the fee inside the balance map preserves the meaning of C1: total funds
across all accounts remain constant.

This is a demonstration policy, not a recommended commercial fee schedule.

## Exact behavior

- A fresh request needs an unused ID, existing and distinct sender and recipient,
  a positive amount, and sender funds for `amount + 1`.
- Account `0` must exist. A fresh request cannot name account `0` as sender or
  recipient. The model has no fee withdrawal operation.
- On success, debit the sender by `amount + 1`, credit the recipient by `amount`,
  credit account `0` by `1`, and cache the exact request under its ID.
- An identical accepted retry returns `Ok`, changes no state, and charges no fee.
  Existing retry semantics remain intact, including accepted records already in
  a well-formed input state. There is no retroactive fee.
- An invalid fresh request returns `Rejected` with no state change and no fee.
  Rejected requests do not create retry records. Self-transfers and conflicting
  reuse of an accepted ID remain rejected.
- Amounts and balances remain mathematical integers. Operations remain sequential.
  This change adds no concurrency, persistence, migration, binary, or deployment
  guarantee. Evidence must retain `end_to_end=false`.

C1, C2, C3, and C5 keep their obligations. C4 changes its definition of a fresh
valid request and its exact balance update. A sender with exactly `amount`
now lacks the extra unit and is rejected. A sender with exactly `amount + 1`
can succeed. This is an explicit behavior change requiring intent approval.

## Expected examples — not executed checks

Each row starts from its stated state, except the retry row.

| Input | Required result |
| --- | --- |
| Balances `{0: 0, 1: 11, 2: 0}`; new ID; `1 → 2`, amount `10` | `Ok`; balances `{0: 1, 1: 0, 2: 10}`. |
| Repeat that exact accepted ID and request | `Ok`; the same balances and accepted map. |
| Balances `{0: 0, 1: 10, 2: 0}`; new ID; `1 → 2`, amount `10` | `Rejected`; unchanged state. |
| Fee account `0` missing; otherwise sufficient funds | `Rejected`; unchanged state. |
| A fresh self-transfer or a fresh transfer involving account `0` | `Rejected`; unchanged state. |
| Reuse an accepted ID with different arguments | `Rejected`; unchanged state. |

## Revision and content binding

- Base repository revision: `b2906e2f64f9e1ecd364d2dced55a391f736c236`.
- Base spec SHA-256: `e9bdfd511d3cffb04c533dcc62252cabf84a825d5577ea5999d18bc25e0bda0f`.
- Base lock SHA-256: `3ef8fca194a6220601fe68c1eae7eb6b0b9e0447b05802dfaa311ddca2fe23ae`.
- Candidate spec SHA-256: `2ad0742dcbf81bf24f9235ed88f9728c7b078dfa6ed55632a90b6aa847b35940`.
- Candidate lock SHA-256: `32cf117f5bcaec2fb0c072650ceb9b535576ab409579a56c00979ed151b03b69`.

The proposed lock fields below describe the state **after** explicit approval.
They do not assert that approval has already occurred. Candidate-owned lock
metadata alone cannot authorize the change. The Stage 4 approval path must use
an external trusted approval record tied to these exact spec and lock bytes.
A different proposed diff requires fresh approval.

## Exact unapplied diff

```diff
--- a/spec/LedgerSpec.dfy
+++ b/spec/LedgerSpec.dfy
@@ -1,4 +1,5 @@
 abstract module LedgerSpec {
+  // Each fresh transfer pays one unit to fee account 0.
   datatype Request = TransferRequest(sender: int, recipient: int, amount: int)
   datatype Outcome = Ok | Rejected
   datatype State = LedgerState(
@@ -36,7 +37,11 @@
     request.sender in state.balances &&
     request.recipient in state.balances &&
     request.sender != request.recipient &&
-    0 < request.amount <= state.balances[request.sender]
+    0 in state.balances &&
+    request.sender != 0 &&
+    request.recipient != 0 &&
+    0 < request.amount &&
+    request.amount + 1 <= state.balances[request.sender]
   }
 
   method Apply(state: State, id: int, request: Request)
@@ -51,13 +56,14 @@
     // C3: accepted retries return Ok and do not repeat the effect.
     ensures IsRetry(state, id, request) ==>
       outcome == Ok && next == state
-    // C4: a valid new request succeeds with the exact debit and credit.
+    // C4: a valid new request succeeds with exact debit, credit, and fee.
     ensures IsFreshValid(state, id, request) ==>
       outcome == Ok &&
       next.balances ==
         state.balances[
-          request.sender := state.balances[request.sender] - request.amount][
-          request.recipient := state.balances[request.recipient] + request.amount] &&
+          request.sender := state.balances[request.sender] - request.amount - 1][
+          request.recipient := state.balances[request.recipient] + request.amount][
+          0 := state.balances[0] + 1] &&
       next.accepted == state.accepted[id := request]
     // C5: every other request is rejected with no state change.
     ensures (!IsRetry(state, id, request) && !IsFreshValid(state, id, request)) ==>
--- a/spec.lock
+++ b/spec.lock
@@ -1,13 +1,13 @@
 {
   "approval": {
-    "candidate_sha256": "e9bdfd511d3cffb04c533dcc62252cabf84a825d5577ea5999d18bc25e0bda0f",
+    "candidate_sha256": "2ad0742dcbf81bf24f9235ed88f9728c7b078dfa6ed55632a90b6aa847b35940",
     "decision": "approved_as_written",
-    "proposal": "proposals/initial-ledger.md",
-    "source": "explicit user approval in this task"
+    "proposal": "proposals/fees.md",
+    "source": "explicit user approval of the exact fee proposal in this task"
   },
   "dafny_build": "4.11.0+fcb2042d6d043a2634f0854338c08feeaaaf4ae2",
   "dafny_version": "4.11.0",
   "schema_version": 1,
   "spec_file": "spec/LedgerSpec.dfy",
-  "spec_sha256": "e9bdfd511d3cffb04c533dcc62252cabf84a825d5577ea5999d18bc25e0bda0f"
+  "spec_sha256": "2ad0742dcbf81bf24f9235ed88f9728c7b078dfa6ed55632a90b6aa847b35940"
 }
```

## Work after approval

Apply only the approved spec and lock bytes. Implement revision-bound approval
in the trusted workflow, then update the refinement, contract-binding checks,
claim text, TypeScript comparison, and examples to follow the new requirement.
Use real Dafny verification and existing rejection controls. Record the actual
new spec digest in evidence. Run the approved-spec PR EXIT and retain the
unapproved-change and C2-weakening controls.

No checker has accepted this candidate spec or a matching implementation yet.
The first two Stage 4 EXITs passed against the original approved spec. Stage 4
remains CURRENT until its approved-spec EXIT also passes.
