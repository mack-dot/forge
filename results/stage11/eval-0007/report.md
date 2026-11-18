# Stage 11 evaluation report

Frozen cases `ceec69ca99000f1c`; 18 cases; cold and warm runs.

| Kind | Cases |
| --- | ---: |
| match | 12 |
| false_accept | 0 |
| false_reject | 0 |
| false_unsupported | 0 |
| other_mismatch | 0 |
| frozen_expectation_superseded_by_design_change | 5 |
| not_constructible | 1 |

| Case | Expected | Observed | Kind | Affected | PR #27 | Cold wall s | Warm wall s | Warm reused |
| --- | --- | --- | --- | --- | --- | ---: | ---: | --- |
| `e01-identical` | VERIFIED | VERIFIED | match | ledger-proof | VERIFIED | 21.575 | 11.568 |  |
| `e02-ledger-rename-local-plus-evidence` | VERIFIED | VERIFIED | match | ledger-proof, ledger-evidence, ledger-model, booking, ledger-witness | UNSUPPORTED | 35.096 | 16.243 | booking, ledger-evidence, ledger-model, ledger-witness |
| `e03-ts-fee-constant` | VERIFIED | UNSUPPORTED | frozen_expectation_superseded_by_design_change | ledger-proof, ledger-model | UNSUPPORTED | 15.74 | 7.79 |  |
| `e04-booking-least-le` | VERIFIED | VERIFIED | match | ledger-proof, booking | UNSUPPORTED | 38.061 | 17.737 | booking |
| `e05-refund-negated-branch` | VERIFIED | VERIFIED | match | ledger-proof, refund-proof, refund-tests | UNSUPPORTED | 39.077 | 14.061 | refund-proof, refund-tests |
| `e06-property-test-comment` | VERIFIED | REJECTED | frozen_expectation_superseded_by_design_change |  | UNSUPPORTED | 0.28 | 0.211 |  |
| `e07-ts-retry-rejected` | REJECTED | UNSUPPORTED | frozen_expectation_superseded_by_design_change | ledger-proof, ledger-model | UNSUPPORTED | 15.677 | 10.965 |  |
| `e08-ledger-edit-stale-evidence` | REJECTED | REJECTED | match | ledger-proof, ledger-evidence, ledger-model, booking, ledger-witness | UNSUPPORTED | 37.374 | 16.754 | booking, ledger-model, ledger-witness |
| `e09-booking-active-not-updated` | REJECTED | REJECTED | match | ledger-proof, booking | UNSUPPORTED | 36.125 | 26.136 |  |
| `e10-refund-ts-drops-bound` | REJECTED | UNSUPPORTED | frozen_expectation_superseded_by_design_change | ledger-proof, refund-tests | UNSUPPORTED | 18.965 | 7.353 |  |
| `e11-weakened-spec-with-lock` | REJECTED | REJECTED | match |  | REJECTED | 0.278 | 0.398 |  |
| `e12-stale-witness` | REJECTED | None | not_constructible |  | None | 0.0 | 0.0 |  |
| `e13-readme-only` | UNSUPPORTED | UNSUPPORTED | match | ledger-proof | UNSUPPORTED | 12.956 | 6.836 |  |
| `e14-new-reader-of-ledger` | UNSUPPORTED | UNSUPPORTED | match | ledger-proof, ledger-evidence, ledger-model, booking, ledger-witness | UNSUPPORTED | 13.575 | 8.64 |  |
| `e15-mixed-docs-plus-ts-refactor` | UNSUPPORTED | UNSUPPORTED | match | ledger-proof, ledger-model | UNSUPPORTED | 12.632 | 6.372 |  |
| `e16-results-record-edit` | UNSUPPORTED | UNSUPPORTED | match | ledger-proof | UNSUPPORTED | 12.601 | 6.709 |  |
| `e17-dafny-missing` | NOT_ESTABLISHED | NOT_ESTABLISHED | match |  | NOT_ESTABLISHED | 0.274 | 0.208 |  |
| `e18-node-modules-missing` | NOT_ESTABLISHED | UNSUPPORTED | frozen_expectation_superseded_by_design_change | ledger-proof, ledger-model | UNSUPPORTED | 13.563 | 7.371 |  |

latency_cold: wall p50 13.575 s, p95 39.077 s, total 323.849 s; CPU p50 10.484 s, p95 39.35 s, total 257.627 s

latency_warm: wall p50 7.371 s, p95 26.136 s, total 165.352 s; CPU p50 7.137 s, p95 20.348 s, total 132.839 s

Warm run same decision: 18 of 18; cases with reused obligations: 4

VERIFIED here, UNSUPPORTED under PR #27: e02-ledger-rename-local-plus-evidence, e04-booking-least-le, e05-refund-negated-branch

## Limits

- Internally authored cases; not independent generalization.
- Warm runs reuse obligation records from the same host and the same root; CI caches are not measured.
- Latency measured on the recorded host; concurrent load noted in the run record when present.
- end_to_end=false.
