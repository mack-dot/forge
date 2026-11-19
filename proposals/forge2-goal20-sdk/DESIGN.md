# Goal 20, `forge-airlock`: design contract between the parts

Status: a build contract written by the orchestrator before the code. It approves nothing. Where the code and
this file differ, `src/airlock/PROTOCOL.md` (written with the engine) is the reference, and the difference is a
finding to record. `end_to_end=false`.

Labels used everywhere: PROVED CORE (CakeML ARM64 binary / Dafny / Spec Clearing), NATIVE CHECK (Rust, not
proved), FINITE TEST.

## Files

| Path | What | Label |
| --- | --- | --- |
| `src/airlock/*.rs` | engine, std-only Rust, `#![forbid(unsafe_code)]`; entry `src/airlock/main.rs` | NATIVE CHECK |
| `src/airlock/PROTOCOL.md` | wire protocol, record layout, exit codes | document |
| `src/airlock/node/booking_check.cjs` | runs the Dafny-compiled `BookingDualCert` checker | PROVED CORE source; Dafny compiler and Node trusted |
| `src/airlock/node/cosign.cjs` | Ed25519 `keygen`, `sign`, `verify` through `node:crypto` | NATIVE CHECK; Node crypto trusted |
| `src/airlock/py/diff_policy.py` | Before/After table; JSON-to-Dafny generator; NO_CHOICE through `scripts/spec_clearing.py` | generator trusted; verdict PROVED CORE for the generated model |
| `src/airlock/py/fuzz.py` | finite fuzz pass | FINITE TEST |
| `bin/forge-airlock` | thin Python stdlib dispatcher | not trusted for a decision |
| `sdk/py/forge_airlock.py`, `sdk/ts/forge_airlock.ts` | SDKs, stdlib only | not trusted for a write decision |
| `tests/airlock/` | suites | FINITE TEST |
| `examples/unbreakable_store/run_demo.py`, `docs/quickstart-5min.md`, `scripts/exit_goal20_sdk.py` | demo, quickstart, EXIT script | FINITE TEST |

Build: `rustc --edition 2021 -D unsafe_code -C opt-level=3 src/airlock/main.rs -o build/airlock/airlock-engine`
(rustc 1.92.0). A second build with `--cfg kill_points` gives the test seams (as in `src/silicon_sink/sink.rs`).
`src/silicon_sink/sink.rs` is not changed.

## Engine rules (generalized from `sink.rs`)

- One store = one folder: a WAL file, a ratchet file, the pinned policy files, the pinned cosign public key.
- Records are length-bounded and carry a CRC-32; a global FNV-1a-128 chain links each record to the one before.
  At most one torn record at the end is cut by recovery; everything else is `CORRUPT_WAL`. (The plan says
  "64-byte record". Tenant, key and saga fields do not fit in 64 bytes; the engine states its layout in
  `PROTOCOL.md`. This is a stated deviation.)
- Every write: exclusive `flock` -> fold -> ratchet check -> checks -> append -> `sync_all` (`F_FULLFSYNC`) ->
  ratchet entry -> `sync_all` -> answer line. `init` also syncs the folder. A refusal leaves no effect record.
- Compare-and-swap: each key (tenant, key) has a `state_hash` = FNV-1a-128 of the last record that changed it.
  A write names the `pre_state_hash` it read; another value gives `STALE_STATE_HASH`.
- Request ids are fresh per store: a committed id gives `DUPLICATE_REQUEST_ID`. A refusal closes only the attempt.
- Ids: `[A-Za-z0-9_-]{1,24}`. Amounts: canonical decimal, at most `9223372036854775807`. Lines are bounded.
- `tenant_id` is a field of every key. A write or read of a key under another tenant is refused.
- A store has a `store_id` (given at `init`, or random). It is bound in the genesis record, so state hashes of two
  stores differ.

Typed results (the SDK names): `COMMITTED`, `REJECTED_POLICY`, `REQUIRE_HUMAN_COSIGN`, `STALE_STATE_HASH`,
`DUPLICATE_REQUEST_ID`, `TENANT_ISOLATION_BREACH`, `DROPPED_OBLIGATION`. Other refusals (malformed input, corrupt
WAL, I/O error, unknown outcome, helper failure) have their own codes and never read as `COMMITTED`.

## Policy files (JSON; strict parser in the engine; unknown keys refused)

Money:

```json
{"airlock": "money", "version": 1, "name": "store-refunds", "profile": "parametric",
 "rules": [
  {"reason": "DUPLICATE_CHARGE", "verdict": "COMMIT"},
  {"reason": "SHIPPING", "max_reason_total_fact": "shipping_paid", "verdict": "COMMIT"},
  {"reason": "GOODWILL", "max_amount": "2000", "verdict": "COMMIT"},
  {"reason": "GOODWILL", "min_amount": "2001", "verdict": "REQUIRE_HUMAN_COSIGN"}
 ]}
```

- Always first, built in: `amount >= 1` and `amount <= remaining` (total cap; `remaining` = original minus all
  committed amounts of the key). Failure: `REJECTED_POLICY TOTAL_CAP` (or `ZERO_AMOUNT`).
- A rule matches when the reason is equal, `min_amount <= amount <= max_amount` (each optional), and, if
  `max_reason_total_fact` is present, (committed total of this reason on this key) + amount <= the fact's value.
  Facts are named amounts fixed when the key is opened (example: `shipping_paid`).
