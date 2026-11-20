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

A cosign signature is verified by the system OpenSSH (`/usr/bin/ssh-keygen -Y verify`,
section 7). No Node runs for a cosign. A store without an inventory policy needs no Node.

Every rule of this file holds only for a caller that reaches the store THROUGH the
production engine. Read section 11 ("Trust boundary") before you rely on any of them.

## 1. Build

```sh
rustc --edition 2021 -D unsafe_code -C opt-level=3 src/airlock/main.rs -o build/airlock/airlock-engine
rustc --edition 2021 -D unsafe_code -C opt-level=3 --cfg kill_points src/airlock/main.rs -o build/silicon/test/airlock-engine-kill
```

The second line is the TEST-ONLY build (live test seams). It goes to `build/silicon/test/`,
never beside the production engine in `build/airlock/` (review F2). `build/silicon/` is the
raw-output folder of `scripts/exit_silicon_sink.py`; that script writes `native_sink`,
`native_sink_kill`, `interpose.dylib`, `bin/` and `<case>/attempt-*` (case `build`, `suite`,
`mutations` or `evidence`) there, so `test/` collides with none of them. `bin/forge-airlock
build` removes an old `build/airlock/airlock-engine-kill`. Case `py_build_separation` of
`tests/airlock/test_sdk.py` runs every executable in `build/airlock/` with the cosign test
seams set: none may commit. In the EXIT script the attempt's kill build lies in
`<attempt>/build/test/`, apart from the engine folder that the SDKs, the demo and the fuzz
pass use.

Standard library only. No crate, no Cargo. `#![forbid(unsafe_code)]`. Modules:
`main.rs` (CLI, `serve`, answers, codes), `store.rs` (records, WAL, ratchet, `init`),
`ledger.rs` (the fold), `policy.rs` (policy files, money rules, native `Accepts`),
`verbs.rs` (request verbs, read airlock), `helpers.rs` (subprocesses), `cosign.rs`
(strict base64, the SSHSIG form, the call of `/usr/bin/ssh-keygen`), `json.rs` (strict
JSON parser), `pin.rs` (std-only SHA-256, weak Ed25519 key check).

The Node helper `src/airlock/node/booking_check.cjs` (inventory only) is compiled INTO the
engine (`include_str!`). The engine runs it as `<node> -e <source> -- <args>`; it reads no
helper file at run time. A change of the helper needs a rebuild of the engine. The Node
cosign helper `cosign.cjs` is deleted (Apex addendum). The human's cosign tools are
`src/airlock/py/cosign_tool.py` (Python stdlib; it runs `/usr/bin/ssh-keygen`).

Test seams, live ONLY in the `--cfg kill_points` build (in the production build the code
is present but `cfg!(kill_points)` is false, so the variables are ignored):
`AIRLOCK_KILL_AT` / `AIRLOCK_KILL_SPLIT` (kill points), `AIRLOCK_TEST_HELPERS=<dir>`
(run `<dir>/booking_check.cjs` instead of the embedded source),
`AIRLOCK_TEST_UNPINNED_BINARY=1` (skip the refund binary pin), `AIRLOCK_TEST_SSH_KEYGEN=<path>`
(run another program in place of `/usr/bin/ssh-keygen`; the ownership and link checks still
apply) and `AIRLOCK_TEST_UNTRUSTED_SSH_KEYGEN=1` (skip those checks, for stand-in programs
owned by the test user). The stand-in cases of `tests/airlock/test_engine.py` run through
the kill-points build; case `seams` checks that the production build ignores the seams.

## 2. Subcommands

