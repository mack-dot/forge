# forge-airlock engine: wire protocol, record layout, codes

Status: the reference for the engine in `src/airlock/*.rs`. Where it differs from
`proposals/forge2-goal20-sdk/DESIGN.md`, this file describes the code, and section 12
lists each difference. `end_to_end=false`.

Labels: **PROVED CORE** (CakeML ARM64 binary, Dafny, Spec Clearing), **NATIVE CHECK**
(Rust, not proved), **FINITE TEST**. The engine as a whole is a NATIVE CHECK. Only two
decisions have a PROVED CORE part:

- a `REFUND` on a key whose policy has `"profile": "canonical-refund"`: the CakeML
  refund binary (SHA-256 `b8ed5ec2…7bb8`) decides;
- a `BOOK`: the Dafny-compiled `BookingDualCert` checker (`booking_check.cjs`, run by
  Node) must accept. The Dafny compiler and Node are trusted.

## 1. Build

```sh
rustc --edition 2021 -D unsafe_code -C opt-level=3 src/airlock/main.rs -o build/airlock/airlock-engine
rustc --edition 2021 -D unsafe_code -C opt-level=3 --cfg kill_points src/airlock/main.rs -o build/airlock/airlock-engine-kill
```

Standard library only. No crate, no Cargo. `#![forbid(unsafe_code)]`. Modules:
`main.rs` (CLI, `serve`, answers, codes), `store.rs` (records, WAL, ratchet, `init`),
`ledger.rs` (the fold), `policy.rs` (policy files, money rules, native `Accepts`),
`verbs.rs` (request verbs, read airlock), `helpers.rs` (subprocesses), `json.rs`
(strict JSON parser).

## 2. Subcommands

| Command | Output (one line unless stated) | Exit |
| --- | --- | --- |
| `init <dir> [--store-id ID] [--policy FILE]... [--cosign-pubkey HEX64]` | `INITIALIZED <store_id> <genesis_hash>` | 0, or a code |
| `serve <dir> [--refund-binary P] [--node P] [--helpers DIR] [--checker MODEL]` | one answer line per request line | code of the last answer; 2 if no line |
| `state <dir>` | `STATE <epoch> <tail_hash> <store_id> keys=<n> effects=<n> leases=<n>` | 0 |
| `get <dir> <tenant> <key>` | as the `GET` verb | 0, 16, 21 |
| `replay <dir>` | `REPLAY <n>`, then n lines `EFFECT <epoch> <payload>` | 0 |
| `leases <dir>` | `LEASES <n>`, then n lines `LEASE <request_id> <deadline_ms>` (WAL order) | 0 |
| `leases <dir> --sweep [--now MS]` | `SWEEP <open> <dropped> now=<MS>`, then one line `DROPPED_OBLIGATION <request_id> <deadline_ms>` per open lease with `now > deadline_ms` | 0 none dropped; 24 at least one |
| `eval <policy.json>` | one answer per stdin line (section 6) | 0; 25 bad policy |
| `cosign-message <dir> <action>` | the exact message bytes (5 lines, LF-terminated) | 0, or a code |

- `--store-id` absent: the engine makes `st-` and 21 hex digits from the clock and the
  process id. Not random in a cryptographic sense.
- `--now` is only valid with `--sweep`. Without `--now`, the sweep uses the system clock
  in milliseconds since the Unix epoch.
- A sweep is read-only: it writes no record. A dropped lease stays open. The next sweep
  reports it again.
- Every command except `init` and `eval` takes the store lock and runs recovery first
  (section 4). They need write access to the store.
- `serve` takes the lock per request, not for its lifetime. Many `serve` processes can
  work on one store at once.
- `--node` must be an absolute path to the Node binary. `--helpers` is the folder of
  `cosign.cjs` and `booking_check.cjs` (normally `src/airlock/node`). `--checker` is the
  compiled model (normally `build/airlock/checker/model.cjs`). A missing flag makes the
  verb that needs it answer `HELPER_FAILED`; it never commits.

## 3. Lines and tokens

- A request line ends with LF. At most 65,536 bytes before the LF (`MAX_LINE`). A
  longer line is skipped up to its LF with constant memory and answered
  `MALFORMED_REQUEST OVERSIZED ...`. Bytes after the last LF with no LF:
  `MALFORMED_REQUEST NO_LINE_END`.
- A request line is printable ASCII (0x20 to 0x7e) only. Fields are separated by ONE
  space. No leading, trailing or double space. No CR, no tab.
- Id (`tenant`, `key`, `request_id`, `store_id`, policy name, `reason`, fact name, saga
  state, `processor`, `idempotency_key`): `[A-Za-z0-9_-]{1,24}`. Case matters.
- Amount (`original`, `amount`, fact value, capacity, `deadline_ms`): `0` or a nonzero
  digit followed by up to 18 digits; at most `9223372036854775807` (MaxMoney).
- Hash (`pre_state_hash`, `state_hash`): exactly 32 lowercase hex digits.
- Signature: exactly 128 lowercase hex digits. Public key: exactly 64 lowercase hex.

## 4. Store and record layout

A store is one folder:

| File | Content |
| --- | --- |
| `airlock.wal` | the records |
| `airlock.epoch` | the ratchet: 12-byte entries (epoch u64 LE, CRC-32 of those 8 bytes) |
| `policy-<name>.json` | the pinned policy files, byte copies of the `--policy` files |

Record (little-endian; a stated deviation from the 64-byte plan, because tenant, key
and saga fields do not fit in 64 bytes):

| Bytes | Field |
| --- | --- |
| 0..4 | magic `FAR1` |
| 4..12 | epoch: 0 for the genesis record, then +1 per record |
| 12..28 | FNV-1a-128 of the whole previous record (zero in the genesis record) |
| 28..32 | payload length L, at most 32,768 |
| 32..32+L | payload: printable ASCII, fields separated by one space |
| 32+L..36+L | CRC-32/IEEE of bytes 0..32+L |

