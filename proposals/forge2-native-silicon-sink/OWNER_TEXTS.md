# Native silicon sink: the owner's texts and decisions

These are the owner's words for goal 19, saved as records. They are
inputs, not results. A text here approves only what it says.

How each text reached the session (evidence class):

- Text 1 came through the session's goal command and as one pasted
  text. I saved it to `goal19.md` (not tracked) on the owner's request.
- Texts 2, 3 and 5 are answers that the owner selected in the
  session's question dialog. Each line gives my question in short form
  and the option that the owner selected.
- Text 4 is one message that held only pasted text. It agrees with the
  dialog answers of text 3. For item (d) it goes further than the
  first answer of text 3; text 5 then confirmed the base commit.

## Text 1: the directive (verbatim)

Goal sentence:

> Cut out the entire Node.js, V8, npm, and SQLite layer from the trusted effect boundary—wiring the HOL4/CakeML-verified ARM64 native binary (b8ed5ec2…) directly to a zero-dependency, <200-line `#![forbid(unsafe_code)]` Rust binary write-ahead-log (WAL) sink, and validating it under continuous kill -9 crash injection and 10 GiB pipe floods.

```text
MASTER FRONTIER DIRECTIVE: THE NATIVE SILICON SINK
(CAKEML ARMV8 NATIVE BINARY -> ZERO-DEPENDENCY NATIVE WAL SINK WITH HARDWARE FSYNC)
DOCTRINE: "NEVER FAKE ANYTHING" — STRICT EPISTEMIC ACCOUNTING — ZERO V8 IN THE TCB

MISSION GOAL
Exise the entire JavaScript / Node.js / V8 / SQLite runtime from the trusted
execution path of the Refund Finality boundary. Replace it with an unbroken
native pipeline running directly on Apple Silicon ARM64 hardware:
  Raw Stdin Bytes -> CakeML ARM64 Binary (b8ed5ec2...) -> Atomic Pipe ->
  Native WAL Sink (sink.rs, #![forbid(unsafe_code)], 0 crates) ->
  POSIX fsync() Hardware Barrier -> Authorized Outbound Dispatch.

Every committed effect e must strictly satisfy:
  Committed(e) ==>
    SpecCleared(e) /\
    AcceptedByCakeMLARMv8Binary(e) /\
    CASMatched(e) /\
    FreshRequest(e) /\
    MonotonicEpoch(e) /\
    DurableWalFsync(e)
under explicit, audited OS kernel/syscall environmental assumptions.

==============================================================================
PRE-FLIGHT & HARD REPOSITORY RULES
==============================================================================
1. Inspect git status, running jobs, and current branch.
   - If PR 58 or any prior PR is still OPEN on origin, STOP and report.
   - Start from clean origin/main in branch `feat/native-silicon-sink`.
   - Do NOT touch untracked `.toolchain`, `node_modules`, or `results/`.
2. Protected paths stay at ZERO edits:
   - Do NOT modify `spec/`, `spec.lock`, `policy/`, `governance/gate-ratifications/`,
     `package.json`, `package-lock.json`, or `tsconfig.json`.
   - Do NOT edit the 8 froate modules in `gate/`.
   - Zero new npm packages. Zero external Cargo crates.
3. Preserve all existing evidence:
   - Slice 1 (`c7f2f41c...`), Slice 2 (`2721a293...`), Slice 3 (`3cdfebfc...`),
     and M1 Conformance (`f55391da...`) bundles MUST remain 100% byte-identical
     in scratch-clone checks.
   - All 28 Stage EXIT checks must pass exit 0.
4. Epistemic honesty:
   - Keep `in_logic_compiler_proof`, `native_wal_crash_tested`, `source_proof`,
     and `os_kernel_assumption` strictly separate in all schemas and reports.
   - Global `end_to_end=false` remains printed: macOS Darwin kernel, Mach-O
     loader, CakeML C basis stub, and physical SSD firmware remain explicit
     assumptions.
5. Single-loop execution: Keep design, Rust/Python code, and repairs in ONE
   main loop. Spawn subagents ONLY for (a) heavy crash-injection runs and (b)
   ONE fresh-context adversarial review before PR creation.

==============================================================================
PHASE 1: RECON & HARDWARE COMPONENT BINDING (PAUSE FOR APPROVAL)
==============================================================================
Inspect the existing native artifacts on disk:
- The compiled CakeML ARM64 native binary `b8ed5ec2...` (verify it runs natively
  on this Apple Silicon Mac via `arch` check).
- Local `rustc 1.92.0` (confirm `rustc -V` and that standalone compilation
  without Cargo works).
- Pinned vector corpus from `tests/refund-finality/` and Wave Gate 1.

Deliverable for Phase 1:
Print a 15-line architecture specification for the native pipeline:
1. Exact binary WAL record format (fixed-size binary struct with magic, epoch,
   pre-state hash, request ID, amount, and CRC32/checksum).
2. Concurrency model: OS file locking (`flock`) + monotonic epoch ratchet to
   permanently close the backup-rollback attack (C-ATT-10 / rollback exploit).
3. Exact anonymous OS pipe / descriptor protocol between the native sink and
   `b8ed5ec2...`.
4. Stop and wait for my explicit go-ahead before writing code.

==============================================================================
PHASE 2: BUILD THE NATIVE SINK (src/silicon_sink/sink.rs)
==============================================================================
Write `src/silicon_sink/sink.rs` under these strict constraints:
1. `#![forbid(unsafe_code)]` at the top of the file.
2. Standard library ONLY (`std::fs`, `std::io`, `std::os::unix`, `std::process`).
   Zero external crates. Compiles cleanly with:
   `rustc -D unsafe_code -C opt-level=3 src/silicon_sink/sink.rs -o build/silicon/native_sink`
