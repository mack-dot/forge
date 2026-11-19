# h-sink3 hardening notes (night shift 2026-11-19, Orchestrator B)

Base: nightshift/B-trust at 370ff65c. Deliverable: `h-sink3.diff` (SHA-256 in `h-sink3.diff.sha256`); file hashes in
`files-sha256.txt`. Owned and changed: `ts/refund-finality/sink.ts`, `ts/refund-finality/core/store.ts`,
`ts/refund-finality/dispatcher.ts`; new `tests/refund-finality/regress/s3_*.ts`, `d3_*.ts`. Nothing else. Not committed.
Everything below is TESTED-UNPROVED TypeScript unless marked otherwise. Nothing here is MACHINE-CHECKED.

## 1. What changed

1. **Journal classifier (C-ATT-33).** `core/store.ts classifyJournal(path)` returns `none`, `not-hot` or `hot`.
   The start-up refusal names the class. `Sink.recover` has two paths:
   - **Not hot:** previews on copies, then removes the journal under a RESERVED lock.
   - **Hot:** previews the rollback as before. The depth rule (item 2) now applies.

   The start never removes a journal itself (decision: section 3).
2. **Depth rule (C-ATT-34).** `Sink.recover` reports success only when it can prove that no acknowledged commit is lost:
   - (i) "before" passes the audit, and "after" equals "before", or "after" equals "before" without its last row; or
   - (ii) `cfg.outsideHead` is given, and "after" EQUALS `outsideHead.committed` or `outsideHead.pending`.

   Every other case is refused. This includes a live file that fails the audit when no outside head is given.
   `cfg.expectedHead` does not authorise a rollback, because it is only a lower bound.
3. **In-transaction file check (C-ATT-35).** `commit()` checks the inode, the links, `-wal` and `-shm` again at two
   points:
   - inside the write transaction, after `onHead` and before COMMIT. On a mismatch it rolls back and halts.
   - after COMMIT, before the acknowledgement. On a mismatch it does not acknowledge and halts.
4. **Ledger hash chain (C-ATT-36).**
   - Each new ledger line carries `prev`, the chain hash of the complete lines before it.
   - The reader computes c_i = SHA-256("forge-refund-dispatch-ledger-v1/line\n" + c_{i-1} + "\n" + line bytes).
   - The dispatch witness gains `{lines, lastHash, ledgerId}`. `cfg.ledgerFloor` and `result.ledgerHead` gain
     `{lines, lastHash}`. These are added optional fields. No existing field changes meaning.
   - The witness is written at five points: after a claim (as before), after `done`, after `failed` (best effort),
     after `resolveInDoubt`, and at the first binding or upgrade.
   - `resolveInDoubt` now checks the witness first.
5. **File identity (C-ATT-37 "case").** The witness names this ledger when one of these is true:
   - the resolved path text is equal; or
   - the device and inode are equal AND the ledger has exactly one link.

   The second rule accepts another letter case and the /System/Volumes/Data firmlink. It does not accept a second hard
   link.

## 2. Classifier rule and its source

- **Source.** The SQLite file-format document (sqlite.org/fileformat2.html, section 4.1 "The Rollback Journal") and the
  pager's hot-journal test (pager.c `hasHotJournal`), as known to the author. These were not re-read from the source
  during this task (ASSUMPTION: my memory of them is correct).
- **Hot condition.** A journal is hot, and SQLite rolls it back at the next shared lock, if and only if all four of these
  are true:
  - (H1) the journal exists;
  - (H2) no connection holds RESERVED or a higher lock;
  - (H3) the database file is not empty. If it is empty, SQLite deletes the journal without playback.
  - (H4) the first journal byte is not 0. A zero-length file reads as 0.
- **Header format.** The magic is d9 d5 05 f9 20 a1 63 d7. Then come nRec, the nonce, the initial page count, the sector
  size and the page size, each 4 bytes big-endian.
- **Why an honest crash leaves a zero header.** With synchronous = FULL, SQLite writes the header with zero magic and a
  zero nRec. It writes the magic only at the journal sync, just before it writes database pages. A crash before that
  point leaves a zero first byte, and the database still holds only committed pages.
- **The classifier.** `not-hot` means: the database size is above 0, and either the journal size is 0 or its first byte
  is 0. Every other present journal is `hot`, which means SQLite acts on it. This class also covers a non-zero first
  byte without the magic: SQLite deletes such a journal and plays nothing back.
- **H2.** The classifier cannot see locks. The removal step takes RESERVED itself (BEGIN IMMEDIATE). It then re-reads the
  journal and requires the same bytes before it unlinks the journal and syncs the directory.
- **Empirical cross-check.** `s3_journal_classifier.ts` ran against the SQLite of Node v24.3.0. It used 156 generated
  journals:
  - zero length; all zero (7 sizes); 60 random tails with a zero first byte;
  - zero byte + magic remainder + records; a zeroed header before valid records; a zeroed magic only;
  - a valid rollback; magic with nRec 0 at the same size; magic with nRec 0 and truncation; nRec 0xffffffff;
  - 60 random journals with a non-zero first byte; short magic prefixes; 15 single-byte journals;
  - an empty database with a zero journal, and an empty database with a magic journal.

  Result: 156 of 156 agree. Classifier `not-hot` <=> SQLite left the journal byte-equal and the database byte-equal.
  H2 case: a reader ignored a valid hot journal while another connection held RESERVED.
  Log: `logs/after_s3_journal_classifier.log` (exit 0). On the unfixed tree: exit 1, because there is no classifier.
