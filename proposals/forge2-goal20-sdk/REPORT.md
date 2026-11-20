# Goal 20, `forge-airlock`: report

CURRENT none. Stage 9 deferred. M1-B OPEN. Stage 12 unauthorized. `end_to_end=false`. Not a stage. Not gate
evidence. No protected file changed. Nothing under `clearing/` changed. NOT merged by the agent.

Branch `feat/zero-babysitting-sdk`, started from `e2b8ba1d`; `origin/main` (`a5133c01`, pull request 63) was merged
in with a merge commit. The owner's directive, the approved plan and the three decisions are in
[BRIEF.md](BRIEF.md). The build contract and what changed after it are in [DESIGN.md](DESIGN.md). The wire is in
[PROTOCOL.md](../../src/airlock/PROTOCOL.md). The one review is in [REVIEW.md](REVIEW.md). The bundle record is
[records/evidence.json](records/evidence.json). The developer text is
[quickstart-5min.md](../../docs/quickstart-5min.md).

## What was built

| Part | Files | Label |
| --- | --- | --- |
| Engine: WAL store with tenant keys, money, saga, inventory, cosign check, read airlock, leases | `src/airlock/*.rs` (8 files, 1860 lines, std only, `#![forbid(unsafe_code)]`) | NATIVE CHECK; not proved |
| Booking checker caller and Ed25519 cosign tool | `src/airlock/node/*.cjs` (compiled into the engine) | the Dafny source is PROVED CORE; the Dafny compiler, Node, `node:crypto`, `bignumber.js` and the conversion code are trusted |
| `diff-policy` | `src/airlock/py/diff_policy.py`, `policy_model.py` | table: NATIVE CHECK on finite scenarios; NO_CHOICE: PROVED CORE for the generated Dafny model only; the generator is a trusted assumption with negative controls |
| Dispatcher, SDKs, fuzz | `bin/forge-airlock`, `sdk/py`, `sdk/ts`, `src/airlock/py/fuzz.py` | not trusted for a write decision; FINITE TEST |
| Demo, quickstart, EXIT script, suites | `examples/unbreakable_store/`, `docs/quickstart-5min.md`, `scripts/exit_goal20_sdk.py`, `tests/airlock/` | FINITE TEST |

PROVED CORE applies to three things only: (1) the decision of the CakeML ARM64 binary `b8ed5ec2…7bb8` for the
canonical-refund profile (three fixed reasons, one charge per key; the engine sets the three flags to True, so the
flag logic of the binary is not exercised through the engine; M1-B is OPEN, so the binary's theorems still have
open premises); (2) the Dafny source `BookingDualCert.dfy` behind the compiled inventory checker; (3) NO_CHOICE or
CHOICE for the Dafny model that the generator writes for one money policy. Every parametric policy, every saga and
every SDK result is NATIVE CHECK and FINITE TEST.

## Actual results

All commands ran on one machine (Darwin arm64, rustc 1.92.0, Node v24.3.0 with the pinned digest, Dafny 4.11.0).

| EXIT command/check | Actual exit/result | Result |
| --- | --- | --- |
| `rustc --edition 2021 -D unsafe_code -C opt-level=3 src/airlock/main.rs -o build/airlock/airlock-engine` | 0 | no warning; a copy with one `unsafe` block: exit 1 |
| `scripts/exit_goal20_sdk.py --case build` | 0 | both engine builds; Dafny verify and build of the checker (46 verified); model `e705ec49…85f4` equals its tracked record |
| `--case suite` | 0 | engine 26 of 26; Node helpers 137 of 137; `diff-policy` 11 of 11; SDK 19 of 19 |
| `--case disasters` | 0 | 8 of 8 PASS; money leaked, read from the WAL: 0 |
| `--case fuzz` | 0 | seed 20, 3 rounds: 8 of 8 invariants HELD |
| `--case mutations` (after the review) | 0 | 114 of 114 changed copies killed; 2 more NOT killed and recorded |
| `--case evidence` (final, run by the orchestrator) | 0 | all of the above twice; bundle `1e75ab471b5fe3cede67f2746fa8c0542fbafff6959bd5a8199cfca3338a70fa`, byte-identical; wall 1645 s |
| the one fresh-context review | 2 FAIL-OPEN; 1 HIGH; 3 MEDIUM; 3 LOW; 2 NOTE | findings 1 to 5 and 7 to 9 repaired in one pass; 6, 10, 11 stated; NOT reviewed again |
| any HOL or Holmake step; Stages 7, 9, 10; a power-loss test; a second review | NOT RUN | not part of this work |

The regression on a scratch clone and the hosted result are in `ROADMAP.md` and `unsure.md`, because they are
measured on the commit that holds this file.