| Command | Output (one line unless stated) | Exit |
| --- | --- | --- |
| `init <dir> [--store-id ID] [--policy FILE]... [--cosign-pubkey KEY] [--node P]` | `INITIALIZED <store_id> <genesis_hash>` | 0, or a code |
| `serve <dir> [--refund-binary P] [--node P] [--checker MODEL]` | one answer line per request line | code of the last answer; 2 if no line |
| `state <dir>` | `STATE <epoch> <tail_hash> <store_id> keys=<n> effects=<n> leases=<n>` | 0 |
| `get <dir> <tenant> <key>` | as the `GET` verb | 0, 21 |
| `replay <dir>` | `REPLAY <n>`, then n lines `EFFECT <epoch> <payload>` | 0 |
| `leases <dir>` | `LEASES <open>`, then one line `LEASE <request_id> <deadline_ms> <tenant> <key>` per OPEN lease (WAL order); a lease in the state PENDING_COSIGN (section 5.1) has ` PENDING_COSIGN <epoch> <detail>` at the end | 0 |
| `leases <dir> --all` | `LEASES <open> all=<n>`, then one line per lease ever opened: `LEASE <request_id> <deadline_ms> <tenant> <key> OPEN`, `LEASE <request_id> <deadline_ms> <tenant> <key> PENDING_COSIGN <epoch> <detail>` (open) or `LEASE <request_id> <deadline_ms> <tenant> <key> CLOSED <epoch> <COMMITTED -\|REJECTED_POLICY <detail>>` | 0 |
| `leases <dir> --sweep [--now MS]` | `SWEEP <open> <dropped> now=<MS>`, then in WAL order one line `DROPPED_OBLIGATION <request_id> <deadline_ms> <tenant> <key>` per open lease (also a PENDING_COSIGN one) with `now > deadline_ms`, and one line `PENDING_COSIGN <request_id> <deadline_ms> <tenant> <key> <detail>` per PENDING_COSIGN lease whose deadline has not passed | 0 none dropped; 24 at least one |
| `eval <policy.json>` | one answer per stdin line (section 6) | 0; 25 bad policy |
| `cosign-message <dir> <action>` | the exact message bytes (6 lines, LF-terminated; section 7) | 0, or a code |
| `cosign-info` | `COSIGN_INFO path=/usr/bin/ssh-keygen sha256=<64 hex> uid=<n> mode=<octal> checks=<OK or the failed check> walked=<the checked parts, : separated, from /> version=<text of ssh -V>` | 0, 22 |
| `sha256 <file>` | `SHA256 <64 hex>` (the engine's own SHA-256; for its test vectors) | 0, 18 |
| `base64-decode <token>` | `BASE64 <hex of the bytes>`, or `MALFORMED_REQUEST BAD_BASE64` (the strict decoder of section 7; for its test vectors) | 0, 12 |

- `--store-id` absent: the engine makes `st-` and 21 hex digits from the clock and the
  process id. Not random in a cryptographic sense.
- `--now` is only valid with `--sweep`; `--sweep` and `--all` together are a usage error.
  Without `--now`, the sweep uses the system clock in milliseconds since the Unix epoch.
- `init --cosign-pubkey KEY`: KEY is the middle field of an OpenSSH `.pub` line of an
  Ed25519 key (what `bin/forge-airlock cosign-keygen` prints): exactly 68 characters of
  canonical base64 that decode to the `ssh-ed25519` wire encoding (string `ssh-ed25519`,
  string of 32 bytes). Anything else: `MALFORMED_REQUEST BAD_PUBKEY` (the old 64-hex form
  too). A small-order or non-canonical key: `MALFORMED_REQUEST WEAK_PUBKEY` (section 7).
- `init --node P`: the engine computes the SHA-256 of the file P and binds it in the
  genesis record. `--node` is REQUIRED only when a policy is an inventory policy
  (`MALFORMED_REQUEST NODE_REQUIRED`); else it is optional. A cosign key needs no Node.
  `init` fails if `/dev/urandom` cannot be read (`IO_ERROR NO_RANDOM`).
- A sweep is read-only: it writes no record. A dropped lease stays open. The next sweep
  reports it again.
- Every command except `init` and `eval` takes the store lock and runs recovery first
  (section 4). They need write access to the store.
- `serve` takes the lock per request, not for its lifetime. Many `serve` processes can
  work on one store at once.
- `serve --node P`: an absolute path to the Node binary (only a `BOOK` uses it). Before the
  first booking helper call of the process, the engine computes the SHA-256 of P and compares it with the store's pin
  (once per process; the result is kept for the process). A difference:
  `HELPER_FAILED PIN_MISMATCH ...`; an unreadable file: `HELPER_FAILED PIN_UNREADABLE ...`;
  a store with no pin: `HELPER_FAILED NO_NODE_PIN ...`. `--refund-binary P`: before its
  first use in the process, P must have SHA-256
  `b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8` (the same codes).
  Limit: a file swapped AFTER that check (between the hash and a later exec) is not
  detected. `--checker` is the compiled model (normally `build/airlock/checker/model.cjs`);
  `booking_check.cjs` pins its SHA-256 itself. There is no `--helpers` flag: it is a usage
  error (exit 2). A missing flag makes the verb that needs it answer `HELPER_FAILED`; it
  never commits.

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
- Signature (`REFUND`): one token of exactly 256 characters, the base64 body of one SSHSIG
  armor (`-----BEGIN SSH SIGNATURE-----`) with its line breaks removed; canonical base64
  (section 7). Public key (`init`): 68 characters of base64 (section 2).

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
hash of the last record that changed the key. The genesis record holds 16 bytes from
`/dev/urandom` (the nonce), so two stores with the same store id, policies and key have
different genesis records, and so different state hashes, unless FNV-1a-128 collides.
FNV-1a-128 is NOT cryptographic: collisions can be computed. The state hash is a
concurrency control (compare-and-swap) and a chain against torn or spliced files, not a
boundary against an attacker.

Payloads:

| Payload | Effect | Written by |
| --- | --- | --- |
| `GENESIS 3 <store_id> <nonce 32 hex> <SHA-256 of Node, 64 hex, or -> <cosign key token (68 base64 characters) or -> <n> [<policy> <money or saga or inventory> <fnv128 of the file>]×n` | store | `init` |
| `OPEN_MONEY <tenant> <key> <request_id> <policy> <original> [<fact>=<value>]...` (facts sorted by name) | yes | `OPEN_MONEY` |
| `REFUND <tenant> <key> <request_id> <reason> <amount> <0 or 1>` (1 = cosigned) | yes | `REFUND` |
| `OPEN_SAGA <tenant> <key> <request_id> <policy> <initial>` | yes | `OPEN_SAGA` |
| `SAGA <tenant> <key> <request_id> <to> <processor or -> <idempotency_key or ->` | yes | `SAGA` |
| `OPEN_INVENTORY <tenant> <key> <request_id> <policy> <c1,c2,...>` | yes | `OPEN_INVENTORY` |
| `BOOK <tenant> <key> <request_id> <x as 0/1 digits> <new remaining c1,c2,...>` | yes | `BOOK` |
| `LEASE <request_id> <deadline_ms> <tenant> <key>` | no | `OPEN_LEASE` |
| `CLOSE <request_id> <tenant> REJECTED_POLICY <detail>` | no | a `REJECTED_POLICY` on the lease's tenant and key while the lease is open (also PENDING_COSIGN) |
| `COSIGN_PENDING <request_id> <tenant> <COSIGN_REQUIRED or NO_COSIGN_KEY or COSIGN_INVALID>` | no | the first `REQUIRE_HUMAN_COSIGN` on the lease's tenant and key while the lease is open and not yet pending (review D6) |
| `CLOSE <request_id> <REJECTED_POLICY or REQUIRE_HUMAN_COSIGN> <detail>` (no tenant) | no | never written now; the form of the engine before review D3 and D6, still read (section 12, items 21 and 22) |

The fold (`ledger.rs`) checks each record again: fresh request id in the record's tenant, a key of
that tenant and of the right kind,
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
- A store of the Node cosign engine (genesis version 2): `CORRUPT_WAL STORE_VERSION_2 ...`
  for every command. It is never read as version 3. There is no migration: its key is a raw
  hex key and its signatures are raw Ed25519 signatures of the version-2 message.
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
`UNKNOWN_KEY` -> `DUPLICATE_REQUEST_ID` -> `STALE_STATE_HASH` -> policy. An open verb
names no `pre_state_hash`; the key must be absent in the caller's tenant: a key of the
same tenant is `STALE_STATE_HASH <present hash>`.

Namespaces (review D3). Keys, request ids and leases are PER TENANT. The fold indexes each
of them by (tenant, name). `t1 order-1` and `t2 order-1` are two keys; request id `r1` of
`t1` and request id `r1` of `t2` are two ids; a lease id can have one lease in each tenant.
A key of another tenant is `UNKNOWN_KEY`, exactly like a key that nobody opened. So one
tenant cannot squat a key name or a request id of another tenant, and no answer about a
key, a request id or a lease tells one tenant what another tenant has. Only an effect
record uses an id up (in its tenant). A refusal (also a terminal one) leaves the id fresh.

What the namespaces do NOT do:

- They do not authenticate the tenant. The tenant is a field of the request line. In the
  shipped flow the engine is a child process of the caller, under the caller's OS user
  (`bin/forge-airlock serve`, both SDKs). Nothing in the engine checks that the caller may
  use the tenant that it names. The namespaces stop accidents, squatting and probes
  between callers that something OUTSIDE the engine holds to their tenant label (for
  example a gateway that writes the tenant field itself). A caller that can name any
  tenant can act as that tenant. A caller that can read the WAL file reads every tenant.
  Real per-tenant authentication needs an isolation mode (a service user, a socket,
  per-tenant credentials): a separate design, not built here. Nothing here is an
  isolation claim.
- Store-wide values stay store-wide: the epoch in `COMMITTED` and `LEASE_OPENED`, the
  state hash (it chains every record of the store), the `STATE` verb (`epoch`, tail hash,
  `keys=`, `effects=`, `leases=` of the whole store), and the time a request waits for the
  store lock. A caller sees from them that other records were written (how many), not which
  keys, ids or leases they name. The subcommands `state`, `replay`, `leases` and
  `cosign-message` are operator views of the whole store.
- Saga idempotency keys are not unique across keys or tenants (they never were): two keys
  can hold the same processor and idempotency key. A real processor that de-duplicates on
  that key across one merchant account can then merge the two. The engine does not see it.

| Verb | Grammar | Success answer |
| --- | --- | --- |
| `OPEN_MONEY` | `OPEN_MONEY <tenant> <key> <request_id> <policy> <original> [<fact>=<value>]...` (0 to 16 facts; none for `canonical-refund`) | `COMMITTED ...` |
| `REFUND` | `REFUND <tenant> <key> <request_id> <pre_state_hash> <reason> <amount> [<signature>]` | `COMMITTED ...` |
| `OPEN_SAGA` | `OPEN_SAGA <tenant> <key> <request_id> <policy>` (state = the policy's `initial`) | `COMMITTED ...` |
| `SAGA` | `SAGA <tenant> <key> <request_id> <pre_state_hash> <to_state> [<processor> <idempotency_key>]` | `COMMITTED ...` |
| `OPEN_INVENTORY` | `OPEN_INVENTORY <tenant> <key> <request_id> <policy> <c1,c2,...>` (1 to 64 amounts) | `COMMITTED ...` |
| `BOOK` | `BOOK <tenant> <key> <request_id> <pre_state_hash> <certificate JSON>` (the rest of the line) | `COMMITTED ...` |
| `OPEN_LEASE` | `OPEN_LEASE <request_id> <deadline_ms> <tenant> <key>` (the key need not exist yet) | `LEASE_OPENED <request_id> <epoch> <deadline_ms> <tenant> <key>` |
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
< UNKNOWN_KEY
> OPEN_SAGA t1 pay-1 r4 payout
> SAGA t1 pay-1 r5 <hash> IN_FLIGHT stripe idem-1
> SAGA t1 pay-1 r6 <hash> IN_FLIGHT paypal idem-2
< REJECTED_POLICY PROCESSOR_IN_FLIGHT
> OPEN_INVENTORY t1 seats-1 r7 seats 3
> BOOK t1 seats-1 r8 <hash> {"A":[["1","1"]],"c":["3"],"w":["5","2"],"x":["1","1"],"y":["0"],"z":["5","2"],"alpha_bps":"0"}
< COMMITTED r8 9 85b8…ab3b BOOK t1 seats-1 r8 11 1
> OPEN_LEASE wh-77 1763560000000 t1 order-1
< LEASE_OPENED wh-77 10 1763560000000 t1 order-1
> READ t1 2
> {"tenant_id":"t1","total":12.5}
> {"tenant_id":"t2","total":3}
< TENANT_ISOLATION_BREACH ROW 1 TENANT_MISMATCH
```

### 5.1 Leases

- A lease is bound to a request id, a tenant and a key. There is only this bound form;
  `OPEN_LEASE <request_id> <deadline_ms>` (the old two-field form) is
  `MALFORMED_REQUEST FIELDS`.
- `OPEN_LEASE` refuses an id that is used up in the lease's tenant (`DUPLICATE_REQUEST_ID`),
  and an id that EVER had a lease in that tenant, open or closed
  (`DUPLICATE_REQUEST_ID LEASE_USED ...`: one lease per id and tenant, so no open/close
  loop writes records without bound). The key need not exist. Ids, keys and leases of
  other tenants change nothing (section 5, namespaces).
- A lease closes ONLY by a terminal verdict of a request with its request id ON its
  tenant and key: an effect record (`COMMITTED`), or a `REJECTED_POLICY` answer. For the
  refusal, the engine writes a durable `CLOSE` record (synced, ratcheted) before the
  answer, and the answer gets `LEASE_CLOSED <epoch>` after its detail:
  `REJECTED_POLICY TOTAL_CAP LEASE_CLOSED 7`. A verdict on another tenant or key leaves
  the lease open, writes no record, and the answer has no `LEASE_CLOSED`. A commit of the
  id on another key uses the id up and leaves the lease open: the sweep then reports it
  until the end.
- `REQUIRE_HUMAN_COSIGN` does NOT close a lease (review D6). The request id stays fresh and
  the signed retry is still expected, so the work is not done. The first such answer on
  the lease's tenant and key writes one durable `COSIGN_PENDING` record (synced,
  ratcheted) before the answer; the lease is then in the state PENDING_COSIGN, and the
  answer gets `LEASE_PENDING <epoch>` after its detail:
  `REQUIRE_HUMAN_COSIGN COSIGN_REQUIRED LEASE_PENDING 7`. A later `REQUIRE_HUMAN_COSIGN`
  (also `COSIGN_INVALID`) writes no record and names the same epoch. A PENDING_COSIGN lease
  is open: `leases` lists it with its state, the sweep lists it as `PENDING_COSIGN` before
  its deadline and as `DROPPED_OBLIGATION` after it, and the signed commit or a
  `REJECTED_POLICY` closes it.
- A `CLOSE <request_id> REQUIRE_HUMAN_COSIGN <detail>` record without a tenant (written by
  the engine before review D6, which closed the lease there) is read as `COSIGN_PENDING`:
  the action of such a lease was still pending. So the sweep now reports that old work
  after its deadline. If the old engine later rejected that request, it wrote no record (the
  lease was closed for it), and the sweep reports the lease as dropped: a false alarm, not
  a hidden drop.
- A request on a key that was never opened answers `UNKNOWN_KEY` before any policy
  verdict, so it never closes a lease.
- `leases --all` shows each closed lease with its closing record, so an obligation that a
  rejection closed stays visible.
- Other refusals (`STALE_STATE_HASH`, `DUPLICATE_REQUEST_ID`, `MALFORMED_REQUEST`,
  `UNKNOWN_KEY`, `HELPER_FAILED`, `BAD_FRAME`, faults) do not
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
100,000) is `MALFORMED_REQUEST READ_HEADER` and consumes no row. Limits: the engine sees
only the rows passed to it. It checks only the TOP-LEVEL `tenant_id` member of each row:
a row of the right tenant that holds a nested object of another tenant passes. The SDK
must hand on the bytes that the engine checked, not its own objects.

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

Trusted inputs: `original`, the facts and the tenant of a key are chosen by whoever opens
the key (`OPEN_MONEY`). The engine does not authenticate the tenant field and does not
check `original` or a fact against any outside record. The total cap and the fact-bound
caps are only as good as the opener's values: an opener that writes `original=10^9` or
`shipping_paid=10^9` gets caps of that size.

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
   `REQUIRE_HUMAN_COSIGN NO_COSIGN_KEY`; a signature by another key or one that
   ssh-keygen answers "incorrect signature": `REQUIRE_HUMAN_COSIGN COSIGN_INVALID`. A
   signature token that is not the one accepted form is `MALFORMED_REQUEST BAD_SIGNATURE`
   (grammar, also on a request whose verdict would be `COMMIT`). A well-formed signature on
   a request whose verdict is `COMMIT` is ignored (the record has cosign flag 0).

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
- The engine pins the binary: before its first use in a process, the file given with
  `--refund-binary` must have SHA-256 `b8ed5ec2…7bb8` (`HELPER_FAILED PIN_MISMATCH`
  otherwise). Limit: a swap after that check is not detected.

## 7. Cosign

Apex addendum (owner decision 2026-11-19): the Node helper `cosign.cjs` is gone. The engine
verifies a cosign with the system OpenSSH, `/usr/bin/ssh-keygen -Y verify`. No Node and no
V8 run for a cosign. Measured here: OpenSSH_10.3p1 with LibreSSL 3.3.6 (macOS).

Message (at most 4,096 bytes; exactly six LF-terminated lines; `cosign_tool.py sign`
refuses any other form):

```text
forge-airlock-cosign-v3\n<store_id>\n<genesis_hash>\n<request_id>\n<pre_state_hash>\n<action>\n
```

- `store_id` `[A-Za-z0-9_-]{1,24}`; `genesis_hash` 32 lowercase hex: the FNV-1a-128 of this
  store's genesis record, which holds the random nonce, so a signature for one store never
  verifies on another store with the same id, policies and key; `request_id`
  `[A-Za-z0-9_-]{1,24}`; `pre_state_hash` 32 lowercase hex; `action` printable ASCII, at
  least 1 byte.
- `action` = the `REFUND` line without the signature field:
  `REFUND <tenant> <key> <request_id> <pre_state_hash> <reason> <amount>`. No field can
  hold a line end, so no field boundary can move.
- Version 3 (was 2): the signature form changed. A version-2 signature never verifies.
- `cosign-message <dir> "<action>"` prints these bytes (it refuses an action with a
  signature field). The human signs them with `bin/forge-airlock cosign-sign <key-file>`
  (`src/airlock/py/cosign_tool.py`); the tool shows the six fields on stderr first.

Human tools (`src/airlock/py/cosign_tool.py`, Python stdlib, no Node):

- `cosign-keygen <new-key-file>`: `ssh-keygen -t ed25519 -N '' -q -C ''` into a private
  0700 folder, checks that the key is a regular 0600 file of the caller, moves it into place
  with `link(2)` (never overwrites; a symbolic link at the path is not followed), syncs it
  and its folder, prints the key token for `init --cosign-pubkey` (68 characters).
- `cosign-sign <key-file>`: the D-1 key rules (`open` with `O_NOFOLLOW | O_NONBLOCK`;
  `fstat` of the opened descriptor: regular file, owner = effective uid, no group or other
  bit, size 1 to 4,096; read from that descriptor: an UNENCRYPTED `openssh-key-v1` key
  with one `ssh-ed25519` key), the message form, then
  `ssh-keygen -Y sign -n forge-airlock-cosign -P "" -f <key-file>` with stdin a pipe, an
  empty environment and a new session (no terminal: a key with a passphrase fails at once;
  it never prompts). ssh-keygen opens the file again by path; the tool binds the two opens:
  the key inside the signature must be the key read from the checked descriptor. It prints
  one token (below).

Signature token (the last field of `REFUND`): the base64 body of the SSHSIG armor that
ssh-keygen writes, with the armor lines and the line breaks removed. Exactly 256
characters. The engine checks it natively, before any store file is opened, in this order;
the first failure is `MALFORMED_REQUEST BAD_SIGNATURE <part>`:

| Part | Rule |
| --- | --- |
| `LENGTH` | exactly 256 characters |
| `BASE64` | strict base64 (RFC 4648 section 4): standard alphabet, padding only at the end and exactly as long as needed, the unused low bits of the last symbol zero (one spelling per byte string). The decoder is in `cosign.rs`; `base64-decode` exposes it for test vectors |
| `MAGIC` / `VERSION` | `SSHSIG`, then version 1 (uint32) |
| `KEY_TYPE` | the public key: string `ssh-ed25519`, string of 32 bytes, nothing else |
| `NAMESPACE` | `forge-airlock-cosign` |
| `RESERVED` | empty |
| `HASH_ALGORITHM` | `sha512` (what OpenSSH 10.3 writes by default; `sha256` is refused) |
| `SIGNATURE` / `SIGNATURE_TYPE` / `SIGNATURE_LENGTH` / `TRAILING` | one string: string `ssh-ed25519`, string of 64 bytes; no byte after it or after the blob |
| `WEAK_R` | R (the first 32 signature bytes) is not a small-order or non-canonical encoding (the weak-key rule below) |
| `S_NOT_CANONICAL` | S (the last 32 bytes, little-endian) < L = 2^252 + 27742317777372353535851937790883648493. ssh-keygen 10.3 accepts S + L (tested); the engine does not |

Then, under the store lock, for a `REQUIRE_HUMAN_COSIGN` verdict: no pinned key:
`NO_COSIGN_KEY`; the key inside the signature is not the pinned key: `COSIGN_INVALID` (no
ssh-keygen runs); else the engine runs ssh-keygen:

- program: `/usr/bin/ssh-keygen`, fixed. Before its first use in a process, the engine
  checks with std only (`symlink_metadata`): no part of the path is a symbolic link, every
  folder on it (from the root folder `/`, which is checked too) and the file are owned by uid 0 with no group or other write bit, the file
  is a regular file (`HELPER_FAILED SSH_KEYGEN_UNTRUSTED <check>` otherwise). Its SHA-256
  is NOT pinned (an OS update would refuse every store); `cosign-info` prints it and the
  `ssh -V` text so that an operator can record them. Limit: a file swapped after the check
  is not detected.
- files: the engine creates `<store>/cosign.tmp` with mode 0700 (exclusive `mkdir`; a
  leftover of a crash, also a symbolic link, is removed first, under the store lock),
  checks it is a folder without group or other bits, writes `allowed_signers`
  (`forge-airlock-cosigner namespaces="forge-airlock-cosign" ssh-ed25519 <pinned key token>`)
  and `signature` (the armor rebuilt from the token, 70 characters per line) with
  exclusive create and mode 0600, and removes the folder after the run (a failed removal
  is cleaned at the next verification). File names are fixed; no request byte reaches a
  file name or the argv.
- run: `ssh-keygen -Y verify -f allowed_signers -I forge-airlock-cosigner -n forge-airlock-cosign -s signature`
  in that folder (relative names), no shell, cleared environment, the message on stdin,
  stdout bound to the longer expected answer + 1 byte, stderr bound 4,096 bytes, time
  limit 30 s (SIGKILL).

How the engine tells an invalid signature from a tool fault. Experiment on this machine
(OpenSSH_10.3p1, LibreSSL 3.3.6), `ssh-keygen -Y verify` with an empty environment:

| Input | Exit | stdout | stderr |
| --- | --- | --- | --- |
| valid signature | 0 | `Good "forge-airlock-cosign" signature for forge-airlock-cosigner with ED25519 key SHA256:<fp>` | empty |
| changed message (any of the six lines), flipped bit in S | 255 | `Could not verify signature.` | `Signature verification failed: incorrect signature` + CR LF |
| signature of another key (not in allowed_signers) | 255 | `Could not verify signature.` | empty |
| wrong namespace (in the blob or in `-n`) | 255 | `Could not verify signature.` | `Couldn't verify signature: namespace does not match` |
| armor body damaged (blob not SSHSIG) | 255 | `Could not verify signature.` | `Couldn't verify signature: invalid format` |
| armor body not base64 | 255 | `Could not verify signature.` | `sshsig_dearmor: decode base64: invalid format` + `sig_verify: sshsig_armor: invalid format` |
| no armor header | 255 | `Could not verify signature.` | `Couldn't parse signature: missing header` + ... |
| malformed allowed_signers line (bad key) | 255 | `Could not verify signature.` | `<file>:1: invalid key` |
| allowed_signers line that is not a key line, other identity, empty file | 255 | `Could not verify signature.` | empty |
| allowed_signers without the namespace | 255 | `Could not verify signature.` | `<file>:1: key is not permitted for use in signature namespace ...` |
| allowed_signers missing / unreadable | 255 | `Could not verify signature.` | `Unable to open allowed keys file ...: No such file or directory` / `Permission denied` |
| signature file missing | 255 | `Could not verify signature.` | `Couldn't read signature file: No such file or directory` |
| missing argument | 1 | empty | usage text |
| S + L in place of S | 0 | the Good line | empty |

The exit code does not separate an invalid signature from a fault (255 for both). So the
engine takes only two exact results. The native checks above come first: against a caller
that holds only the request pipe, a signature that reaches ssh-keygen is well formed and
names the pinned key. That sentence does NOT hold against a process that can write the
store folder: it can replace the two files in `cosign.tmp` between the engine's write and
ssh-keygen's read (one review did it: ssh-keygen then verified the attacker's own files in
about 97% of 40,000 tries; 0 commits). In that case the ONE check that holds is the exact
compare of the Good line with the fingerprint of the PINNED key:

| ssh-keygen result | Answer |
| --- | --- |
| exit 0, stdout exactly the Good line with the SHA-256 fingerprint of the PINNED key + LF, stderr empty, all of stdin written | commit (cosign flag 1) |
| exit 255, stdout exactly `Could not verify signature.` + LF, stderr exactly `Signature verification failed: incorrect signature` + CR LF, all of stdin written | `REQUIRE_HUMAN_COSIGN COSIGN_INVALID` (a bound lease becomes PENDING_COSIGN, section 5.1) |
| anything else: another exit code, other bytes, text on stderr with exit 0, a signal, a timeout, no program, a failed check of the program, a failed write of the folder or files | `HELPER_FAILED` (not terminal; never a commit) |

When in doubt the answer is the more restrictive one: an unknown text of a later OpenSSH is
`HELPER_FAILED` (fail closed), never a commit. The engine never reads a private key.

Weak keys: `init` (and the fold) refuse a public key, and the grammar refuses a signature
whose R, that is a small-order or non-canonical Ed25519 encoding: the 5 values of
libsodium's blocklist (`has_small_order` in
`src/libsodium/crypto_core/ed25519/ref10/ed25519_ref10.c`) compared with bit 255 cleared,
which covers the 8 torsion points and their non-canonical encodings (14 byte strings; see
Chalkias, Garillot, Nikolaenko, "Taming the many EdDSAs", 2020), and every y >= p =
2^255 - 19. The rule is applied to the 32 raw key bytes inside the key token. The suites
check that each listed point has an order that divides 8 (a computation in the test, not a
proof).

