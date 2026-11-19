# h-dispatch notes (night shift 2026-11-19, Orchestrator B)

Base: nightshift/B-trust at 608b5165. Deliverable: `h-dispatch.diff` (SHA-256 in `h-dispatch.diff.sha256`); file hashes in
`files-sha256.txt`. Nothing is applied to the repository. Owned: `ts/refund-finality/dispatcher.ts`,
`tests/refund-finality/{dispatch,commit}_cli.ts`, new `tests/refund-finality/regress/d_*.ts`.
Unapplied caller diffs: `unapplied/suite-C-ATT-18.diff` (suite.ts row x5 now expects "in doubt"),
`unapplied/sink_tool-C-HOST-06.diff` (sink_tool takes the anchor from the config only).

## 1. Design
- **Claim rule (safety, C-ATT-17).** The ledger has four line kinds: `intent` (before the effect; carries a random run
  nonce and the pid), `done` (after emit returned), `failed` (emit threw), `resolved` (operator decision). The FIRST
  intent line for row n is the claim. A run emits row n only if a re-read AFTER its own synced intent line shows its own
  nonce as the claim. Two runs therefore never both emit one row or one request id, whatever happens to the lock.
- **Owned lock (order, liveness).** The lock file holds {pid, run, host}. A run re-checks it before each claim and stops
  if it is gone or foreign. It removes the lock only if the lock names its own run. A lock whose pid is dead on this
  host is taken over by rename (C-HOST-02). An unreadable or foreign-host lock is never taken over.
- **Delivery policy (C-ATT-18).** AT MOST ONCE by the dispatcher. A claim without `done` is IN DOUBT: reported in
  `refused` (reason "in doubt: ...") and `inDoubt` in every run; never counted as dispatched. The operator ends it with
  `resolveInDoubt(id, "sent")` (count it) or `resolveInDoubt(id, "retry")` (next run claims and emits again: AT LEAST
  ONCE on the operator's word). `resolveInDoubt` refuses while the claiming pid is alive on this host. CLI:
  `dispatch_cli.ts resolve <db> <ledger> <cfg> <id> sent|retry <note>`.
- **Dispatch witness (C-HOST-05, part of C-ATT-19).** `<resolved db>.dispatch-witness.json` = {ledger realpath, n,
  rowHead}, written (tmp + rename) after each confirmed claim. A run stops if the store is bound to another ledger
  (also with `newLedgerH0` still set) or if the ledger does not reach the witness's claim (ledger restored without the
  witness). Removing the witness is the explicit step to bind a new ledger.
- **Outside anchor (C-ATT-19).** `cfg.ledgerFloor = {n, rowHead}` (an earlier `result.ledgerHead`, kept off this
  medium): the ledger must reach it. The row-log witness (every claim's rowHead and token hash must still match the
  store) stops a store rollback; "ledger ahead of store" (power loss) is an alarm, never new work.
- **Row types (C-ATT-20).** Outbox rows are listed by `typeof` and `hex`; a non-text or U+0000 id is refused under its
  exact bytes with a "dispatcher alarm" reason; after a passing audit, any mismatch between listing and audit stops the run.
- **Short writes (C-ATT-22).** Write loop; 0 bytes or an error stops before emit. Only 0x0A-ended lines count. A torn
  last record is cut under the lock and kept in `<ledger>.torn-<run>`; a complete unparsable line is an alarm.
- **CLIs (C-HOST-01/03/04/07).** dispatch_cli: absolute paths only; one JSON report with `status` and `emittedIds`
  (also when stopped); exit 0 ok, 1 stopped, 2 usage, 3 emit failed, 4 refused or in doubt; EPIPE ignored (exit code
  = outcome). commit_cli: exit 0 committed/replayed, 1 rejected/error, 2 usage or missing database without
  `--create-store`; EPIPE ignored.

## 2. Emit contract (for h-provider)
`emit(effect, intent)` with `effect = {requestId, intent}`. The receiver MUST use `effect.requestId` (equal to
`intent.requestId`, unique per charge) as the idempotency key. emit returns only after the receiver acknowledged;
it throws if the outcome is unknown or failed. With such a receiver, "retry" after a crash is safe; without one, it is
the operator's risk (assumption IDEMPOTENT-RECEIVER-ABSENT).

## 3. Evaluated proposals (Orchestrator B, P1)
- Lease lock with a fencing token: ADOPTED in substance. The run nonce is the fencing token; the fence is the claim rule
  at the ledger append, not the lock. It is atomic only under APPEND-ATOMIC (below).
- Claim row per request id in SQLite (UNIQUE, one transaction before emit): NOT ADOPTED here. Reasons: the dispatcher
  opens the store read-only; the h1 triggers forbid any write outside the commit; a claim table needs a store.ts schema
  change (not mine) and a writable dispatcher connection; against a file writer who drops triggers (threat (c)) a
  claim row is as deletable as a ledger line. It would give a stronger atomicity basis (SQLite locking instead of
  O_APPEND). If wanted, it is a separate store diff plus a dispatcher change; the ledger would stay as witness.
- Outbox state machine: ADOPTED in the ledger (intent = CLAIMED, done = DONE, failed/no done = IN DOUBT, resolved).

## 4. Properties by threat
| property | (a) honest operators, crashes | (b) writer keeps the schema | (c) file writer (drops triggers) |
|---|---|---|---|
| one emit per row/id across runs (claim rule) | holds (TESTED) | holds | holds for the store; a writer of the LEDGER file breaks it (assumption LEDGER-TRUSTED) |
| no silent loss (in doubt) | holds (TESTED) | holds | ledger writer can forge `done` |
| rollback: store below ledger | alarm (TESTED) | alarm | alarm, unless the writer also rewrites the ledger |
| rollback: older ledger | detected if the witness or ledgerFloor is not restored with it | same | not detected without ledgerFloor |
| row type (C-ATT-20) | n/a | blocked by CHECK | refused loudly (TESTED) |

## 5. Assumptions (by name)
APPEND-ATOMIC (one O_APPEND write of one line is not interleaved; a reader after fsync sees it and every earlier
line; local POSIX file system); LOCK-LOCAL (O_EXCL create atomic); SINGLE-HOST-PID (pid liveness only on the named
host; pid reuse only delays a takeover); LEDGER-TRUSTED (the ledger and witness files and this process are outside the
attacker's reach); LEDGER-MONOTONE (no restore of ledger + witness together without ledgerFloor); ANCHOR-MONOTONE
(sink); RECEIVER-RECONCILED (the operator's "sent"/"retry" matches the receiver); IDEMPOTENT-RECEIVER-ABSENT (no
exactly-once: a crash between the effect and `done` is indistinguishable from a crash before the effect).

## 6. Limits
- Not proved: all of this is TESTED-UNPROVED TypeScript.
- A torn tail written by a concurrently RACING run is not cut; a later line merges with it; every run then stops.
- The lock release (read, compare, unlink) is not atomic; safety rests on the claim rule, not on the lock.
- Old h1 ledgers (lines without `kind`) are refused; no migration.
- `resolveInDoubt` in the same process as a run still inside emit (nested call) is not refused.
- The witness file needs write access to the database's folder.
- Full suite.ts with the diffs: NOT RUN (heavy); script `heavy_suite_NOT_RUN.sh`.