The hash of a record is FNV-1a-128 of all its bytes. The `state_hash` of a key is the
hash of the last record that changed the key. The genesis record holds the store id, so
two stores never give the same state hashes for the same requests. FNV-1a-128 is NOT
cryptographic.

Payloads:

| Payload | Effect | Written by |
| --- | --- | --- |
| `GENESIS 1 <store_id> <pubkey or -> <n> [<policy> <money or saga or inventory> <fnv128 of the file>]×n` | store | `init` |
| `OPEN_MONEY <tenant> <key> <request_id> <policy> <original> [<fact>=<value>]...` (facts sorted by name) | yes | `OPEN_MONEY` |
| `REFUND <tenant> <key> <request_id> <reason> <amount> <0 or 1>` (1 = cosigned) | yes | `REFUND` |
| `OPEN_SAGA <tenant> <key> <request_id> <policy> <initial>` | yes | `OPEN_SAGA` |
| `SAGA <tenant> <key> <request_id> <to> <processor or -> <idempotency_key or ->` | yes | `SAGA` |
| `OPEN_INVENTORY <tenant> <key> <request_id> <policy> <c1,c2,...>` | yes | `OPEN_INVENTORY` |
| `BOOK <tenant> <key> <request_id> <x as 0/1 digits> <new remaining c1,c2,...>` | yes | `BOOK` |
| `LEASE <request_id> <deadline_ms>` | no | `OPEN_LEASE` |
| `CLOSE <request_id> <REJECTED_POLICY or REQUIRE_HUMAN_COSIGN> <detail>` | no | a terminal refusal while a lease is open |

The fold (`ledger.rs`) checks each record again: fresh request id, key kind and tenant,
`1 <= amount <= remaining` for a refund, new remaining capacity not above the old one, a
`CLOSE` only for an open lease. A record that fails is `CORRUPT_WAL`. The writer applies
the same fold to a record before it writes it: a record that the fold would refuse is
never written (`MALFORMED_REQUEST RECORD_NOT_FOLDABLE`).

Order of one write: exclusive `flock` on `airlock.wal` (before any store file is read)
-> fold -> ratchet check -> recovery -> pinned policy files read and hashed -> checks ->
helper process (if any; the lock is held) -> write of the record -> `sync_all` ->
ratchet entry -> `sync_all` -> lock released -> answer line. `sync_all` is
`fcntl(F_FULLFSYNC)` on macOS.

- A failed write or sync of the record: the engine cuts the WAL back to its old length
  and syncs. If that works: `IO_ERROR` (nothing committed). If not: `OUTCOME_UNKNOWN`
  (a record may stay). A failed ratchet entry after a durable record: `OUTCOME_UNKNOWN`.
- Recovery: after the valid prefix, at most one incomplete record may follow, and only
  at the end of the file: fewer than 32 bytes, or a header whose length runs past the
  end. It is cut, the WAL is synced, and a ratchet entry is pushed. A whole record that
  is not valid, anywhere, is `CORRUPT_WAL`. A ratchet maximum above the last epoch is
  `EPOCH_REGRESSION` (an older WAL with the present ratchet).
- A policy file whose FNV-1a-128 differs from its genesis pin: `CORRUPT_WAL POLICY_CHANGED`.
- `init` builds the store in a fresh sibling folder `<dir>.init-<pid>-<ns>`, syncs every
  file and that folder, renames it to `<dir>`, and syncs the parent folder. It refuses
  when `<dir>` exists in any form (`IO_ERROR STORE_EXISTS`). A failure before the rename
  removes the temporary folder and answers `IO_ERROR`; a killed `init` leaves no `<dir>`
  (it can leave the temporary folder).
- Rule: the answer of `init` and the disk agree. `INITIALIZED` comes only after the sync
  of the parent folder returned Ok. If that sync fails (after the rename), the engine
  undoes the store: it takes the store lock, checks that the WAL still holds only the
  genesis record, empties the WAL and syncs it (a process that opened the store meanwhile
  then gets `CORRUPT_WAL`, never a commit), renames the folder back, removes it, and syncs
  the parent folder again. All steps worked: `IO_ERROR`, and no `<dir>` stays. Any step
  failed, or another process wrote a record: `OUTCOME_UNKNOWN` (19); the store may stay,
  live or with an empty WAL (then every command answers `CORRUPT_WAL`). Never
  `INITIALIZED` without the parent sync, never a working store behind `IO_ERROR`.

## 5. Request verbs (`serve`)

Check order for a write to an existing key: grammar (no file opened) -> lock and fold ->
`UNKNOWN_KEY` -> `TENANT_ISOLATION_BREACH` -> `DUPLICATE_REQUEST_ID` ->
`STALE_STATE_HASH` -> policy. An open verb names no `pre_state_hash`; the key must be
absent: a key of another tenant is `TENANT_ISOLATION_BREACH`, a key of the same tenant
is `STALE_STATE_HASH <present hash>`.

Request ids are fresh per store: one namespace for all keys, tenants and verbs. Only an
effect record uses an id up. A refusal (also a terminal one) leaves the id fresh.

