# HARDENING_NOTES_2: the refund-finality sink after h-sink2

Task h-sink2, Orchestrator B, night shift 2026-11-19. Target: branch `nightshift/B-trust` at `f08a21c1`.
Changed files: `ts/refund-finality/sink.ts`, `ts/refund-finality/core/store.ts`, `ts/refund-finality/dispatcher.ts`.
New files: `tests/refund-finality/regress/s_lib.ts` and seven `s_*.ts` regressions.
Deliverable: `h-sink2.diff` (SHA-256 in `h-sink2.diff.sha256`). Nothing is committed.

Classes of claims: TESTED-UNPROVED (a test passes; no proof), ASSUMPTION (named, not checked), MISSING (no defence).
Nothing in this file is MACHINE-CHECKED. The Dafny core (StepQ6, AuditStep, AuditEnd) is unchanged.

## 1. Attacker classes and claims

(a) Honest operators and crashes.
- TESTED-UNPROVED: legitimate commits succeed: zero amounts, two zero-amount refunds on one pre-state, the
  largest refund (2^63 - 1), a replay, the maximal legitimate intent text (3166 characters).
- TESTED-UNPROVED: after an honest crash the sink refuses to start while `<db>-journal` exists. The operator step
  `Sink.recover` previews the rollback on a copy, logs the head before and after, and applies it. Test: the crash
  state "file holds the unfinished commit, journal restores the file before it"; this state is BUILT, not made by a
  real kill (s_att21 recover-honest).
- ASSUMPTION FS-SYNC: with `synchronous = FULL` and `fullfsync = ON`, an acknowledged commit survives power loss.
  NOT TESTED against real power loss. The drive may still lie about its cache.

(b) A writer that keeps the schema (plain SQL through SQLite, triggers on).
- TESTED-UNPROVED (h1, unchanged): S1 to S6 refuse every out-of-order, duplicate, partial, or over-limit write
  (db_safeguards.ts: 69 PASS).
- MISSING in SQL, by construction: a row with a wrong `self` or with an unsigned token. SQLite has no hash function
  (node:sqlite 3.50.1: `sha3`, `sha256`, `sha1`, `md5` do not exist; probe in this task) and no Ed25519. Such a row
  is accepted by the triggers and refused by the audit: the store halts. Repair: section 3, item 8.

(c) A FILE writer WITHOUT an outside head (drops triggers, edits pages, recomputes the unkeyed chain; or plants files).
- TESTED-UNPROVED: a RUNNING sink halts on any change to a row it has audited (prefixSame re-reads every kept row on a
  foreign change), and never commits a second effect for an id whose row was changed behind it (C-ATT-24).
- TESTED-UNPROVED: the sink and the dispatcher refuse a planted `-journal`, `-wal` or `-shm` at open, a WAL header,
  a database with two hard links, and a header with user_version or application_id not 0 (C-ATT-21, C-ATT-23).
- NOT CLAIMED: rollback resistance. While the sink is stopped, the writer can roll back to an earlier valid log,
  delete zero-amount rows, or swap a row for another signed transition on the same pre-state (normal under the
  per-request minter rule). The restart audit accepts that log. The dispatcher sends rows after its ledger's last
  claim as they are (C-ATT-25 "none" case: r2b is sent; s_att25 records it as information).

