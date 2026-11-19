# Native silicon sink: the one fresh-context review and its disposition

One review, by an agent with a fresh context, of `src/silicon_sink/sink.rs`,
`tests/silicon_sink/test_silicon_crash.py`, `tests/silicon_sink/interpose.c`
and `scripts/exit_silicon_sink.py`. The reviewer got the code, the rule
that the sink claims, and the stated limits. It did not get my results.
Date: 2026-11-19 (UTC). 32 tool calls, about 23 minutes. A full-size run
of my suite ran on the same machine during the review.

The reviewer ran the production sink by hand, wrote a short-write
interposer of its own, and compiled eleven changed copies of the sink.
It did not run the EXIT script, the full suite or the 10 GiB flood.
Section 3 is its text. Sections 1 and 2 are mine.

## 1. Result in one table

| Class | Count | Findings |
| --- | --- | --- |
| FAIL-OPEN | 1 | R1: by the letter of the rule. A refusal with code 18 left a record in the WAL, and the next start adopted it. No COMMITTED line was printed |
| HIGH | 1 | R2: the stream went on after an answer could not be written, and could end with exit code 0 |
| MEDIUM | 11 | R3 to R13 |
| LOW | 5 | R14 to R18 |

The reviewer found no path to a COMMITTED line without the two syncs,
no double record, no commit on a stale state, and no money above the
original amount. That is its reading and its small runs; it is not a
proof.

Statements of mine that were false or too strong before the review:

- "A refusal writes no record" (a comment in `sink.rs`). False for
  code 18 after the record was written (R1).
- "The real binary gives none of the bad outputs" (a comment in the
  suite). The sink itself turned a normal rejection of a short request
  into BAD_FRAME (R3).
- The record text said that the order of the durable calls held for
  all recorded commits. It was observed for one traced commit (R18).
- "No timing" in the lock case. It waits 3 seconds (R18).
- "It does not ask the sink whether a file is sound." The check after
  a kill starts the sink's recovery first (R12, R18).

## 2. Disposition (repairs in one pass; NOT reviewed again)