| Verb | Grammar | Success answer |
| --- | --- | --- |
| `OPEN_MONEY` | `OPEN_MONEY <tenant> <key> <request_id> <policy> <original> [<fact>=<value>]...` (0 to 16 facts; none for `canonical-refund`) | `COMMITTED ...` |
| `REFUND` | `REFUND <tenant> <key> <request_id> <pre_state_hash> <reason> <amount> [<signature>]` | `COMMITTED ...` |
| `OPEN_SAGA` | `OPEN_SAGA <tenant> <key> <request_id> <policy>` (state = the policy's `initial`) | `COMMITTED ...` |
| `SAGA` | `SAGA <tenant> <key> <request_id> <pre_state_hash> <to_state> [<processor> <idempotency_key>]` | `COMMITTED ...` |
| `OPEN_INVENTORY` | `OPEN_INVENTORY <tenant> <key> <request_id> <policy> <c1,c2,...>` (1 to 64 amounts) | `COMMITTED ...` |
| `BOOK` | `BOOK <tenant> <key> <request_id> <pre_state_hash> <certificate JSON>` (the rest of the line) | `COMMITTED ...` |
| `OPEN_LEASE` | `OPEN_LEASE <request_id> <deadline_ms>` | `LEASE_OPENED <request_id> <epoch> <deadline_ms>` |
| `GET` | `GET <tenant> <key>` | `OK <state_hash> <kind> <field>=<value>...` |
| `STATE` | `STATE` | as the `state` subcommand |
| `READ` | `READ <tenant> <n>`, then exactly n row lines | `OK <n>` |

`COMMITTED <request_id> <epoch> <new_state_hash> <record payload>`. The new state hash
is the `pre_state_hash` for the next write to the key.

`GET` fields: money `policy= original= remaining= fact.<name>= total.<reason>=`; saga
`policy= state= processor= idempotency_key=` (`-` when not in flight); inventory
`policy= remaining=c1,c2,...`.

Examples (hashes shortened here; on the wire they are 32 digits):

```text
> OPEN_MONEY t1 order-1 r1 store-refunds 10000 shipping_paid=1000
< COMMITTED r1 1 4b8b…bf21 OPEN_MONEY t1 order-1 r1 store-refunds 10000 shipping_paid=1000
> REFUND t1 order-1 r2 4b8b…bf21 SHIPPING 8000
< REJECTED_POLICY REASON_CAP
> REFUND t1 order-1 r2 4b8b…bf21 SHIPPING 500
< COMMITTED r2 2 88e0…ac41 REFUND t1 order-1 r2 SHIPPING 500 0
> REFUND t1 order-1 r3 4b8b…bf21 SHIPPING 500
< STALE_STATE_HASH 88e0…ac41
> REFUND t2 order-1 r3 88e0…ac41 SHIPPING 1
< TENANT_ISOLATION_BREACH KEY_OF_ANOTHER_TENANT
> OPEN_SAGA t1 pay-1 r4 payout
> SAGA t1 pay-1 r5 <hash> IN_FLIGHT stripe idem-1
> SAGA t1 pay-1 r6 <hash> IN_FLIGHT paypal idem-2
< REJECTED_POLICY PROCESSOR_IN_FLIGHT
> OPEN_INVENTORY t1 seats-1 r7 seats 3
> BOOK t1 seats-1 r8 <hash> {"A":[["1","1"]],"c":["3"],"w":["5","2"],"x":["1","1"],"y":["0"],"z":["5","2"],"alpha_bps":"0"}
< COMMITTED r8 9 85b8…ab3b BOOK t1 seats-1 r8 11 1
> OPEN_LEASE wh-77 1763560000000
< LEASE_OPENED wh-77 10 1763560000000
> READ t1 2
> {"tenant_id":"t1","total":12.5}
> {"tenant_id":"t2","total":3}
< TENANT_ISOLATION_BREACH ROW 1 TENANT_MISMATCH
```

### 5.1 Leases

- `OPEN_LEASE` refuses an id that is used up or has an open lease
  (`DUPLICATE_REQUEST_ID`).
- A lease closes ONLY by a terminal verdict for its request id: an effect record
  (`COMMITTED`), or a `REJECTED_POLICY` or `REQUIRE_HUMAN_COSIGN` answer. For the two
  refusals, the engine writes a durable `CLOSE` record (synced, ratcheted) before the
  answer, and the answer gets `LEASE_CLOSED <epoch>` after its detail:
  `REJECTED_POLICY TOTAL_CAP LEASE_CLOSED 7`.
- Other refusals (`STALE_STATE_HASH`, `DUPLICATE_REQUEST_ID`, `MALFORMED_REQUEST`,
  `TENANT_ISOLATION_BREACH`, `UNKNOWN_KEY`, `HELPER_FAILED`, `BAD_FRAME`, faults) do not
  close a lease.
- Limit: the engine sees only handlers that opened a lease.

### 5.2 Read airlock

`READ <tenant> <n>` with `0 <= n <= 100000` (canonical decimal), then n row lines. The
engine reads all n lines also after a failure, so the stream stays in step. A row is a
UTF-8 line of at most 65,536 bytes holding one strict JSON object (section 9). Answer
`OK <n>` only if the tenant is a canonical id and every row is an object with a
`tenant_id` member whose value is a string equal to the tenant. Otherwise
`TENANT_ISOLATION_BREACH <why>` and 0 rows are released. `<why>`:
`TENANT_NOT_CANONICAL`, `ROW <i> <TENANT_MISMATCH|TENANT_NOT_STRING|TENANT_MISSING|NOT_OBJECT|NOT_UTF8|OVERSIZED|NO_LINE_END|<JSON error>>`,
`ROWS_MISSING <i> of <n> rows came` (EOF). A bad header (`n` not canonical or above
100,000) is `MALFORMED_REQUEST READ_HEADER` and consumes no row. Limit: the engine sees
only the rows passed to it.

## 6. Money airlock

Policy file (strict; unknown keys refused; `version` must be the JSON integer 1):

```json
{"airlock": "money", "version": 1, "name": "store-refunds", "profile": "parametric",
 "rules": [
  {"reason": "DUPLICATE_CHARGE", "verdict": "COMMIT"},
  {"reason": "SHIPPING", "max_reason_total_fact": "shipping_paid", "verdict": "COMMIT"},
  {"reason": "GOODWILL", "max_amount": "2000", "verdict": "COMMIT"},
  {"reason": "GOODWILL", "min_amount": "2001", "verdict": "REQUIRE_HUMAN_COSIGN"}
 ]}
```

Rule keys: `reason`, `verdict` (`COMMIT`, `REQUIRE_HUMAN_COSIGN`, `REJECTED_POLICY`),
optional `min_amount`, `max_amount` (amount strings; `min <= max`),
`max_reason_total_fact` (a fact name). 1 to 256 rules.

`eval_money` (`policy.rs`), the one function behind a parametric `REFUND` and `eval`:

1. `amount == 0`: `REJECTED_POLICY ZERO_AMOUNT`.
2. `amount > remaining` (remaining = original minus all committed refunds of the key):
   `REJECTED_POLICY TOTAL_CAP`.
3. A rule matches when the reason is equal, `min_amount <= amount <= max_amount` (each
   optional), and, with `max_reason_total_fact`, the fact exists on the key and
   (committed total of this reason on the key) + amount <= the fact value.
4. Several matches: the most restrictive verdict wins: `REJECTED_POLICY` >
   `REQUIRE_HUMAN_COSIGN` > `COMMIT`. A `REJECTED_POLICY` rule gives detail `RULE`.
5. No match: `REJECTED_POLICY REASON_CAP` if a rule of that reason failed only on its
   fact cap; else `REJECTED_POLICY NO_RULE`.
6. `REQUIRE_HUMAN_COSIGN` becomes a commit only with a valid signature (section 7).
   Without one: `REQUIRE_HUMAN_COSIGN COSIGN_REQUIRED`; no pinned key:
   `REQUIRE_HUMAN_COSIGN NO_COSIGN_KEY`; helper answer `INVALID`:
   `REQUIRE_HUMAN_COSIGN COSIGN_INVALID`. A signature on a request whose verdict is
   `COMMIT` is ignored (the record has cosign flag 0).

`eval <policy.json>`: stdin lines
`EVAL <reason> <amount> <remaining> <reason_total> [<fact>=<value>]...`; answers
`COMMIT`, `REQUIRE_HUMAN_COSIGN`, `REJECTED_POLICY <CODE>`, or
`MALFORMED_REQUEST EVAL ...`. Only parametric money policies (else exit 25).

### 6.1 Profile `canonical-refund` (PROVED CORE for the decision)

Policy: `{"airlock": "money", "version": 1, "name": "<name>", "profile": "canonical-refund"}`
(no other key). Scope, exactly:

- One key is one charge. The key name is the charge id. `OPEN_MONEY` takes no facts.
- The binary's three approved reasons: `duplicate_charge`, `service_not_delivered`,
  `returned_item`. Any other reason is rejected by the binary.
- The engine first refuses `amount == 0` natively (`REJECTED_POLICY ZERO_AMOUNT`); the
  binary itself would accept 0.
- Then one private process of the binary per request, as in `src/silicon_sink/sink.rs`:
  cleared environment plus `CML_HEAP_SIZE=256` and `CML_STACK_SIZE=256`; stdin is the
  exact text `(<key> <request_id> <original> <remaining> True True True <amount> <reason>)`
  with NO line end; stdout read up to max(accept frame, reject frame) + 1 bytes;
  stderr up to 4,096 bytes; time limit 10 s.
- The three flags are `enabled`, `opened` (request open), `candidate` (response is a
  candidate). The ENGINE sets all three to `True`; the caller cannot set them. They
  stand for: the key was opened under this profile (enabled); the request id is fresh,
  checked under the lock (opened); the request passed the grammar (candidate). So the
  binary's flag logic is not exercised through the engine.
- Commit only for exactly `(refund-result-v1 True <amount> <reason> <key> <request_id> 1)`,
  exit 0, empty stderr, all of stdin written. Exactly the rejection frame
  `(refund-result-v1 False 0 "" "" "" 0)` with a clean exit: `REJECTED_POLICY CAKEML_REJECTED`.
  Anything else: `BAD_FRAME`. A binary that cannot start or times out: `HELPER_FAILED`.
- After an accept, the engine checks natively that `amount <= remaining` and the reason
  is one of the three; else `BAD_FRAME`.
- The engine does not hash the binary. The launcher must pin SHA-256 `b8ed5ec2…7bb8`.

## 7. Cosign

Message (DESIGN.md; `cosign.cjs` enforces the same form):

```text
forge-airlock-cosign-v1\n<store_id>\n<request_id>\n<pre_state_hash>\n<action>\n
```

`action` = the `REFUND` line without the signature field:
`REFUND <tenant> <key> <request_id> <pre_state_hash> <reason> <amount>`. No field can
hold a line end. `cosign-message <dir> "<action>"` prints these bytes (it refuses an
action with a signature field). The human signs them with `cosign.cjs sign <key-file>`.

Verification: `<node> <helpers>/cosign.cjs verify <pinned public key> <signature>`,
message on stdin, cleared environment, stdout bound 9 bytes, stderr bound 4,096 bytes,
time limit 30 s. `VALID\n` + exit 0 + empty stderr: commit (cosign flag 1). `INVALID\n`
+ exit 1 + empty stderr: `REQUIRE_HUMAN_COSIGN COSIGN_INVALID`. Anything else (no node,
no helper, a timeout, other bytes, a signal, text on stderr): `HELPER_FAILED`. The
engine never reads a private key. Limit: an agent that runs as the same OS user as the
key owner can read a 0600 key file; "the agent cannot self-cosign" holds only when the
private key is outside the agent's reach.

## 8. Saga and inventory airlocks

Saga policy keys: `airlock`, `version`, `name`, `states` (1 to 64 unique ids),
`initial` (in `states`), `in_flight` (subset of `states`), `transitions` (unique
`[from, to]` pairs of states). Decision for `SAGA ... <to> [<p> <k>]` from state `cur`,
first match wins:

1. `to` not in `states`: `REJECTED_POLICY UNKNOWN_STATE`.
2. `cur` in flight and the pair differs from the held pair (or is absent):
   `REJECTED_POLICY PROCESSOR_IN_FLIGHT`.
3. `[cur, to]` not in `transitions`: `REJECTED_POLICY NO_TRANSITION`.
4. `to` in flight and no pair: `REJECTED_POLICY PAIR_REQUIRED`.
5. Neither `cur` nor `to` in flight and a pair: `REJECTED_POLICY PAIR_NOT_ALLOWED`.
6. Commit. The record holds the pair when `to` is in flight, else `- -`.

A line with a processor and no idempotency key is `MALFORMED_REQUEST PAIR`.

Inventory policy keys: `airlock`, `version`, `name`, `max_alpha_bps` (amount string,
at most 10000). Certificate JSON: exactly the keys `A`, `c`, `w`, `x`, `y`, `z`,
`alpha_bps`; every integer a canonical decimal string from 0 to MaxMoney (no negative
values); 1 to 64 rows, 1 to 1,024 columns; `|A| = |c| = |y|`, every row and `w`, `x`,
`z` of one length n. Shape faults are `MALFORMED_REQUEST CERT_*`. Decision, first match
wins:

1. `c` differs from the present remaining capacities of the key: `REJECTED_POLICY CAPACITY_MISMATCH`.
2. `alpha_bps > max_alpha_bps`: `REJECTED_POLICY ALPHA_ABOVE_POLICY`.
3. Native `Accepts` (u128, checked; overflow is `MALFORMED_REQUEST OVERFLOW`):
   `alpha_bps <= 10000`; `x` is 0/1 (`NOT_BINARY`); `A x <= c` (`OVERBOOKED`);
   `A^T y + z >= w` (`DUAL_INFEASIBLE`);
   `(10000 - alpha_bps) * (y.c + sum z) <= 10000 * w.x` (`GAP_TOO_LARGE`).
4. `<node> <helpers>/booking_check.cjs <checker>`, stdin = the canonical JSON of the
   checked values (keys in the order above, no spaces), time limit 30 s. `ACCEPT\n` +
   exit 0 + empty stderr: go on. `REJECT\n` + exit 1 + empty stderr:
   `REJECTED_POLICY CHECKER_REJECTED`. Else `HELPER_FAILED`.
5. New remaining = `c - A x` per row (checked). Record `BOOK` with `x` and the new
   remaining.

What `Accepts` means (`proposals/forge2-pillar3-dual-certificate/BookingDualCert.dfy`):
shapes agree, `alpha_bps <= 10000`, `x` is a feasible 0/1 allocation (`A x <= c`),
`(y, z)` is dual feasible (`y >= 0`, `z >= 0`, `A^T y + z >= w`), and the gap test
above holds. The proved lemma `QualityAll`: an accepted `x` is within the factor
`(10000 - alpha_bps)/10000` of EVERY feasible allocation (weak duality only). With
`alpha_bps = 0`, `x` is a global optimum. It shows nothing about the solver, and nothing
about the existence of a certificate.

## 9. Strict JSON

RFC 8259 grammar (`json.rs`). Refused: duplicate keys in one object (compared after
unescaping), a lone surrogate escape, a raw control byte in a string, bytes after the
value, nesting deeper than 64, invalid UTF-8 (row lines). Policy files: at most 1 MiB.

## 10. Answer codes and exit codes

Every answer is one line. Its first token is the typed code. A success line starts with
`COMMITTED`, `LEASE_OPENED`, `OK`, `STATE`, `REPLAY`, `LEASES`, `SWEEP`, `INITIALIZED`,
or (eval) `COMMIT` / `REQUIRE_HUMAN_COSIGN`. A refusal line is `<NAME>` or
`<NAME> <detail>`; the detail is free text up to the line end and can hold spaces. Only a
line whose first token is `COMMITTED` reports a new effect. No other code means a commit.

Answers with no detail (the bare name, then LF):

- `DUPLICATE_REQUEST_ID`: the request id is used up (a lease open for the id gives
  `DUPLICATE_REQUEST_ID LEASE_OPEN ...`).
- `UNKNOWN_KEY`: the key was never opened (write verbs, `GET`, `get`).
- `eval` only: `COMMIT` and `REQUIRE_HUMAN_COSIGN` (eval results, not refusals of a store).

Every other refusal has a detail. A parser must accept both forms for every code.

| Exit | Name | Class | Meaning |
| --- | --- | --- | --- |
| 0 | `COMMITTED` / `OK` / ... | success | |
| 2 | `USAGE` | usage | bad arguments; `serve` with no request |
| 10 | `REJECTED_POLICY` | terminal refusal | detail: `ZERO_AMOUNT`, `TOTAL_CAP`, `REASON_CAP`, `NO_RULE`, `RULE`, `CAKEML_REJECTED`, `UNKNOWN_STATE`, `PROCESSOR_IN_FLIGHT`, `NO_TRANSITION`, `PAIR_REQUIRED`, `PAIR_NOT_ALLOWED`, `CAPACITY_MISMATCH`, `ALPHA_ABOVE_POLICY`, `NOT_BINARY`, `OVERBOOKED`, `DUAL_INFEASIBLE`, `GAP_TOO_LARGE`, `CHECKER_REJECTED` |
| 11 | `REQUIRE_HUMAN_COSIGN` | terminal refusal | `COSIGN_REQUIRED`, `NO_COSIGN_KEY`, `COSIGN_INVALID` |
| 12 | `MALFORMED_REQUEST` | refusal | grammar, ids, amounts, `OVERSIZED`, `NO_LINE_END`, `NON_ASCII`, `UNKNOWN_VERB`, `UNKNOWN_POLICY`, `POLICY_KIND`, `KEY_KIND`, `CERT_*`, `OVERFLOW`, `RECORD_NOT_FOLDABLE` |
| 13 | `STALE_STATE_HASH` | refusal | detail = the present state hash |
| 14 | `DUPLICATE_REQUEST_ID` | refusal | id used up, or a lease open for it (`LEASE_OPEN`) |
| 15 | `EPOCH_REGRESSION` | fault | the WAL is older than its ratchet |
| 16 | `TENANT_ISOLATION_BREACH` | refusal | key of another tenant; read airlock |
| 17 | `CORRUPT_WAL` | fault | a record, the ratchet or a pinned policy file is not valid |
| 18 | `IO_ERROR` | fault | nothing committed; also `STORE_EXISTS` at `init` |
| 19 | `OUTCOME_UNKNOWN` | fault | a record may stay in the WAL; it was not answered as committed |
| 20 | `DISPATCH_FAILED` | fault | the answer line could not be written; a commit of that line stays committed |
| 21 | `UNKNOWN_KEY` | refusal | the key was never opened |
| 22 | `HELPER_FAILED` | refusal | binary, node, helper or flag missing; timeout; any other helper result |
| 23 | `BAD_FRAME` | refusal | the refund binary gave no exact frame |
| 24 | `DROPPED_OBLIGATION` | report | `leases --sweep` found at least one |
| 25 | `MALFORMED_POLICY` | refusal | `init` or `eval`: a policy file is not valid |

`serve` ends after the first answer with a fault code (15, 17, 18, 19, 20) and reads no
further line. Its exit code is the code of its last answer.

## 11. Trusted assumptions and not claimed

Trusted: the macOS kernel and the drive for `F_FULLFSYNC`; `flock`; whoever can write
the store folder, the engine binary, the refund binary, Node, the helpers and the
checker model; the launcher that pins the refund binary and the helpers (the engine
hashes none of them); Node's `node:crypto` for Ed25519; the Dafny compiler for
`model.cjs`.

Not claimed: no proof of the engine, the fold, the parser, the policy functions, the
SDKs, the helpers' wiring or the dispatcher. A SIGKILL is not a power loss. FNV-1a-128
is not cryptographic. A restore of the WAL AND the ratchet together is not detected. A
rewritten suffix with a recomputed chain is accepted. The parametric money rules, the
saga table, the read airlock and leases are NATIVE CHECK + FINITE TEST only. No "% of
bugs" figure. M1-B stays OPEN.

Known limits: a helper subprocess runs while the store lock is held (at most 10 s for
the binary, 30 s for Node). A `serve` process that waits for the lock waits without a
bound. A killed `init` can leave a `<dir>.init-*` folder. `state`, `get`, `replay` and
`leases` need write access (they run recovery).

## 12. Departures from DESIGN.md

1. Record layout: variable length (section 4), not 64 bytes (allowed by DESIGN.md).
2. Inventory policy key `max_alpha_bps` (the largest allowed gap), not `min_alpha_bps`.
3. Certificate integers must be non-negative (`Accepts` allows any integer).
4. The engine also checks `Accepts` natively before it runs the helper.
5. `eval` refuses a `canonical-refund` policy (exit 25).
6. `canonical-refund`: amount 0 refused natively; the engine sets the three flags; no facts.
7. An open of an existing key is `STALE_STATE_HASH` (no explicit "absent" hash token).
8. Extra saga codes: `UNKNOWN_STATE`, `PAIR_REQUIRED`, `PAIR_NOT_ALLOWED`.
9. A failed fact cap reports `REASON_CAP`, not `NO_RULE`.
10. A cosign `INVALID` answer is `REQUIRE_HUMAN_COSIGN COSIGN_INVALID` (terminal; it closes a lease).
11. `cosign-message <dir> <action>` (subcommand first), not `<store> cosign-message`.
12. Store ids are at most 24 bytes (the helper allows 64).
13. `EPOCH_REGRESSION` ends `serve` (in `sink.rs` it did not).
14. A sweep writes no record.
15. A rule may have the verdict `REJECTED_POLICY` (detail `RULE`).
16. Any malformed row, an empty or non-canonical tenant, and missing rows are all
    `TENANT_ISOLATION_BREACH` in the read airlock.

## 13. Mutation seams

The list is the `M` and `S` entries of the `MUTANTS` list in `scripts/exit_goal20_sdk.py`
(that script is the reference; this table is a copy). Each entry changes one place in
the source: the exact text (it must occur exactly once in the file; `⏎` is a line end)
is replaced, the changed copy is built (both builds), and the named case of
`tests/airlock/test_engine.py` (19 cases) must fail. M01 to M35 remove checks of the
verbs, the policies and the store. S01 to S18 remove a durable step, a check of its
result, the order of the lock, or the `DISPATCH_FAILED` code; the cases `trace`,
`dispatch` and `lock` see them (the test interposer `tests/airlock/interpose.c` traces
the system calls and injects failed syncs and writes). Results: see the exit script's
record, not this file.

| Id | File | Exact text | Replacement | Case that must fail | Check removed |
| --- | --- | --- | --- | --- | --- |
| M01_check_key_tenant | verbs.rs | `if k.tenant != tenant { return no(Code::Breach, "KEY_OF_ANOTHER_TENANT") }⏎    if s.l.ids.contains(req) { return no(Code::Duplicate, "DUPLICATE_REQUEST_ID") }⏎    if k.hash != pre` | `if s.l.ids.contains(req) { return no(Code::Duplicate, "DUPLICATE_REQUEST_ID") }⏎    if k.hash != pre` | tenant | the tenant check of a write to an existing key |
| M02_check_key_duplicate_id | verbs.rs | `if s.l.ids.contains(req) { return no(Code::Duplicate, "DUPLICATE_REQUEST_ID") }⏎    if k.hash != pre` | `if k.hash != pre` | cas | the fresh request id of a write to an existing key |
| M03_compare_and_swap | verbs.rs | `if k.hash != pre { return no(Code::Stale, hx(k.hash)) }⏎` | (empty) | race | the compare-and-swap on the state hash |
| M04_check_open_tenant | verbs.rs | `if k.tenant != tenant { return no(Code::Breach, "KEY_OF_ANOTHER_TENANT") }⏎` | (empty) | tenant | the tenant check of an open |
| M05_zero_amount | policy.rs | `if amount == 0 { return Verdict::Reject("ZERO_AMOUNT") }⏎` | (empty) | money | the zero-amount refusal of the money rules |
| M06_total_cap | policy.rs | `if amount > remaining { return Verdict::Reject("TOTAL_CAP") }⏎` | (empty) | money | the total cap |
| M07_reason_cap | policy.rs | `if !within { capped = true; continue }⏎` | (empty) | money | the fact-bound reason cap (SHIPPING <= shipping_paid) |
| M08_most_restrictive | policy.rs | `r.verdict.rank() > b.rank()` | `false` | money | the rule that the most restrictive verdict wins |
| M09_cosign_not_verified | verbs.rs | `if !helpers::cosign_verify(&ctx.node(), &pk, sig, &msg)? {` | `if false {` | cosign | the verification of a cosign signature |
| M10_cosign_answer_any_bytes | helpers.rs | `(Some(0), true, o) if o == yes => Ok(true),` | `(Some(0), _, _) => Ok(true),` | cosign | the exact VALID line and the empty stderr of the cosign helper |
| M11_refund_frame_unclean | helpers.rs | `let clean = r.code == Some(0) && r.err.is_empty() && r.sent;` | `let clean = true;` | canonical | the clean exit and empty stderr of the refund binary |
| M12_cakeml_reject_ignored | verbs.rs | `if !helpers::refund_binary(ctx.binary.as_deref(), &wire, &expect)? {` | `if helpers::refund_binary(ctx.binary.as_deref(), &wire, &expect).is_err() {` | canonical | the rejection by the CakeML binary |
| M13_processor_in_flight | verbs.rs | `} else if cur_in && pair != *held {` | `} else if false {` | saga | the refusal of a second processor while a key is in flight |
| M14_saga_transition | verbs.rs | `} else if !sp.transitions.iter().any(\|(a, b)\| a == cur && b == to) {` | `} else if false {` | saga | the transition table |
| M15_capacity_mismatch | verbs.rs | `let decision = if cert.c != *remaining {` | `let decision = if false {` | inventory | the comparison of the certificate capacities with the key |
| M16_alpha_above_policy | verbs.rs | `} else if cert.alpha > ip.max_alpha_bps {` | `} else if false {` | inventory | the alpha_bps bound of the policy |
| M17_checker_not_consulted | verbs.rs | `if !helpers::booking_check(&ctx.node(), &policy::cert_json(&cert))? {` | `if false {` | inventory | the call of the Dafny-compiled checker |
| M18_native_overbooked | policy.rs | `if used.iter().zip(&c.c).any(\|(u, cap)\| *u > *cap as u128) { return Err("OVERBOOKED") }⏎` | (empty) | inventory | the native A x <= c check |
| M19_lease_close_record | verbs.rs | `if s.l.leases.contains_key(req) {⏎        let (epoch, _)` | `if false {⏎        let (epoch, _)` | leases | the durable CLOSE record of a terminal refusal |
| M20_commit_closes_lease | ledger.rs | `self.leases.remove(req);` | (empty) | leases | the close of a lease by a committed effect |
| M21_sweep_deadline | main.rs | `} else if now > *deadline {` | `} else if now >= *deadline {` | leases | the strict deadline of a sweep |
| M22_read_tenant_value | verbs.rs | `(J::Obj(_), Some(J::Str(t))) if t == tenant => Ok(()),` | `(J::Obj(_), Some(J::Str(_))) => Ok(()),` | read | the comparison of a row tenant_id with the caller tenant |
| M23_read_tenant_canonical | verbs.rs | `(!canonical_id(tenant)).then(\|\| "TENANT_NOT_CANONICAL".to_string())` | `None` | read | the canonical-id rule for the caller tenant |
| M24_json_duplicate_key | json.rs | `if !seen.insert(key.clone()) {` | `if !seen.insert(key.clone()) && false {` | read | the refusal of a duplicate JSON key |
| M25_no_lock | store.rs | `wal.lock()?; // exclusive flock, taken before any file of the store is read; the kernel releases it at exit or kill⏎` | (empty) | lock | the store lock |
| M26_epoch_regression | store.rs | `if l.epoch < floor {` | `if false {` | recovery | the comparison of the WAL with its ratchet |
| M27_torn_tail_corrupt | store.rs | `if got < body.len() { torn = (HDR + got) as u64; break }` | `if got < body.len() { return no(Code::CorruptWal, "x") }` | recovery | the cut of a torn record at the end |
| M28_serve_continues_after_fault | main.rs | `if is_fault(code) { return code }⏎    }⏎}⏎⏎/// 'eval` | `}⏎}⏎⏎/// 'eval` | recovery | the end of serve at a fault |
| M29_oversized_line_not_skipped | main.rs | `input.skip_until(b'\n')?;⏎` | (empty) | lines | the skip of an oversized line to its line end |
| M30_line_bound_4096 | main.rs | `pub const MAX_LINE: usize = 65536;` | `pub const MAX_LINE: usize = 4096;` | lines | the line bound of 65,536 bytes |
| M31_canonical_zero_amount | verbs.rs | `if amount == 0 { return verdict(s, req, Code::RejectedPolicy, "ZERO_AMOUNT") }⏎` | (empty) | canonical | the native zero-amount refusal before the CakeML binary |
| M32_cosign_store_id_fixed | verbs.rs | `cosign_message(&s.l.store_id, req, t[4], &action)` | `cosign_message("store-a", req, t[4], &action)` | cosign | the store id inside the signed cosign message |
| M33_get_tenant | verbs.rs | `if k.tenant != tenant { return no(Code::Breach, "KEY_OF_ANOTHER_TENANT") }⏎    let rest = match` | `let rest = match` | tenant | the tenant check of GET |
| M34_policy_pin | store.rs | `if fnv128(&bytes) != pin.hash {` | `if false {` | recovery | the pin of a policy file |
| M35_json_trailing_bytes | json.rs | `if p.i != p.b.len() {` | `if false {` | read | the refusal of bytes after a JSON value |
| S01_no_wal_sync | store.rs | `if let Err(e) = written.and_then(\|()\| wal.sync_all()) {` | `if let Err(e) = written {` | trace | the F_FULLFSYNC of the WAL before the answer |
| S02_ignore_wal_sync_error | store.rs | `if let Err(e) = written.and_then(\|()\| wal.sync_all()) {` | `let _ = wal.sync_all();⏎        if let Err(e) = written {` | trace | the result of the WAL sync |
| S03_no_cut_after_failed_sync | store.rs | `let undone = wal.set_len(old_len).and_then(\|()\| wal.sync_all());` | `let undone: io::Result<()> = Ok(());` | trace | the cut of a record whose write or sync failed |
| S04_no_ratchet_sync | store.rs | `.concat()).and_then(\|()\| ratchet.sync_all())` | `.concat())` | trace | the F_FULLFSYNC of the ratchet entry |
| S05_ignore_ratchet_error | store.rs | `if push(&mut ratchet, epoch).is_err() { return no(Code::OutcomeUnknown, "OUTCOME_UNKNOWN the record is in the WAL; its ratchet entry failed") }` | `let _ = push(&mut ratchet, epoch);` | trace | the result of the ratchet write and sync |
| S06_no_ratchet_entry | store.rs | `if push(&mut ratchet, epoch).is_err() { return no(Code::OutcomeUnknown, "OUTCOME_UNKNOWN the record is in the WAL; its ratchet entry failed") }⏎` | (empty) | trace | the ratchet entry of a commit |
| S07_early_answer | store.rs | `cut("c");⏎` | `cut("c");⏎        let _ = io::stdout().write_all(b"COMMITTED ").and_then(\|()\| io::stdout().flush());⏎` | trace | the order: no answer byte before the WAL sync |
| S08_no_recovery_wal_sync | store.rs | `wal_ref.sync_all()?;⏎` | (empty) | trace | the WAL sync after a recovery cut |
| S09_ignore_recovery_sync_error | store.rs | `wal_ref.sync_all()?;⏎` | `let _ = wal_ref.sync_all();⏎` | trace | the result of the WAL sync in the recovery |
| S10_no_init_wal_sync | store.rs | `wal.write_all(&genesis)?;⏎        wal.sync_all()?;⏎` | `wal.write_all(&genesis)?;⏎` | trace | the sync of the genesis record |
| S11_no_init_folder_sync | store.rs | `File::open(&tmp)?.sync_all()?;⏎` | (empty) | trace | the sync of the new store folder |
| S12_no_init_parent_sync | store.rs | `File::open(&parent)?.sync_all()?;⏎` | (empty) | trace | the sync of the parent folder after the rename |
| S13_no_init_policy_sync | store.rs | `f.write_all(bytes)?;⏎            f.sync_all()?;⏎` | `f.write_all(bytes)?;⏎` | trace | the sync of a pinned policy file |
| S14_init_keeps_tmp_after_failure | store.rs | `let _ = std::fs::remove_dir_all(&tmp); // a refused init leaves no folder of its own⏎` | (empty) | trace | the removal of the temporary folder of a refused init |
| S15_ignore_init_wal_sync_error | store.rs | `wal.sync_all()?;⏎        File::open(&tmp)` | `let _ = wal.sync_all();⏎        File::open(&tmp)` | trace | the result of the sync of the genesis record |
| S16_lock_after_wal_read | store.rs | `wal.lock()?; // exclusive flock, taken before any file of the store is read; the kernel releases it at exit or kill⏎    let (l, total) = scan(&mut BufReader::new(&wal), &mut \|_, _\| {})?;⏎` | `let (l, total) = scan(&mut BufReader::new(&wal), &mut \|_, _\| {})?;⏎    wal.lock()?;⏎` | trace | the rule that the lock comes before any read of a store file |
| S17_shared_lock | store.rs | `wal.lock()?; // exclusive flock, taken before any file of the store is read; the kernel releases it at exit or kill⏎` | `wal.lock_shared()?; // exclusive flock, taken before any file of the store is read; the kernel releases it at exit or kill⏎` | lock | the exclusiveness of the store lock |
| S18_ignore_failed_answer | main.rs | `{ code } else { Code::DispatchFailed.num() }` | `{ code } else { code }` | dispatch | the DISPATCH_FAILED code for an answer that could not be written |

Not covered: the `sent` check of a helper process (a stand-in cannot make the stdin write
fail before it happens); a power loss (a SIGKILL keeps the page cache).
