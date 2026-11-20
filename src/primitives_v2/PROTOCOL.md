# forge primitives engine v2: wire protocol, store, module interface, trusted clock, `rate_window`

Status: the reference for `src/primitives_v2/*.rs`. Labels: everything here is **NATIVE CHECK** (Rust, not
proved) with **FINITE TEST** (`tests/primitives_v2/`). Nothing here is a PROVED CORE. `end_to_end=false`.
Every rule holds only for a caller that reaches the store THROUGH the production binary (section 11).

## 1. Build

```sh
rustc --edition 2021 -D unsafe_code -C opt-level=3 src/primitives_v2/main.rs -o build/primitives_v2/primitives-engine
rustc --edition 2021 -D unsafe_code -C opt-level=3 --cfg test_seams src/primitives_v2/main.rs -o build/primitives_v2_test/primitives-engine-seams
```

- Standard library only. No crate, no Cargo. `#![forbid(unsafe_code)]`. Read-only reuse of the Goal 20 engine
  through `#[path]`: `src/airlock/json.rs` (strict JSON, section 9 of `src/airlock/PROTOCOL.md`) and
  `src/airlock/pin.rs` (SHA-256). Those files are not changed.
- The test build goes ONLY to `build/primitives_v2_test/`, never beside the production binary. It differs in four
  ways, all behind `cfg!(test_seams)` / `#[cfg(test_seams)]`: it reads `PRIMITIVES_TEST_CLOCK` (section 8) and
  `PRIMITIVES_TEST_PAUSE_AT` (pause points `locked`, `before_write`, `before_sync`, `synced`: the process prints
  `AT <point>` on stderr and waits for SIGKILL with the lock held), it has the test module `cas_probe`, and it writes
  `test-seams` as the build kind into the genesis record. Each build refuses a store of the other build
  (`CORRUPT_WAL why=BUILD_MISMATCH`), so a test store never runs under production and the reverse. Case `seams`
  checks that the production build ignores both variables and has no `cas_probe`.
- Modules: `main.rs` (CLI, `serve`, answers, exit codes), `store.rs` (records, WAL, lock, replay, `init`, mode and
  owner checks), `clock.rs` (trusted clock), `engine.rs` (grammar, registry, tenants, ids, multi-key CAS),
  `prim.rs` (module interface), `rate.rs` (primitive 6), `cosign_ttl.rs` (TTL; signature stub), stubs
  `ledger_graph.rs` (7), `taint.rs` (8), `farkas.rs` (9), `probe.rs` (test build only).

## 2. Subcommands

| Command | Output (one line unless stated) | Exit |
| --- | --- | --- |
| `init <dir> [--store-id ID] [--policy FILE]...` | `INITIALIZED store_id= genesis= build= now_ms=` | 0, or a code |
| `serve <dir>` | one answer line per request line | code of the last answer; 2 if no line |
| `state <dir>` | `STATE store_id= seq= tail= last_ms= now_ms= wall_ms= skew_ms= build= keys= ids= genesis=` | 0, or a code |
| `get <dir> <tenant> <key>` | as the `GET` verb | 0, 12, 16, faults |
| `replay <dir>` | `REPLAY records=<n>`, then n lines `RECORD <seq> <now_ms> <wall_ms> <payload>` (genesis included) | 0, or a code |
| `cosign-message <dir> <request_id> <pre_state_hash or *> <not_after_ms> <action>` | the exact 7 message lines (section 10) | 0, 2, 12 |
| `cosign-ttl <dir> <not_after_ms> <max_ttl_ms>` | `TTL_OPEN left_ms= now_ms= skew_ms= signature=NOT_CHECKED`, or `COSIGN_EXPIRED` / `COSIGN_TTL_TOO_LONG` | 0, 10 |

- `--store-id` absent: `store`. Store ids, tenants, request ids, policy names: `[A-Za-z0-9_-]{1,24}`.
- Every command but `init` opens the store: folder and file checks, the lock, replay, the cut of a torn last record.
  So `state`, `get`, `replay` and `cosign-ttl` need write access to the store folder.