Who can cosign. "The agent cannot self-cosign" needs BOTH:

1. the private key is outside the agent's reach (another OS user, a hardware key, or
   another machine; an agent that runs as the key owner's OS user can read a 0600 file);
2. the agent cannot write the store folder and cannot run another engine on it. A process
   that can write the store folder can append records itself (the CRC and the FNV chain
   authenticate nothing). A process that can start its own engine build can ignore every
   check. Example of a setup that meets this: `serve` runs under another OS user that owns
   the store folder, and the agent holds only the pipe to that process.

The engine cannot check either condition. Section 11 states the same boundary for every
other rule.

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
4. `<node> -e <embedded booking_check.cjs> -- <checker>` (the Node binary pinned,
   section 2; the helper pins the model's SHA-256), stdin = the canonical JSON of the
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

- `DUPLICATE_REQUEST_ID`: the request id is used up (an `OPEN_LEASE` for an id that had
  a lease gives `DUPLICATE_REQUEST_ID LEASE_USED ...`).
- `UNKNOWN_KEY`: the key was never opened (write verbs, `GET`, `get`).
- `eval` only: `COMMIT` and `REQUIRE_HUMAN_COSIGN` (eval results, not refusals of a store).

Every other refusal has a detail. A parser must accept both forms for every code.

| Exit | Name | Class | Meaning |
| --- | --- | --- | --- |
| 0 | `COMMITTED` / `OK` / ... | success | |
| 2 | `USAGE` | usage | bad arguments; `serve` with no request |
| 10 | `REJECTED_POLICY` | terminal refusal | detail: `ZERO_AMOUNT`, `TOTAL_CAP`, `REASON_CAP`, `NO_RULE`, `RULE`, `CAKEML_REJECTED`, `UNKNOWN_STATE`, `PROCESSOR_IN_FLIGHT`, `NO_TRANSITION`, `PAIR_REQUIRED`, `PAIR_NOT_ALLOWED`, `CAPACITY_MISMATCH`, `ALPHA_ABOVE_POLICY`, `NOT_BINARY`, `OVERBOOKED`, `DUAL_INFEASIBLE`, `GAP_TOO_LARGE`, `CHECKER_REJECTED` |
| 11 | `REQUIRE_HUMAN_COSIGN` | verdict refusal; the work is pending, not done (a bound lease becomes PENDING_COSIGN, section 5.1) | `COSIGN_REQUIRED`, `NO_COSIGN_KEY`, `COSIGN_INVALID` |
| 12 | `MALFORMED_REQUEST` | refusal | grammar, ids, amounts, `OVERSIZED`, `NO_LINE_END`, `NON_ASCII`, `UNKNOWN_VERB`, `UNKNOWN_POLICY`, `POLICY_KIND`, `KEY_KIND`, `CERT_*`, `OVERFLOW`, `RECORD_NOT_FOLDABLE`; `BAD_SIGNATURE <part>` (section 7); at `init`: `BAD_PUBKEY`, `WEAK_PUBKEY`, `NODE_REQUIRED`, `NODE_UNREADABLE`; `base64-decode`: `BAD_BASE64` |
| 13 | `STALE_STATE_HASH` | refusal | detail = the present state hash |
| 14 | `DUPLICATE_REQUEST_ID` | refusal | id used up; or `OPEN_LEASE` for an id that had a lease (`LEASE_USED`) |
| 15 | `EPOCH_REGRESSION` | fault | the WAL is older than its ratchet |
| 16 | `TENANT_ISOLATION_BREACH` | refusal | read airlock only (a row set that holds a row of another tenant). Since the per-tenant namespaces (review D3) no write, `GET` or lease answer gives it: a key of another tenant is `UNKNOWN_KEY`. The name stays for the wire; the tenant is not authenticated (section 5) |
| 17 | `CORRUPT_WAL` | fault | a record, the ratchet or a pinned policy file is not valid; `STORE_VERSION_2` (a store of the Node cosign engine) |
| 18 | `IO_ERROR` | fault | nothing committed; also `STORE_EXISTS` and `NO_RANDOM` at `init` |
| 19 | `OUTCOME_UNKNOWN` | fault | a record may stay in the WAL; it was not answered as committed |
| 20 | `DISPATCH_FAILED` | fault | the answer line could not be written; a commit of that line stays committed |
| 21 | `UNKNOWN_KEY` | refusal | the key was never opened |
| 22 | `HELPER_FAILED` | refusal | binary, node, model or flag missing; `PIN_MISMATCH`, `PIN_UNREADABLE`, `NO_NODE_PIN`; `SSH_KEYGEN_UNTRUSTED <check>`, `TMP_NOT_PRIVATE`, `SPAWN_FAILED`; timeout; any other helper result (`HELPER_RESULT ...`), also every ssh-keygen result that is not one of the two exact answers of section 7 |
| 23 | `BAD_FRAME` | refusal | the refund binary gave no exact frame |
| 24 | `DROPPED_OBLIGATION` | report | `leases --sweep` found at least one |
| 25 | `MALFORMED_POLICY` | refusal | `init` or `eval`: a policy file is not valid |

`serve` ends after the first answer with a fault code (15, 17, 18, 19, 20) and reads no
further line. Its exit code is the code of its last answer.

## 11. Trust boundary, trusted assumptions and not claimed

Trust boundary. Every rule here (CAS, fresh ids, per-tenant namespaces, caps, cosign, saga,
inventory, leases) holds only against a caller that reaches the store THROUGH the
production engine. A process that can write the store folder can append records itself:
the CRC-32 and the FNV-1a-128 chain authenticate nothing. A process that can start its
own engine build (for example the `kill_points` build with its test seams, or a changed
copy) can ignore every check. A deployment that wants these rules against an agent must
keep the agent from writing the store folder and from running another engine on it: for
example `serve` runs under another OS user that owns the folder, and the agent holds
only its pipe. The engine cannot check this.

Cosign limits of the same-user threat model (review F1, F9, F7; owner decision: stated, not
changed):

- A process of the store's own OS user can append a record with cosign flag 1 by hand. The
  record holds no signature, so no later audit can tell. The separation by OS user ID
  removes that attacker.
- A signature has no expiry. It stays valid for its request while the key's state hash is
  unchanged: a holder of the request pipe can keep a signature back and use it later, as long
  as no other write changed the key (and FNV-1a-128 collisions can be computed, so the
  state hash is a weak freshness value). There is no deadline field in the message.
- A mixed-order public key (a valid key plus a small-order component) is accepted at `init`.
  The weak-key rule refuses only the small-order and non-canonical encodings; no check that
  L times the key is the identity is done. No third-party forgery through such a key is known.
- The kill-points build accepts the test seams (a stand-in verifier commits a cosign).
  `bin/forge-airlock build` writes it only to the test-only folder `build/silicon/test/`,
  never into `build/airlock/` (review F2); a deployment copies only `airlock-engine`.

What is pinned by what:

- the refund binary: by the engine (compiled-in SHA-256, checked once per process);
- the Node binary: by the store (SHA-256 bound in the genesis record at `init`, checked
  by `serve` once per process before the first booking helper call); inventory only;
- the booking helper: by the engine build (its source is compiled in; no helper file is
  read at run time);
- `/usr/bin/ssh-keygen`: NOT pinned. The engine checks its path once per process
  (section 7: root-owned, no group or other write bit, no symbolic link); `cosign-info`
  prints its SHA-256 for the operator's record;
- the checker model: by `booking_check.cjs` (its own SHA-256 pin, `O_NOFOLLOW`);
- the policies: by the genesis record (FNV-1a-128 of each file; not cryptographic);
- the engine binary itself: by nothing in this repository; whoever starts it chooses it.

Trusted: the macOS kernel and the drive for `F_FULLFSYNC`; `flock`; `/dev/urandom`;
whoever can write the store folder or start an engine on it; the engine binary;
the system OpenSSH is a trusted assumption: `/usr/bin/ssh-keygen` (OpenSSH_10.3p1 with
LibreSSL 3.3.6 on the measured machine) verifies every cosign signature, and an update of
the operating system can change it without a change of any store (its native checks of
section 7 come first; an unknown answer is `HELPER_FAILED`); OpenSSH with LibreSSL is now
in the trusted base for cosign in place of Node/V8: smaller and widely reviewed, but not
zero; Node 24.3.0 (and `bignumber.js` from `node_modules`) for the booking checker only;
the Dafny compiler for `model.cjs`. The opener of a key is trusted for its
tenant, `original` and facts (section 6). A file swapped between its pin check and a
later exec is not detected.

Not claimed: no proof of the engine, the fold, the parser, the policy functions, the
SDKs, the helpers' wiring or the dispatcher. A SIGKILL is not a power loss. FNV-1a-128
is not cryptographic. A restore of the WAL AND the ratchet together is not detected. A
rewritten suffix with a recomputed chain is accepted. The parametric money rules, the
saga table, the read airlock and leases are NATIVE CHECK + FINITE TEST only. No "% of
bugs" figure. M1-B stays OPEN.

FNV-1a-128 collisions can be computed: the state hash is a concurrency control, not a
boundary against an attacker. The read airlock checks only the top-level `tenant_id`.

Known limits: a helper subprocess runs while the store lock is held (at most 10 s for
the binary, 30 s for Node or ssh-keygen). The cosign folder `<store>/cosign.tmp` exists
during a verification; a crash can leave it, and the next verification removes it. A `serve` process that waits for the lock waits without a
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
10. An invalid cosign is `REQUIRE_HUMAN_COSIGN COSIGN_INVALID` (since review D6 it leaves a
    bound lease PENDING_COSIGN; before, it closed the lease).
11. `cosign-message <dir> <action>` (subcommand first), not `<store> cosign-message`.
12. Store ids are at most 24 bytes.
13. `EPOCH_REGRESSION` ends `serve` (in `sink.rs` it did not).
14. A sweep writes no record.
15. A rule may have the verdict `REJECTED_POLICY` (detail `RULE`).
16. Any malformed row, an empty or non-canonical tenant, and missing rows are all
    `TENANT_ISOLATION_BREACH` in the read airlock.
17. Review repairs: the cosign message has six lines (`forge-airlock-cosign-v2`, with the
    genesis hash); DESIGN.md has five. The genesis record is version 2 (nonce, Node pin).
    No version-1 store is read.
18. The helpers are compiled into the engine; DESIGN.md's `--helpers` folder is gone.
    `init` takes `--node` and pins it; DESIGN.md had no Node pin.
19. Leases are bound to a tenant and a key (`OPEN_LEASE <request_id> <deadline_ms>
    <tenant> <key>`), and one request id can have only one lease per tenant, ever.
20. Apex addendum: DESIGN.md's Node Ed25519 helper is replaced by `/usr/bin/ssh-keygen -Y
    verify`. The cosign key is an OpenSSH `ssh-ed25519` key token, the signature an SSHSIG
    token, the message `forge-airlock-cosign-v3`, the genesis record version 3 (no
    version-2 store is read). Node is needed only for the inventory airlock.
21. Review D3: keys, request ids and leases are per tenant (DESIGN.md had one store-wide
    namespace). The `CLOSE` record names the tenant: `CLOSE <request_id> <tenant> <verdict>
    <detail>`. The form without a tenant (written by the engine before this change) is
    still read, but only while exactly one lease in the whole store has that request id
    (always true in a WAL of that engine: it allowed one lease per id in the store);
    otherwise it is `CORRUPT_WAL`. No genesis version change: a WAL of the engine before
    this change folds to the same keys, ids, effects and leases (case `legacy_wal` of
    `tests/airlock/test_engine.py` and `proposals/review-20261120-engine/compat_wal.py`), and
    that engine refuses (`CORRUPT_WAL`) every record that only the new engine writes.
22. Review D6: `REQUIRE_HUMAN_COSIGN` no longer closes a lease. It writes one
    `COSIGN_PENDING <request_id> <tenant> <detail>` record (the lease is PENDING_COSIGN)
    and the answer names `LEASE_PENDING <epoch>`. The sweep reports a PENDING_COSIGN lease
    as `PENDING_COSIGN` before its deadline and as `DROPPED_OBLIGATION` after it. An old
    `CLOSE <request_id> REQUIRE_HUMAN_COSIGN <detail>` record is read as `COSIGN_PENDING`.
    The new `CLOSE` form takes only `REJECTED_POLICY`.

## 13. Mutation seams

The list is the `M` and `S` entries of the `MUTANTS` list in `scripts/exit_goal20_sdk.py`
(that script is the reference; this table is a copy). Each entry changes one place in
the source: the exact text (it must occur exactly once in the file; `⏎` is a line end)
is replaced, the changed copy is built (both builds), and the named case of
`tests/airlock/test_engine.py` must fail. M01 to M35 remove checks of the
verbs, the policies and the store. S01 to S18 remove a durable step, a check of its
result, the order of the lock, or the `DISPATCH_FAILED` code; the cases `trace`,
`dispatch` and `lock` see them (the test interposer `tests/airlock/interpose.c` traces
the system calls and injects failed syncs and writes). Results: see the exit script's
record, not this file.

Review of the native cosign (F2, F4, F6): new copies `F2_kill_build_beside_engine`
(bin/forge-airlock; case `py_build_separation`), `F4_root_not_walked` (cosign.rs; case
`cosign_faults`) and `F6_sign_lines_not_crosschecked` (cosign_tool.py; case
`sign_action_request_id_differs`).

Apex addendum (cosign through `/usr/bin/ssh-keygen`): in the table below, M09 now reads
`if !cosign::verify(&ctx.dir, &pk, sig, &msg)? {` (verbs.rs) and M10 reads
`(Some(0), true, o) if o == good.as_bytes() => Ok(true),` (cosign.rs, case
`cosign_faults`). R1a moved to case `inventory` (the Node pin is now for the booking
helper only), R1b to the seam `AIRLOCK_TEST_SSH_KEYGEN`. The Node helper copies N01 to
N05, X06 and R4c of the exit script were replaced by copies of `cosign_tool.py` and
`cosign.rs`, and new copies (group C) remove the native checks of section 7. The exit
script is the reference for the exact texts.

Review repair pass (2026-11-19): three texts of the table below no longer occur in the
source and must be replaced in the exit script (each new text was applied alone, built
both ways, and the named case failed):

| Id | File | New exact text | Replacement | Case |
| --- | --- | --- | --- | --- |
| M19_lease_close_record | verbs.rs | `    if bound {⏎        let (epoch, _)` | `    if false {⏎        let (epoch, _)` | leases |
| M20_commit_closes_lease | ledger.rs | `l.closed = Some((index, "COMMITTED".into(), "-".into()))` | `l.closed = None` | leases |
| M32_cosign_store_id_fixed | verbs.rs | `cosign_message(&s.l.store_id, s.l.genesis_hash, req, t[4], &action)` | `cosign_message("store-a", s.l.genesis_hash, req, t[4], &action)` | cosign |

Proposed new seams for the repairs (each was run alone; the case failed):

| Id | File | Exact text | Replacement | Case | Failure text |
| --- | --- | --- | --- | --- | --- |
| R1a_node_pin | helpers.rs | `    pinned(&NODE_CHECKED, node, pin, "Node binary")?;⏎` | (empty) | inventory | `a Node binary other than the pinned one` |
| R1b_seam_in_production | helpers.rs | `if cfg!(kill_points) { std::env::var(var).ok() } else { None }` | `std::env::var(var).ok()` | seams | `with AIRLOCK_TEST_SSH_KEYGEN: expected REQUIRE_HUMAN_COSIGN COSIGN_INVALID` |
| R1c_binary_pin | helpers.rs | `        pinned(&BINARY_CHECKED, b, REFUND_BINARY_SHA256, "refund binary")?;⏎` | (empty) | canonical | `expected HELPER_FAILED (exit 22), got exit 23` |
| R2a_no_nonce | store.rs | `    let nonce: String = nonce.iter().map(\|b\| format!("{b:02x}")).collect();` | `    let nonce: String = "0".repeat(32);` | nonce | `the two genesis records must differ by their nonce` |
| R2b_genesis_not_in_message | verbs.rs | `cosign_message(&s.l.store_id, s.l.genesis_hash, req, t[4], &action)` | `cosign_message(&s.l.store_id, 0, req, t[4], &action)` | cosign | `expected COMMITTED (exit 0), got exit 11` |
| R4a_small_order | pin.rs | `    SMALL_ORDER.contains(&masked.as_str()) \|\| y_ge_p` | `    y_ge_p` | weakkey | `accepted: 0 'INITIALIZED` |
| R4b_init_weak | store.rs | `        if crate::pin::weak_ed25519(&raw) {` | `        if false {` | weakkey | `weak key` |
| R5a_lease_reopen | verbs.rs | `    if s.l.leases.contains_key(req) { return no(Code::Duplicate, "LEASE_USED` | `    if false { return no(Code::Duplicate, "LEASE_USED` | lease_binding | `'OPEN_LEASE wh-2 100 t1 order-1': expected DUPLICATE_REQUEST_ID` |
| R5b_lease_unbound | verbs.rs | `\|(t, k)\| s.l.leases.get(req).map_or(false, \|l\| l.binds(t, k))` | `\|(_, _)\| s.l.leases.get(req).map_or(false, \|l\| l.is_open())` | lease_binding | `a verdict on another key must not name a close` |

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
| M09_cosign_not_verified | verbs.rs | `if !cosign::verify(&ctx.dir, &pk, sig, &msg)? {` | `if false {` | cosign | the verification of a cosign signature |
| M10_cosign_answer_any_bytes | cosign.rs | `(Some(0), true, o) if o == good.as_bytes() => Ok(true),` | `(Some(0), _, _) => Ok(true),` | cosign_faults | the exact Good line and the empty stderr of ssh-keygen |
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
