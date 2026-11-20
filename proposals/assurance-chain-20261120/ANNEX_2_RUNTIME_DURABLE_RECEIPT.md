# Annex 2: executed artifact, runtime enforcement, durable effect, execution receipt

Investigator 2 of 3. Date 2026-11-20. Tree read: `origin/main` `058eabcb`. Read-only investigation.
No HOL, Holmake or Dafny ran. No test ran. Every status below comes from reading source code and committed
records. `end_to_end=false`. M1-B OPEN. Stage 9 deferred.

Scope (chain part): EXACT EXECUTED ARTIFACT -> RUNTIME ENFORCEMENT -> ACTUAL STATE TRANSITION -> DURABLE
EFFECT -> INDEPENDENTLY VERIFIABLE EXECUTION RECEIPT, and the design of an independent verifier.

Engines read in full or in their decision paths:

| Engine | Files | Lines | Source pinned by a committed record? |
| --- | --- | --- | --- |
| Native silicon sink (Goal 19) | `src/silicon_sink/sink.rs` | 248 | YES: `proposals/forge2-native-silicon-sink/records/evidence.json` pins `sink.rs` SHA-256 `1962af4a…db71` (equal to `main`) |
| Airlock engine (Goal 20 + PR 72 + PR 73) | `src/airlock/*.rs` | 1,989 Rust | NO. `proposals/forge2-goal20-sdk/records/evidence.json` pins the PRE-PR-72 sources: 20 of 64 subject files differ from `main` (all `src/airlock/*.rs` but `json.rs`, `policy.rs`, `cosign.rs` absent; `node/cosign.cjs` pinned but deleted). PR 73 logs exist (`proposals/review-20261120-engine/logs/`), no evidence bundle for the merged engine bytes was found |
| MCP proxy | `src/mcp_proxy/*.rs` | 5,385 Rust incl. tests | NO committed JSON record found; bundle `13608d7e…20bd` named in text only (`ROADMAP.md:381`, `unsure.md:20150`) |
| Primitives v2 | `src/primitives_v2/*.rs` | 3,252 Rust | NO committed JSON record found; bundle `100476fe…a8dc` named in text only (`ROADMAP.md:55`, `unsure.md:20984`) |

Note on "T19 hardened sink": T19 (`proposals/t19-hardened-sink-20261119/REPORT.md`, commit `f1d87032`) hardened
the TypeScript/SQLite sink, minter and dispatcher (`ts/refund-finality/…`). It did NOT change the Rust sink.
`git log -- src/silicon_sink/` shows only `6d66a558` (Goal 19). The airlock header says the sink is "unchanged"
(`src/airlock/main.rs:4`).

---

## 1. Findings

### F1. No Rust engine has any machine-checked statement. PROVEN = none.

- Every engine says so in its own header: `sink.rs:3` "NOT proved"; `src/airlock/main.rs:3` "NOT PROVED";
  `src/mcp_proxy/PROTOCOL.md:3` "Nothing … is proved"; `src/primitives_v2/PROTOCOL.md:4` "No Rust file here is a
  PROVED CORE". The silicon record states `"source_proof": {"status": "none"}`.
- I verified it independently: no Rust verification tool (Kani, Prusti, Creusot, Verus, Aeneas) appears in the
  tree's build commands; the only build commands are plain `rustc` (`bin/forge-airlock` `RUSTC`,
  `bin/forge-mcp-proxy` `RUSTC`, `scripts/exit_silicon_sink.py` `BUILD_COMMAND`).
- The compiler is `rustc 1.92.0` (`scripts/exit_silicon_sink.py` `RUSTC_VERSION`): not a verified compiler.
- `#![forbid(unsafe_code)]` is on line 1 of each crate root (`sink.rs:1`, `airlock/main.rs:1`,
  `primitives_v2/main.rs:1`, `mcp_proxy/main.rs:10`). There is no `extern`, no FFI and no libc call in the four
  engines (grep). The only C in the paths is the TEST interposer (`tests/silicon_sink/interpose.c`,
  `tests/airlock/interpose.c`), loaded only by tests. Memory safety therefore rests on the Rust type system and
  std (TRUSTED), not on review of raw pointers. `O_NOFOLLOW`/`O_NONBLOCK` are hand-coded per platform constants
  (`evidence.rs` ~line 172; `primitives_v2/store.rs` ~line 27), guarded by a `compile_error!` on other targets
  in `evidence.rs`.

### F2. Where the decision is made (relationship to any verified protocol)