## 3. Store and record layout

One folder, mode 0700 (any group or other bit refuses it: `UNSAFE_STORE why=FOLDER_MODE`), a directory and not a
symbolic link, owned by the effective user. Files, each mode 0600 (`FILE_MODE`), regular, opened with `O_NOFOLLOW`,
the same inode as their `lstat`, owned by the effective user:

| File | Content |
| --- | --- |
| `primitives.wal` | the records |
| `policy-<name>.json` | byte copies of the `--policy` files; SHA-256 of each is in the genesis record |

The effective uid comes without `unsafe` and without a crate: the engine creates a new file (`O_CREAT|O_EXCL`,
0600) named `.euid-probe-<pid>-<n>` in the store folder, reads its owner with `fstat`, and removes it (once per
process; the method of `src/mcp_proxy` on branch `demo/archia-mcp-showcase`). A kill between create and remove
can leave one probe file; the engine ignores it.

Record (little-endian):

| Bytes | Field |
| --- | --- |
| 0..4 | magic `PV2R` |
| 4..12 | seq: 0 for the genesis record, then +1 |
| 12..20 | `now_ms`: the engine time of the record (section 8) |
| 20..28 | `wall_ms`: the raw wall-clock reading at the write (`wall_ms <= now_ms`) |
| 28..60 | SHA-256 of the whole previous record (32 zero bytes in the genesis record) |
| 60..64 | payload length L, at most 131,072 |
| 64..68 | CRC-32/IEEE of bytes 0..64 (the header check) |
| 68..68+L | payload: printable ASCII |
| 68+L..72+L | CRC-32/IEEE of bytes 0..68+L |

- The hash of a record is the SHA-256 of all its bytes. The state hash of a key is the hash of the last record
  that touched it, or the genesis hash for a key that no record touched (so `GET` gives a usable `pre_state_hash`
  for a new key). The genesis record holds 16 bytes from `/dev/urandom`, so two stores never share a state hash.
- Genesis payload: `G pv2 <store_id> <nonce 32 hex> <production|test-seams> <n> [<policy> <primitive> <sha256>]×n`.
- Effect payload: `E <primitive> <op> <request_id> <tenant> <C|R> <n> <key_1> ... <key_n> |[ <module payload>]`
  (`C` commit, `R` the state change of a refusal; 1 to 16 keys in strictly ascending byte order).