## The eight disasters (engine answers, from the bundle)

| No. | Disaster | Observed |
| --- | --- | --- |
| 1 | 50 processes, one refund, one `pre_state_hash` | 1 `COMMITTED`, 49 `STALE_STATE_HASH`; the WAL holds one refund |
| 2 | 50,000 dollar injected refund on a 100 dollar order | `REJECTED_POLICY TOTAL_CAP` (Python and TypeScript); canonical profile: `REJECTED_POLICY CAKEML_REJECTED`; 0 effects |
| 3 | 10 dollar shipping ask proposed as 80 | `REJECTED_POLICY REASON_CAP`; the real 10 dollar ask then commits |
| 4 | 75 dollar goodwill | `REQUIRE_HUMAN_COSIGN`; a signature of another key: `COSIGN_INVALID`; the pinned (temporary) key: `COMMITTED` |
| 5 | timeout retry and failover while in flight (LOCAL FAKE Stripe and PayPal) | both `REJECTED_POLICY PROCESSOR_IN_FLIGHT`; after `CONFIRMED_REJECTED` the failover commits |
| 6 | forgotten tenant filter | `TENANT_ISOLATION_BREACH`, 0 rows and 0 bytes returned (both SDKs) |
| 7 | TypeError in a webhook before the sink | the lease stays open; a rejection on another key does not close it; the sweep reports `DROPPED_OBLIGATION` for both handlers |
| 8 | solver swap with bad batches | overbooked and suboptimal batches rejected; the optimum commits; 0 Dafny starts seen at run time |

Valid traffic: 20 commits. Attacks blocked: 61. Demo measurements of one run (not in the bundle): Python SDK call
p50 8.0 ms and p99 508 ms (the p99 holds the first helper call of a process, which hashes the Node binary);
TypeScript step p50 0.6 ms and p99 66 ms; peak resident memory 103 MB for the Node child, 26 MB for the demo.

## Limits and trusted assumptions

- Trust boundary. Every rule holds only against a caller that reaches the store through the engine. A process
  that can write the store folder can append records itself. A process that can run its own engine on the folder
  can ignore every check.
- Cosign. The engine verifies an Ed25519 signature of the pinned public key through `node:crypto`. An agent that
  runs as the same OS user as the key owner can read a 0600 key file. "The agent cannot self-cosign" needs the
  private key outside the agent's reach AND an agent that cannot write the store folder or run another engine on
  it. The demo runs the agent and the key as one OS user: it shows the mechanism, not the separation.
- The opener of a key is trusted for `original`, the facts and the tenant. The tenant field is not authenticated.
- The read airlock sees only the rows passed to it and checks only the top-level `tenant_id`.
- Leases cover only handlers that opened one.
- Trusted: the Dafny compiler and its JavaScript runtime; Node and `node:crypto`; `bignumber.js` 9.3.1 from the
  pinned `node_modules` (the compiled checker needs it; it is an existing dependency, not a new one); the
  JSON-to-Dafny generator; the kernel and the drive for `F_FULLFSYNC`; rustc.
- A file swapped after its hash check is not detected. A restore of the WAL and the ratchet together is not
  detected. FNV-1a-128 is a concurrency control, not cryptography. A SIGKILL is not a power loss.
- macOS ARM64 only for the CakeML binary. `diff-policy` supports money and saga policies; for a saga it prints a
  set difference and proves nothing.
- Disaster 8: the two bad batches are rejected by the native `Accepts` check before the compiled checker runs.
  The compiled checker decides only batches that pass the native check. "0 Dafny starts" rests on a PATH with no
  Dafny and on process listings of the demo's descendants; a start by absolute path of a very short process could
  be missed.
- Two changed copies are NOT killed: the check that a helper read all of its input (X01), and the sparse-array
  guard of the TypeScript `readScoped` alone (R8; a second layer gives the same answer).
- No "% of bugs" figure is claimed: nothing measures one.

## Differences from the directive and the plan

- Record layout: variable length (32-byte header, payload up to 32 KiB), not 64 bytes.
- The inventory policy key is `max_alpha_bps`.
- The store pins the Node binary; the helpers are inside the engine; `init --node` is needed for a cosign key or
  an inventory policy. A first helper call of a process costs about 0.5 s for the hash.
- `with_lease` takes a tenant and a key (review finding 5).
- "5 minutes" needs rustc 1.92.0 and Node 24.3.0 installed, and the pinned Dafny once for the inventory checker.
- Commits carry the trailer of the model that ran the session (`Claude Fable 5.2`), not the trailer named in the
  launcher's text; the workers ran on the model `opus`.