| Engine / decision | Decided by | Relationship to a proved artifact |
| --- | --- | --- |
| Silicon sink, refund accept/reject | the CakeML binary `b8ed5ec2…7bb8`, subprocess; Rust then checks CAS, id, amount, reason | binary: CakeML-compiled, HOL theorems with open premises (M1-B OPEN). Binary-to-Dafny spec link: finite test only (`proposals/forge2-m1-conformance/records/evidence.json`, bundle `91b49423…`) |
| Silicon sink, ledger (CAS, ids, ratchet, crash) | unproved Rust | none |
| Airlock `canonical-refund` REFUND | the same CakeML binary, subprocess (`verbs.rs:168-177`, `helpers.rs:157-171`) | as above |
| Airlock parametric money, saga, lease, read airlock | unproved Rust (`policy.rs`, `verbs.rs`) | none; `diff-policy` clears a GENERATED Dafny model of a policy, not the Rust evaluator |
| Airlock BOOK | Rust pre-checks, then Dafny-compiled JS `model.cjs` run by Node (`verbs.rs:262`) | source `BookingDualCert.dfy` verified (record: `forge2-goal20-sdk/records/evidence.json` `build.checker_model`, "46 verified, 0 errors"); compiled JS NOT proved; Node TRUSTED |
| Airlock cosign | Rust form checks + `/usr/bin/ssh-keygen -Y verify` (`cosign.rs:239-258`) | OpenSSH TRUSTED; not pinned by hash |
| MCP proxy, every verdict | unproved Rust (`policy.rs`, `proxy.rs`, `ledger.rs`) | none |
| Primitives v2, every verdict | unproved Rust | `FarkasCert.Soundness` is about the Dafny predicate only (`PROTOCOL.md:5`) |

Subprocess parsing (fail-open question). The refund binary result counts only as: exit code `Some(0)`, empty
stderr, all stdin written, and stdout byte-equal to the expected accept frame or to `REJECT_FRAME`
(`sink.rs:154-158`; `helpers.rs:165-169`). Any other byte string, a signal, a timeout (airlock only) or a
spawn failure is a refusal (`BAD_FRAME`, `HELPER_FAILED`). stdout is read with a bound of
`max(expect, REJECT_FRAME)+1` bytes, so a longer output can never equal the frame. The binary's known behaviour
on malformed input is empty stdout with exit 0 (`unsure.md` U275/U276, ~line 8310 and 8480); that maps to
`BAD_FRAME`, a refusal. ssh-keygen: only exit 0 with the exact "Good …" line for the pinned key fingerprint, or
exit 255 with the exact two failure texts; anything else is `HELPER_FAILED` (`cosign.rs:252-257`). Node helper:
`ACCEPT\n`+exit 0 or `REJECT\n`+exit 1 (`helpers.rs:187-191`). By reading, I found no parse path that fails open.
This is a reading result, not a proof.

Engine-side re-checks after an accept: the airlock re-checks `amount <= remaining` and the reason list after the
binary accepts (`verbs.rs:177`); the silicon sink checks reason, CAS, original, remaining and amount under the
lock (`sink.rs:163-171`). So a binary that wrongly accepts an over-refund is still refused by unproved Rust.

### F3. The silicon sink passes caller-chosen authorization flags to the verified decision

The silicon sink request is `<hash> (<charge> <request> <original> <remaining> <flag> <flag> <flag> <amount>
<reason>)` (`sink.rs:128-134`). The three flags (enabled, opened, candidate in the airlock's naming,
`verbs.rs:170-172`) come from the CALLER and go to the binary unchanged as `r.wire` (`sink.rs:192`). The sink
checks `original`/`remaining`/charge/tail against the ledger (`sink.rs:168`) and the request id freshness
itself (`sink.rs:167`), but NEVER checks the flags. The accept frame demands the binary said `True`, so a
caller that wants an accept simply sends `True True True`. Consequence: the "enabled" input of the
verified decision is a caller assertion in the silicon sink. The airlock fixes this: the engine builds the wire
with the flags set by itself (`verbs.rs:174`). TESTED: not tested as a defect in either suite by my reading.
Impact: the composed statement "the binary decided" holds only for a decision whose inputs include unchecked
caller assertions.

### F4. Exact artifact binding at run time: only the CakeML binary is pinned, and only by the airlock

| Artifact | Who checks it | When | Window | Status |
| --- | --- | --- | --- | --- |
| CakeML refund binary, airlock path | engine: compiled-in SHA-256 `REFUND_BINARY_SHA256` (`helpers.rs:41`); path canonicalized, every path part owned by root or the engine uid, no group/other write, no symlink (`cosign.rs:185-206`), hashed at EVERY exec, identity re-read after hashing (`helpers.rs:134-151`) | each REFUND | exec by path after the hash: a writer with root or the engine uid can swap between hash and exec (stated `helpers.rs:18-22`). macOS has no `fexecve` (log `proposals/review-20261120-engine/logs/d2-fdexec.log`) | TESTED_ONLY (`tests/airlock/test_engine.py` cases `pin`, `pin_window`) |
| CakeML refund binary, dispatcher | `bin/forge-airlock` re-hashes `build/airlock/refund-binary` at each `serve` (`bin/forge-airlock:171-178`) | at start | Python, same user | TESTED_ONLY |
| CakeML refund binary, silicon sink | NOBODY in production. `sink.rs:13-14`: "This program does not hash the binary; its launcher must." There is no launcher for the silicon sink in `bin/`. Only the test script checks the file hash | never | the whole run | MISSING |
| Airlock engine binary | nobody: "the engine binary itself: by nothing in this repository; whoever starts it chooses it" (`src/airlock/PROTOCOL.md:800`). `--engine-dir` selects any engine (`bin/forge-airlock:162-168`). No build record pins the engine binary hash (`evidence.json` `build.engine_builds` holds commands and exit codes only) | never | | MISSING |
| MCP proxy binary | nobody; `$FORGE_MCP_PROXY` selects any binary (`bin/forge-mcp-proxy:52`) | never | | MISSING |
| Primitives engine binary | nobody; the genesis records a self-declared build KIND string (`store.rs` `BUILD`) | never | | MISSING |
| `/usr/bin/ssh-keygen` | ownership/mode/no-symlink path checks at every run, NOT hashed (`cosign.rs:9-16`, `PROTOCOL.md` section 11) | each cosign | root can change it | ASSUMED |
| Node (inventory) | SHA-256 in genesis, re-hashed when inode identity changes (`helpers.rs:11-22`); its 9 Homebrew dylibs NOT covered (`helpers.rs:23-25`) | each BOOK | admin group can inject via dylibs: OPEN | INCOMPLETE |
| Policies | FNV-1a-128 of each policy file in the genesis (`store.rs:192`); FNV is not collision resistant (stated `store.rs:5`) | each open | store writer | TESTED_ONLY, cryptographically weak |