- No rule matches: `REJECTED_POLICY NO_RULE`. Rules that match with different verdicts: the engine takes the most
  restrictive (`REJECTED_POLICY` > `REQUIRE_HUMAN_COSIGN` > `COMMIT`); `diff-policy` reports that policy as CHOICE.
- `REQUIRE_HUMAN_COSIGN` becomes `COMMIT` only with a valid cosign (below).
- `"profile": "canonical-refund"`: no `rules`; the three reasons `duplicate_charge`, `service_not_delivered`,
  `returned_item`, one charge per key; each request goes through the CakeML binary `b8ed5ec2...7bb8` exactly as in
  `sink.rs` (private process, empty environment, exact frame). Only this profile has the PROVED CORE label for the
  decision. A parametric policy is NATIVE CHECK + FINITE TEST.

Pure evaluation for `diff-policy` and tests (no store): `airlock-engine eval <policy.json>` reads lines
`EVAL <reason> <amount> <remaining> <reason_total> [<fact>=<value>]...` and answers one line each: `COMMIT`,
`REQUIRE_HUMAN_COSIGN`, or `REJECTED_POLICY <CODE>`. The engine uses the same function for a commit.

Saga:

```json
{"airlock": "saga", "version": 1, "name": "payout",
 "states": ["PAID", "IN_FLIGHT", "SETTLED", "CONFIRMED_REJECTED"], "initial": "PAID",
 "in_flight": ["IN_FLIGHT"],
 "transitions": [["PAID", "IN_FLIGHT"], ["IN_FLIGHT", "SETTLED"], ["IN_FLIGHT", "CONFIRMED_REJECTED"],
                 ["CONFIRMED_REJECTED", "IN_FLIGHT"]]}
```

A move into an `in_flight` state names `(processor, idempotency_key)`; the record holds both. A move out of it must
name the same pair. While a key is in flight, a move that names another processor or key is refused
(`REJECTED_POLICY PROCESSOR_IN_FLIGHT`). A pair that is not in `transitions` is `REJECTED_POLICY NO_TRANSITION`.

Inventory:

```json
{"airlock": "inventory", "version": 1, "name": "seats", "min_alpha_bps": "0"}
```

A key is opened with a capacity vector `c`. A batch commit carries the Slice 3 certificate
`(A, c, w, x, y, z, alpha_bps)`. Native checks: `c` equals the present remaining capacities of the key; sizes are
bounded; `alpha_bps` meets the policy. Then `booking_check.cjs` must answer exactly `ACCEPT`. The new remaining
capacity is `c - A*x`, computed natively and checked to be non-negative. No Dafny process starts at run time.

## Node helpers (bounded private subprocess; the engine accepts only exit 0 + the exact line + empty stderr)

- `node src/airlock/node/booking_check.cjs <model.cjs>`: stdin = one JSON object
  `{"A":[["1","0"]],"c":["3"],"w":["5","2"],"x":["1","0"],"y":["0"],"z":["5","0"],"alpha_bps":"0"}` (integers as
  canonical decimal strings; at most 1 MiB). stdout `ACCEPT\n` (exit 0) or `REJECT\n` (exit 1). Malformed: exit 2.
- `node src/airlock/node/cosign.cjs verify <public-key-hex> <signature-hex>`: message bytes on stdin. `VALID\n`
  exit 0; `INVALID\n` exit 1; else exit 2.
- `cosign.cjs keygen <new-key-file>` (creates with `O_EXCL`, mode 0600; prints the public key hex) and
  `cosign.cjs sign <key-file>` (message on stdin; D-1 rules on the opened descriptor: `O_NOFOLLOW`, regular file,
  uid == euid, `mode & 0o077 == 0`; prints the signature hex). These two are the HUMAN's tool. The engine never
  reads a private key.

## Cosign

Message = the bytes `forge-airlock-cosign-v1\n<store_id>\n<request_id>\n<pre_state_hash 32 hex>\n<action>\n`,
where `action` is the canonical request text with no line end. No field can hold a line end, so no field boundary
can move. The engine builds the message (`airlock-engine <store> cosign-message ...` prints it for the human's
tool) and verifies the signature against the public key pinned at `init`. Limit: an agent that runs as the same OS
user as the key owner can read a 0600 file. "The agent cannot self-cosign" holds only when the private key is
outside the agent's reach.

## Read airlock (L3) and leases (L4)

- `read_scoped(tenant_id, rows)`: the SDK sends the caller's tenant and every row to the engine; the engine
  refuses the whole result (`TENANT_ISOLATION_BREACH`, 0 rows) if the tenant is empty or not canonical, or any row
  lacks a string `tenant_id` equal to it. Limit: it sees only the rows passed to it.
- `OPEN_LEASE(request_id, deadline_ms)` is a durable record. Only a terminal verdict record for the same request
  id closes it: `COMMITTED`, `REJECTED_POLICY`, `REQUIRE_HUMAN_COSIGN`. `leases --sweep` reports each open lease
  past its deadline as `DROPPED_OBLIGATION`. Limit: only handlers that opened a lease.

## Not claimed

No proof of the engine, the SDKs, the helpers or the dispatcher. No "% of bugs" figure. A SIGKILL is not a power
loss. FNV-1a-128 is not cryptographic. Whoever can write the store folder is trusted. M1-B stays OPEN.