- Replay checks every record: magic, header check, seq, length bound, record CRC, chain, printable payload, times
  (`now_ms` never below the previous record's, `wall_ms <= now_ms`), the genesis form and build kind, each policy
  file against its SHA-256, then for an effect: a known primitive and op, the key count, canonical ids and keys in
  order, a request id never used before, each key's tenant and primitive unchanged, and the module's own strict
  `fold` (section 7). Any fault: `CORRUPT_WAL why=<word> record=<seq>`, and the store is refused. There is no repair.
- Torn tail: after the valid prefix, at most one incomplete record may follow, at the end of the file: bytes that
  agree with a record start (a prefix of the magic and, once 12 bytes are there, the expected seq), or a whole
  header whose header check is valid and whose length runs past the end. It is cut (`set_len`, `sync_all`). Any
  other tail (garbage, a wrong seq, a bad header check) refuses the store. The header check is the reason a damaged
  length field in the last record is `CORRUPT_WAL`, never a silent cut (case `flip`, copy `S3`).
- Order of one write: exclusive lock (`File::try_lock`, a `flock`; bounded wait of 60 s, then `STORE_BUSY
  retry_after_ms=1000`) before any byte of the store is read -> replay -> trusted Now -> checks -> module decision ->
  fold of the new record (a record the fold refuses is never written: `MODULE_FAULT why=RECORD_NOT_FOLDABLE`) ->
  one `write_all` -> `sync_all` (`fcntl(F_FULLFSYNC)` on macOS) -> lock released -> answer. A failed write or sync:
  the WAL is cut back to its old length and synced: `IO_ERROR` (nothing committed); if that fails too:
  `OUTCOME_UNKNOWN` (a record may stay; it was not answered).
- `init` builds the store in a fresh sibling folder `<dir>.init-<pid>-<ms>` (mode 0700), writes and syncs each file,
  syncs the folder, renames it to `<dir>` (refused if `<dir>` exists in any form: `IO_ERROR why=STORE_EXISTS`),
  and syncs the parent folder. A failed parent sync after the rename answers `OUTCOME_UNKNOWN why=PARENT_SYNC` (the
  store may stay). A refused `init` removes its temporary folder.

Lock scope (decision): per exchange, not per process. Each request line takes the lock, replays the whole WAL,
writes at most one record, syncs, and releases the lock before the answer. Reasons: many `serve` processes can share
one store (the 50-process races), a killed process holds nothing after the kernel drops its descriptor, and no state
lives in memory between two requests, so "restart" and "next request" are the same thing (a non-durable state
change cannot survive even within one process). Cost: every request reads the whole WAL (O(WAL) per request).

## 4. Request lines (`serve`)

- One request per line, LF-terminated, at most 65,536 bytes before the LF. A longer line is skipped to its LF with
  constant memory (the 64 KiB reader buffer) and answered `MALFORMED_REQUEST why=OVERSIZED max_line=65536`. Bytes
  at EOF with no LF: `why=NO_LINE_END`. Printable ASCII only (`why=NON_ASCII`). Fields are separated by exactly one
  space (`why=SPACING`).
- Verbs:

| Verb | Grammar | Success |
| --- | --- | --- |
| `DO` | `DO <primitive> <op> <request_id> <tenant> <n> <key_1> <hash_1> ... <key_n> <hash_n> [<args>]` | `COMMITTED ...`, or `OK verdict=...` (stateless) |
| `GET` | `GET <tenant> <key>` | `OK key= hash= exists=0 now_ms= skew_ms=` or `OK key= hash= exists=1 primitive= now_ms= skew_ms= <module fields>` |
| `STATE` | `STATE` | `STATE store_id= seq= tail= last_ms= now_ms= wall_ms= skew_ms= build=` |

- Key: `[A-Za-z0-9_.:@+-]{1,128}`. Hash: 64 lowercase hex, or `*` where the op allows it (`Cas::AnyAllowed`).
  `n`: 0 to 16 and within the op's range. `<args>`: the rest of the line, owned by the module (no leading or
  trailing space).
- Check order of `DO`: grammar (no file opened: primitive, op, ids, key count, keys strictly ascending
  (`KEY_ORDER`, `DUPLICATE_KEY`), hashes (`BAD_HASH`, `CAS_REQUIRED`)) -> lock and replay -> trusted Now -> for
  every key: another tenant's key (`TENANT_ISOLATION_BREACH why=KEY_OF_ANOTHER_TENANT key=<k>`), another
  primitive's key (`MALFORMED_REQUEST why=KEY_KIND`) -> request id used (`DUPLICATE_REQUEST_ID`) -> compare-and-swap
  of EVERY key: one or more stale keys refuse the whole request, `STALE_STATE_HASH stale=<count> hash.<key>=<present>`
  for each stale key -> module decision -> at most one record.
- Request ids are one-time per store (one namespace). A record uses its id up (a commit, and also a durable
  refusal). A refusal without a record and a stateless answer leave the id fresh.
- A key binds to (tenant, primitive) at the first record that touches it.

## 5. Answer wire form

Every answer is one line (`replay` excepted): `<CODE>( <name>=<value>)*( -- <detail>)?`.

- `CODE`: `[A-Z][A-Z0-9_]{2,47}`. Names: `[A-Za-z0-9_.:@+-]+` (an engine name can hold a key: `hash.<key>`).
  Values: percent-encoded; every byte outside `[A-Za-z0-9._~:/@$[]+,-]` is `%XX` (so a value never holds a space or
  `=`). A client splits on spaces up to ` -- `, splits each token at its first `=`, and percent-decodes the value.
  The detail is printable text for a human; no program needs it.