Runtime measurement or attestation: NONE. No TPM, Secure Enclave, code-signing check of the engine, or
remote attestation is used by any engine (grep of `src/`; `spec/provenance/protocol.md:158` says "Remote
attestation of the controller is not established" for the Stage 9 fixture, which covers a build provenance of
`gcd-selftest.elf`, not runtime receipts). "Who checks the checker": nobody; the checker (engine binary) chooses
itself.

Receipts and artifact hashes: no receipt of any engine names the engine binary hash or the refund binary hash.
The airlock genesis names the Node hash (inventory only) and policy FNV pins; the primitives genesis names its
build kind; the MCP evidence record names agent id and tool only. Every such field is written by the
implementation itself, so an implementation can state any value. A receipt field is an assertion of the writer.

### F5. Durable transition: ordering is careful, durability is ASSUMED, rollback detection is partial

Order of a commit (read in code):
- Silicon sink: binary decides BEFORE the lock (`sink.rs:192`); then `open_ledger` takes `flock` exclusive
  (`sink.rs:108`), folds, checks ratchet, CAS, id; writes one 64-byte record; `sync_all` (F_FULLFSYNC on
  macOS); appends ratchet entry; `sync_all`; releases lock; prints `COMMITTED` (`sink.rs:162-187`). A failed write
  or sync truncates back and syncs; if that fails: `OUTCOME_UNKNOWN` (`sink.rs:179-182`).
- Airlock: same order, but the subprocess decision (binary, ssh-keygen, Node) runs UNDER the lock
  (`verbs.rs:162-176`), so there is no window between the decision's pre-state read and the append
  (`store.rs:210-236`). The writer runs the fold's `apply` on the new record before writing it
  (`store.rs:219`), so writer and reader agree on what is foldable.
- MCP proxy: ledger record, `sync_all`, then evidence record + signature in one write + sync, then forward
  (`PROTOCOL.md` section 3.2; `ledger.rs:412-441`).
- Primitives v2: one record holds the whole multi-key transaction; every key's pre-state hash is compared
  before anything is written (`engine.rs:289`); one write, `sync_all` (`store.rs:384-408`). So multi-key
  atomicity reduces to single-record atomicity. NO epoch ratchet (`PROTOCOL.md:784`).

Crash consistency:
- Torn tail: each scanner accepts at most one incomplete trailing record and cuts it under the lock
  (`sink.rs:98, 119-121`; `store.rs:97-102, 175-187`; MCP `ledger.rs` torn-tail rule; primitives `store.rs:371`).
- A record is acknowledged only after `sync_all` returned. Rust std implements `sync_all` with
  `fcntl(F_FULLFSYNC)` on Apple targets. That the drive keeps such data on power loss is ASSUMED and NOT
  TESTED: the silicon record says "APFS and the physical SSD firmware keep data that F_FULLFSYNC reported as
  stored, also at power loss. NOT tested." (`evidence.json` `os_kernel_assumption`). All crash tests use
  SIGKILL, which is not a power loss (`scripts/exit_silicon_sink.py:10`).
- After a failed fsync the code truncates and syncs again and reports IO_ERROR if that works. The state of
  the page cache after an fsync error is OS-specific; correctness of "truncate then sync = no record" after an
  fsync error is ASSUMED.
- No rename-based commit: commits are appends. `rename` is used only at `init` (airlock `store.rs:299`,
  primitives `store.rs:465`), with parent-folder sync and an undo path (`store.rs:320-329`). The silicon sink
  `init` syncs the folder (`sink.rs:228`) and has no rename.

Replay protection:
- The used-id set is the fold of the WAL: silicon `Ledger.ids` (`sink.rs:78`), airlock per-tenant
  `ids: HashSet<(tenant, id)>` (`ledger.rs:61`), MCP digest set in the ledger replay. It lives ONLY in the WAL.
- Restore of the WAL only: detected by the ratchet in the silicon sink and the airlock (`EPOCH_REGRESSION`,
  `sink.rs:118`, `store.rs:162`); by start-up reconciliation with `evidence.wal` in the MCP proxy
  (`PROTOCOL.md` 7.1); NOT detected in primitives v2 (`PROTOCOL.md:784`).
- Restore or coordinated cut of BOTH files: not detected anywhere (stated: `sink.rs:15`; MCP `PROTOCOL.md:221`;
  airlock `PROTOCOL.md` section 11). After such a restore, every forgotten request id can commit again: a
  duplicate effect. Nothing outside the store anchors either chain.
