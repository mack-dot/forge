# Anchor interface draft for the sink owner (h-sink) — h-anchor, 2026-11-19

Reference implementation: `witness_file.ts` (this directory; NOT on the branch; NOT proved).
Light self-test: `witness_selftest.ts`, log `logs/witness_selftest_1.log` (exit 0).

## Functions
```ts
type RowHead = { n: number; h: string };              // n = number of committed rows; h = hex SHA-256
genesisHash(initialStateText, specLockSha256, checkerSha256, issuerPublicKeyPem): string   // h_0
linkHash(prev: string, tokenText: string, intentText: string): string                     // h_{i+1}
headOf(h0, rows: {token, intent}[]): RowHead
interface Witness {
  register(chargeId: string, h0: string): void;         // once per charge; refuses a second call
  latestHead(chargeId: string): RowHead;                 // throws if no valid record (fail closed)
  publishHead(chargeId: string, expected: RowHead, next: RowHead): void;  // compare-and-swap
}
```
`publishHead` refuses unless `latestHead == expected` and `next.n > expected.n`. The CAS check and the
append run under one lock file. The file witness appends one canonical JSON line, fsyncs the file and its
directory. Its directory must not be the sink's directory (different disk or host in production).
The witness cannot check that `next` extends `expected` (it has no rows): the CALLER checks that, by
recomputing the chain from its own rows. A count-only check is not enough (Anchor.dfy C3, mutant M4).

## Sink: what to add (sink.ts or the v6 sink)
- `meta`: keys `row_head_n`, `row_head_h`, `h0`. `init()` computes h_0 and stores it; the deployer calls
  `witness.register(chargeId, h0)` from the authentic charge record (not from the database).
- `head(): RowHead` returns (`row_head_n`, `row_head_h`). `expectedHead` (if option 1 is chosen) is
  compared with `head()` inside the commit transaction.

## Commit path (inside the existing IMMEDIATE transaction, then after it)
1. Existing checks (shape, ids, signature, fresh request id, matching pre-state).
2. In the same transaction: insert settled + outbox rows (outbox `dispatchable = 0`); set
   `row_head = (n+1, linkHash(h_n, tokenText, intentText))`. COMMIT.
3. After COMMIT: `witness.publishHead(chargeId, (n, h_n), (n+1, h_{n+1}))`.
4. On success: `UPDATE outbox SET dispatchable = 1 WHERE seq = …` (or the dispatcher treats rows with
   index ≤ `latestHead.n` as dispatchable and needs no flag).
5. On failure (witness down): leave the row in the unpublished tail; return `committed` with a warning;
   the dispatcher sends nothing beyond `latestHead.n`.
   On a CAS refusal: the store is a fork or stale. Stop the sink (fail closed) and alarm.

## Start-up sequence
1. `L = witness.latestHead(chargeId)` (throws: refuse to start).
2. Recompute the chain from h_0 (from `meta`) over all settled rows, in `seq` order. Require it to equal
   `row_head` (internal consistency) AND rows 1..L.n to chain to `L.h`, with `n_store >= L.n`.
   Else refuse to start: "store is not an extension of the anchored history" (rollback, deletion,
   reorder, forged initial charge).
3. Publish the tail rows L.n+1..n_store one at a time by CAS (crash recovery).

## Dispatcher (recommended: its ledger IS the witness)
- Pin h_0. Each ledger line gains `n` and `rowHead`. Before sending row n+1: recompute the sink's chain
  over rows 1..n+1; require rows 1..n to give the ledger's last `rowHead` and the request id not done.
  Any mismatch: stop the whole run, send nothing, report. A missing ledger is an error after registration.

## Test cases (described; NOT implemented on the branch)
1. Rollback to prefix: commit r1, r2(0), r3(0); publish; copy back the snapshot after r1; start the sink:
   EXPECT refuse "store is behind the witness"; dispatcher: no effect. Re-commit r2 into the snapshot
   without a start check: dispatcher stops (rows 1..3 do not give the ledger head) or sends nothing new.
2. Zero-amount row deletion: delete the settled and outbox rows of r2(0) by SQL; restart: EXPECT refuse
   (count 2 < 3). Variant with a later honest row r4 (count 3): EXPECT refuse (chain differs).
3. Swapped zero-amount rows: swap seq of r2(0) and r3(0); EXPECT refuse at start; dispatcher stops.
4. Forged initial charge: create a database with remaining 1000 and its own h_0'; EXPECT start refused
   (h_0' ≠ registered h_0) and the dispatcher refuses row 1.
5. Crash between commit and publish: kill after COMMIT, before `publishHead`; restart: EXPECT the tail row
   published by the start step, then dispatched exactly once.
6. Witness unavailable: make the witness directory unreadable; EXPECT commit returns committed+warning,
   the dispatcher sends nothing, `latestHead` throws; restore: the tail is published and sent once.
7. Two sinks on two copies of one database: each commits a different token at n+1; EXPECT exactly one
   CAS succeeds; the other sink stops; one effect.
8. Witness rolled back (control, ANCHOR-MONOTONE violated): truncate the witness file; EXPECT the start
   check to accept a matching rolled-back store: documents that the claim depends on the assumption
   (self-test: `after truncation … latest 1`; probe E: ledger lost, r1 sent twice).
Positive controls in every case: the honest history with zero-amount rows commits, publishes, is sent.
