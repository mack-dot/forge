# Native silicon sink (goal 19): a refund boundary without Node, V8, npm and SQLite

CURRENT none. Stage 9 deferred. M1 open. Stage 12 unauthorized.
`end_to_end=false`. Not a stage. No protected file changed. Not gate
evidence.

This is a FINITE TEST of a new, unproved program on one machine (macOS
27.0.1, arm64), on 2026-11-19 (UTC). It is not a proof of `sink.rs`. It
is not a compiler proof. It adds nothing to M1 and closes no M1 item.
A SIGKILL is not a power loss.

Directive and owner decisions: [OWNER_TEXTS.md](OWNER_TEXTS.md).
Review and its disposition: [REVIEW.md](REVIEW.md).
Entries: `unsure.md` U700 to U708.

## 1. What was built

```text
request line on stdin
  -> src/silicon_sink/sink.rs (Rust, std only, #![forbid(unsafe_code)])
  -> one private process of the CakeML refund binary b8ed5ec2...7bb8, over three anonymous pipes
  -> exact decision frame (byte equality), exit code 0, empty stderr
  -> exclusive flock on ledger.wal: ratchet, request id, state hash, state values
  -> one write of a 64-byte record -> fcntl(F_FULLFSYNC)
  -> one 12-byte ratchet entry in ledger.epoch -> fcntl(F_FULLFSYNC)
  -> lock released -> one COMMITTED line on stdout (the dispatch)
```

No JavaScript, no Node, no V8, no npm package and no SQLite is in this
path. The Slice 1 stack is unchanged; it is not removed and not used
here.