| Finding | Class | What I did | Checked by |
| --- | --- | --- | --- |
| R1 | FAIL-OPEN (letter) | REPAIRED. A record whose write or sync failed is cut off again, and the cut is synced: code 18 now means that nothing is committed. If the cut fails too, the new code 19 (`OUTCOME_UNKNOWN`) says that a record may stay. If the ratchet entry fails after the record is durable, the answer is 19: the record stays, nothing is dispatched, the next start adopts it. The rule is now: a refusal leaves no record, except code 19 | case `trace`: failed sync of the WAL (files unchanged, the request commits again), failed sync of the WAL and of the cut, failed write, short write of 30 bytes, failed ratchet write and sync. Changed copies `no_undo_after_failed_sync`, `ignore_wal_sync_error`, `ignore_ratchet_error` |
| R2 | HIGH | REPAIRED. An answer that cannot be written gives the new code 20 (`DISPATCH_FAILED`). `serve` ends at the first answer with a code from 17 up (`CORRUPT_WAL`, `IO_ERROR`, `OUTCOME_UNKNOWN`, `DISPATCH_FAILED`): it reads no further line | new case `dispatch` (answers with no reader: exit 20, one record of three, the request again is a duplicate). Changed copies `ignore_failed_answer`, `stream_continues_after_fault` |
| R3 | MEDIUM | REPAIRED. The read bound is the longer of the accept frame and the rejection frame, plus one byte | case `basic`: two short requests. Changed copy `short_rejection_not_read` |
| R4 | MEDIUM | REPAIRED with R1 and R2: the record of a failed sync is cut off, and the stream ends. LEFT: when the cut itself fails (code 19), a later start can adopt the record. That is what code 19 says |
| R5 | MEDIUM | REPAIRED IN PART. `init` refuses when one of the two files exists, before it makes a file. It makes the ratchet first, so a WAL never exists without its ratchet. After a failure it removes the files that it made. NOT repaired: `init` takes no lock; a KILL inside `init` can leave a folder that every command refuses until a person deletes the files; no kill point is in `init` | case `basic`: `init` beside one leftover file. Case `trace`: three failed syncs in `init` (no file stays; `init` works again). Changed copies `init_no_existence_check`, `init_keeps_files_after_failure` |
| R6 | MEDIUM | REPAIRED. After every commit the suite compares the last record (reason, request id, amount) with the request that it sent | changed copy `kind_swapped` |
| R7 | MEDIUM | REPAIRED: see R2 | case `dispatch` |
| R8 | MEDIUM | REPAIRED IN PART. Traces of `init` and of one recovery; failed syncs in `init` (3) and in the recovery (2). NOT repaired: no kill point is inside `open_ledger`, `push` or `init` | changed copies `no_recovery_wal_sync`, `ignore_recovery_sync_error`, `no_init_wal_sync`, `no_init_folder_sync` |
| R9 | MEDIUM | REPAIRED. Lines of 254, 255, 256, 257, 511, 512 and 4,096 bytes, each followed by a valid request | changed copies `oversized_skip_eats_next_line`, `line_bound_4096` |
| R10 | MEDIUM | REPAIRED. The interposer traces `ftruncate` and `close`, injects a short write, and can fail every sync from a number on. LEFT: it reports only the two ledger files, the ledger folder and stdout | case `trace` |
| R11 | MEDIUM | REPAIRED, not as proposed. The proposed repair (the holder waits after its write; the waiting process must get `STALE_STATE_HASH`) did NOT detect the reviewer's copy M11 (my run: the case passed on it, because the waiting process starts after the write). Repair that does: TWO processes wait for the same state while the holder waits before its write; after the kill of the holder exactly one of them may commit, and the other must get `STALE_STATE_HASH`. The proposed part is kept as a check of the adoption path | changed copy `lock_after_the_reads` (first run with the proposed repair: suite exit 0 on the copy; then exit 1) |
| R12 | MEDIUM | REPAIRED. After every commit the suite reads both files directly, before the sink runs again: the record, the earlier bytes, the remaining amount, the ratchet value, the COMMITTED line. After a kill it still starts the recovery first: the recovery is the thing under test there | changed copy `ratchet_one_behind` |
| R13 | MEDIUM | REPAIRED IN PART. The bundle now holds the SHA-256 of the final WAL of three cases whose bytes do not depend on timing (`basic`, `ids`, `latency`): the two runs compare bytes that the sink wrote. The literal `violations: 0` is gone. NOT repaired: the time bounds (250 ms, the owner's bound; waits of 3 s and 1 s in case `lock`) can fail on a loaded machine. A failure is then a failure of the run |
| R14 | LOW | REPAIRED. Only a kill of a process that still ran counts as a blind kill; the number of attempts is in the measurements |
| R15 | LOW | STATED. `sent.is_ok()` has no test: a stand-in cannot make the write fail before the write happens. It stays as a defensive condition |
| R16 | LOW | REPAIRED. The cut answer at point e must be a strict prefix of the right COMMITTED line |
| R17 | LOW | STATED. A pipe read error leaves a zombie until the sink ends; the wait for the lock has no bound; `state` and `replay` need write access (they repair); `init` reports `MALFORMED_ID` also for a bad amount; the conformance case uses the 22 typed fixtures only |
| R18 | LOW | REPAIRED. All seven texts are corrected |

The reviewer's changed copies: M1, M2, M3, M4, M6, M7, M8, M9 and M11
are now in the list of the EXIT script (49 changed copies in all),
each with the case that must fail and a part of the failure message
that must appear. M5
(`sent` not checked) is not in the list (R15). M10 was detected
already and is close to M11. The five copies that the reviewer
proposed and did not test are in the list too.

Left open after this pass: the repairs had no second review (the
directive allows one). Codes 19 and 20 are new; they were not in the
specification that the owner approved. A fault of the suite that I did
not think of can still hide a fault of the sink.

## 3. The review text (verbatim; the home folder and the session scratch folder are replaced)

Abbreviations: `B=<forge>/build/silicon`, `S=<session scratch folder>/review`. All files I wrote are in `S`. I changed nothing in the repository (`git status` checked at the end; refund binary still `b8ed5ec2…`).

### 1. Counts

| Class | Count |
|---|---|
| FAIL-OPEN | 1 (R1: by the letter of the rule; no COMMITTED line is printed) |
| HIGH | 1 (R2) |
| MEDIUM | 11 (R3–R13) |
| LOW | 5 (R14–R18) |

I found no path to a COMMITTED line without a prior successful WAL sync and ratchet sync. I found no double record, no commit on a stale state, and no money above the original. That is from reading plus the small runs below; it is not a proof.

### 2. Findings

**R1. FAIL-OPEN (letter of the rule). A refusal with code 18 changes the WAL, and the refused request becomes a committed effect.** `sink.rs:181-187` (`?` after the first WAL byte), `sink.rs:125-130` (adoption), docstring `sink.rs:32`.
RAN, production sink, three fault shapes:
- Failed WAL sync: `printf '%s (charge-1 rq-A 100 100 True True True 40 returned_item)\n' $H | DYLD_INSERT_LIBRARIES=$B/interpose.dylib SINK_FAIL_SYNC=1 $B/native_sink e3 serve $B/bin/refund` gave `REJECT 18 IO_ERROR: Input/output error (os error 5)`, exit 18. WAL went from 64 to 128 bytes. Then `state` gave `STATE 1 … charge-1 100 60` and `replay` gave `EFFECT (refund-result-v1 True 40 returned_item charge-1 rq-A 1)`.
- Failed ratchet write (`SINK_FAIL_WRITE=2`), same line twice in one process: `REJECT 18 … No space left on device`, then `REJECT 14 DUPLICATE_REQUEST_ID`, exit 14. No COMMITTED line ever; `replay` prints the effect.
- Short write (my interposer `$S/shortwrite.c`: 30 bytes really written, then ENOSPC): `REJECT 18`, exit 18, WAL 94 bytes. The next `state` cut it to 64 and appended to the ratchet.

Why it matters: the rule says a refusal changes no file and a record exists only if `sync_all` returned Ok. A caller that reads 18 as "nothing happened" is wrong. The suite requires this behaviour (`test_silicon_crash.py:673-675`, `:689`), so the rule text and the suite disagree.
Repair: on any error after the first WAL byte, do `set_len(old_len)` plus sync. If that fails, print a distinct answer (for example `REJECT 19 OUTCOME_UNKNOWN`) and end the process. Correct `sink.rs:32` and the rule text, or change suite lines 673-675 and 689.

**R2. HIGH. `serve` continues after a failed dispatch write, and can exit 0.** `sink.rs:199-207`, `:218`.
RAN `python3 -B $S/e5.py` (three pipelined valid requests; hashes computed in the script):
- stdout a pipe with no reader: exit 18, WAL 256 bytes, `STATE 3 … 100 70`, `REPLAY 3`. Three commits, zero dispatches.
- stdout a full non-blocking pipe for requests 1 and 2, drained before request 3: exit **0**. The consumer got only `COMMITTED 3 …rq-2…`. Records 1 and 2 are committed and were never dispatched.

Condition: stdout must fail (dead consumer, or non-blocking and full). Not run: a partial write to a full file would also put the next answer on the same line.
Repair: return from `serve` with IO_ERROR at the first failed answer; add a suite case with a closed stdout.

**R3. MEDIUM. The real binary's rejection is reported as BAD_FRAME 11 when the request is short.** `sink.rs:158` reads `expect.len()+1` bytes; the rejection frame is 37 bytes.
RAN: `$B/native_sink e2 init c 5`, then `<hash> (c r 5 5 True True True 1 x)` gave `REJECT 11 BAD_FRAME`. The binary run directly printed the exact 37-byte rejection frame. Reason `xxxx` gave `REJECT 10`; `xxx` gave 11. It happens when the lengths of amount, reason, charge and request sum to 6 or less. No commit is possible there (approved reasons are 13 bytes or more). The earlier contract (D5) used `max(len(accept), 37)`. `test_silicon_crash.py:406` says the real binary gives none of the bad outputs; here the sink calls a normal rejection bad.
Repair: `take(expect.len().max(REJECT_FRAME.len()) as u64 + 1)`; add a test with 1-byte ids and reason.

**R4. MEDIUM. A record whose own sync failed is adopted at the next start.** `sink.rs:125-130`. READ, not run beyond R1. Recovery cannot tell "killed at c" from "sync returned an error". I did not check what macOS does with the pages after a failed F_FULLFSYNC. A later commit is dispatched on top of that record.
Repair: as R1; never continue the stream after a failed sync.

**R5. MEDIUM. `init` takes no lock, is not crash-safe, and a refused `init` can create a live ledger.** `sink.rs:222-233`.
RAN: directory with only `ledger.wal`: `state` exit 18, `init` again exit 18 (`File exists`). Empty WAL: `state` 17, `init` 18. Both are dead for good. Directory with only an old `ledger.epoch`: `init charge-9 7` gave `REJECT 18 … File exists`, yet created `ledger.wal`; `state` then gave `STATE 0 … charge-9 7 7`, exit 0. No kill point and no test covers `init`.
Repair: build both files under temporary names and rename, or let `init` finish a half-made ledger.

**R6. MEDIUM. The suite never compares the stored kind byte with the request's reason.** `check_ledger` (`:215-231`) compares the sink's `replay` with the sink's own WAL. RAN: copy M1 passes (section 3). On it `replay` prints `service_not_delivered` for a commit of `duplicate_charge`.
Repair: compare `wal['effects']` with the list of requests the test sent.

**R7. MEDIUM. No test breaks stdout.** RAN: copy M2 (exit 0 when the answer could not be written) passes basic, trace, frames.

**R8. MEDIUM. Recovery and `init` durability are not observed.** `trace_of` runs only on clean ledgers; no fault is injected in recovery; no kill point is in `open_ledger`, `push` or `init`. RAN: M3 (no WAL sync in recovery) and M6 (no syncs in `init`) pass. The stock interposer trace of M3's recovery shows no `fullfsync ledger.wal`.

**R9. MEDIUM. The 255/256-byte boundary has no test.** RAN on production: lines of 255, 256, 257 bytes then a valid request behave correctly. RAN: M4 (a 255-byte line eats the next line) and M8 (`MAX_LINE = 4096`) pass basic and flood.

**R10. MEDIUM. The interposer injects only all-or-nothing write failures and traces three calls.** `interpose.c:76-81` writes nothing on failure; a short write is never tested with the suite (R1 shows it leaves bytes). `ftruncate` is not hooked: a recovery that cut 4 bytes showed no event. The filter at `test_silicon_crash.py:634` drops events for any other file name.

**R11. MEDIUM. The `lock` case cannot see a lock taken too late.** The holder waits at point a and never writes (`:710`). RAN: M11 (both files read BEFORE `lock()`) passes lock, trace, rollback. Only crash catches it: `kill 1 at point b: exit codes of the other processes [0, 0, 0]` (three commits where one is allowed). The EXIT script pairs lock mutants with the `lock` case only.
Repair: hold at point c and require the waiter to get STALE; add M11 to `MUTANTS`.

**R12. MEDIUM. `check_ledger` runs the sink's recovery before it reads the files** (`:217`). The on-disk state right after a commit is never read directly. RAN: M7 (commit ratchets the old epoch) is caught only by side effects (`trace`: system calls of a stale request; `basic`: "second zero amount … a refusal changed the ledger files").

**R13. MEDIUM. The "two bundles byte-identical" check is close to vacuous, and time bounds are tight.** READ. The bundle holds literals and counts fixed by the test code (`'violations': 0` at `:829`, `fixtures=22` at `:395`, `exit_code: 0`), so two passing runs must be equal unless a source changes between them (`exit_silicon_sink.py:336`). READ in `$B/suite/attempt-0001/measurements.json`: latency p99 186.9 ms, max 246.4 ms, bound 250 ms. Load average was 27 during my runs. `lock` proves blocking with 3.0 s and 1.0 s waits (`:715`, `:722`).

**R14. LOW.** READ, same file: 15 of 100 blind kills hit a process that had ended; the record says `blind_kills: 100`.
**R15. LOW.** `:437` ("does not read its input, exits 1") passes because of exit 1, not `sent.is_ok()`. RAN: M5 passes frames. The check is almost unobservable.
**R16. LOW.** `:784`: the partial output at point e is not checked to be a prefix of the right COMMITTED line. READ.
**R17. LOW.** READ: a pipe read error at `sink.rs:158-159` returns before `wait()` (zombie). The lock wait has no bound. RAN: `state` and `replay` on read-only files give exit 18. `init c 01` reports MALFORMED_ID for an amount. Conformance uses only `['typed']` (`:338`); 11 of 22 fixtures never reach the binary.
**R18. LOW. Overclaims.**
- `sink.rs:32` "A refusal writes no record": false (R1).
- `exit_silicon_sink.py:119-121`: "printed a COMMITTED line only after both F_FULLFSYNC calls returned 0" for all recorded requests, kills and races. The order is observed for ONE commit (`:651-655`). It also omits that a REJECT 18 can leave a committed record.
- `test_silicon_crash.py:659` "A refusal makes no write … and no sync": RAN, a STALE refusal on a ledger that needed recovery changed the ratchet (12 to 24 bytes).
- `:9-10` "does not ask the sink whether a file is sound": it runs recovery first.
- `:706` "No timing".
- `exit_silicon_sink.py:287`: the recorded `argv` is not the argv that ran.
- `sink.rs:111` "Every command starts here": not `init`.

### 3. Changed copies (sources in `$S/mut/*.rs`; `rustc -D unsafe_code -C opt-level=3`, with and without `--cfg kill_points`; suite with `--quick`)

| Copy | Change | Cases run | Result |
|---|---|---|---|
| M1 kind_swapped | kind byte `b'1' + [1,0,2][kind]` | basic, trace, ids, latency | NOT detected: 4 of 4 PASS |
| M2 ignore_stdout_error | `answer` returns `code` on a write error | basic, trace, frames | NOT detected: 3 of 3 PASS |
| M3 no_recovery_wal_sync | no `wal.sync_all()` in `open_ledger` | trace, rollback, lock, crash | NOT detected: all PASS |
| M4 skip_eats_next_line | `if long && skip_until` | basic, flood | NOT detected |
| M5 sent_not_checked | no `&& sent.is_ok()` | frames | NOT detected |
| M6 no_init_sync | no WAL sync, no directory sync in `init` | basic, rollback | NOT detected |
| M8 max_line_4096 | `MAX_LINE = 4096` | basic, flood | NOT detected |
| M11 lock_after_both_reads | `lock()` after both reads | lock, trace, rollback; crash | lock, trace, rollback PASS; crash FAILS (detected) |
| M10 lock_after_wal_read | `lock()` after the WAL read only | lock, trace | detected: `FAIL lock the waiting state command must end after the kill` |
| M7 ratchet_off_by_one | commit pushes `l.epoch` | trace; basic | detected in both |
| M9 reject_code_for_dirty_exit | `(_, REJECT_FRAME)` gives code 10 | frames | detected: `rejection frame, exit status 1: exit 10, expected 11` |

For M1 to M8 I did not run conformance, recovery or race (above the process budget). By reading, they hold no check that would catch them.
Proposed, not tested, predicted NOT detected: no `canonical_id(id)` in `scan`; ratchet floor `.last()` instead of `.max()`; no `amount <= MAX_MONEY` for the genesis record; lock released before the ratchet push; `let _ = wal.sync_all()` in recovery.

### 4. Not checked

- Power loss, a real full disk, real fsync errors (interposers only).
- The full suite, the 10 GiB flood, and the cases conformance, recovery and race on any copy; the EXIT script itself.
- A binary that hangs or floods stderr (stated limit).
- `Command` PATH lookup for a binary name with no slash; non-APFS file systems; whether the lock is released before the dispatch (no hook observes it).
- Descriptors: one run showed the binary inherits only what the sink's launcher passed (0 1 2 and my extra 9); no ledger descriptor leaked. One run only.
- Recovery with torn WAL tail, ratchet behind and torn ratchet entry together: one hand run, correct.