3. Pipeline Mechanics:
   - Takes incoming request over standard input or domain socket.
   - Pipes request into `b8ed5ec2...` over an anonymous OS pipe.
   - Reads exact decision frame from the CakeML ARM64 binary.
   - If rejected: drops authority immediately, emits 0 effects, writes nothing.
   - If accepted:
     a. Validates request ID canonical format (rejects `\0`, index substitutions,
        and whitespace variations).
     b. Reads the current WAL tail: verifies `pre_state_hash` matches current
        state AND `request_id` has never been committed.
     c. Verifies monotonic epoch (rejects state rollback / stale backup replay).
     d. Writes 64-byte binary record to `ledger.wal`.
     e. Calls `File::sync_all()` (kernel `fsync` syscall to force hardware SSD
        flush).
     f. Dispatches effect callback ONLY after `sync_all()` returns exit 0.
4. Clean diagnostic error codes: distinct exit/return codes for
   `STALE_STATE_HASH`, `DUPLICATE_REQUEST_ID`, `MALFORMED_ID`, `EPOCH_REGRESSION`,
   and `CAKEML_REJECTED`.

==============================================================================
PHASE 3: THE BRUTAL FAULT-INJECTION & 10 GIB FLOOD SUITE
==============================================================================
Build `tests/silicon_sink/test_silicon_crash.py` and `scripts/exit_silicon_sink.py`:
1. The `kill -9` Crash Matrix:
   - Spawns concurrent refund worker processes against a single `ledger.wal`.
   - Sends randomized `SIGKILL` (`kill -9`) signals at 5 distinct microsecond
     cut-points:
       (a) pre-WAL write,
       (b) mid-write (partial record),
       (c) post-write / pre-fsync,
       (d) post-fsync / pre-dispatch,
       (e) mid-dispatch.
   - Reboots the native sink after each kill and verifies:
       - 0 corrupted records admitted on recovery.
       - Exactly 0 double-refunds or double-credits committed.
       - Partial/truncated WAL records are cleanly discarded at recovery.
       - Re-running the interrupted request either completes cleanly once or
         safely detects the already-committed transaction.
   - Minimum 100 randomized kill iterations; 100% must recover cleanly.
2. The 10 GiB No-Newline Native Flood:
   - Streams `10,737,418,240` bytes with no newline directly through the native
     pipeline into `b8ed5ec2...`.
   - Asserts peak RSS memory stays flat (below 50 MiB).
   - Asserts zero process crashes or memory leaks.
   - Asserts the very next valid request on the next byte executes and commits
     in under 2 milliseconds.
3. Concurrent TOCTOU Race Storm:
   - 100 concurrent native processes firing refunds against a single account
     balance. Exactly 1 must commit; 99 must fail with `STALE_STATE_HASH`.
     Total money refunded must strictly equal the single authorized amount.
4. Negative Mutations (N/N checks):
   - At least 10 deliberately mutated copies of `sink.rs` (removing `fsync`,
     removing CAS check, ignoring epoch, ignoring request ID uniqueness, etc.).
   - The test suite must fail on 100% of the mutated copies.