- `COMMITTED request_id= seq= now_ms= skew_ms= hash.<key>=<new hash>... effect=<module payload>`: the new hash of
  EVERY key of the request is the same record hash.
- A durable refusal: `<CODE> <module fields> request_id= seq= now_ms= skew_ms= hash.<key>=... [-- detail]`.
- A module refusal without record: `<CODE> <module fields> now_ms= skew_ms= [-- detail]`.
- A stateless answer: `OK verdict=<WORD> <module fields> now_ms= skew_ms= [-- detail]`.
- Engine refusals carry `why=<WORD>`.

## 6. Codes and exit codes

| Exit | Code | Class |
| --- | --- | --- |
| 0 | `COMMITTED`, `OK`, `STATE`, `REPLAY`, `INITIALIZED`, `TTL_OPEN` | success |
| 2 | `USAGE` | bad arguments; `serve` with no line |
| 10 | any module code not listed here (`RATE_LIMIT_EXCEEDED`, `COOLDOWN_ACTIVE`, `VOLUME_ABOVE_CAP`, `UNKNOWN_POLICY`, `POLICY_MISMATCH`, `COSIGN_EXPIRED`, `COSIGN_TTL_TOO_LONG`, and the codes of primitives 7 to 9) | policy refusal |
| 12 | `MALFORMED_REQUEST` | refusal (engine or module grammar) |
| 13 | `STALE_STATE_HASH` | refusal |
| 14 | `DUPLICATE_REQUEST_ID` | refusal |
| 16 | `TENANT_ISOLATION_BREACH` | refusal |
| 17 | `CORRUPT_WAL` | fault |
| 18 | `IO_ERROR` | fault (nothing committed) |
| 19 | `OUTCOME_UNKNOWN` | fault (a record may stay; not answered as committed) |
| 20 | (none printed) | fault: the answer line could not be written |
| 25 | `MALFORMED_POLICY` | `init` refused a policy file |
| 26 | `STORE_BUSY` | refusal (lock not free for 60 s) |
| 27 | `NOT_IMPLEMENTED` | refusal (a stub primitive, the cosign signature) |
| 28 | `UNSAFE_STORE` | fault (mode, owner, link) |
| 29 | `MODULE_FAULT` | refusal: a module broke the interface; nothing written |

`serve` ends after a fault (17, 18, 19, 20, 28) and reads no further line.

## 7. Module interface (`prim.rs`)

### 7.1 Signatures (binding for primitives 7, 8, 9)

```rust
pub struct Now { pub now_ms: u64, pub wall_ms: u64, pub skew_ms: u64 }
pub enum Cas { Required, AnyAllowed }
pub struct OpSpec { pub op: &'static str, pub min_keys: usize, pub max_keys: usize, pub cas: Cas }
pub struct KeyView<'a> { pub key: &'a str, pub exists: bool }
pub struct Request<'a> { pub request_id: &'a str, pub tenant: &'a str, pub op: &'a str, pub keys: &'a [KeyView<'a>], pub args: &'a str }
pub enum Kind { Commit, Refusal }
pub struct Record<'a> { pub seq: u64, pub now_ms: u64, pub request_id: &'a str, pub tenant: &'a str, pub op: &'a str,
                        pub kind: Kind, pub keys: &'a [&'a str], pub payload: &'a str }
pub struct Refusal { pub code: &'static str, pub repair: Vec<(&'static str, String)>, pub detail: String }
pub enum Decision { Refuse(Refusal), RefuseDurable(Refusal, String), Commit(String),
                    Answer(&'static str, Vec<(&'static str, String)>, String) }
pub type Policies<P> = BTreeMap<String, P>;
pub trait Primitive {
    const NAME: &'static str;
    const OPS: &'static [OpSpec];
    type Policy;
    type State: Default;
    fn parse_policy(doc: &J) -> Result<Self::Policy, String>;
    fn decide(req: &Request, state: &Self::State, policies: &Policies<Self::Policy>, now: &Now) -> Decision;
    fn fold(state: &mut Self::State, rec: &Record, policies: &Policies<Self::Policy>) -> Result<(), String>;
    fn describe(state: &Self::State, key: &str, policies: &Policies<Self::Policy>, now: &Now) -> Option<Vec<(&'static str, String)>>;
}
// helpers: refusal(code, repair, detail), dec_u64(s), policy_fields(doc, keys), wire_value(s), MAX_MODULE_PAYLOAD
```

