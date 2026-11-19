# Orchestrator C (red team) state

Started 2026-11-19T14:19:25Z. Branch nightshift/C-redteam from 4af09308 (B head). Worktree: <SCRATCH>/redteam-C/wt.
Target with adoption-v6.diff applied (uncommitted, read-only use): <SCRATCH>/redteam-C/target-v6. A target: dae1b93e.
unsure block U580-U619: none used yet. C holds no lock. HOL lock held by A at start (no heavy run by C).
Partner IDs: B a56d4886a49375909, A aabe04fa1c6495747.

## Wave 1 (started 14:19Z); workers: opus, light runs only
| Worker | Class | Evidence dir | State |
|---|---|---|---|
| c1-concurrency | parallel writers, crash, restart, retry | orch-C/c1-concurrency | running |
| c2-malformed | malformed inputs, serializer, decoder, value conversion | orch-C/c2-malformed | DONE 14:30Z: C-ATT-01 (known, open), C-NEG-01; re-run by C |
| c3-identity | identity substitution, cross-charge, replay, zero value | orch-C/c3-identity | running |
| c4-rollback | rollback, forged initial state, database tamper, dispatcher ledger | orch-C/c4-rollback | running |
| c5-gate | gate rule 3: bypass and false rejection | orch-C/c5-gate | running |
| c6-premises | A's theorem premises against the real executable | orch-C/c6-premises | running |

## 14:22Z B's reply (data)
- B head de538868 (pushed); sink, dispatcher, minter, gate rule unchanged on the branch; target 4af09308 + adoption-v6.diff stays valid.
- B's known limits (not new if found again): zero-amount row deletion/reorder/re-commit (U565); whole-file and prefix rollback; initial charge authentic only by configuration; key or pin rotation refuses a legitimate store; minter pre-state hash is one unchecked TypeScript line; rule 3 refuses 21 of 67 correct.
- B works on: h-sink (database-level safeguards, triggers, row-log chain head with expectedHead), h-regress (tests/refund-finality/regress/ with a runner that takes a sink module path), h-anchor, h-specdiff, h-gate. B sends SHA and diff path when each lands. NEXT for C: re-attack h-sink when it lands; run h-regress against the C checkout.
- B needs per counterexample: class; target SHA; exact command; expected vs actual; smallest input files with SHA-256.
