# Ledger claims and generated behavior examples

Generated from real source-proof evidence and observed model comparisons.
Run `python3 scripts/generate_claim_docs.py` with the pinned toolchain.

Spec SHA-256: `2ad0742dcbf81bf24f9235ed88f9728c7b078dfa6ed55632a90b6aa847b35940`.

| Claim | Established behavior | Spec location |
| --- | --- | --- |
| C1 | A transfer preserves total funds. | `spec/LedgerSpec.dfy:53` |
| C2 | Every resulting account balance is non-negative. | `spec/LedgerSpec.dfy:55` |
| C3 | An accepted identical retry returns Ok without repeating its effect. | `spec/LedgerSpec.dfy:57` |
| C4 | A fresh valid transfer terminates, debits amount plus one from the sender, credits the recipient by amount, and credits fee account 0 by one. | `spec/LedgerSpec.dfy:60` |
| C5 | Every other request is rejected without changing either state map. | `spec/LedgerSpec.dfy:69` |

These source proofs assume a WellFormed input state and sequential operations
over mathematical integers. The fee account is `0`. A fresh transfer needs
a distinct sender and recipient, neither equal to `0`, and funds for amount
plus one. Retries and rejected requests leave state unchanged.

## Generated examples

227 actual comparisons: 6 returned `Ok`; 221 returned `Rejected`.
Every row matched the handwritten TypeScript implementation against the compiled
Dafny model. This is `tested_against_proved_model`, not a TypeScript proof.

| ID | Input balances | Request ID; sender → recipient; amount | Outcome | Next balances |
| --- | --- | --- | --- | --- |
| E225 | `{0: 0, 1: 11, 2: 0}` | `7; 1 → 2; 10` | Ok | `{0: 1, 1: 0, 2: 10}` |
| E226 | `{0: 1, 1: 0, 2: 10}` | `7; 1 → 2; 10` | Ok | `{0: 1, 1: 0, 2: 10}` |
| E227 | `{0: 1, 1: 0, 2: 10}` | `7; 1 → 2; 9` | Rejected | `{0: 1, 1: 0, 2: 10}` |
| E049 | `{0: 0, 1: 11, 2: 0}` | `7; 1 → 2; 11` | Rejected | `{0: 0, 1: 11, 2: 0}` |
| E038 | `{0: 0, 1: 11, 2: 0}` | `7; 1 → 1; 1` | Rejected | `{0: 0, 1: 11, 2: 0}` |
| E157 | `{1: 11, 2: 0}` | `7; 1 → 2; 1` | Rejected | `{1: 11, 2: 0}` |
| E031 | `{0: 0, 1: 11, 2: 0}` | `7; 1 → 0; 1` | Rejected | `{0: 0, 1: 11, 2: 0}` |

The full [example records](../results/stage5/examples.json) include accepted-request maps.
They are finite observations. The source-to-module compiler/runtime/bridge link is
an assumption. Compiler, binary, concurrency, persistence, and deployment behavior
remain outside these proofs. `end_to_end=false`.

A successful-execution witness and a mutation report provide separate spec-quality
diagnostics. Neither establishes that the specification captures all human intent.