### 7.2 Rules

- PURE: no file, socket, clock, environment, process, randomness or global state. Time is `now` (decide) or
  `rec.now_ms` (fold) only.
- `decide` and `fold` agree. The engine folds a new record before it writes it. `fold` must refuse (Err) every
  payload that `decide` could not have produced; at replay an Err refuses the store. Re-check the decision in
  `fold` (as `rate.rs` does with the record time): then a forged or damaged record is refused, not trusted.
- A module payload is printable ASCII, at most 65,536 bytes. Codes and field names follow section 5; the engine
  refuses a reserved code (`prim::RESERVED`) or field name (`prim::RESERVED_FIELDS`, `hash.*`) with `MODULE_FAULT`.
- A refusal never carries a secret, a value of the request document, or data of another tenant. The engine refuses
  another tenant's key before the module runs, but the module's `State` holds every tenant's data: the module must
  not copy any of it into an answer.
- Arithmetic on request data: `checked_*`, saturating with a stated reason, or u128. No panic on request data.
- To fill a stub, replace the body of `ledger_graph.rs`, `taint.rs` or `farkas.rs` only. Keep the unit struct name,
  `NAME`, and the trait signatures. `OPS`, `Policy`, `State` and the bodies are free. The registry in `engine.rs`
  already names all three; no other file changes. Policy files: `{"primitive": NAME, "version": 1, "name": <id>, ...}`.

### 7.3 Multi-key effects (primitive 7)

A request names 2 to 16 keys in strictly ascending byte order, each with its present state hash
(`Cas::Required`). The engine checks tenant and kind of every key, then compares ALL hashes before the module runs;
one stale key refuses the whole request with the present hash of each stale key. The module then sees all keys at
once and returns ONE `Commit(payload)`; the engine writes ONE record naming all keys and sets the state hash of
every key to that record's hash. Atomicity follows from one record under one lock with one sync: the record is in
the WAL whole, or not at all (a torn record is cut). The module's `fold` applies all keys of the record together and
can check an invariant over all its state (for example the sum of all accounts). Tested with the test module
`cas_probe` (case `multikey`); no ledger rule is tested here.

### 7.4 Stateless checks (primitives 8 and 9)

An op with `max_keys = 0` returns `Decision::Answer` (allow: `OK verdict=<WORD> ...`) or `Decision::Refuse`
(block). It writes NO record, also no receipt. Reasons: nothing changes, so there is nothing to fold; a receipt per
check would let traffic that is only refused grow the WAL without a bound; and the request id stays fresh. A
`Commit` or `RefuseDurable` from a 0-key op is `MODULE_FAULT why=WRITE_WITHOUT_KEY`. Recommendation to the workers:
put the SHA-256 of the checked bytes into the answer fields, so a caller can bind the verdict to the exact bytes.
The document travels in `<args>` (printable ASCII: non-ASCII text must be `\u`-escaped JSON; at most the line bound).

## 8. The trusted clock (`clock.rs`)

- The engine reads `SystemTime` and `Instant` itself. No request field is ever a time (case `clock_request`).
- Rule: `now_ms = max(wall_ms, last_ms, mono_floor_ms)`. `last_ms` = the engine time of the newest record (read
  under the lock). `mono_floor_ms` = `anchor_ms + (Instant now - anchor Instant)` where the anchor is the first
  reading of this process (0 at that reading). `skew_ms = now_ms - wall_ms` is reported in every answer that has a
  time and in `STATE`.