==============================================================================
PHASE 4: SCRATCH-CLONE VERIFICATION, TCB AUDIT & PR CREATION
==============================================================================
1. Run ONE fresh-context adversarial review against `sink.rs` and the test
   harness. Fix any confirmed FAIL-OPEN, HIGH, or MEDIUM issues in one pass.
2. Verify in a fresh scratch clone:
   - All 28 Stage EXIT cases exit 0.
   - `check_frozen_pr_gate.py` exits 0.
   - Slices 1, 2, 3, and M1 conformance bundle digests remain byte-identical.
   - `scripts/exit_silicon_sink.py` passes 100%.
3. Produce `proposals/forge2-native-silicon-sink/REPORT.md`:
   - Full TCB Comparison Table: Old Node/V8/SQLite Stack vs. Native Silicon Sink.
   - Exact lines of code added (`<250` LOC Rust, 0 crates).
   - Exact measured latency, throughput, peak memory, and crash recovery stats.
   - Complete Epistemic Assurance Table: what is CakeML-proved, what is
     native-crash-tested, and what remains an explicit OS/hardware assumption.
4. Commit, push `feat/native-silicon-sink`, open PR without admin bypass or
   self-merge, confirm hosted `pr_check.py == 3` (UNSUPPORTED, expected),
   print the complete EXIT table + PR URL, and PAUSE for my review and merge.
```

## Text 2: answers at the pre-flight (2026-11-19)

Pull request 58 was OPEN when the run started. The directive says to
STOP in that case.

| My question (short form) | The owner's selected answer |
| --- | --- |
| Pull request 58 is open; the directive says STOP. What do you want? | "Recon only, PR 58 stays open": Phase 1 as read-only recon; no branch and no file until pull request 58 is merged |
| Nine older pull requests are open (14, 15, 36; drafts 1, 2, 3, 5, 34, 37). Do they block? | "They do not block": the rule is read as pull request 58 only |

## Text 3: answers after the Phase 1 specification (2026-11-19)

| My question (short form) | The owner's selected answer |
| --- | --- |
| Do you approve the 15-line specification, and what is the state of pull request 58? | "Approved; PR 58 is merged" |
| "Commit under 2 ms" is not reachable (binary run at least 3.8 ms, full flush at least 2.5 ms). Which bound? | "Record p50/p99, assert < 250 ms" |
| A flood straight into the binary takes 131 MiB at heap 256. How must the flood test run? | "Flood the sink; raw run as observation" |
| 200 or 250 lines for `sink.rs`? | "Under 250 total lines" |

## Text 4: one pasted message (verbatim)

```text
Phase 1 spec (items 1-14) is approved--proceed to Phase 2, 3, and 4 now with these four decisions for item 15:
(a) Approved: record p50 and p99 latencies and assert < 250 ms (real F_FULLFSYNC + process spawn).
(b) Approved: run 10 GiB no-newline flood into the sink with the < 50 MiB RSS bound, plus the raw binary flood as a recorded observation with no RSS bound.
(c) Approved: up to 250 lines of clean, auditable `#![forbid(unsafe_code)]` Rust (document FNV-1a-128 as non-cryptographic CAS).
(d) Do NOT wait for PR 58: branch `feat/native-silicon-sink` directly from current `origin/main` now.
```

## Text 5: the base commit (2026-11-19)

After text 3 I checked GitHub. Pull request 58 was still OPEN. Its
content was in `origin/main` through pull request 59 (commit
`b9f2831c`; 0 files of pull request 58 missing). Pull requests 60 and
61 were open.

| My question (short form) | The owner's selected answer |
| --- | --- |
| Pull request 58 is still OPEN on GitHub; its files are in `origin/main` `b9f2831c`. May I create the branch from `b9f2831c` now? | "Start from b9f2831c now" |

## Text 6: answers after the merge of pull request 62 (2026-11-19)

Pull request 62 showed as MERGED by the account `mack-dot`
(2026-11-19T18:52:51Z, commit `6d66a558`). I had no word of the owner
about that merge, so I asked. The owner selected these answers in the
session's question dialog.

| My question (short form) | The owner's selected answer |
| --- | --- |
| Pull request 62 is merged by the account `mack-dot`. Is that merge yours, and do you accept it? | "Yes, it is my merge" |
| Pull request 63 (records, documents only) is open; I opened it without asking first. What do you want with it? | "I will merge it" |
| "Commit under 2 ms" (measured minimum 7.95 ms; assertion below 250 ms) and "<200-line" (248 compact lines; `rustfmt` 521): are the two replacements final? | "Final as they are" |
| Exit codes 19 `OUTCOME_UNKNOWN` and 20 `DISPATCH_FAILED`, and the end of the stream at the first code from 17 up: do you accept them? | "Accept both" |

## Text 7: one pasted text after the merge, with the words "and consider this" (2026-11-19)

The owner's own words in the message: "and consider this". The rest of
the message was one pasted text. It is stored verbatim below. I read
the owner's words as: examine the text. They are not a word to start a
gate, to change a queue file, or to merge. I started no gate. What I
found is entry U709 of `unsure.md`. Another session keeps the queue
that the text names (U709). This copy is a record and not an
authorization.

```text
APEX FRONTIER ADDENDUM: LIVE MCP (`stdio`) AIRLOCK PROXY & HOL4/CAKEML
SILICON-SINK PROOF CLOSURE (`ITEM F2.7` + `PRIORITY A`) -- "NEVER FAKE ANYTHING"