- NEW, by reading, NOT run: the silicon sink keeps the pre-D7 ratchet rule. It silently drops ratchet entries
  with a bad CRC (`sink.rs:114`, `filter`) and takes the max of the rest. A one-record WAL rollback plus a one-bit
  change of the newest ratchet entry therefore passes the epoch check without repair; the dropped record's
  request id can commit again. The airlock fixed exactly this shape in PR 73, review D7 (`store.rs:163-173`); the
  silicon sink did not get the fix. It needs write access to both files, which is inside the stated trust
  boundary, so it weakens the ratchet's purpose but grants no new privilege.

Concurrency: `flock` exclusive, advisory, released by the kernel on exit (`sink.rs:108`, `store.rs:142`; MCP and
primitives `try_lock`, primitives with a 60 s bounded wait). Two processes through the engine serialize; a
process that ignores the lock is not stopped (stated). TESTED: silicon case `race` (100 processes) and `lock`;
airlock cases `race`, `lock`. Silicon TOCTOU between the binary decision (no lock) and the append: closed by the
CAS on `tail`, charge, original and remaining under the lock (`sink.rs:168`).

Integer conversions (read, not proved): all subtractions are guarded (`sink.rs:92-93`, `ledger.rs:145-147`,
`verbs.rs:264` `checked_sub`); totals use `checked_add` (`ledger.rs:146`); primitives `seq.checked_add`
(`store.rs:390`); `payload.len() as u32` is bounded by `MAX_PAYLOAD` (`store.rs:215`); `u32 as usize` lengths are
bounded before allocation (`store.rs:99`, `MAX_PAYLOAD` 32 KiB). `as_millis() as u64` truncation in the lease
sweep is harmless at present times. Release builds wrap on overflow; the code does not rely on panics. No
defect found by reading.

Liveness, not safety: the silicon sink has no subprocess timeout and reads stdout to EOF before stderr
(`sink.rs:152-153`), so a hanging binary blocks the sink while it holds no lock. The airlock has 10/30 s
timeouts and SIGKILL (`helpers.rs:43-44, 85-105`) but holds the store lock during them.

### F6. Receipt generation order relative to the durable write

| Case | Durable write without a receipt? | Receipt without a durable write? |
| --- | --- | --- |
| Silicon/airlock: answer line fails to write | YES: `DISPATCH_FAILED` (exit 20); the record stays committed, not dispatched (`sink.rs:28`, stated) | no |
| Silicon/airlock: ratchet push fails after WAL sync | YES: `OUTCOME_UNKNOWN`; the next open repairs the ratchet and the record counts as committed (`sink.rs:184`, `store.rs:232`) | no |
| Silicon/airlock: WAL sync fails and undo fails | possibly: `OUTCOME_UNKNOWN` | no |
| MCP: crash after ledger sync, before evidence | YES until next start; start-up writes the receipt from the ledger with the RECOVERY time as timestamp (`PROTOCOL.md` 7.1) | no (ledger synced first; `E > L` refuses start) |
| MCP: evidence write fails | YES; sticky fault; call not forwarded (`PROTOCOL.md` 3.3) | no |
| Primitives v2 | answer after sync; answer loss = durable write without receipt | no |