- Why max, not refuse: a wall clock set back (operator, NTP, restored machine image) must never reopen a window,
  end a cooldown or revive a cosign token; with the max rule the engine time never goes back past the newest record,
  and the WAL times are non-decreasing (replay checks it). Refusing every request while the clock is behind would
  also be safe, but it stops all work until the clock catches up; the max rule fails closed (windows stay full
  longer) and keeps working, and `skew_ms` makes the fault visible.
- Monotonic readings mean nothing across processes: `Instant` has a per-process, per-boot origin, and on macOS it
  does not count sleep. The engine never writes a monotonic reading and never compares two processes' readings. A
  new process starts with no monotonic floor (case `clock_setback`). Inside one process the floor lets time go on
  while the wall clock is behind.
- Limits: the engine trusts the host clock. A host administrator who moves the clock FORWARD ends every window and
  every cooldown early, and expires every cosign token early. A time once written stays the floor: a clock set far
  forward by mistake freezes the engine time at that value until the wall clock passes it (windows stay full: fail
  closed, but a denial of service). A WAL restored to an older copy forgets the newer records and their events. A
  token that expired after the newest record can be revived by a set-back clock. Nothing here is a secure time
  source.
- Test seam (test build only): `PRIMITIVES_TEST_CLOCK=<file>`, the file holds `<wall_ms> <mono_ms>` and is read at
  every reading.

## 9. Primitive 6: `rate_window` (`rate.rs`)

Policy: `{"primitive": "rate_window", "version": 1, "name": "<id>", "max_ops_per_window": "1..65536",
"max_volume_per_window": "0..18446744073709551615", "window_ms": "1..18446744073709551615", "cooldown_after":
"0..1024", "cooldown_ms": "0..18446744073709551615"}` (strings of canonical decimals; `cooldown_ms >= 1` when
`cooldown_after > 0`; `cooldown_after = 0` disables the cooldown). One window per (tenant, key); the first record
binds the key to its policy (`POLICY_MISMATCH` after that).

Op: `DO rate_window acquire <request_id> <tenant> 1 <key> <hash or *> <policy> <volume>` (volume: canonical decimal
u64; `*` allowed: the engine decides on the present state under the lock).

- Window: an event at t counts at `now` while `now < t + window_ms`; it stops counting AT `t + window_ms`. If
  `t + window_ms` overflows u64, the event never stops counting.
- State: the EXACT list of (time, volume) of the events that may still count. The fold drops every event with
  `t + window_ms <= record time`; engine time never goes back, so a dropped event can never count again. A commit
  needs `live_ops + 1 <= max_ops`, so the list holds at most `max_ops_per_window` events. Rebuilt from the WAL at
  every request. Nothing is approximated: the list is the set of events that count.
- Decision, first match wins: (1) `volume > max_volume_per_window`: `VOLUME_ABOVE_CAP` (never fits), no record;
  (2) cooldown active (`now < cooldown_until`): `COOLDOWN_ACTIVE retry_after_ms=<cooldown_until - now>`, no record;
  (3) fits (`live_ops + 1 <= max_ops` and `live_volume + volume <= max_volume`, sums in u128): `COMMITTED`, record
  `A <policy> <volume>`; (4) else `RATE_LIMIT_EXCEEDED retry_after_ms=<n>`. `n` is exact: let k be the least number
  of oldest live events whose end frees one op AND enough volume; `n = t_k + window_ms - now` (`never` if that sum
  overflows). At `now + n - 1` the same request is refused with `retry_after_ms=1`; at `now + n` it commits (case
  `boundary`: 36 n-1/n checks on 12 random policies).
- Cooldown: with `cooldown_after = N > 0`, a rule-4 refusal changes state (the count of consecutive rejections), so
  it is a durable record `X <policy> <volume>` (kind R, uses the request id up). The N-th consecutive one starts the
  cooldown: `cooldown_until = t + cooldown_ms` (checked; overflow gives u64::MAX). A commit resets the count; the
  start of a cooldown resets it. Without the record a restart would forgive the rejections; with per-exchange replay
  it would forgive them at the next request (copy `C1`).