- **Not tested:** a hot journal that names a missing super-journal; other SQLite builds or versions.

## 3. Decision: no automatic removal at start

The start keeps refusing every `-journal`. It keeps the text prefix "companion file(s) present" and now appends the
class. The reasons:

- The pre-lock check stays as it is, so the C-ATT-21 window does not grow.
- Every journal leaves through one logged operator step that does the preview on copies.
- s_att21 and the suite prefixes stay unchanged.

The cost: after a not-hot crash, the operator must run Sink.recover once. That step then always succeeds while the
store is intact (s3_att33: onhead, zero512, zerolen).

## 4. Claims per attacker class

| item | (a) honest crashes / operators | (b) writer keeps schema | (c) file writer, no key | (d) c + outside head (FRESHNESS RULE) |
|---|---|---|---|---|
| C-ATT-33 not-hot journal | served after Sink.recover (TESTED: one real SIGKILL inside onHead; planted zero / zero-length) | n/a | a planted not-hot journal cannot change the store; removed only after the preview | same |
| C-ATT-21 planted hot journal | n/a | n/a | start refuses; recover refuses more than one row (TESTED) | recover needs after = committed/pending |
| C-ATT-34 deep rollback | torn live file + no outside head: REFUSED (a false rejection, the stated cost); with outside head: recovered (TESTED with a stand-in for a torn file) | n/a | refused (TESTED: deep, deep-stale) | only the exact outside head is accepted |
| C-ATT-35 inode swap during commit | n/a | n/a | not acknowledged when the swap happens before COMMIT or before the post-COMMIT check (TESTED); window: see section 6 | same |
| C-ATT-36 lone ledger restore after "retry" | alarm, nothing sent (TESTED: attack, resolve) | n/a | LEDGER-TRUSTED | ledger + witness restored: caught by `ledgerFloor` with `{lines, lastHash}` (TESTED) |
| C-ATT-37 case / firmlink | runs (TESTED) | n/a | n/a | n/a |
| C-ATT-37 store hard link | alarm (TESTED; already closed at 370ff65c by the h-sink2 st_nlink check) | n/a | a MOVED store + a new ledger + newLedgerH0 sends again (INFORMATION in d3_att37) | same |
| C-ATT-19 full restore without floor | NOT closed (stated limit; a7 nofloor exit 1) | | | closed with floor (a7 floor exit 0) |

## 5. Assumptions (by name)

- **SQLITE-HOT-RULE.** The SQLite of this Node follows H1–H4. This rests on 156 tested cases, not on a proof.
- **DIR-EXCLUSIVE.** No other party creates, replaces, renames or links files in the database directory. Without it:
  - the pre-lock window of C-ATT-21 stays open;
  - the C-ATT-35 windows in section 6 stay open;
  - the moved-store case of C-ATT-37 stays open.
- **NEW-LEDGER-DECLARED.** `cfg.newLedgerH0` is set only for an intended new ledger. The moved-store case of C-ATT-37
  rests on this.
- **FRESHNESS RULE** (sink.ts). Every authorisation by an outside head depends on it.
- The h-dispatch assumptions stay unchanged: LEDGER-TRUSTED, APPEND-ATOMIC, LEDGER-MONOTONE (now only for a restore of the
  ledger AND the witness without a floor), LOCK-LOCAL, SINGLE-HOST-PID, RECEIVER-RECONCILED and
  IDEMPOTENT-RECEIVER-ABSENT.

## 6. Limits

- **C-ATT-35 remaining windows.** A rename can still land at one of these points:
  - after the post-COMMIT check and before the host persists `result.head`. The row is then acknowledged but exists
    only in the unlinked inode. The next commit halts.
  - inside SQLite's COMMIT itself.

  An outside head detects the first case at the next restart.
- **C-ATT-34 cost.** An honest crash that leaves a torn live file (a kill between page writes after the journal sync) is
  refused unless `cfg.outsideHead` is given. The window is small, and its rate is MEASURED ONLY BY THE NOT-RUN kill
  regression (counter `noAnchorRecoverRefused`).
- **Ledger chain and races.** Two runs can append at the same time only after a person removes a live lock. Their lines
  can carry the same `prev`, and the reader accepts this through the sibling rule. This sibling path is NOT TESTED
  (MISSING). Three or more racers that saw different stale states stop every run (fail closed).
- **Witness after done.** The witness write after `done` is best effort. If it lags, a restore to the point between the
  claim and `done` shows the row as in doubt. Nothing is sent.
- **Full restore of everything without a floor.** NOT closed. See C-ATT-19.
- **Recover-step window.** Between the classification and SQLite's shared lock in Sink.recover, a planted hot journal
  could be applied by SQLite. The step then refuses, because the journal changed or the database changed, but the
  database is already rolled back. This is the same class as the C-ATT-21 pre-lock window (DIR-EXCLUSIVE).

## 7. Ledger format change: effect on other tests

| test | fixed tree | unfixed tree |
|---|---|---|
| every `p_*.ts` in modes a, b, c | exit 0 | exit 0 |
| `p_timeout_retry` mode c (the control) | exit 1 | exit 1 |

The light suite probe shows the same 24 rows and 0 failed on both trees. A pre-chain ledger is accepted as a prefix (d3
`migrate`). suite.ts line 673 appends a line without `n`. That line is still refused, for the same reason as before.