QUEUE ORDER INTEGRATION
Insert `GATE APEX-1`, `GATE APEX-2`, and `GATE APEX-3` into `QUEUED.md`
immediately AFTER `GATE F1` (Bridge-1 Intent Engine) and BEFORE `GATE F2`
(`Stage 9` Lock & Benchmark) and `GATE F3` (`FORGE_PAPER.md` & `README.md`),
so Stage 9 locks once and the final paper includes both the MCP Airlock and
the HOL4/CakeML Silicon-Sink closure. Each gate opens its own standalone PR
from clean `origin/main` and pauses for my squash-merge.

HARD RULES (APPLY TO ALL APEX GATES)
1. Touch `0` protected or frozen paths (`gate/`, `spec/`, `spec.lock`,
   `policy/`, `governance/gate-ratifications/`, `package.json`, etc.). Zero
   external npm, pip, or Cargo packages (`std` only).
2. Preserve ALL prior evidence bundles byte-identical (`Slices 1-3`, `M1
   Conformance`, `Goal 19 Silicon Sink`, `Goal 20 SDK`, `Goal 21 Intent`) and
   all `28/28` Stage EXITs.
3. Every reported number (RAM, latency, line count, obligation count, kill
   count) MUST be read directly from committed run artifacts, never copied
   from prompt text. Keep `end_to_end=false` explicit everywhere OS syscalls,
   C FFI stubs, loaders, or hardware remain assumptions.
4. Strictly 1 HOL4 / `cake_compile` process at a time (`hol.lock`), requiring
   AC wall power for multi-hour HOL runs.

------------------------------------------------------------------------------
GATE APEX-1 -- DROP-IN MCP (`stdio` JSON-RPC 2.0) AIRLOCK & HIPAA/FINTECH DEMO
Branch: `feat/mcp-stdio-airlock` from clean `origin/main` (post-Gate F1)
1. Build `forge-airlock mcp --policy <policy.json> --agent-id <id> -- <cmd...>`
   (`std`-only Rust/Python over real MCP newline-delimited JSON-RPC 2.0 `stdio`
   transport; `0` external packages):
   - Identity & Config Binding: Binds exact SHA-256 of the cleared policy and
     `agent_id`; refuses startup if policy fails `NO_CHOICE` / clearing check.
   - Inbound Mutating `tools/call` Gate: Intercepts mutating MCP tool calls
     (e.g. `issue_refund`, `wire_payout`, `book_slot`) and enforces the native
     `F_FULLFSYNC` WAL (`pre_state_hash` CAS, `fresh_request_id`, epoch
     ratchet, fact-bound reason sub-caps like `SHIPPING <= shipping_paid`, and
     `0600` human Ed25519 cosign) BEFORE forwarding a single byte to the
     upstream MCP tool server. Rejected calls never reach the upstream server!
   - Outbound HIPAA/Tenant Read Filter: Inspects MCP `tools/call` responses
     carrying scoped records; if ANY record mismatches the session's
     `tenant_id` / `clinic_id`, drops the entire response (`0` PHI/cross-tenant
     bytes ever emitted to `stdout` / LLM context) and logs a breach block.
   - Signed Auditor Receipt: Writes a hash-chained, Ed25519-signed receipt per
     MCP call `(agent_id, policy_sha256, tool, wal_epoch, pre_state_hash,
     verdict)` verifiable offline by an independent auditor CLI command.
