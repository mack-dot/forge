# Stage 10 benchmark cases (frozen in manifest.json)

Generated from `cases/*.json`; those files are authoritative. Gates: `incremental` = `gate/incremental.py` (ledger PR gate, candidate tree);
`gate` = `gate/gate.py --impl impl/Ledger.dfy`; `booking` = `gate/booking.py`; `refund` = `gate/refund.py --tier critical`.
Target `candidate` = the PR tree; `root` = the checkout the gate runs from. `unsupported` means no acceptance and a "no claim" report.

| # | Case | Gate | Input change | Expected | Why |
| ---: | --- | --- | --- | --- | --- |
| 1 | `ledger-evidence-seed-fresh` | gate | no change | accept (exit 0) | Unchanged approved ledger; fresh checker run writes the seed evidence for the evidence cases. |
| 2 | `booking-seed-fresh` | booking | no change | accept (exit 0) | Unchanged approved booking matcher; fresh run writes the seed evidence. |
| 3 | `refund-seed-fresh` | refund | no change | accept (exit 0) | Unchanged approved refund boundary; fresh run writes the seed evidence. |
| 4 | `ledger-pr-accept-branch-order` | incremental | edit impl/Ledger.dfy (candidate) | accept (exit 0) | Fresh-transfer branch tested before the retry branch; the two conditions are mutually exclusive, so behavior is unchanged. |
| 5 | `ledger-pr-accept-early-return` | incremental | edit impl/Ledger.dfy (candidate) | accept (exit 0) | Default to the rejected result and return early; same outcomes for every input. |
| 6 | `ledger-pr-accept-transfer-lemma` | incremental | edit impl/Ledger.dfy (candidate) | accept (exit 0) | One conservation lemma for the whole transfer replaces three inline lemma calls; the next state is written as one map update chain. |
| 7 | `ledger-pr-accept-comment-only` | incremental | edit impl/Ledger.dfy (candidate) | accept (exit 0) | Comment-only change to the implementation. |
| 8 | `ledger-pr-defect-fee-not-debited` | incremental | edit impl/Ledger.dfy (candidate) | defect / VERIFICATION_REJECTED (exit 1) | Sender is not charged the fee while account 0 still gains it: violates C1 conservation and C4. |
| 9 | `ledger-pr-defect-retry-rejected` | incremental | edit impl/Ledger.dfy (candidate) | defect / VERIFICATION_REJECTED (exit 1) | An accepted identical retry returns Rejected: violates C3. |
| 10 | `ledger-pr-defect-invalid-accepted` | incremental | edit impl/Ledger.dfy (candidate) | defect / VERIFICATION_REJECTED (exit 1) | Every other request returns Ok: violates C5. |
| 11 | `ledger-pr-defect-overdraft` | incremental | edit impl/Ledger.dfy (candidate) | defect / VERIFICATION_REJECTED (exit 1) | Balance check dropped from the transfer condition: overdrafts give negative balances (C2) and wrong acceptances (C5). |
| 12 | `ledger-pr-policy-assume` | incremental | edit impl/Ledger.dfy (candidate) | policy_reject / AUDIT_REJECTED (exit 1) | An assume statement inside the fresh-transfer branch (forbidden assumption). |
| 13 | `ledger-pr-policy-axiom-attribute` | incremental | edit impl/Ledger.dfy (candidate) | policy_reject / SOURCE_SCOPE (exit 1) | A bodiless {:axiom} lemma that would make any total equal zero. |
| 14 | `ledger-pr-policy-extra-import` | incremental | edit impl/Ledger.dfy (candidate) | policy_reject / SOURCE_SCOPE (exit 1) | A second file is pulled into the ledger implementation. |
| 15 | `ledger-pr-policy-spec-weakened` | incremental | edit spec.lock (candidate), edit spec/LedgerSpec.dfy (candidate) | policy_reject / UNAPPROVED_PROTECTED_CHANGE (exit 1) | C2 postcondition deleted from the spec and spec.lock updated to match, with no approval record. |
| 16 | `ledger-pr-policy-forged-approval` | incremental | edit spec.lock (candidate), edit spec/LedgerSpec.dfy (candidate), write gate/approvals/9999-bench-forged.json (candidate) | policy_reject / UNAPPROVED_PROTECTED_CHANGE (exit 1) | Same weakened spec plus a forged approval record added by the PR itself. |
| 17 | `ledger-pr-policy-gate-edit` | incremental | edit gate/incremental.py (candidate) | policy_reject / UNAPPROVED_PROTECTED_CHANGE (exit 1) | The PR edits the gate so that Dafny exit 4 would be accepted. |
| 18 | `ledger-pr-unsupported-ts-fee-bug` | incremental | edit ts/ledger.ts (candidate) | unsupported | Only ts/ledger.ts changes: the shipped TypeScript transfer stops charging the fee. No Forge claim covers this file. |
| 19 | `ledger-pr-unsupported-app-change` | incremental | edit app/main.ts (candidate) | unsupported | Only app/main.ts changes (a new transfer). No Forge claim covers this file. |
| 20 | `ledger-pr-unsupported-new-dafny-module` | incremental | write impl/Extra.dfy (candidate) | unsupported | A new Dafny module with a false postcondition (odd inputs) and no claim. |
| 21 | `ledger-pr-unsupported-refund-wrapper` | incremental | edit ts/refund.ts (candidate) | unsupported | Only ts/refund.ts changes: the wire decoder drops its MAX_MONEY bound. The critical refund proof does not cover this file. |
| 22 | `ledger-pr-tool-dafny-missing` | incremental | delete .toolchain/dafny-4.11.0/dafny/dafny (root) | tool_failure (exit 2) | The trusted Dafny executable is missing (injected in this case's isolated copy only). |
| 23 | `ledger-pr-tool-z3-corrupt` | incremental | truncate .toolchain/dafny-4.11.0/dafny/z3/bin/z3-4.12.1 (root) | tool_failure (exit 2) | The trusted Z3 solver is truncated to zero bytes (isolated copy only). |
| 24 | `ledger-evidence-accept-unchanged` | gate | supplied evidence from `ledger-evidence-seed-fresh` | accept (exit 0) | The seed evidence, supplied unchanged, is validated and reproduced. |
| 25 | `ledger-evidence-claim-failed` | gate | supplied evidence from `ledger-evidence-seed-fresh` + set evidence/C2/result="failed" | missing_evidence / MISSING_EVIDENCE (exit 1) | C2 evidence result changed to failed. |
| 26 | `ledger-evidence-record-removed` | gate | supplied evidence from `ledger-evidence-seed-fresh` + remove evidence/C4 | missing_evidence / MISSING_EVIDENCE (exit 1) | C4 evidence record removed. |
| 27 | `ledger-evidence-artifact-swapped` | gate | supplied evidence from `ledger-evidence-seed-fresh` + set artifact/sha256="ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff" | missing_evidence / ARTIFACT_MISMATCH (exit 1) | Artifact digest replaced. |
| 28 | `ledger-evidence-end-to-end-claimed` | gate | supplied evidence from `ledger-evidence-seed-fresh` + set end_to_end=true | missing_evidence / COVERAGE_SCOPE (exit 1) | end_to_end set to true. |
| 29 | `ledger-evidence-tool-version-edited` | gate | supplied evidence from `ledger-evidence-seed-fresh` + set evidence/C1/tool_version="4.11.1" | missing_evidence / REPRODUCTION_MISMATCH (exit 1) | C1 tool_version edited; still schema- and policy-valid, so only the fresh rerun can catch it. |
| 30 | `ledger-evidence-duplicate-key` | gate | supplied evidence from `ledger-evidence-seed-fresh` + duplicate key end_to_end | missing_evidence / DOCUMENT_FORMAT (exit 1) | A duplicate top-level end_to_end key (JSON parsers disagree on which value wins). |
| 31 | `ledger-evidence-from-other-domain` | gate | supplied evidence from `booking-seed-fresh` | missing_evidence / ARTIFACT_MISMATCH (exit 1) | Valid booking evidence supplied for the ledger artifact. |
| 32 | `ledger-evidence-policy-version` | gate | supplied evidence from `ledger-evidence-seed-fresh` + set policy/version="9.9.9" | missing_evidence / POLICY_BINDING (exit 1) | Policy version in the bundle changed. |
| 33 | `ledger-evidence-method-downgraded` | gate | supplied evidence from `ledger-evidence-seed-fresh` + set evidence/C3/method="property_tested" | policy_reject / METHOD_POLICY (exit 1) | C3 evidence method changed from source_proof to property_tested. |
| 34 | `booking-accept-branch-order` | booking | edit impl/Booking.dfy (root) | accept (exit 0) | Retry branch moved after the two fresh branches; the conditions are mutually exclusive. |
| 35 | `booking-accept-least-rewrite` | booking | edit impl/Booking.dfy (root) | accept (exit 0) | Least rewritten with a separate singleton branch and a conditional expression. |
| 36 | `booking-accept-supplied-unchanged` | booking | supplied evidence from `booking-seed-fresh` | accept (exit 0) | The booking seed evidence, supplied unchanged. |
| 37 | `booking-defect-not-least` | booking | edit impl/Booking.dfy (root) | defect / VERIFICATION_REJECTED (exit 1) | Any available slot is chosen instead of the least one: violates B2. |
| 38 | `booking-defect-cancel-keeps-active` | booking | edit impl/Booking.dfy (root) | defect / VERIFICATION_REJECTED (exit 1) | Cancellation frees the slot but leaves the booking active: violates B3 and well-formedness. |
| 39 | `booking-policy-assume` | booking | edit impl/Booking.dfy (root) | policy_reject / AUDIT_REJECTED (exit 1) | An assume statement in the fresh-book branch. |
| 40 | `booking-policy-spec-weakened` | booking | edit spec/booking/BookingSpec.dfy (root) | policy_reject / BOOKING_SPEC_LOCK (exit 1) | B1 postcondition deleted from the approved booking spec. |
| 41 | `booking-policy-witness-edited` | booking | edit tests/booking/SuccessfulExecution.dfy (root) | policy_reject / WITNESS_BINDING (exit 1) | The checked successful-execution witness is changed. |
| 42 | `booking-evidence-claim-failed` | booking | supplied evidence from `booking-seed-fresh` + set evidence/B3/result="failed" | missing_evidence / MISSING_EVIDENCE (exit 1) | B3 evidence result changed to failed. |
| 43 | `booking-tool-lying-checker` | booking | write .toolchain/dafny-4.11.0/dafny/dafny (root) | tool_failure (exit 2) | Dafny replaced by a script that prints the pinned version and exits 0 for everything (isolated copy only). |
| 44 | `refund-accept-inline-condition` | refund | edit impl/Refund.dfy (root) | accept (exit 0) | Eligibility written out inline instead of calling Eligible. |
| 45 | `refund-accept-default-reject` | refund | edit impl/Refund.dfy (root) | accept (exit 0) | Start from Rejected and an empty plan; overwrite only when eligible. |
| 46 | `refund-accept-supplied-unchanged` | refund | supplied evidence from `refund-seed-fresh` | accept (exit 0) | The refund seed evidence, supplied unchanged. |
| 47 | `refund-defect-original-bound` | refund | edit impl/Refund.dfy (root) | defect / VERIFICATION_REJECTED (exit 1) | Amount checked against the original charge instead of the remaining amount: violates R1. |
| 48 | `refund-defect-swapped-ids` | refund | edit impl/Refund.dfy (root) | defect / VERIFICATION_REJECTED (exit 1) | Intent written with charge and request IDs swapped: violates R4/R5. |
| 49 | `refund-policy-spec-weakened` | refund | edit spec/refund/RefundSpec.dfy (root) | policy_reject / APPROVED_CONTRACT (exit 1) | R2 reason restriction deleted from the approved refund spec. |
| 50 | `refund-evidence-record-removed` | refund | supplied evidence from `refund-seed-fresh` + remove evidence/R2 | missing_evidence / MISSING_EVIDENCE (exit 1) | R2 evidence record removed. |
| 51 | `refund-tool-dafny-missing` | refund | delete .toolchain/dafny-4.11.0/dafny/dafny (root) | tool_failure (exit 2) | The trusted Dafny executable is missing (isolated copy only). |