On honest hardware and an honest engine no receipt precedes durability. A durable write without a delivered
receipt is a designed, stated outcome in every engine. These are TESTED_ONLY (interposer fault injection:
silicon mutants `ignore_wal_sync_error`, `ignore_ratchet_error`, `early_dispatch`; airlock group "durable order
and answer (interposer)" 19/19 killed, per the stale Goal 20 record).

### F7. Model-level proofs exist only for an abstract protocol; nothing connects them to the Rust code

- `proposals/forge2-pillar2-finality-protocol/FinalityProtocol.dfy` (SHA-256 `8b70b6b4…7484`, equal to the
  record). Record `records/summary-attempt-0002.json`: "22 verified, 0 errors", 2026-11-17, pinned Dafny,
  one machine; plus negative fixtures (`NoNonceCheck.dfy` exit 4). Status for the MODEL: MACHINE_CHECKED (one
  recorded run; I found no clean-state replay record for this file).
- Its statement (`InvMeaning`, lines 244-251): every settled claim satisfies `SpecRel`; the log forms one chain
  from `init` to `store`; one outbox entry per settled claim; request ids distinct. `ReplayRejected` (line
  274), `StaleStateRejected` (268), `ForgedTagRejected` (256).
- Assumptions in the model: A1 `IdealMac` (line 10), A3 "Commit is one step of the model" (line 12). A3 is
  EXACTLY the property that durability and crash consistency must establish. The model has no disk, no crash,
  no torn write, no fsync, no rollback, no second writer. So durable execution has NO model-level proof.
- Connection to Rust: none. The silicon record: "The Dafny proofs of Slice 1 …, of the finality protocol model
  and of the sink core model are not connected to this program" (`evidence.json` `source_proof`). No
  refinement mapping from WAL bytes to the model `System` exists. The tests use a hand transcription of the
  formats (`scripts/exit_silicon_sink.py:9`).
- WAL fold F2.7: design only. `proposals/forge2-v2-formal-ceiling/DESIGN.md:261-300`: a CakeML pure-filter
  program `refund_wal`; "NOT started" (commit `33055a59` title); the basis FFI model has "no lock, no sync, no
  truncation, no append, and no crash" (DESIGN.md, U709 findings 4(d), 4(e)); conservation, one commit per id and
  the ratchet are "NEW intent" without an approved spec (F27 precondition P-2); estimate 9 to 18 days, ESTIMATE
  (DESIGN.md:396); "Status after R6, the T11 lift and the WAL fold, if all three succeed: `end_to_end=false`"
  (DESIGN.md:406). Even F2.7 would prove the decision of a pure function over WAL bytes; the write, sync, lock
  and drive stay outside.

### F8. Tests: what kills what

| Suite | Count (from records, not rerun) | Covers source on `main`? |
| --- | --- | --- |
| Silicon: `tests/silicon_sink/test_silicon_crash.py`, 13 cases; 120 chosen kills + 100 blind kills; 49 changed copies, all killed | `proposals/forge2-native-silicon-sink/records/evidence.json` (`mutations.changed_copies` 49), bundle `f8b85b97…` | YES (sink.rs hash equal) |
| Airlock: `tests/airlock/test_engine.py` 33 cases; 114 changed copies killed, 3 known survivors (`X01_helper_input_not_checked`, `R8_ts_sparse_guard`, `N15_sign_key_binding`; `scripts/exit_goal20_sdk.py:481-494`) | `proposals/forge2-goal20-sdk/records/evidence.json` | NO: record predates PR 72 and PR 73 (20 subject files differ). PR 73 before/after logs in `proposals/review-20261120-engine/logs/` |
| MCP proxy: unit 146, servers 14, e2e 27, faults 41 + 1 known limit, regressions 17; 44 of 47 changed copies killed (E01, M04, M27 not killed) | text in `ROADMAP.md:379-381`, `unsure.md:20144-20150` | not pinned by a committed JSON record I could find |
| Primitives v2: 97 or 103 changed copies killed (two numbers in the records: `058eabcb` commit body says 97 of 97 and U912 says 103 of 103) | `ROADMAP.md:55`, `unsure.md:20984` | not pinned by a committed JSON record I could find |

UNTESTED (stated in the records or found absent): power loss on any engine; uid separation (engine under
another OS user: design only, `unsure.md` U894, `proposals/review-20261120-isolation/`, NOT started); a
store writer that ignores `flock`; FNV collisions on policy pins; restore of both files; the silicon flags gap
(F3); the silicon D7 ratchet shape (F5); Node dylib injection (OPEN).

### F9. The receipt: what it is per engine, and who holds the key

| Engine | "Receipt" today | Integrity | Key |
| --- | --- | --- | --- |
| Silicon sink | stdout `COMMITTED <epoch> <fnv128(record)> <frame>`; WAL record 64 B; `replay` reprints frames REBUILT by the sink from records (`sink.rs:241-244`), not the binary's original output | CRC-32 + FNV-1a-128 chain: no key, not cryptographic | none |
| Airlock | stdout `COMMITTED <req> <epoch> <fnv> <payload>`; WAL record `FAR1`; `replay` | CRC-32 + FNV-1a-128: no key | none for records. The cosign record `REFUND … <cosigned 0/1>` stores a FLAG, not the signature (`verbs.rs:194`; stated `PROTOCOL.md:771`: "The record holds no signature, so no later audit can tell") |
| Primitives v2 | answer line; `PV2R` record | SHA-256 chain: no key | none; cosign signature is a STUB that never accepts (`cosign_ttl.rs:61`) |
| MCP proxy | `evidence.wal`: 113-byte record (epoch, ms timestamp, agent_id, tool, pre 16 B, post 16 B, verdict) + SHA-256 chain + `ssh-keygen -Y sign` signature per record (`evidence.rs:1-60`) | Ed25519 signature over the chain hex | an OpenSSH key FILE, mode 0600, owner = euid = the proxy's user (`evidence.rs` "Key check": "a 0600 key does not stop another process of the SAME OS user. It can read the key and sign") |
| Stage 9 hosted signing | Sigstore keyless for BUILD provenance of a research fixture (`spec/provenance/protocol.md`); not for runtime receipts; renewal deferred (`ROADMAP.md:3-12`) | | |

The MCP receipt does not contain: the request line, the request id, the arguments, the policy or its hash,
the proxy binary hash, or a store identity (the ledger genesis is one fixed constant for all stores:
`ledger.rs` "genesis = first16(SHA-256(…))"). The ledger record holds SHA-256 of the request id and of the
raw line, so a third party who also gets `ledger.wal` and the raw line can recompute `post`
(`verify_independent.py --ledger` recomputes the ledger chain and compares pre/post/tool, but has no raw line,
so it cannot check the arguments). Nobody can recompute the POLICY decision, because the policy is not bound.
The verifier states its own limit: whole trailing records removed are not detected without an outside anchor
(`evidence.rs` verifier section).

---

## 2. Evidence or assertion?

Answer: every execution receipt in Forge today is an ASSERTION by the implementation, not evidence of an
enforced transition.

- Silicon sink, airlock, primitives: the chain has no key. Any process of the store's OS user can write a
  valid chain with any content (stated by each engine). The receipt shows that the bytes are internally
  consistent, nothing more.
- MCP proxy: the signature shows that a holder of key K signed the chain value. K is a file of the same OS
  user that runs the proxy, and in the shipped flow the same user that runs the agent (one-user limit). So
  the signature binds "someone with this user's file access", not "the enforced proxy".

What a compromised engine or orchestrator (same OS user) CAN forge: any record, any verdict, any cosign flag,
any agent id, any timestamp, any pre/post pair, any artifact claim; a new valid chain after a coordinated cut
of both files; a valid MCP signature (it reads the key); suppression of trailing records.

What it CANNOT forge: (a) a cosign SIGNATURE of the human key over a message it did not get signed (but the
airlock does not keep the signature, so the forger does not need one: it writes the flag); (b) a valid MCP
receipt signature WITHOUT read access to the key file (an attacker under another uid); (c) a chain that is
consistent with an earlier `final_chain` value that a third party already holds, if that value was taken
before the forgery (an anchor). None of (b) or (c) is deployed: uid separation is NOT TESTED and no anchor
exists.

---

## 3. Independent verifier design (mission section 6)

### 3.1 What a third party can check TODAY without trusting the agent, implementation or orchestrator

- `mcp-proxy verify-evidence` and `tests/mcp_proxy/verify_independent.py` (second implementation, stdlib +
  `/usr/bin/ssh-keygen`): frames, chain, commit continuity, one signature per record, optional ledger
  recomputation. They establish "this file is a well-formed chain whose every record was signed by a key in
  the allowed-signers file". Trust root: the allowed-signers file (the key holder is the proxy's user).
- Silicon/airlock/primitives `replay`/`state`: these are the engine checking itself. A third party can
  re-implement the scan (formats are documented) and get internal consistency only.
- Recomputing a canonical-refund decision: a third party can run the pinned binary (or Dafny
  `RefundFinality.Check`) on the wire rebuilt from the fold. That is re-execution under the same trust in the
  binary; it is not available for cosign (signature not stored) or for parametric money without
  re-implementing `policy.rs`.
- Gate evidence and clearing checks concern build-time proof records, not runtime execution (not checked by
  me beyond scope).

### 3.2 Minimal evidence package for ONE execution

| # | Field | Purpose |
| --- | --- | --- |
| 1 | `store_id`, genesis record bytes (nonce, cosign public key, policy pins as SHA-256, not FNV) | identity of the state machine |
| 2 | policy file bytes | recompute the decision |
| 3 | WAL prefix bytes from genesis to the record before the execution (or a signed checkpoint of the fold state plus the records since) | recompute the pre-state by replay |
| 4 | the exact request line bytes as received | input of the decision |
| 5 | decision evidence: for canonical refund, the exact wire sent and the exact stdout frame, exit code, stderr length; for cosign, the full SSHSIG token and the canonical message; for BOOK, the certificate JSON | recompute or re-verify the decision |
| 6 | the committed record bytes (header, payload, CRC), its epoch and chain hash | the claimed transition |
| 7 | artifact identities: SHA-256 of engine binary, refund binary, ssh-keygen, Node, `model.cjs`, policy files | what claims to have run (assertion unless item 9 attests it) |
| 8 | signature by the engine key K over H(1..7) | who asserts it |
| 9 | trust anchor: a witness co-signature over (store_id, epoch, chain head) by a separate principal, or an inclusion proof in an append-only log, or a platform attestation quote binding K to a code measurement | why the verifier should believe K |
| 10 | a later checkpoint (epoch >= this one) from the same anchor | completeness: no rollback or fork hid or replaced this record |

### 3.3 Checks, classes and verdicts

Pure recomputation (no trust root): CRC and chain of item 3 and item 6; fold replay gives the pre-state;
`apply(pre, record) = post` (same fold rules); request id not in the replayed id set; CAS value in the
request equals the replayed key hash; policy decision recomputed from (pre-state, request, policy) by an
independent evaluator (the Dafny-generated model of `diff-policy` is a candidate); for canonical refund the
wire equals the one rebuilt from the fold with engine-set flags and the frame equals the expected accept
frame; cosign: `ssh-keygen -Y verify` of item 5 against the key of item 1 (this needs only the human's
public key, so it is evidence of human authorization, not of execution).

Needs a trust root: item 8 (needs K's holder to be known), item 7 (needs attestation or a reproducible build
plus attestation that the build ran), items 9 and 10 (needs a witness key or log key and a freshness rule).

Verdicts (fail closed; the first applicable verdict wins; exit codes distinct):

| Verdict | Condition | Exit |
| --- | --- | --- |
| `UNVERIFIABLE_MISSING` | any of items 1 to 8 absent; item 9 absent when the caller asked for the anchored level | 3 |
| `FAIL_MALFORMED` | a field does not parse by the documented format, a length or CRC is wrong | 1 |
| `FAIL_INCONSISTENT` | chain break, replay pre-state differs from the request's CAS, `apply` gives another post, duplicate id, record not foldable | 1 |
| `FAIL_POLICY` | the recomputed decision is not COMMIT, or the decision evidence (frame, signature) does not verify | 1 |
| `FAIL_SIGNATURE` | K's signature or the anchor signature does not verify | 1 |
| `UNVERIFIABLE_TRUST_ROOT` | K or the anchor key is not in the verifier's own trusted set; attestation not checkable | 3 |
| `CONSISTENT_ONLY` | all recomputation passed; no item 8 checked | 0 with level 1 |
| `SIGNED_BY_K` | plus K verified | 0 with level 2 |
| `ANCHORED` | plus items 9 and 10 verified | 0 with level 3 |

"Nothing to verify" is never a pass (same rule as `verify-evidence`).

### 3.4 The smallest honest verifier, and the sentence

The smallest verifier recomputes items 1 to 6 and checks item 8. It can establish: "this record chain is
internally consistent, the transition follows from the replayed pre-state under the bound policy and the
recorded decision evidence, and the chain was signed by key K". It can NOT establish "the state transition
happened on the real store" UNLESS the key that signs (or co-signs) each commit is held by a principal that
(i) the agent and the orchestrator cannot impersonate (another uid, another machine, or hardware that never
exports the key), (ii) itself replayed the fold and checked the transition against ITS OWN copy of the
pre-state before signing, and (iii) publishes its signed chain heads to a place where the verifier sees a
later head (an append-only anchor), so that a rollback, fork or deletion is visible. Even then, "real store"
means "the store as the witness observed it"; the physical drive (F_FULLFSYNC), the external effect (payment,
upstream MCP call) and the code identity of the engine stay outside unless the witness is attested.

Options:

| Option | Adds | Does not add | Cost |
| --- | --- | --- | --- |
| Witness co-signer process under another uid on the same machine (the airlock isolation mode of U894 is the nearest design) | separation from the agent's uid: the agent cannot sign or append; the witness re-checks each transition | protection from root or the kernel; code identity of the witness; anchoring against a joint rollback by root | a service user, a socket, key file owned by the witness user; the D1 design and estimate in `proposals/review-20261120-isolation/` (NOT started); a lock-step protocol between engine and witness |
| External append-only log (own witness on another machine, or a transparency log with signed tree heads) | rollback, fork and truncation detection; ordering; a third party's own copy of heads; timestamps from outside | correctness of the transition (the log signs what it gets) unless the log operator also replays; code identity | network per commit or per batch (a batch leaves unanchored commits); log operator trusted for availability; gossip or witness cosigning for split-view |
| Hardware attestation (TEE quote binding K to the engine measurement: SEV-SNP, TDX, Nitro, TPM-measured boot on Linux) | "this key is held only by code with measurement M"; links the receipt to the exact executed artifact | a proof that code M is correct (still needs the verified chain); durability of the drive | a platform change: macOS offers Secure Enclave keys (non-exportable) but no general code-measurement attestation for a user process, so on the current machine this option gives "key not copied" only; large effort |

---

## 4. Edge table (this part of the chain)

| Edge | Source -> destination | Required invariant | Proof (file, theorem, line) | Checker / command | Environment assumptions | Status | Remaining work |
| --- | --- | --- | --- | --- | --- | --- | --- |
| E6a | built CakeML binary -> binary executed by the airlock | the exec'd bytes have SHA-256 `b8ed5ec2…7bb8` | none | `helpers.rs:134-151` at each exec; `tests/airlock/test_engine.py` cases `pin`, `pin_window` (record stale vs `main`) | kernel; no root or same-uid swap between hash and exec | TESTED_ONLY | fresh evidence bundle for `main`; exec from a verified fd is impossible on macOS: run under another uid that owns a read-only copy |
| E6b | built CakeML binary -> binary executed by the silicon sink | as E6a | none | none in production; test script checks the file only | caller passes the right path | MISSING | add the same pin as the airlock, or retire the silicon sink in favour of the airlock path |
| E6c | Rust source -> engine binary that runs (all four engines) | the running engine is `rustc` output of the pinned source | none; `rustc` unverified | none; no binary hash recorded | `rustc`, linker, loader, launcher, caller choice | MISSING | reproducible build with a recorded hash; launcher check; runtime attestation for a third party (section 3.4) |
| E6d | executed artifacts -> receipt names them | receipt binds artifact hashes | none | none | | MISSING | add hashes to genesis and receipts; only attestation makes them evidence |
| E7a | executed binary -> refund decision enforced by the engine | commit only on the exact accept frame; engine sets flags | none (M1-B OPEN for the binary itself) | silicon 49/49 mutants; airlock mutants (stale record) | pipes, kernel | TESTED_ONLY (airlock); INCOMPLETE (silicon: flags caller-chosen, F3) | silicon: build the flags in the sink; both: refresh records |
| E7b | Rust policy, CAS, ids, tenant, lease rules -> enforced | rules of `PROTOCOL.md` hold for every request through the engine | none | suites + mutants (section F8) | caller cannot write the store folder or start another engine | TESTED_ONLY | a model of the fold with a refinement claim, or a verified fold (F2.7) |
| E7c | MCP policy and ordering -> enforced | commit before forward; deny by default | none | MCP suites; 44/47 mutants | upstream parser equals proxy parser (stated limit) | TESTED_ONLY | bind policy hash; repair E01/M04/M27 survivors |
| E8 | enforced decision -> actual state transition in the WAL | transition = one record appended iff all checks pass; id once; CAS | model only: `FinalityProtocol.dfy` `InvMeaning` 244-251, `ReplayRejected` 274, `StaleStateRejected` 268, under A1 and A3 | model: Dafny run `records/summary-attempt-0002.json` (2026-11-17, one machine, no replay record found); code: tests | A3 atomic commit; single writer via advisory `flock` | MACHINE_CHECKED for the abstract model; TESTED_ONLY for code; link model->code MISSING | a refinement statement: `Abs(scan(wal_bytes ++ encode(rec))) == Commit(Abs(scan(wal_bytes)), c, t)` for the record the engine writes; at least as a differential test of a Dafny-compiled fold against `scan` |
| E9a | WAL transition -> durable on the drive | acknowledged => present after crash or power loss | none | SIGKILL tests (silicon 220 kills; airlock case `kill`); interposer fault injection | F_FULLFSYNC semantics, APFS, SSD firmware (`evidence.json` `os_kernel_assumption`) | TESTED_ONLY (SIGKILL); ASSUMED (power loss) | power-loss test rig; a crash model that discharges A3 (prefix-closed writes) |
| E9b | durable WAL -> no rollback, no replay | used ids never forgotten | none | silicon case `rollback`; airlock case `ratchet_entry` | both files not restored together | TESTED_ONLY (WAL-only restore); MISSING (joint restore; primitives v2 has no ratchet); silicon D7 shape open (F5) | external anchor (section 3.4); port D7 fix to silicon; ratchet for primitives |
| E9c | durable WAL -> external effect | effect at most once, after durability | none | silicon case `dispatch`; MCP `COMMITTED_NOT_FORWARDED` tests | the dispatcher reads the answer line; provider idempotence | TESTED_ONLY; effect execution itself not observed (MCP `PROTOCOL.md:244`) | provider-side receipts; idempotency keys bound into the record |
| E10a | durable transition -> receipt (silicon, airlock, primitives) | a receipt exists only for a durable record, and is checkable | none | ordering tests | | TESTED_ONLY for ordering; receipt integrity MISSING (no key) | sign records; keep cosign signatures and decision frames in the record |
| E10b | durable transition -> signed MCP receipt | record i signed after ledger sync; continuity | none | `verify-evidence`; `verify_independent.py`; MCP suites | key file under the same uid; ssh-keygen trusted | TESTED_ONLY; trust root ASSUMED (same-user key) | witness key under another uid; anchor; bind policy hash, request digest, store id, artifact hashes into the record |
| E10c | receipt -> third-party verdict "the execution respected the spec" | section 3.3 | none | none implements section 3.3 | | MISSING | build the verifier of section 3.4 |

---

## 5. What I could not establish

- Whether the merged airlock engine on `main` (after PR 72 and PR 73) passes its full suite and all changed
  copies: no committed record pins its source; I ran nothing.
- The exact MCP and primitives v2 test results: only text in `ROADMAP.md`/`unsure.md`; no committed JSON
  record with source pins found. The primitives kill count differs between texts (97 of 97 vs 103 of 103).
- Whether any record shows a clean-state replay of `FinalityProtocol.dfy`.
- Whether `sync_all` maps to `F_FULLFSYNC` in the exact std of `rustc 1.92.0`: I rely on the code comments
  (`mcp_proxy/ledger.rs:436-438`) and the interposer traces in the records, not on reading std.
- The silicon flags gap (F3) and the silicon D7 shape (F5) are reading results; I did not run them.
- Whether the HOL M1 statement constrains the three flags in a way that changes F3 (investigator 1's part).
- The behaviour of `rename`/directory sync on APFS at power loss (only `init` uses it).

## 6. Remaining work per edge (honest sizes)

| Edge | Smallest next step | Size | Reuse |
| --- | --- | --- | --- |
| E6b | pin the refund binary in `sink.rs` as in `helpers.rs:134-151`; or declare the airlock the only refund path | small (hours) | `pin.rs`, `cosign::path_checks` |
| E6c/E6d | record engine binary SHA-256 per build; launcher check; put artifact hashes in genesis and in each receipt | small; gives assertion only | `pin.rs` |
| E6c (evidence level) | attestation-bound key (Linux TEE) | large; platform change | none in the tree |
| E7a | silicon: engine-set flags | small | `verbs.rs:170-175` |
| E7b/E8 | Dafny model of the WAL byte fold with a crash model (writes are prefixes), proving: recovery of any prefix of (old ++ record) yields the old or the new abstract state; refines `FinalityProtocol.Commit` and so discharges A3 at model level. Theorem statements: `RecoverPrefix(old, rec, k) in {Abs(old), Commit(Abs(old), c, t)}`; `ScanAppend(old, rec) == Commit(...)`. Then a differential test of the compiled fold against Rust `scan` | medium for the model (no estimate source; my guess 1 to 2 weeks), small for the test | `FinalityProtocol.dfy`, `FinalityProtocol` lemmas `CommitPreservesInv`, `ReplayRejected` |
| E7b (proof of code) | F2.7 `refund_wal` pure filter in CakeML | 9 to 18 calendar days per `DESIGN.md:396` (ESTIMATE), needs the owner's scope decision Q-4 and an approved stored-state spec; M1-B must close first for the theorem to mean anything natively | M1 chain (71 theories) |
| E9a | power-loss rig on the target drive | medium; hardware | silicon interposer |
| E9b | witness or external anchor of chain heads; D7 port to silicon; ratchet for primitives | small (D7, ratchet); medium (anchor) | airlock `store.rs:163-173` |
| E10a/E10b | sign every record with a witness-held key; keep cosign token, decision frame, request digest, policy SHA-256, store id in the record | medium | MCP `evidence.rs` signer and verifier |
| E10c | the verifier of section 3.4 | medium; second implementation recommended | `verify_independent.py` pattern |

None of these items makes `end_to_end` true. They move receipts from assertion to evidence only together with
a separate key holder and an anchor.