2. Build `examples/mcp_hipaa_fintech/run_demo.py` and `scripts/exit_mcp_airlock.py`:
   - Spawns real local upstream HIPAA Chart + FinTech Payout MCP `stdio`
     servers behind `forge-airlock mcp` and fires:
     (a) Prompt-injected cross-clinic PHI chart fetch -> `0` PHI bytes leaked,
     (b) 20-process concurrent `issue_refund` MCP race -> `1` upstream call,
         `19` CAS-blocked (`0` duplicate upstream tool executions),
     (c) Timeout retry + cross-processor `IN_FLIGHT` failover -> blocked,
     (d) "$10 shipping ask proposed as $80" -> blocked by reason sub-cap,
     (e) `1 GiB` no-newline malformed JSON-RPC flood -> bounded flat RSS, next
         valid MCP `tools/call` succeeds and emits valid signed receipt.
   - `>= 20` mutated copies fail for their named reason; 2 byte-identical
     evidence runs; 1 fresh-context adversarial review; scratch-clone check.
   - Push, open PR without admin bypass, and PAUSE for my squash-merge.

------------------------------------------------------------------------------
GATE APEX-2 -- MECHANICAL DAFNY <-> HOL4 CONTRACT LINK & PROFILE A CLOSURE
Branch: `feat/m1-contract-link-closure` from clean `origin/main` (post-APEX-1)
1. Reusing `LinkedRefund.dfy` (`1,486` obligations) and Orchestrator A's HOL
   work (`1a53594d`), execute Priority A under `hol.lock`:
   - Mechanically prove in HOL4 (`Holmake` exit 0) that HOL's `eligible` /
     `refund_fields` satisfies the exact exported flat 6-field refund contract
     over the supported input domain (preserving integers, booleans, UTF-8 byte
     sequences, `chargeId` vs `requestId` order, `MaxMoney`, and R1-R5
     fallback); if any irreducible cross-tool syntax translation boundary
     remains, isolate it to a minimal, hash-pinned, negative-control-tested
     check and never call an assumed translation "machine-checked".
   - Run negative controls (swapped `chargeId`/`requestId`, altered guard
     conjuncts, off-by-one `MaxMoney`) confirming `Holmake` / check fails.
   - Apply the honest Route A simulation form for `fficlose` and ARMv8
     `TBI0`/`SA0` user-space premises, and update the **45-Link Assurance
     Graph** strictly from verified results.
2. Verify byte-identical HOL exports on repeat run + scratch-clone regression,
   open PR without admin bypass, and PAUSE for my squash-merge.

------------------------------------------------------------------------------
GATE APEX-3 -- FORMAL SILICON-SINK CLOSURE (`ITEM F2.7`: WAL-FOLD + POLICY IN
ONE VERIFIED HOL4/CAKEML ARM64 BINARY)
Branch: `feat/cakeml-verified-wal-sink` from clean `origin/main` (post-APEX-2)
1. STEP 3A RECON & BUDGET GATE (STOP FOR MY WORD BEFORE `cake_compile`):
   - Print a 12-line HOL4/CakeML design & wall-time estimate for moving the
     pure 64-byte WAL state-fold, CRC/hash-chain CAS, `epoch` ratchet,
     `request_id` uniqueness, and `remaining` conservation check INSIDE HOL4 /
     CakeML alongside the `R1-R5` refund decision, leaving ONLY a minimal
     (`<= 60` LOC) C `basis_ffi` syscall stub for `flock`, `write`, and
     `fcntl(F_FULLFSYNC)`. Pause for my budget approval before `cake_compile`.
2. STEP 3B PROVE, COMPILE & TORTURE-TEST (After my Step 3A go-ahead):
   - Prove in HOL4 (`Holmake` exit 0, broken-invariant controls exit non-zero)
     that the CakeML WAL-fold + refund transition preserves money conservation
     (`sum(committed) <= original`), single-commit per `request_id`, `epoch`
     monotonicity, and `R1-R5` eligibility on every accepted transition.
   - Compile via `cake_compile_heap` + `hol-arm8-step` to a verified `arm64`
     machine-code theorem and link with the minimal audited C `flock` /
     `F_FULLFSYNC` stub (recording exact C stub line count as trusted FFI).
   - Run the full Goal 19 torture suite (`dyld` `F_FULLFSYNC` syscall order +
     injected `EIO`, `220` `kill -9` crashes, 100-process race, 10 GiB flood,
     and C-stub/harness mutations) against this CakeML-verified WAL binary,
     update the 45-link graph honestly (`end_to_end=false` for C stub/OS/CPU),
     open PR without admin bypass, and PAUSE for my squash-merge (then proceed
     to queued `GATE F2` Stage 9 and `GATE F3` Final Paper).
```