| File | Lines | Role | In the trusted base of a commit |
| --- | --- | --- | --- |
| `src/silicon_sink/sink.rs` | 248 | the sink: parser of one line format, caller of the binary, WAL, ratchet, recovery | yes |
| `proposals/forge2-m1-conformance/artifacts/refund-arm64-macho` | 238,776 bytes | the refund decision (CakeML, compiled in HOL4 on 2026-11-04); not changed | yes |
| `tests/silicon_sink/test_silicon_crash.py` | 1,177 | the fault-injection suite, with its own reader of the two files | no |
| `tests/silicon_sink/interpose.c` | 148 | test-only `dyld` interposer: system-call order, injected faults, a forged binary | no |
| `scripts/exit_silicon_sink.py` | 408 | EXIT script: source rules, builds, suite, changed copies, record | no (it does the launcher's duty: it hashes the binary) |

Lines of Rust added: 248 (215 code lines, 32 comment lines, 1 blank
line). External crates: 0. `unsafe`: 0, refused by
`#![forbid(unsafe_code)]` and by `-D unsafe_code`; a copy with one
`unsafe` block does not compile (control, exit 1). Cargo is not used.

The 248 lines are in a hand-made compact layout: lines up to 152
characters, short functions on one line, four or five constants on one
line. `rustfmt` with its default settings prints the same code on 521
lines. The owner's limit ("up to 250 lines") is met for the file as
written. It is NOT met for the `rustfmt` layout. The owner was asked
after the merge and answered "Final as they are" (text 6 of the
owner's texts).

Record of `ledger.wal` (64 bytes, little-endian):

| Bytes | Field |
| --- | --- |
| 0 to 2 | magic `FSW` |
| 3 | kind: `G` genesis; `1`, `2`, `3` = `duplicate_charge`, `service_not_delivered`, `returned_item` |
| 4 to 11 | epoch: 0 for the genesis record; each next record the previous + 1 |
| 12 to 27 | pre-state hash: FNV-1a-128 of the previous record (zero in the genesis record). NOT cryptographic |
| 28 to 51 | request id, 1 to 24 bytes of `[A-Za-z0-9_-]`, NUL-padded (genesis: the charge id) |
| 52 to 59 | amount in minor units (genesis: the original amount) |
| 60 to 63 | CRC-32/IEEE of bytes 0 to 59 |

`ledger.epoch` (the ratchet) holds 12-byte entries: epoch and CRC-32.

Exit codes: 0 COMMITTED, 2 usage or no request, 10 CAKEML_REJECTED,
11 BAD_FRAME, 12 MALFORMED_ID, 13 STALE_STATE_HASH,
14 DUPLICATE_REQUEST_ID, 15 EPOCH_REGRESSION, 16 MALFORMED_REQUEST
(also an oversized line), 17 CORRUPT_WAL, 18 IO_ERROR (nothing is
committed), 19 OUTCOME_UNKNOWN (a record may stay; nothing was
dispatched), 20 DISPATCH_FAILED (the answer line could not be written;
a commit of that line stays committed). `serve` reads no further line
after an answer with a code from 17 up. Codes 19 and 20 come from the
review; they were not in the approved specification.

## 2. Actual results

| EXIT command/check | Actual exit/result | Result |
| --- | --- | --- |
| Phase 1 recon (read-only; scratch folder only): `shasum`, `file`, `lipo`, `codesign` on the tracked binary; `rustc -V` |0 each|SHA-256 `b8ed5ec2…7bb8`; thin arm64 Mach-O; the tracked file has mode 644, so a private 0700 copy runs; `rustc 1.92.0 (ded5c06cf 2025-12-08)` |
| scratch probe (binary run time, `File::lock`, `sync_all`), attempts 1 to 3 |panic; stopped by me; 0|attempt 1: the tracked file is not executable; attempt 2: my own lock test blocked itself; attempt 3: 800 of 800 exact accept frames, run of the binary at least 3.8 ms, `sync_all` at least 2.5 ms |
| scratch probe of a `dyld` interposer, attempts 1 and 2 |not built; 0|attempt 1: `cc` in this shell is not the compiler; attempt 2 (`/usr/bin/cc`): the call `fcntl(F_FULLFSYNC)` is seen and can be made to fail |
| `rustc -D unsafe_code -C opt-level=3 src/silicon_sink/sink.rs -o build/silicon/native_sink`, first version |1; then 0|attempt 1: `TryInto` is not in scope in the default edition (2015), and two `const` lines of mine were not Rust. Then 309 lines; reduced in steps to 249 |
| first runs of the suite (reduced size) |1; 0|run 1: 1 of 3 cases: two faults of my tests, and the sink gave code 16 for an id with a byte that is not UTF-8 (changed to 12). Run 2: 12 of 12 |
| `scripts/exit_silicon_sink.py --case build` (before the review) |0|249 lines; the copy with an `unsafe` block: compile exit 1 |
| `--case mutations`, attempt 1 (before the review) |0|the suite failed on 30 of 30 changed copies |
| `--case suite`, attempt 1 (before the review; the reviewer's runs and a HOL job of another session used the machine) |0|12 of 12 cases; latency p50 24.3 ms, p99 186.9 ms, max 246.4 ms: close to the bound |
| the one fresh-context review |1 FAIL-OPEN by the letter of the rule; 1 HIGH; 11 MEDIUM; 5 LOW|no path to a dispatch without the two syncs was found ([REVIEW.md](REVIEW.md)) |
| after the repairs (one pass): the suite, reduced size, runs 1 and 2 |1; 0|run 1: 12 of 13: my expectation of the order of two `close` calls after a refusal was wrong; run 2: 13 of 13 |
| `--case mutations`, attempts 2 to 5 (after the repairs) |1; 1; 1; 0|attempts 2 and 3: a copy was detected, but with another failure message than the one I had named for it; attempt 4: the copy `lock_after_the_reads` was NOT detected (the lock case as the reviewer proposed it passed on it); the lock case was repaired; attempt 5: 49 of 49 |
| `--case evidence`, attempt 1 (final) |0|build, 13 of 13 cases, 49 of 49 changed copies, twice; the two bundles are byte-identical; SHA-256 `1f569fcf…932c` |
| any HOL, Holmake or Dafny process; Stage 7; Stage 9; Stage 10 |NOT RUN|not part of this work |
| the scratch-clone regression; the push; the pull request; the hosted gate |see section 10|run after the commit of this report |

Final bundle: `records/evidence.json`, SHA-256
`1f569fcfc4c87fbeb8d787cee687eb74acde8200c9350d8f0a5959b8cd1c932c`.
Measurements of the two runs: `records/measurements-run-1.json` and
`records/measurements-run-2.json` (not in the bundle).

What the thirteen cases of the suite did in the final run:

| Case | Result (from the bundle) |
| --- | --- |
| `basic` | 7 commits; 62 malformed lines refused; false state claims, old hashes, repeated ids, a second `init`, `init` beside a leftover file, line lengths 254 to 4,096; zero amounts; MaxMoney |
| `conformance` | the 22 HOL-written fixtures: 5 committed with the HOL-written bytes, 6 rejected by the binary, 11 refused by the sink's own grammar before the binary runs; 270 boundary vectors: 66 committed, 204 rejected by the binary, as a reference predicate says |
| `frames` | 28 stand-ins for the binary (cut, longer, two frames, other id, amount, reason or charge, exit status 1 and 255, text on stderr, a signal, endless output): only the exact frame with a clean exit commits |
| `ids` | 77 refusals of ids with NUL, control bytes, Unicode spaces, quotes, other marks, 25 bytes; 13 ids that look alike (`rq-1`, `RQ-1`, `1`, `01`, `001`) are 13 different ids, each single-use |
| `recovery` | 138 torn tails cut; 2,048 single-bit changes: every one refused (CORRUPT_WAL, or EPOCH_REGRESSION for the last record); cut, exchanged and replaced records refused. LIMIT observed: a rewritten suffix with a recomputed chain is accepted |
| `rollback` | an older WAL with the present ratchet: 9 of 9 requests refused, also `state` and `replay`. LIMIT observed: both files restored together are accepted; a request on the later hash is then refused, the rolled-back refund commits again |
| `trace` | system-call order of `init`, of one commit and of one recovery, as required; 11 injected faults; the loader variable does not reach the binary |
| `dispatch` | answers with no reader: exit 20; one record of three; no further line read |
| `lock` | two processes wait while a third holds the lock; after its kill exactly one commits |
| `crash` | 120 SIGKILLs at six points (20 each) and 100 SIGKILLs of a running process at random times; after each: recovery, both files read by the suite, the interrupted request again |
| `race` | 100 processes for one balance, 3 rounds: 1 commit and 99 times STALE_STATE_HASH each; 1 round with amount 0: the same; 1 round with one request id; 1 round for the last unit |
| `flood` | 10,737,418,240 bytes with no line end into the sink: one OVERSIZED answer, then the request on the next byte commits. The same flood into the binary alone: no authorization, exit status not 0 |
| `latency` | 200 commits in one stream |

## 3. The target formula, conjunct by conjunct

`Committed(e) ==> SpecCleared(e) /\ AcceptedByCakeMLARMv8Binary(e) /\
CASMatched(e) /\ FreshRequest(e) /\ MonotonicEpoch(e) /\
DurableWalFsync(e)`

| Conjunct | What stands behind it in this pipeline | Class |
| --- | --- | --- |
| `SpecCleared(e)` | NOT enforced at run time. The binary implements the HOL definition `eligible_def`. The approved refund spec is linked to this binary only by the finite test of Wave Gate 1 (bundle `f55391da…`, pinned by digest in the EXIT script; not run again here) | tested elsewhere on a finite corpus; not proved; not checked by the sink |
| `AcceptedByCakeMLARMv8Binary(e)` | the sink commits only after the process it started ended with exit code 0, empty stderr and exactly the one accept frame of the request. That the started file is `b8ed5ec2…` is checked by the EXIT script, not by the sink | code, finite tests (stand-in binaries, 22 HOL-written fixtures, 270 boundary vectors); binary identity is a launcher duty |
| `CASMatched(e)` | under the lock: the request's state hash is the hash of the last record, and its charge, original and remaining amounts are the values folded from the WAL | code, finite tests (races of 100 processes; false claims) |
| `FreshRequest(e)` | under the lock: the request id is in no earlier record. Ids are raw bytes, not folded, not read as numbers | code, finite tests |
| `MonotonicEpoch(e)` | each record has the epoch of its position; the WAL is refused when it is shorter than its ratchet | code, finite tests. LIMIT: a restore of BOTH files is not detected |
| `DurableWalFsync(e)` | the COMMITTED line is written only after `fcntl(F_FULLFSYNC)` returned 0 for the WAL and then for the ratchet | observed at the system-call boundary with an interposer; a failed sync was injected. That the drive keeps the data is an ASSUMPTION |

Who writes the request line supplies the three flags (refund enabled,
request open, response is a candidate), the amount and the reason. The
sink does not know whether a flag is true. This is the interface of
the M1 program; it is the same trust as for the host in
`spec/refund/protocol.md`.

## 4. Trusted base: the Slice 1 stack and the native sink

"Trusted" means: a defect there can produce a wrong commit or a wrong
effect, and nothing in the path checks it.

| Part | Slice 1 stack (Node) | Native silicon sink |
| --- | --- | --- |
| Refund decision | `impl/Refund.dfy` and `impl/RefundFinality.dfy`: source proofs R1 to R5 and P1 to P4 (Dafny). The compiled JavaScript (1,745 lines) is not proved | the CakeML binary `b8ed5ec2…` (238,776 bytes): machine-model theorems with open premises (M1 open). Linked to the approved spec by a finite test only |
| Decision to sink | Ed25519 token: the sink holds only the public key | no token. The sink starts the binary itself and reads its pipe: one trust domain |
| Sink code | `ts/refund-finality/sink.ts`, `encoding.ts`, `minter.ts`, `dispatcher.ts`, `proposer.ts`: 525 lines of TypeScript, not proved | `sink.rs`: 249 lines of Rust, not proved |
| Language run-time | Node 24.3.0 (one executable of 89,025,440 bytes), V8 13.6, the Dafny JavaScript run-time, `tsx` | Rust standard library, linked into one executable of 560,088 bytes; the CakeML basis C code inside the refund binary |
| Compiler from source to what runs | Dafny to JavaScript (not proved), TypeScript by `tsx`/esbuild, V8 JIT | rustc 1.92.0 with LLVM 21 (not verified). For the refund binary: the CakeML compiler, with a proof at model level |
| Storage | SQLite 3.50.1 inside Node, rollback journal, `synchronous=FULL`, `fullfsync=0`: plain `fsync` | two append-only files; `fcntl(F_FULLFSYNC)` twice per commit |
| Cryptography | OpenSSL 3.6 (Ed25519, SHA-256) | none. CRC-32 and FNV-1a-128 are not cryptography |
| Packages | 37 npm packages in `package-lock.json` | 0 crates, 0 npm packages |
| Operating system | macOS kernel, `dyld`, libSystem | macOS kernel, `dyld`, libSystem |
| Memory of one request | about 46 MB per Node process (report D6 of the M1-B mission) | 1.9 MB for the sink (measured peak), 1.9 MB for one run of the binary |
| Proof of the store protocol | a Dafny MODEL of the protocol (`FinalityProtocol.dfy`), not of `sink.ts` | none |

What the native sink removes from the trusted path: Node, V8, the
Dafny JavaScript run-time, `tsx`, 37 npm packages, SQLite, OpenSSL.

What it does NOT have, and the Slice 1 stack has: a decision core
with a source proof against the approved spec; a signed token; a
protocol model with a proof. What both lack: a proof of the code that
writes the store.

## 5. Measurements

One machine, two runs of the EXIT script on 2026-11-19. Times change
with the load of the machine: an earlier run, with two other jobs on
the machine, is in the last column.

| Measure | Run 1 | Run 2 | Earlier run under load |
| --- | --- | --- | --- |
| Commit latency, 200 commits in one stream: min | 7.95 ms | 8.81 ms | 11.67 ms |
| p50 | 11.08 ms | 11.26 ms | 24.28 ms |
| p90 | 15.02 ms | 16.52 ms | 69.11 ms |
| p99 | 45.19 ms | 48.23 ms | 186.87 ms |
| max | 87.52 ms | 64.36 ms | 246.41 ms |
| Throughput of that stream | 79.3 commits/s | 75.9 commits/s | 28.3 commits/s |
| Flood of 10 GiB into the sink | 3.33 s (3.01 GiB/s) | 2.31 s (4.33 GiB/s) | 31.5 s (0.32 GiB/s) |
| Peak resident memory of the sink in the flood | 1,949,696 bytes (1.86 MiB) | 1,949,696 bytes | 1,949,696 bytes |
| First request after the flood | 13.0 ms | 15.3 ms | 50.8 ms |
| The same flood into the binary alone: bytes taken before it ended | 132,120,576 (126 MiB) | 132,120,576 | 132,120,576 |
| its exit status and stderr | 1, "Program exited with nonzero exit code." | the same | the same |
| its peak resident memory (no bound asserted) | 270,286,848 bytes (258 MiB) | 269,877,248 bytes | 235,225,088 bytes |

Asserted bounds: p50 and p99 below 250 ms; the first request after
the flood below 250 ms; the sink's peak resident memory in the flood
below 50 MiB. All held in the three runs. Under load the p99 came to
75% of the bound and the maximum to 99%: on a busier machine the run
can fail. "Under 2 ms" was never reached: the minimum is 7.95 ms. One
commit holds one start of the binary and two `F_FULLFSYNC` calls.

Crash recovery (120 kills at points, 100 kills of a running process):

| Measure | Run 1 | Run 2 |
| --- | --- | --- |
| Recoveries that left a wrong ledger | 0 of 220 | 0 of 220 |
| Records in the WAL at the end | 439 | 421 |
| Dispatched (a complete COMMITTED line was seen) | 334 | 316 |
| Committed and never dispatched (kills at c, r, d, e; some blind kills) | 105 | 105 |
| Request ids committed twice; ids dispatched twice; dispatch without a record | 0; 0; 0 | 0; 0; 0 |
| Blind kills: attempts needed to hit 100 running processes | 169 | 155 |
| of the 100: the record of the victim was committed / was not | 29 / 71 | 26 / 74 |

The 105 records that were committed and not dispatched are the cost of
the at-most-once rule: the refund is in the ledger, its COMMITTED line
was never printed, and only `replay` shows it.

## 6. Epistemic table

The four classes are separate keys of the record
(`records/evidence.json`) and separate rows here.

| Class | What exists | What this work adds |
| --- | --- | --- |
| `in_logic_compiler_proof` | HOL4/CakeML theorems about the refund binary at the level of a machine model, with open premises. M1 is open. ROADMAP: M1 and integration EXIT NOT_ESTABLISHED | nothing. No HOL run. No theorem is used |
| `source_proof` | none for `sink.rs`. The Dafny proofs of Slice 1 are about other programs | nothing |
| `native_wal_crash_tested` | — | the finite tests of sections 2 and 5: kills at six points, blind kills, damaged files, stand-in binaries, races, a flood, system-call order with injected faults, 49 changed copies |
| `os_kernel_assumption` | — | a list, not a test: see below |

Explicit assumptions (`os_kernel_assumption`):

1. macOS Darwin kernel: `flock` is exclusive and ends with the
   process; a 64-byte write with `O_APPEND` lands at the end of the
   file; pipes carry what was written; `fcntl(F_FULLFSYNC)` returns 0
   only after the drive was asked to store the data.
2. APFS and the SSD firmware keep data that `F_FULLFSYNC` reported as
   stored, also at power loss. NOT tested.
3. The Mach-O loader and `dyld` start both programs as their files
   say. The CakeML basis C code and libSystem inside the refund binary
   do what the HOL model of the foreign functions says. NOT proved.
4. rustc 1.92.0, LLVM and the Rust standard library compile and run
   `sink.rs` as written. They are not verified.
5. The two ledger files, the refund binary file, and the arguments and
   environment of the sink are out of an attacker's reach. The sink
   does not hash the binary.
6. A restore of BOTH ledger files, or of the volume, to an older state
   is not detected on one machine.
7. The consumer of the COMMITTED lines uses the request id as an
   idempotency key.

`end_to_end=false`: no link of 1 to 4 is covered by a checked method.

## 7. Differences from the text of the directive

| Directive | What was done | Why; who decided |
| --- | --- | --- |
| "commits in under 2 milliseconds" | measured p50 and p99; assertion `< 250 ms` | not reachable: one run of the binary takes at least 3.8 ms and one `F_FULLFSYNC` at least 2.5 ms (measured). Owner decision (a) |
| 10 GiB "into `b8ed5ec2…`", RSS below 50 MiB | 10 GiB into the sink (bound 50 MiB); the same flood straight into the binary as an observation with no bound | the sink sends at most 154 bytes to the binary. The binary alone takes 126 MiB and then stops with exit status 1; its peak memory was 258 MiB. Owner decision (b) |
| "<200-line" and "<250 LOC" | 248 lines, compact layout | owner decision (c); see section 1 for the `rustfmt` count (521) |
| "permanently close the backup-rollback attack (C-ATT-10)" | a ratchet file: a restore of the WAL alone is refused | a restore of both files cannot be seen on one machine. "C-ATT-10" has no record in the repository. Stated in the specification (item 10), approved |
| "POSIX fsync()" | `File::sync_all()`, which is `fcntl(F_FULLFSYNC)` on macOS | plain `fsync(2)` does not ask the drive to flush on macOS (measured: 0.03 ms against 5 ms) |
| "standard input or domain socket" | standard input only | specification item 5, approved |
| request id check after the acceptance | before the binary runs | the WAL cannot hold another id; the binary never gets a line outside the sink's grammar. Specification item 4, approved |
| order: state hash and request id, then epoch | ratchet first, then request id, then state | a rolled-back WAL cannot answer the other two questions; a repeated request must get `DUPLICATE_REQUEST_ID`. Specification item 8, approved |
| five kill points | six: a, b, c, r, d, e | two syncs make one more point (r: between them) |
| "effect callback" | one `COMMITTED` line on stdout; `replay` prints committed effects again | specification items 9 and 11, approved. Delivery is at most once per commit |
| exit codes 0 and 10 to 18 (specification item 12) | two more: 19 `OUTCOME_UNKNOWN`, 20 `DISPATCH_FAILED`; the stream ends at the first code from 17 up | from the review (R1, R2). Not in the specification that the owner approved first; accepted by the owner after the merge (text 6 of the owner's texts) |
| "A refusal writes nothing" | true for codes 10 to 18. Code 19 can leave a record; code 20 follows a commit | from the review (R1) |
| Rust and Python only | one C file of 148 lines for tests | a SIGKILL cannot show a missing sync; an interposer can. Specification item 14, approved. Not in the trusted base |

## 8. The review

One fresh-context review, as the directive says. Result: 1 FAIL-OPEN
by the letter of the rule (a refusal with code 18 left a record that
the next start adopted; no COMMITTED line was printed), 1 HIGH (the
stream went on after an answer could not be written), 11 MEDIUM,
5 LOW. The reviewer found no path to a dispatch without the two
syncs, no double record, no commit on a stale state.

All of FAIL-OPEN, HIGH and MEDIUM were repaired in one pass, three of
them in part (R5 `init`, R8 kill points in the recovery, R13 time
bounds). Five statements of mine were false or too strong; they are
listed in [REVIEW.md](REVIEW.md) and corrected. One repair that the
reviewer proposed (R11) did not detect the reviewer's own changed copy;
I measured that and repaired the case in another way.

The repairs were NOT reviewed again.

## 9. Limits

- Nothing here is proved. Every result is one run (or two) on one
  machine. Another machine, another macOS version or another drive can
  behave differently.
- No power loss, no kernel stop and no drive fault was tested. The
  kill tests keep the page cache.
- Kills at chosen points use a build of the same source with
  `--cfg kill_points`. The production build has no kill point
  (checked: the name of the control variable is not in its bytes, and
  it ignores the variable). Blind kills at random times use the
  production build; where they land is not controlled.
- The suite reads the files with its own code. That code and the sink
  can be wrong in the same way.
- The sink has no time limit for the binary: a binary that does not
  end makes the sink wait. No effect; no progress.
- `init` takes no lock and has no kill point in the tests. A kill
  inside `init` can leave a folder that every command refuses until a
  person deletes the two files. No kill point is inside the recovery
  either: the recovery is tested by the kills before it, by damaged
  files and by injected sync failures.
- Code 19 (`OUTCOME_UNKNOWN`) means what it says: the caller must ask
  `state` or `replay`. Code 20 (`DISPATCH_FAILED`) after a commit means
  that the refund is in the ledger and was not dispatched.
- The time bounds (250 ms; waits of 3 s and 1 s in case `lock`) can
  fail on a loaded machine.
- After a kill between the sync and the dispatch, the refund is
  committed and its COMMITTED line was never printed. The same request
  then gets `DUPLICATE_REQUEST_ID`. A person or a consumer must use
  `replay`.
- A full WAL scan runs at every start: the cost of one commit grows
  with the number of records.
- The sink accepts fewer requests than the binary: ids of 1 to 24
  bytes of `[A-Za-z0-9_-]`, canonical decimal amounts. 3 of the 8
  HOL-written fixtures that the binary authorizes are refused by the
  sink for this reason.

## 10. After the commit: scratch clone, pull request, hosted gate

The first commit of this work is `a51984bb`. The regression ran on a
fresh scratch clone of exactly that commit
(`run_regression.py`; record `records/regression.json`). The second
commit (`c3889be2`) holds this section, the regression record, entry
U705 and one changed row of `ROADMAP.md`: documents only. A third
commit records the push, the pull request and the hosted result of the
second commit (entry U706): documents only again.

| EXIT command/check | Actual exit/result | Result |
| --- | --- | --- |
| `python3 proposals/forge2-native-silicon-sink/run_regression.py <new clone> <record>` |0|clone of `a51984bb`; merge base with `origin/main`: `b9f2831c` |
| Stage EXIT cases in the clone: Stages 1, 2, 3, 5, 6, 8 (22); Stage 4 (3); Stage 11 (3) |0 each|28 of 28 |
| `check_frozen_pr_gate.py HEAD` in the clone |0|the eight frozen modules are unchanged |
| `check_links.py` for `FORGE_MASTER_IDEA.md`, `ROADMAP.md`, `unsure.md`, this report |0; 0; 0; 0|no link without a target |
| `scripts/exit_slice1.py`, `exit_slice2.py`, `exit_slice3.py`, `exit_m1_conformance.py`, each `--case evidence`, in the clone |0; 0; 0; 0|bundles `c7f2f41c…`, `2721a293…`, `3cdfebfc…`, `f55391da…`: byte-identical to the tracked records |
| `scripts/exit_silicon_sink.py --case evidence` in the clone |0|bundle `1f569fcf…`: byte-identical to the tracked record (third and fourth full run of the suite and of the 49 changed copies) |
| protected paths among the 13 files changed against the merge base |0|`spec/`, `spec.lock`, `policy/`, `governance/gate-ratifications/`, `package.json`, `package-lock.json`, `tsconfig.json`, `gate/`: none |
| Stage 7; Stage 9; Stage 10; any HOL or Holmake process |NOT RUN|Docker time; deferred; no EXIT script on `main`; not part of this work |
| `git push -u origin feat/native-silicon-sink`; `gh pr create` (pull request 62) |0; 0|no administrator rights used; the agent did not merge |
| `check_links.py` for `ROADMAP.md`, `unsure.md`, this report, the review, the owner's texts; `check_frozen_pr_gate.py HEAD`, on the second commit |0 each (5); 0|run in the working repository, not in a clone |
| hosted `gate/pr_check.py`, pull request 62, head `c3889be2`, run 44591773836 (Linux profile) |3|UNSUPPORTED, as expected: every obligation that ran holds; 14 coverage findings (changed paths that no obligation lists) |
| hosted `gate/pr_check.py`, pull request 62, head `e280addf` (the third commit), run 44592215424 |3|UNSUPPORTED, as expected: 14 coverage findings |
| merge of pull request 62 |done by the account `mack-dot` on 2026-11-19T18:52:51Z; commit `6d66a558`|the agent did not merge and used no administrator right. After the merge: the files of this work on `main` are equal to the branch head `e280addf` (`git diff`: no difference); the bundle on `main` is `1f569fcf…` |
| this row and entry U707 (a later pull request, documents only): its own hosted run |NOT RECORDED|the chain of records stops here by statement |

The Stage runs wrote result files under `results/` in the clone only.
The clone is a throwaway folder; nothing of it is in the repository.