(d) A FILE writer WITH a fresh outside head (the host follows the freshness rule, section 2).
- TESTED-UNPROVED: the restart refuses any store whose head is not exactly the persisted committed or pending head
  (deletion with recomputed chain: s_att27 z1del; C's hport2 z1del iface: exit 0).
- TESTED-UNPROVED: the dispatcher with `expectedHead` sends no row that the anchored chain does not contain, and no row
  after the anchored count (s_att25; C's hport2 d14 head: exit 0).
- TESTED-UNPROVED: in outsideHead mode the sink is the single writer: any foreign change halts it, also a validly
  signed foreign append (s_att27 single).
- Rollback resistance is claimed ONLY in this class, and only under ANCHOR-FRESH and ANCHOR-OUTSIDE (section 4).

## 2. The outside-head interface (C-ATT-27)

- `CommitResult.head`: the audited head after the call (`{count, chainHash}`), on committed, replayed, and ordinary
  rejections. Absent when the sink is halted or the decoder refused the input.
- `cfg.onHead(next)`: called inside the write transaction, after every check, BEFORE the SQLite COMMIT (ANCHOR-FIRST).
  If it throws, the transaction rolls back and commit() returns rejected ("the outside head was not persisted").
- `cfg.outsideHead = {committed, pending?}`: at start the stored head must EQUAL `committed` or `pending`. Rows beyond
  are refused (unlike the h1 `expectedHead`, which only requires the store to EXTEND the anchor; kept unchanged for
  compatibility, see the stale case in s_att27).
- Dispatcher `cfg.expectedHead`: the store must extend it; rows after `expectedHead.count` are never sent.

FRESHNESS RULE (the host's duty): (1) persist `pending = next` in onHead; (2) when commit() returns committed, persist
`committed = result.head` and clear `pending`, THEN acknowledge; (3) at the next start pass `{committed, pending}`;
(4) give the dispatcher `expectedHead = committed`. Both writes must be durable and atomic on the outside medium.
Crash windows (tested in s_att27 crash): crash before COMMIT -> store = committed -> starts; COMMIT done but not
promoted -> store = pending -> starts (that row was never acknowledged, and the dispatcher does not send it until the
host promotes it). A rollback of an acknowledged row is refused at start and by `Sink.recover`.
Cost: onHead runs while the sink holds the RESERVED lock; a slow anchor store slows every commit.

## 3. Items

1. C-ATT-24 (running sink, old row). Fix: on a foreign change, `prefixSame` re-reads rows 1..count as exact bytes,
   checks the request id columns against the kept ids, recomputes token_sha256 and the chain from genesis, and requires
   the kept chain hash; new rows are audited from the kept fold state as before. The commit path also compares the
   indexed lookup of the request id with a kept map (id -> token_sha256); a difference halts. Cost (measured, single
   runs, machine under HOL load): commit after a foreign append at 1,000 rows 87 ms (before 37 ms), at 5,000 rows
   427 ms (before 142 ms); a plain commit does no re-read. Exact residue: the re-read runs only when data_version or
   the guard values change. A raw page writer that keeps the file change counter and the guard values unchanged is not
   seen by that trigger; then only the kept id map stops a second commit for a kept id (this line is NOT exercised in
   isolation by any test). Between the check and the COMMIT the sink holds the RESERVED lock; SQLite writers wait, but
   a raw file writer ignores locks: a page write in that window is detected only by a later audit or the anchor.
2. C-ATT-25 (dispatcher swap). Why it passed: the ledger records rowHead only for CLAIMED rows; row 3 was committed but
   not yet claimed, so nothing bound it; the store audit accepts any signed, authorized transition. Fix: dispatcher
   `cfg.expectedHead` (extension required; nothing after its count is sent). Without an anchor: stated limit (class c).
3. C-ATT-27. Fix: section 2. Rollback resistance claimed only under the freshness rule.
4. C-ATT-26. Fix: intent bound = MAX_TOKEN_TEXT (8192), because the stored intent is a sub-text of a token that the
   decoder accepted (<= 8192 UTF-16 units >= code points). Arithmetic (encoding.ts bounds; SQLite length() counts code
   points): a text of <= 256 UTF-16 units is a JSON string of <= 2 + 6 * 256 = 1538 characters. intent = 11 (`{"amount":"`)
   + 19 + 13 (`","chargeId":`) + 1538 + 10 (`,"reason":`) + R + 13 (`,"requestId":`) + 1538 + 1 = 3133 + R. R = 23 for
   the longest approved reason ("service_not_delivered"): 3166 (measured by canon: 3166). R <= 1538 by encoding.ts
   alone: 4681. State text: 12 + 1538 + 13 + 19 + 36 + 19 + 2 = 1639 <= 2048 (bound unchanged). Note: a token with a
   256-unit control-character reason is 8296 units and the decoder refuses it (unchanged since v6); such a reason is not
   approved, so no legitimate commit is refused.
5. C-ATT-21 (planted files). Fix: before the first SQLite lock the sink refuses `-journal`, `-wal`, `-shm` (at the
   given and the real path), a WAL-mode header (bytes 18, 19), a non-SQLite header; it pins journal_mode = DELETE and
   reads it back; the audit checks user_version = 0 and application_id = 0. Before every write transaction: same inode,
   one link, no `-wal`/`-shm`; in outsideHead mode also no `-journal`. The dispatcher refuses `-wal`/`-shm` (a live
   sink's `-journal` is legitimate; a read-only connection cannot apply a hot journal and fails closed).
   Honest-crash policy: refuse, and require `Sink.recover` (logs before/after; refuses -wal/-shm, a rollback of more
   than one row of a valid log, a result that fails the audit or the outside head; files unchanged on refusal).
   NOT checked (decision, deviation from the request): the schema cookie. Any SQLite writer can set it back
   (`PRAGMA schema_version = N`), so it gives no protection against class c/d; and a check would turn the db_safeguards
   row "HOSTILE ... restart WITHOUT expectedHead STARTED head=3 (honest limit)" into a FAIL. The schema TEXT compare and
   integrity_check decide what the schema is.
   Detected WITHOUT DIR-EXCLUSIVE: a companion file present at open or (for -wal/-shm, and -journal in single-writer
   mode) before a write; a second hard link present at open or before a write; a replaced inode while running (NOT tested); header
   values. Detected ONLY with the outside head: a journal planted in the window between the pre-open check and the first
   lock (microseconds); a journal planted while a multi-writer sink runs (content check halts the running sink, but the
   restart without an anchor accepts the rolled-back prefix); a rollback of exactly one row that the operator accepts in
   `Sink.recover` (indistinguishable from an honest crash without the anchor); a file replaced while the sink is stopped.
6. C-ATT-23 (hard links). Fix: refuse st_nlink > 1 at open (sink and dispatcher) and before every write. NOT covered:
   bind mounts, copies, network file systems, two hosts on one file, a link made and removed between two checks.
7. Durability. Set and read back: journal_mode = DELETE, synchronous = FULL, fullfsync = ON (`Sink.pragmas()`).
   Cost measured (200 commits, single runs): 6.47 ms per commit before, 21.05 ms after. Claim: an acknowledged commit
   was handed to the drive with F_FULLFSYNC before COMMIT returned. NOT TESTED against power loss.
8. Repair. A trigger cannot refuse a wrong `self` (no SQL hash function) or an unsigned token: stated limit. Procedure
   (no in-place edit; does not weaken append-only): `Sink.validPrefix(path, cfg)` (read only) returns the audited
   prefix tokens and their head; create a NEW store at a new path with the same cfg, init, commit the tokens in order
   (all must be committed; the new head must equal the prefix head; the prefix ids stay settled); log old path, old
   file SHA-256, problem, prefix head, new path; keep the old file; the new head must equal or extend the persisted
   outside head (else acknowledged rows are lost: escalate); point host and dispatcher at the new path (same ledger).
   Tested in s_repair_prefix (wrong self; another key's signature). The "new genesis that records the old head" was not
   built: the same genesis keeps the chain and the dispatcher ledger valid; the operator log records the old head.
9. Stale sentences corrected: sink.ts (old lines 22-25: "two transitions that a faulty issuer signed"), dispatcher.ts
   (old lines 75-78: "if the issuer signs two transitions ... known limit"), dispatcher.ts line 68 ("no F_FULLFSYNC in the
   sink"). Two signed transitions for one pre-state are normal operation under the per-request minter rule.

## 4. Assumptions by name

- DIR-EXCLUSIVE: no other party can create, replace, rename or link files in the database directory.
- ANCHOR-FRESH: the host follows the freshness rule of section 2.
- ANCHOR-OUTSIDE: the outside head store is out of the file writer's reach and is not rolled back with the database.
- SINGLE-WRITER: with `cfg.outsideHead` no other process writes the store (a foreign change halts the sink).
- FS-SYNC: F_FULLFSYNC reaches stable storage. SQLITE-SEMANTICS: data_version, hot-journal rollback, RESERVED lock,
  integrity_check behave as documented. HASH/SIG: SHA-256 collision resistance; Ed25519 unforgeability; key not leaked.
- APPEND-ATOMIC, LEDGER-MONOTONE, LOCK-LOCAL, SINGLE-HOST-PID: dispatcher assumptions, unchanged.

## 5. Limits and open doubts

- No migration: the intent CHECK text changed, so a store made by `f08a21c1` fails the schema TEXT compare. STORE_FORMAT
  stays "forge-sink-h1" (db_safeguards writes that literal).
- Memory: the running sink keeps one id and one hash per row.
- `Sink.recover` relies on SQLite applying the same journal to the copy and to the real file; a file change during the
  step is detected afterwards (head compare) but the real file is then already changed.
- Not run: a real kill or power-loss test; the full suite (`tests/refund-finality/suite.ts`); p_*/k_*/x_* files
  standalone (the x_* cases run inside run.ts); the 1,000-commit timing (about 21 s with fullfsync, hol.lock present):
  script `perf/run_perf.sh <tree> commits1000 <log>` prepared, NOT RUN.