- Growth bound of refusal-only traffic: rules 1 and 2 write nothing; rule 4 needs a live committed event in the
  window of that key, and at most N records come before each cooldown, during which nothing is written. So per key,
  within any span of `window_ms` after a commit, rejection records are at most `N * (window_ms / cooldown_ms + 1)`:
  refusals grow the WAL at most in proportion to commits. With `N = 0` refusals write nothing.
- Replay re-checks every record with its record time: a commit that did not fit, a rejection that would have
  fitted, a record during a cooldown, a rejection record without a cooldown, or a policy change refuses the store.
- `GET` fields: `policy= ops= volume= rejections= cooldown_ms_left=`.

## 10. Cosign TTL (`cosign_ttl.rs`)

Message (7 LF-terminated lines, at most 4,096 bytes):
`forge-primitives-cosign-v1\n<store_id>\n<genesis_hash>\n<request_id>\n<pre_state_hash or *>\n<not_after_ms>\n<action>\n`.
`not_after_ms` is inside the signed bytes. The engine compares it with its trusted Now: `now > not_after` is
`COSIGN_EXPIRED expired_by_ms=`; `not_after - now > max_ttl_ms` is `COSIGN_TTL_TOO_LONG max_ttl_ms=`. The TTL check
runs before any signature tool, so an expired token never starts one. The signature check itself is a STUB
(`verify` answers `NOT_IMPLEMENTED`, never accepts): the owner's method `/usr/bin/ssh-keygen -Y verify` has a
reviewed design on the unmerged branch `apex1/native-cosign`; it is not copied here (section 13). `cosign-ttl`
answers `signature=NOT_CHECKED` on purpose. No op of `rate_window` takes a cosign yet.

## 11. Trust boundary, trusted assumptions, not claimed

- Every rule holds only for a caller that reaches the store through the production binary. A process that can
  write the store folder can write a new valid chain (CRC and SHA-256 authenticate nothing) and can delete or roll
  back the WAL. A process that can start another build (the test-seams build, or a changed copy) can ignore every
  check. Keep the agent out of the store folder (for example `serve` under another OS user that owns it).
- Trusted: the kernel, the file system and the drive for `F_FULLFSYNC`; `flock`; `/dev/urandom`; the host clock;
  the engine binary; whoever can write the store folder.
- Not claimed: no proof of anything here. A SIGKILL is not a power loss. A WAL restored to an older copy is not
  detected (no epoch ratchet in this engine). A truncation of a whole committed last record looks like a torn
  record and is cut (only a writer of the folder can do it). The parent folders of the store are not checked.
- Leaks by design: `GET` of another tenant's key answers `TENANT_ISOLATION_BREACH` (it shows that the key exists);
  `STATE` shows the store's record count and tail hash to every caller of `serve`. Any tenant can bind an unused key
  name first.
- Limits: every request replays the whole WAL (O(WAL)); a `serve` waits at most 60 s for the lock. `state`, `get`,
  `replay` need write access.

## 12. Tests and controls

`tests/primitives_v2/test_engine.py <engine> <seams-engine> [--case N]... [--big-gib G]` (20 cases; a case that
cannot run FAILS with NOT RUN). `tests/primitives_v2/mutants.py`: 24 changed copies, each with one exact-once text
replacement, both builds, one case that must FAIL with a named text; the unchanged copy first passes every named
case. The sync copy `S1` is seen only through the read-only test interposer `tests/airlock/interpose.c` (case
`trace`, F_FULLFSYNC order and an injected sync failure); no test sees a power loss.

## 13. Departures from the directive and open points

1. The cosign signature check is a stub (section 10); only the TTL rule is implemented and tested.
2. Lock per exchange, not per process (section 3).
3. A durable refusal record uses up its request id (a retry needs a new id).
4. A request that can never fit (`VOLUME_ABOVE_CAP`) writes nothing and does not count toward the cooldown.
5. No epoch ratchet: a restored older WAL is not detected (the Goal 20 engine has one).
6. Stateless checks write no receipt (section 7.4); if the owner wants an audit trail, it needs a separate bounded
   log, not the WAL.
