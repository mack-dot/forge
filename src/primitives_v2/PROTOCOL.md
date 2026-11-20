# forge primitives engine v2: wire protocol, store, module interface, trusted clock, primitives 6 to 9

Status: the reference for `src/primitives_v2/*.rs` and `sdk/py/forge_primitives.py`. Labels: every rule here is
**NATIVE CHECK** (Rust, not proved) with **FINITE TEST** (`tests/primitives_v2/`). No Rust file here is a PROVED
CORE. The one Dafny statement (section 13: `FarkasCert.Soundness`) is about the Dafny predicate only, not about
`farkas.rs`. `end_to_end=false`. Every rule holds only for a caller that reaches the store THROUGH the production
binary (section 15).

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
  `prim.rs` (module interface), `rate.rs` (primitive 6), `cosign_ttl.rs` (TTL implemented; signature STUB),
  `ledger_graph.rs` (7), `taint.rs` (8), `farkas.rs` (9), `probe.rs` (test build only). The policy-to-Dafny
  generator of primitive 9 (`src/primitives_v2/py/policy_to_dfy.py`, `domains/compiled_policies/`) is not part of
  the engine binary; its own files and suite describe it.
- SDK: `sdk/py/forge_primitives.py` (Python stdlib; section 16). No TypeScript wrapper for this engine exists.

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
- Check order of `DO`: grammar (no file opened: primitive, op, ids, key count, per key: form (`BAD_KEY`), reserved
  prefix of another primitive (`RESERVED_KEY`, section 4.1), strictly ascending (`KEY_ORDER`, `DUPLICATE_KEY`),
  hash (`BAD_HASH`, `CAS_REQUIRED`)) -> lock and replay -> trusted Now -> for
  every key: another tenant's key (`TENANT_ISOLATION_BREACH why=KEY_OF_ANOTHER_TENANT key_index=<i>`), another
  primitive's key (`MALFORMED_REQUEST why=KEY_KIND key_index=<i>`) -> request id used (`DUPLICATE_REQUEST_ID`) -> compare-and-swap
  of EVERY key: one or more stale keys refuse the whole request, `STALE_STATE_HASH stale=<count> hash.<key>=<present>`
  for each stale key -> module decision -> at most one record.
- Request ids are one-time per store (one namespace). A record uses its id up (a commit, and also a durable
  refusal). A refusal without a record and a stateless answer leave the id fresh.
- A key binds to (tenant, primitive) at the first record that touches it.
- Engine refusals name a key by `key_index=<i>`, its 0-based position in the request, never by the key itself
  (`RESERVED_KEY`, `TENANT_ISOLATION_BREACH`, `KEY_KIND`; review finding L4, 2026-11-20). Still named: the key of
  a `STALE_STATE_HASH` in the field NAME `hash.<key>` (the caller's own key, needed for the repair), the key of a
  `GET` answer (`OK key=`), and the caller's own key in the ledger_graph module refusals (`UNKNOWN_ACCOUNT key=`,
  `INSUFFICIENT_FUNDS key=`, ...; section 14). A key is the caller's own request data; a caller that puts a secret
  in a key name sees it in these answers.

### 4.1 Reserved key prefixes

A primitive can own a key-name prefix. The table is in the engine (`engine::RESERVED_PREFIXES`), because key
binding is an engine rule:

| Prefix | Owner | Why |
| --- | --- | --- |
| `reg:` | `ledger_graph` | the registry handles `reg:<tenant>` (section 11.4) |

- A `DO` of any OTHER primitive that names a key that starts with an owned prefix is refused in the grammar step,
  before the store is opened and before any module code runs: `MALFORMED_REQUEST why=RESERVED_KEY key_index=<i>
  prefix=<p> owner=<primitive>` (exit 12; no record; no clock fields; the request id stays fresh). One such key
  refuses the whole multi-key request. The owner's own ops pass this step; the owner module keeps its own rules
  (`ledger_graph` refuses `reg:` keys for accounts and graphs and requires exactly `reg:<tenant>` for a claim).
- Replay: a record of another primitive that names such a key refuses the store: `CORRUPT_WAL why=MODULE
  record=<seq>`, detail `<primitive>: RESERVED_KEY ...` (the check sits in `engine::fold_module`; store.rs gives
  every fold error the word `MODULE`). The same fold runs before every write, so such a record is never written
  (`MODULE_FAULT why=RECORD_NOT_FOLDABLE` would be the second line of defence).
- Prefixes compare as exact bytes (case-sensitive): `Reg:t1`, `regt1`, `xreg:t1` are ordinary keys.
- Why (case `reserved`): before this rule, `DO rate_window acquire x1 t2 1 reg:t1 * api 1` committed and bound
  `reg:t1` to tenant t2, and every later claim of t1 got `TENANT_ISOLATION_BREACH` for ever (squatting; seen on
  the engine of commit `2bf34eb5`). A tenant could also block its own handle (`KEY_KIND`). A store written by that
  engine with such a record is now refused at replay (no repair).
- Limit: a new owned prefix needs a row in this table AND in the owner module; a future module that forgets the
  row is not protected. Other key names stay first come, first served (section 15).

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
| 10 | any module code not listed here (every code of section 14 with exit 10) | policy refusal |
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
| 27 | `NOT_IMPLEMENTED` | refusal (the cosign signature stub; no command of this build answers it) |
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
- The registry in `engine.rs` names the four modules (`rate_window`, `ledger_graph`, `taint_egress`, `farkas`; and
  `cas_probe` in the test build only). A new module needs a registry entry in each `match` of `engine.rs`, and a
  row in `RESERVED_PREFIXES` if it owns key names. Policy files: `{"primitive": NAME, "version": 1, "name": <id>,
  ...}`.

### 7.3 Multi-key effects (primitive 7)

A request names 2 to 16 keys in strictly ascending byte order, each with its present state hash
(`Cas::Required`). The engine checks tenant and kind of every key, then compares ALL hashes before the module runs;
one stale key refuses the whole request with the present hash of each stale key. The module then sees all keys at
once and returns ONE `Commit(payload)`; the engine writes ONE record naming all keys and sets the state hash of
every key to that record's hash. Atomicity follows from one record under one lock with one sync: the record is in
the WAL whole, or not at all (a torn record is cut). The module's `fold` applies all keys of the record together and
can check an invariant over all its state (for example the sum of all accounts). Tested with the test module
`cas_probe` (case `multikey`); the ledger rules are in section 11 and `test_ledger_graph.py`.

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
  `A <policy> <volume>`; (4) else `RATE_LIMIT_EXCEEDED retry_after_ms=<n>`. `n` is the LEAST wait after which the
  same request commits, given the state that this refusal leaves. Window part w: let k be the least number of
  oldest live events whose end frees one op AND enough volume; `w = t_k + window_ms - now` (`never` if that sum
  overflows). If THIS refusal starts the cooldown (`cooldown_after > 0` and `rejections + 1 >= cooldown_after`),
  `n = max(w, cooldown_until - now)` with `cooldown_until = now + cooldown_ms` (checked; u64::MAX on overflow);
  else `n = w`. At `now + n - 1` the same request is refused (`retry_after_ms=1`); at `now + n` it commits (case
  `boundary`: 36 n-1/n checks on 12 random policies; case `cooldown_retry`: cooldown_ms 30,000 > window_ms 3,000,
  review finding M1). Before the repair of 2026-11-20, `n` was `w` alone: with `cooldown_ms > window_ms` the retry
  at the stated time got `COOLDOWN_ACTIVE` (repro: max_ops 2, window 3,000 ms, cooldown_after 1, cooldown 30,000 ms:
  `retry_after_ms=2989`, then `COOLDOWN_ACTIVE retry_after_ms=26806`). `COOLDOWN_ACTIVE retry_after_ms` (rule 2)
  is the rest of the cooldown only: the window can still be full at that time, and an early retry that is then
  refused counts as a rejection. The generated Dafny MODEL of a rate policy (`policy_to_dfy.py`, `domains/compiled_policies/rate_window-*.dfy`)
  states the corrected property in its `Post` (`CommitsAfter`, `CoolEnd`) and in the lemma `RetryCommitsAfterStep`;
  that is a statement about the model, tied to `rate.rs` only by the finite differential replay of its vectors.
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
- Limit, not a protection (review finding M2): rate_window limits a KEY; the key and tenant must be bound by a
  trusted wrapper outside the engine. The caller picks the key, and the `<tenant>` field is not authenticated
  (section 15): a fresh key, or the same key name under another tenant name, has its own empty window and no
  cooldown. Case `rate_key_limit` pins this behaviour and prints `KNOWN LIMIT`; it is not counted as a protection.

## 10. Cosign TTL (`cosign_ttl.rs`)

Status, plainly: the TTL rule is IMPLEMENTED and tested (case `cosign_ttl`). The signature check is a STUB: it
never accepts (`verify` answers `NOT_IMPLEMENTED`), and no command of this build calls it. It stays a stub until
the native cosign branch `apex1/native-cosign` is merged; until then NO cosign token is authenticated by this
engine, and no op of any primitive takes a cosign.

Message (7 LF-terminated lines, at most 4,096 bytes):
`forge-primitives-cosign-v1\n<store_id>\n<genesis_hash>\n<request_id>\n<pre_state_hash or *>\n<not_after_ms>\n<action>\n`.
`not_after_ms` is inside the signed bytes. The engine compares it with its trusted Now: `now > not_after` is
`COSIGN_EXPIRED expired_by_ms=`; `not_after - now > max_ttl_ms` is `COSIGN_TTL_TOO_LONG max_ttl_ms=`. The TTL check
runs before any signature tool, so an expired token never starts one. The owner's method for the signature,
`/usr/bin/ssh-keygen -Y verify`, has a reviewed design on that unmerged branch; it is not copied here (section 18).
`cosign-ttl` answers `signature=NOT_CHECKED` on purpose. Limits: a clock set back can revive a token that expired
AFTER the newest record; a clock moved forward expires every token early (section 8).

## 11. Primitive 7: `ledger_graph` (`ledger_graph.rs`)

Multi-account double-entry ledgers, a global uniqueness registry, an acyclic graph guard. NATIVE CHECK, FINITE TEST
(`test_ledger_graph.py`, copies `mutants_p7.py`). Pure module; only BTree maps.

### 11.1 Policies (the policy name is the ledger, registry or graph name)

```
{"primitive": "ledger_graph", "version": 1, "name": "<id>", "kind": "ledger",
 "issuance": "fixed" | "mint_burn", "max_balance": "1..18446744073709551615", "max_legs": "2..16"}
{"primitive": "ledger_graph", "version": 1, "name": "<id>", "kind": "registry",
 "case": "exact" | "ascii_fold", "max_name_bytes": "1..256"}
{"primitive": "ledger_graph", "version": 1, "name": "<id>", "kind": "graph",
 "max_nodes": "2..1000000", "max_edges": "1..4000000"}
```
Every value is a JSON string; numbers are canonical decimals. The key set is exact.

### 11.2 Ops (`DO ledger_graph <op> <request_id> <tenant> <n> <key hash>... <args>`)

| op | keys | CAS | args | record payload (kind C) |
| --- | --- | --- | --- | --- |
| `open` | 1..16 new accounts | required | `<ledger> <balance_1> ... <balance_n>` (key order) | the args |
| `transfer` | 2 accounts | required | `<ledger> <from> <to> <amount>` | the args |
| `post` | 2..16 accounts | required | `<ledger> <leg_1> ... <leg_n>`, leg `-<amount>` (debit: leaves) or `+<amount>` (credit: enters), key order | the args |
| `mint` / `burn` | 1 account | required | `<ledger> <amount>` | the args |
| `claim` / `release` | 1: `reg:<tenant>` | `*` allowed | `<registry> <name>` | `<registry> <canonical name>` |
| `add_edge` | 1 graph key | required | `<graph policy> <from> <to>( <from> <to>)*` (a batch, all or nothing) | the args |
| `remove_edge` | 1 graph key | required | `<graph policy> <from> <to>` | the args |

The module writes only kind-C records (no durable refusal). `fold` parses each payload strictly, requires it to be
canonical, re-runs the SAME checks as `decide` against the folded state, applies it, and re-checks
`total == issued - destroyed` for the touched ledger. So a forged record with a valid chain that overdraws, breaks
conservation, claims a held name, or closes a cycle refuses the store.

Limit of that in-engine check (review finding L5): `total` is a running counter that each op changes by the same
amounts as the balances it touches; the check does NOT sum the account balances. A bug that changes a balance and
`total` alike, or a balance alone, is not caught by it. Only the OUTSIDE test covers a balance bug: the suites sum
the balances read with `GET` and compare the sum with the issued amounts (`test_ledger_graph.py` cases `ledger`,
`model`, `race_ledger`, `kill9`; the demo check `total_supply_constant`).

### 11.3 Ledger

- A ledger instance is (tenant, ledger policy). An account is a key, bound to one instance by its `open` record
  (the engine binds it to the tenant). Balances are exact u64, `0 <= balance <= max_balance`.
- Conserved quantity per instance: `sum(balances) == issued - destroyed`, where `issued` = the sum of the `open`
  balances and `mint` amounts, `destroyed` = the sum of `burn` amounts (u128). With `issuance = fixed`, `mint` and
  `burn` are refused (`ISSUANCE_DISABLED`) and only the FIRST `open` of the instance may hold nonzero balances
  (`SUPPLY_FIXED` after that): then `sum(balances)` is the constant set at that first open, for ever.
- Check order of `post`: grammar, policy, leg count, zero legs, balance of the legs (`CONSERVATION_BREACH`),
  accounts, overdraft, limit. The balance of the legs comes before the accounts on purpose: it is a fault of the
  posting itself and its repair needs no account data.
- Cross-tenant: the engine refuses another tenant's key first (`TENANT_ISOLATION_BREACH`, exit 16); the module
  re-checks the tenant (`CROSS_TENANT`) as a second line.

### 11.4 Registry (global across tenants)

- The record key is the caller's own handle `reg:<tenant>` (exactly; else `MALFORMED_REQUEST why=REGISTRY_KEY
  expected=`). The prefix `reg:` is reserved for `ledger_graph` (section 4.1). The name itself is NOT a key: the
  engine binds a key to the first tenant that touches it, so a name key would make the namespace per tenant. The
  global map (registry, canonical name) -> holder lives in the module state, which every request rebuilds under the
  exclusive lock, so the first claim wins and every later claim by any tenant (the holder too) is `DUPLICATE_KEY
  registry=`. The refusal never names the holder or echoes the name. `release` by anyone but the holder, or of a
  free name: `NOT_HOLDER registry=` (one code for both).
- Name: 1..max_name_bytes bytes, each 0x21..0x7E (printable ASCII, no space). Canonical form: `exact` = the bytes
  as given; `ascii_fold` = A-Z mapped to a-z, every other byte unchanged. Nothing else: no Unicode normalisation,
  no confusable detection, no trimming, no `\u` decoding (backslash, `u`, `0430` is six ASCII bytes, not one
  letter). A name that looks the same in another script, or in another escape form, is a DIFFERENT name here.

### 11.5 Graph guard

- A graph is one key (bound to one graph policy at its first record) and one consistency unit: every edge change
  names the key with its present state hash (CAS required), and the engine decides under the exclusive lock on the
  whole folded graph. Two edges that are each fine but close a cycle together cannot both commit: the second
  decision sees the first edge (lock), and its CAS hash is stale anyway. Cost: changes to one graph are fully
  serialised; under contention each loser gets `STALE_STATE_HASH`, re-reads (`GET`) and retries, and each try
  replays the whole WAL (O(WAL)).
- Node names: `[A-Za-z0-9_.:@+-]{1,64}`. A node exists while it has an edge. `DAG_CYCLE_DETECTED edge=<from>-><to>
  cycle_len=<k> index=<i>`: the cycle the edge would close has k edges (a self-loop is k = 1); i is the position
  in the batch.
- Search (Pearce-Kelly dynamic topological order, rebuilt by the fold at every replay): the graph keeps an order
  `ord` with ord[a] < ord[b] for every edge. A new `from` node goes before every node, a new `to` node after every
  node, so an edge with a new end, or with ord[from] < ord[to], needs no search: O(log V). Else a breadth-first
  search from `to` through nodes with ord <= ord[from] either reaches `from` (refused; the BFS depth gives the exact
  shortest cycle length) or gives the set to move; a backward search from `from` through ord >= ord[to] gives the
  other set; both sets are re-ordered into their own old slots. Explicit queues, no recursion: no stack overflow on
  a 100,000-node chain (case `chain`). Cost per edge: O((|F| + |B|) log V), at most O((V + E) log V); worst case of
  a whole replay O(E (V + E) log V), bounded by max_nodes and max_edges (an adversarial insertion order can reach
  it; chains, trees and edges added in any topological order cost O(log V) each). `decide` runs the batch on a COPY
  of the graph (O(V + E) per add_edge request); `fold` runs it in place.

### 11.6 `GET` fields

Account: `kind=account ledger= balance= ledger_total= ledger_issued= ledger_destroyed= ledger_accounts=` (the
totals are those of the caller's own instance); `reg:<tenant>`: `kind=registry claims=`; graph: `kind=graph policy=
nodes= edges=`.

## 12. Primitive 8: `taint_egress` (`taint.rs`)

A stateless egress check of ONE JSON document against field labels (section 7.4: no key, no record, no receipt;
the request id stays fresh). NATIVE CHECK, FINITE TEST (`test_taint.py`, copies `mutants_p8.py`).

### 12.1 Model

A policy declares LABELS on fields and, per DESTINATION, the labels that may leave to it. Labels: `PII`, `PHI`,
`SECRET_KEY`, `TENANT:<id>` (`<id>` = `[A-Za-z0-9_-]{1,24}`), and the policy's own words in `labels`
(`[A-Z][A-Z0-9_]{1,31}`). Labels are SETS. Destinations: `PUBLIC_HTTP`, `LLM_STDOUT`, any `[A-Z][A-Z0-9_]{1,31}`
the policy names, and `TENANT:<id>` (the policy entry `TENANT:*` holds the labels for every tenant destination).

A node gets labels from three sources, all unioned:
- (a) NAME RULES of the policy, `{"path": P, "labels": [...]}`. `P` = `$` then `(.name|[])*` (ANCHORED at the
  root: the whole logical path must match), or `name(.name|[])*` (UNANCHORED: the rule matches the END of the
  logical path, at any depth). `name` = `[A-Za-z0-9_-]{1,64}`, compared after normalization; `[]` matches any array
  index. The LOGICAL path of a node is its path of normalized key names and array indices; the `value` step of a
  label carrier and the step into JSON inside a string are NOT in it (both are transparent).
- (b) In-document CARRIERS: an object `{"$taint": [<label>...], "value": <any>}` (exactly these two members, names
  compared after normalization) labels itself with the listed labels; an object with a member whose normalized
  name is `tenantid` (`tenant_id`, `tenantId`, `TENANT-ID`, ...) and whose value is a canonical id string labels
  the object `TENANT:<id>`. A carrier with a bad shape: `MALFORMED_CARRIER`; a label word the policy does not know:
  `UNKNOWN_LABEL` (fail closed, never ignored).
- INHERITANCE: a node's labels are its own plus every ancestor's, through objects, arrays, carriers and JSON in
  strings, to any depth. A forbidden label is reported ONCE, at the topmost node that carries it.

Key normalization (name rules, carriers, `AMBIGUOUS_KEY`), on the key AFTER the parser has decoded every `\u`
escape: fullwidth ASCII U+FF01..U+FF5E becomes ASCII; U+017F (long s) becomes `s` and U+212A (Kelvin sign) becomes
`k`; `_`, `-` and every Unicode White_Space code point (space, NBSP, U+2000..U+200A, U+3000, ...) are dropped; ASCII
A-Z becomes a-z. Nothing else: no full Unicode case fold (`ß` stays), no NFC/NFKC, no homoglyph map. (Review
finding L3, 2026-11-20: before, keys with NBSP or `ſ` passed a rule for `ssn`.) Two keys of one object that are equal after
normalization: `AMBIGUOUS_KEY`. Raw duplicate keys: the strict parser refuses the document (`MALFORMED_REQUEST
why=BAD_JSON error=DUPLICATE_KEY`).

Decision for destination D: every label of every node must be allowed for D. A tenant label `TENANT:x` is allowed
for `TENANT:a` only when x == a (the policy cannot allow another tenant's label to a tenant destination;
`TENANT:*` lists no tenant label). For another destination it is allowed when the destination lists `TENANT:*` or
`TENANT:x`. Any other label is allowed when the destination lists it.

### 12.2 Modes: what ALLOW says

- `"mode": "detect"` (allow by default). An UNLABELLED field passes with any value. ALLOW says only: "no name rule
  and no carrier puts a label on this document that the destination forbids". It is a DETECTOR of labelled fields,
  NOT a guarantee that no secret leaves: a secret under a name that no rule names passes.
- `"mode": "strict"` (allow-list). Every node must be COVERED by a name rule (the rule matches the node or an
  ancestor; `"labels": []` declares a public field), except a container whose logical path is empty or is a proper
  prefix of an ANCHORED rule. An uncovered node: `UNLABELLED_FIELD`, once per uncovered subtree. A carrier adds
  labels but NEVER covers. ALLOW then says: "every key and leaf of this document sits at a place the policy
  declared, and no declared or carried label is forbidden for the destination". It still does NOT say that a VALUE
  at a declared public place holds no secret.

### 12.3 The walk

1. Strict parse (src/airlock/json.rs: duplicate keys, lone surrogates, control bytes, trailing bytes, depth > 64
   refused): else `MALFORMED_REQUEST why=BAD_JSON error=<word>`.
2. Expansion: every string VALUE that LOOKS LIKE JSON (after leading Unicode White_Space, default-ignorable code
   points and C0/C1 controls U+0000..U+001F, U+007F..U+009F it starts with `{`, `[` or `"`, or with the fullwidth
   `｛`, `［` or `＂`) is strict-parsed and takes the place of the string, recursively, to
   MAX_NESTED = 4 levels. A JSON-like string that fails the strict parse is refused (`OPAQUE_JSON error=<word>`).
   False refusals by design: `"quoted" words`, `[draft] note`. Text that does not START like JSON is plain text.
   (Review finding L3: before the repair, `\u001e{"ssn":...}` was plain text, and Python's `json.loads(v.strip())`
   recovers it; now it is `OPAQUE_JSON`, as is a fullwidth opener.)
3. Bounds over the EXPANDED document, counted before any label is checked, refused whole, never truncated: nodes >
   MAX_NODES = 16384: `TAINT_LIMIT why=TOO_MANY_NODES`; a node deeper than MAX_DEPTH = 32: `why=TOO_DEEP`; a
   JSON-like string at level 4: `why=NESTED_TOO_DEEP`. Every loop is iterative.
4. One pre-order walk in CANONICAL order (object members by raw key bytes, array items by index): the result does
   not depend on key order (case `order`).

Every object key is checked: `UNSAFE_KEY why=` `TOO_LONG` (> 256 UTF-8 bytes), `CONTROL`, `IGNORABLE`
(Default_Ignorable_Code_Point: zero-width, bidi controls, variation selectors, tags), `JSON_LIKE`, `CARRIER_NAME`
(the normalized key CONTAINS `tenantid` or `$taint` but is not equal to it; false refusals by design).

### 12.4 Wire

`DO taint_egress check <request_id> <tenant> 0 <policy> <destination> <json>`. The document is the rest of the line,
printable ASCII (non-ASCII as `\u` escapes). The engine's `<tenant>` field is not compared with the destination: the
caller names the destination.

ALLOW: `OK verdict=ALLOW policy= destination= mode=detect|strict sha256=<SHA-256 of the exact document bytes>
bytes=<length> nodes=<expanded nodes> now_ms= skew_ms=`. Refusals (no record) in this precedence; each reports the
FIRST finding of its class in canonical order and `more=<count of further findings of the same class>`:
(1) `UNKNOWN_POLICY`, `UNKNOWN_DESTINATION`, `MALFORMED_REQUEST why=TAINT_ARGS|BAD_JSON`; (2) `TAINT_LIMIT`;
(3) structure: `UNSAFE_KEY`, `OPAQUE_JSON`, `AMBIGUOUS_KEY`, `UNKNOWN_LABEL`, `MALFORMED_CARRIER`;
(4) `TAINT_EGRESS_BLOCKED json_path= label= more=`; (5) `UNLABELLED_FIELD json_path= more=` (strict mode only).

`json_path` grammar: `$` (root), then per step `.<name>` | `.~<i>` | `[<i>]` | `@`. `.<name>` is the NORMALIZED key,
shown only when it is a name of a policy rule path, `value` or `tenantid` and the key is not unsafe. Every other key
is shown as `.~<i>`: its 0-based rank among the object's keys in raw byte order. A key is never echoed (it may BE the
secret). `[<i>]` is an array index; `@` steps into the JSON parsed from the string at that place. A `label` is shown
as written, except a tenant label, shown as `TENANT` (its id is document data). No refusal carries a value, a key, a
tenant id from the document, or a digest (case `leak`).

### 12.5 Policy file

`{"primitive": "taint_egress", "version": 1, "name": "<id>", "mode": "detect"|"strict", "labels": ["<WORD>"...],
"fields": [{"path": "<P>", "labels": ["<label>"...]}...], "destinations": {"<DEST>"|"TENANT:*": ["<label>"|"TENANT:*"...]}}`.
Exact key sets. At most 256 rules, 1 to 64 destinations. Refused (`MALFORMED_POLICY`): an unknown label, a duplicate
label in one list, a duplicate rule, a bad path, a tenant label or `TENANT:*` in the `TENANT:*` list, `TENANT:*` in a
rule, a custom word equal to a fixed label or `TENANT`.

### 12.6 "0 bytes leaked" is the CALLER's property

This module only answers ALLOW or a refusal; the engine prints only that answer and never forwards the document. A
caller gets "0 bytes leaked" only if it (1) emits nothing unless the answer is `OK verdict=ALLOW`, (2) emits EXACTLY
the bytes it sent for the check (compare SHA-256 and length with `sha256=` and `bytes=`; never re-serialize: the Goal
20 review, finding 3), (3) emits to the destination it named, and (4) treats any other answer, a missing answer or an
engine fault as a refusal. Nothing in the engine enforces (1) to (4). The SDK (section 16) does (2) for the check
answer and returns the exact text sent; emitting it is still the caller's act.

### 12.7 Known limits (each row TRIED: case `evasions` of `test_taint.py` asserts the result)

| Evasion | Result |
| --- | --- |
| secret value under an unlabelled, allowed name | detect: ALLOW (passes). strict: `UNLABELLED_FIELD` unless the name is covered; under a covered public name: ALLOW (passes) |
| encodings of a VALUE: base64, hex, percent, HTML entities, `\x` | values are never read: ALLOW under an unlabelled name; blocked under a labelled name (by the name, not the content) |
| encodings of a KEY: `ss%6E`, `&#115;sn`, literal `\x73sn` | not decoded: detect ALLOW (passes); strict `UNLABELLED_FIELD`. JSON `ssn` IS decoded by the parser: blocked |
| compressed (gzip+base64) or split secret across fields | ALLOW under unlabelled names (passes) |
| numbers as carriers | a number under an unlabelled name: ALLOW (passes); under a labelled name: blocked |
| homoglyph key (Cyrillic `ѕsn`) | not folded: detect ALLOW (passes); strict `UNLABELLED_FIELD` |
| Kelvin sign in `api_Key`, long s in `ſsn`, NBSP or U+3000 in a key | folded or dropped (since review L3): blocked |
| full case fold: `ßn` (Python `casefold()` gives `ssn`), ligature `ﬀ` | not folded: detect ALLOW (passes); strict `UNLABELLED_FIELD` |
| compatibility forms (NFKC): circled letters such as `ⓢsn` | not folded: detect ALLOW (passes) |
| JSON in a string after a C0/C1 control (`\u001e{`, `\u001c{`, `\u0000{`, `\u0008{`, `\u0085{`) or with a fullwidth opener (`｛`, `［`) | `OPAQUE_JSON` (refused, since review L3) |
| JSON in a string after a printable prefix (`x{"ssn":1}`) | plain text: detect ALLOW (passes); a reader that searches for the first `{` recovers it |
| zero-width or bidi code point in a key | `UNSAFE_KEY why=IGNORABLE` (refused in every mode) |
| fullwidth key `ｓｓｎ` | folded: blocked |
| keys that differ only by Unicode normalization (NFC and NFD side by side) | no NFC: both kept, not `AMBIGUOUS_KEY`: ALLOW (passes) |
| array of pairs `[["ssn", "..."]]` | `ssn` is a value, not a key: detect ALLOW (passes); strict `UNLABELLED_FIELD` |
| very deep (> 32) or very wide (> 16,384 nodes) document | `TAINT_LIMIT` (refused, never truncated) |
| label carrier omitted by the author (a foreign record with no `tenant_id`) | detect: ALLOW (passes); only name rules apply |
| label word the policy does not know | `UNKNOWN_LABEL` (refused) |
| free text that names another tenant | text is never read: detect ALLOW (passes); strict: `UNLABELLED_FIELD` unless the name is covered |
| ASCII case, `_`, `-`, White_Space, `ſ`, Kelvin sign and fullwidth variants of a covered key | normalized to the policy name: a covert channel of a few bits per key (not refused) |

This module checks LABELS and NAMES, not the content of values. It trusts the policy author for the rules and the
document author for the carriers: an omitted carrier is not detected, and a wrong `tenant_id` written by the
document's author is believed. The translation of the MCP proxy review's nine leaking shapes (rows r1 to r9 of case
`table`) is in the header of `taint.rs`, section 8.

## 13. Primitive 9: `farkas` (`farkas.rs`)

Re-synced with the final header of `farkas.rs` (lines 1 to 37 at commit 50cf0293). The header text is reproduced
below, then the answer details that the header does not name, read from the code of the same commit. If this section
and the file differ, the file wins.

The check of a Farkas infeasibility certificate. Stateless (section 7.4: no key, no record, no receipt; the request id
stays fresh). NATIVE CHECK that MIRRORS the Dafny predicate `FarkasCert.Accepts` of
`src/primitives_v2/dafny/FarkasCert.dfy`. This Rust code is NOT proved and NOT compiled from Dafny. The tie between
the two is a FINITE differential test (`tests/primitives_v2/test_farkas.py`, case `differential`): the Dafny
predicate, compiled by the pinned Dafny's Python back end, and this check answer the same on thousands of random and
edge-case systems. Why not compiled from Dafny: the Dafny 4.11 Rust back end emits code that needs the
`dafny_runtime` crate (rustc with no crate: exit 1, E0432; see the P9 report).

What the Dafny lemma `Soundness` says (PROVED in a Dafny run, about the Dafny predicate only): if `Accepts(A, b, y)`,
then NO non-negative INTEGER vector x satisfies `A x >= b`. Not stated there: rational or real x; completeness (an
integer-infeasible system can be rational-feasible, and then no certificate exists); anything about any solver or
about `farkas.rs`. The EXIT script `scripts/exit_universal_primitives.py` (case `proofs`) re-runs `dafny verify` and
`dafny audit` on `FarkasCert.dfy` and records the actual exit codes; this document runs nothing.

Wire: `DO farkas check <request_id> <tenant> 0 <json>`. `<json>`: one strict JSON object with exactly the keys `"A"`
(array of 1..64 rows, each an array of 1..64 integers, all rows of one length n), `"b"` (array of m integers, m =
number of rows) and `"y"` (array of m integers). An integer is a JSON number `-?(0|[1-9][0-9]*)` (no fraction, no
exponent, no `-0`) in the signed 64-bit range. The system is `A x >= b, x >= 0`; y is the certificate of the claim
"no x exists". Answers, first match wins:

- `MALFORMED_REQUEST why=FARKAS_JSON|FARKAS_KEYS|FARKAS_NUMBER` (exit 12): not the format above.
- `SHAPE why=ROWS|COLS|ROW_LEN|B_LEN|Y_LEN|ENTRY_RANGE [row=] [col=]` (exit 10): sizes, shapes or an entry outside
  the signed 64-bit range (`FarkasCert.Shape` is false).
- `CERT_REJECTED claim=INFEASIBILITY_NOT_PROVED reason=Y_NEGATIVE row=<i>` (exit 10): y[i] < 0 (first i).
- `CERT_REJECTED claim=INFEASIBILITY_NOT_PROVED reason=YTA_POSITIVE col=<j>` (exit 10): (y^T A)[j] > 0 (first j).
- `CERT_REJECTED claim=INFEASIBILITY_NOT_PROVED reason=YTB_NOT_POSITIVE` (exit 10): y^T b <= 0.
- `OVERFLOW claim=INFEASIBILITY_NOT_PROVED why=ARITH [col=<j>]` (exit 10): a sum left the i128 range (checked
  arithmetic; fail closed: never a proof). The Dafny predicate has no overflow (mathematical integers), so OVERFLOW
  can stand for an input that the Dafny predicate accepts: then the check refuses a valid certificate. It never
  accepts because of an overflow.
- `OK verdict=INFEASIBILITY_PROVED scope=nonneg_integer_x rows=<m> cols=<n> system_sha256=<h> cert_sha256=<h>`
  (exit 0): every clause of Accepts holds.

Every refusal after the parse also carries `system_sha256=`. A refusal is never "feasible": the check never says that
a solution exists. Digests: `system_sha256` = SHA-256 of the canonical text `{"A":[[a11,...],...],"b":[b1,...]}` (no
spaces, canonical decimals); `cert_sha256` = SHA-256 of `{"y":[y1,...]}`. They bind the verdict to the exact system
and certificate. Policy files: none (`init` refuses a farkas policy: `MALFORMED_POLICY NO_POLICY`). Records: none
(`fold` refuses any record of this primitive).

Read from the code (not named in the header):

- `system_sha256=` comes only with `CERT_REJECTED`, `OVERFLOW` and `OK` ("after the parse" above means after the
  parse AND the shape check). `MALFORMED_REQUEST` and `SHAPE` carry no digest.
- `SHAPE why=ENTRY_RANGE` also carries `in=A|b|y`: for `in=A`, `row=` and `col=` name the entry; for `in=b` and
  `in=y`, `row=` is the index.
- `MALFORMED_REQUEST why=FARKAS_OP`: the module's own refusal of an op other than `check` or of a request with keys.
  The engine refuses both earlier (`UNKNOWN_OP`, `KEY_COUNT`: the op table is `check` with 0 keys), so this is a
  second line behind the engine.

## 14. Refusal codes: one index

Every code once; its exit (section 6) and its repair fields. Engine bookkeeping fields (`now_ms`, `skew_ms`; and on
a durable refusal `request_id`, `seq`, `hash.<key>`) are not repeated. A code that two primitives use has ONE meaning.

| Code | Exit | From | Repair fields |
| --- | --- | --- | --- |
| `USAGE` | 2 | CLI | `why=` (`NOT_AFTER_MS`, `MS`, ...) |
| `MALFORMED_REQUEST` | 12 | engine, every module | `why=`: engine `NON_ASCII`, `SPACING`, `FIELDS`, `OVERSIZED max_line=`, `NO_LINE_END`, `UNKNOWN_VERB`, `UNKNOWN_PRIMITIVE`, `UNKNOWN_OP`, `BAD_REQUEST_ID`, `BAD_TENANT`, `KEY_COUNT`, `BAD_KEY`, `RESERVED_KEY key_index= prefix= owner=` (section 4.1), `DUPLICATE_KEY` (a key named twice), `KEY_ORDER`, `BAD_HASH`, `CAS_REQUIRED`, `KEY_KIND key_index=`; rate `RATE_ARGS`; ledger_graph `LG_ARGS`, `LEG_KEYS`, `LEG_COUNT`, `RESERVED_KEY` (no fields: a `reg:` key as account or graph), `REGISTRY_KEY expected=`, `NAME [max_name_bytes=]`, `NODE`; taint `TAINT_ARGS`, `BAD_JSON error=`; farkas `FARKAS_JSON`, `FARKAS_KEYS`, `FARKAS_NUMBER`, `FARKAS_OP` (behind the engine) |
| `STALE_STATE_HASH` | 13 | engine | `stale=<count>`, `hash.<key>=<present hash>` per stale key |
| `DUPLICATE_REQUEST_ID` | 14 | engine | none: use a new id |
| `TENANT_ISOLATION_BREACH` | 16 | engine | `why=KEY_OF_ANOTHER_TENANT`, `key_index=` (a `DO`; never the key; `GET` gives no index) |
| `CORRUPT_WAL` | 17 | store | `why=` (`HEADER`, `CRC`, `CHAIN`, `MODULE`, ...), `record=` (fault: no repair) |
| `IO_ERROR` | 18 | store | `why=` (fault; nothing committed) |
| `OUTCOME_UNKNOWN` | 19 | store | `why=` (fault; a record may stay) |
| `MALFORMED_POLICY` | 25 | init | `why=` (the first fault of the file) |
| `STORE_BUSY` | 26 | store | `retry_after_ms=1000` |
| `NOT_IMPLEMENTED` | 27 | cosign stub | `why=COSIGN_SIGNATURE` (unreachable in this build) |
| `UNSAFE_STORE` | 28 | store | `why=` (fault) |
| `MODULE_FAULT` | 29 | engine | `why=BAD_REFUSAL`, `BAD_ANSWER`, `WRITE_WITHOUT_KEY`, `BAD_PAYLOAD`, `RECORD_NOT_FOLDABLE`, `RECORD_TOO_LONG`, `SEQ_OVERFLOW` |
| `RATE_LIMIT_EXCEEDED` | 10 | rate_window | `retry_after_ms=<n or never>` (the least wait to commit, the cooldown this refusal starts included); durable when `cooldown_after > 0` |
| `COOLDOWN_ACTIVE` | 10 | rate_window | `retry_after_ms=` |
| `VOLUME_ABOVE_CAP` | 10 | rate_window | `max_volume_per_window=` |
| `UNKNOWN_POLICY` | 10 | rate_window, ledger_graph, taint_egress | none |
| `POLICY_MISMATCH` | 10 | rate_window, ledger_graph (graph) | `policy=` (the bound policy) |
| `COSIGN_EXPIRED` | 10 | cosign-ttl | `expired_by_ms=` |
| `COSIGN_TTL_TOO_LONG` | 10 | cosign-ttl | `max_ttl_ms=` |
| `WRONG_POLICY_KIND` | 10 | ledger_graph | `policy_kind=` (`not_ledger`, `not_registry`, `not_graph`) |
| `ACCOUNT_EXISTS` | 10 | ledger_graph | `key=` |
| `SUPPLY_FIXED` | 10 | ledger_graph | none: open with balance 0 |
| `ISSUANCE_DISABLED` | 10 | ledger_graph | none |
| `UNKNOWN_ACCOUNT` | 10 | ledger_graph | `key=` |
| `WRONG_KEY_KIND` | 10 | ledger_graph | `key=`, `kind=` |
| `CROSS_LEDGER` | 10 | ledger_graph | `key=`, `ledger=` |
| `CROSS_TENANT` | 10 | ledger_graph | `key=` (second line behind the engine) |
| `ZERO_AMOUNT` | 10 | ledger_graph | `index=` |
| `SELF_TRANSFER` | 10 | ledger_graph | none |
| `INSUFFICIENT_FUNDS` | 10 | ledger_graph | `key=`, `balance=`, `needed=` |
| `BALANCE_LIMIT` | 10 | ledger_graph | `key=`, `max_balance=` |
| `TOO_MANY_LEGS` | 10 | ledger_graph | `max_legs=` |
| `CONSERVATION_BREACH` | 10 | ledger_graph | `debit_total=`, `credit_total=` |
| `DUPLICATE_KEY` | 10 | ledger_graph (registry) | `registry=` (never the holder, never the name) |
| `NOT_HOLDER` | 10 | ledger_graph (registry) | `registry=` |
| `DAG_CYCLE_DETECTED` | 10 | ledger_graph (graph) | `edge=<from>-><to>`, `cycle_len=`, `index=` |
| `EDGE_EXISTS` | 10 | ledger_graph (graph) | `edge=`, `index=` |
| `GRAPH_FULL` | 10 | ledger_graph (graph) | `limit=max_nodes|max_edges`, `max=` |
| `NO_SUCH_EDGE` | 10 | ledger_graph (graph) | `edge=` |
| `UNKNOWN_DESTINATION` | 10 | taint_egress | none |
| `TAINT_LIMIT` | 10 | taint_egress | `why=TOO_MANY_NODES|TOO_DEEP|NESTED_TOO_DEEP`, `max=` |
| `UNSAFE_KEY` | 10 | taint_egress | `json_path=`, `why=`, `more=` |
| `OPAQUE_JSON` | 10 | taint_egress | `json_path=`, `error=`, `more=` |
| `AMBIGUOUS_KEY` | 10 | taint_egress | `json_path=`, `more=` |
| `UNKNOWN_LABEL` | 10 | taint_egress | `json_path=`, `more=` |
| `MALFORMED_CARRIER` | 10 | taint_egress | `json_path=`, `why=SHAPE|LABELS_NOT_ARRAY|LABEL_NOT_STRING|TENANT_ID`, `more=` |
| `TAINT_EGRESS_BLOCKED` | 10 | taint_egress | `json_path=`, `label=`, `more=` |
| `UNLABELLED_FIELD` | 10 | taint_egress (strict) | `json_path=`, `more=` |
| `SHAPE` | 10 | farkas | `why=`, `[in=]`, `[row=]`, `[col=]` (no digest) |
| `CERT_REJECTED` | 10 | farkas | `claim=INFEASIBILITY_NOT_PROVED`, `reason=`, `[row=|col=]`, `system_sha256=` |
| `OVERFLOW` | 10 | farkas | `claim=INFEASIBILITY_NOT_PROVED`, `why=ARITH`, `[col=]`, `system_sha256=` |

Note: `DUPLICATE_KEY` as a CODE (exit 10) is the registry's "name taken"; `MALFORMED_REQUEST why=DUPLICATE_KEY` (exit
12) is the engine's "a key named twice in one request"; `MALFORMED_REQUEST why=BAD_JSON error=DUPLICATE_KEY` is the
JSON parser's duplicate member. Three different faults; a client must read the code first.

## 15. Trust boundary, trusted assumptions, not claimed

- Every rule holds only for a caller that reaches the store through the production binary. A process that can
  write the store folder can write a new valid chain (CRC and SHA-256 authenticate nothing) and can delete or roll
  back the WAL. A process that can start another build (the test-seams build, or a changed copy) can ignore every
  check. Keep the agent out of the store folder (for example `serve` under another OS user that owns it).
- Trusted: the kernel, the file system and the drive for `F_FULLFSYNC`; `flock`; `/dev/urandom`; the host clock;
  the engine binary; whoever can write the store folder. The `<tenant>` field of a request is NOT authenticated:
  any caller of `serve` can name any tenant. The caller also picks every key name. So rate_window limits a key; the
  key and tenant must be bound by a trusted wrapper outside the engine: a fresh key or another tenant name gets
  around every window and cooldown (review finding M2; case `rate_key_limit`, a KNOWN LIMIT, not a protection).
- Not claimed: no proof of anything in the engine or the modules. A SIGKILL is not a power loss. A WAL restored to
  an older copy is not detected (no epoch ratchet in this engine). A truncation of a whole committed last record
  looks like a torn record and is cut (only a writer of the folder can do it). The parent folders of the store are
  not checked.
- Leaks by design: `GET` of another tenant's key answers `TENANT_ISOLATION_BREACH` (it shows that the key exists);
  `STATE` shows the store's record count and tail hash to every caller of `serve`; a registry `DUPLICATE_KEY` shows
  that a name is taken (not by whom). Any tenant can bind an unused key name first, except a name under a prefix
  reserved by another primitive (section 4.1). Engine refusals name a key by `key_index` only (section 4); a
  `STALE_STATE_HASH` field name, a `GET` answer and the ledger_graph module refusals do name the caller's own key.
- Limits: every request replays the whole WAL (O(WAL)); a `serve` waits at most 60 s for the lock. `state`, `get`,
  `replay` need write access.

## 16. SDK (`sdk/py/forge_primitives.py`)

Python stdlib only; not trusted for a write decision; FINITE TEST (`test_sdk_primitives.py`). One long-lived
`primitives-engine serve <dir>` per client. One method per op: `acquire` (6); `open_accounts`, `transfer`, `post`,
`mint`, `burn`, `claim`, `release`, `add_edges`, `remove_edge` (7); `taint_check` (8); `farkas_check` (9); and
`get`, `state`, `read_hashes`. Results: `Committed`, `Verdict` (`OK verdict=`), `Refusal` (`.code`, `.repair` = the
decoded fields without the engine's bookkeeping, `.detail`, `.durable`, `.hashes`), `KeyState`. Raised, never
returned: `LocalRefusal` (nothing sent), `EngineFault` (sections 6 and 14 faults, and `MODULE_FAULT`),
`ProtocolError` (an answer that breaks the grammar or does not match the request: another request id, missing or
extra key hashes, a missing or non-decimal `seq`/`now_ms`/`skew_ms`, OK for a keyed op, a digest that is not the
digest of the bytes sent, an OK word other than `ALLOW` for `taint_check` or `INFEASIBILITY_PROVED` for
`farkas_check`), `EngineDead`, `EngineTimeout`. Every ProtocolError closes the client (review findings L1 and L2,
2026-11-20: before, a bad decimal field raised without closing, and any OK word was returned as a Verdict; case
`fake_answers`, copies `mutants_sdk.py`). The SDK reads state hashes only when the caller passes `pre='read'` (one `GET` per key, not atomic
with the write) and never retries: a CAS conflict is returned as `STALE_STATE_HASH` with the present hashes. Not
built: a TypeScript wrapper.

## 17. Tests and controls

- `tests/primitives_v2/test_engine.py <engine> <seams-engine> [--case N]... [--big-gib G]` (23 cases; `cooldown_retry`
  covers review finding M1, `rate_key_limit` pins the KNOWN LIMIT of finding M2; a case that
  cannot run FAILS with NOT RUN). Case `unknown` replaced the old case `stubs` (primitive 9 is no longer a stub);
  case `reserved` covers section 4.1. `tests/primitives_v2/mutants.py`: 30 changed copies, each with one exact-once
  text replacement, both builds, one case that must FAIL with a named text; the unchanged copy first passes every
  named case. The sync copy `S1` is seen only through the read-only test interposer `tests/airlock/interpose.c`
  (case `trace`); no test sees a power loss.
- Per primitive: `test_ledger_graph.py` with `mutants_p7.py` (7), `test_taint.py` with `mutants_p8.py` (8),
  `test_farkas.py`, `test_policy_to_dfy.py` with `mutants_p9.py` (9). SDK: `test_sdk_primitives.py <engine>` with
  `mutants_sdk.py` (changed copies of the SDK; the suite runs from a mirror tree that holds the copy).

## 18. Departures from the directive and open points

1. The cosign signature check is a stub (section 10); only the TTL rule is implemented and tested.
2. Lock per exchange, not per process (section 3).
3. A durable refusal record uses up its request id (a retry needs a new id).
4. A request that can never fit (`VOLUME_ABOVE_CAP`) writes nothing and does not count toward the cooldown.
5. No epoch ratchet: a restored older WAL is not detected (the Goal 20 engine has one).
6. Stateless checks write no receipt (section 7.4); if the owner wants an audit trail, it needs a separate bounded
   log, not the WAL.
7. The reserved-prefix table is engine-side, not a trait constant (section 4.1): `ledger_graph.rs` was not this
   change's file. Its replay fault word is `MODULE` (store.rs maps every fold error to it), not `RESERVED_KEY`.
8. `taint_egress` checks labels and names, not values (section 12.7). A `farkas` verdict covers only non-negative
   INTEGER x, and the Rust check is tied to the Dafny predicate only by a finite differential test (section 13).
9. No `source_proof` core runs in the engine. The directive asked the policy compiler to upgrade custom policies
   "from NATIVE CHECK to real Dafny source_proof cores"; this pack does not: every verdict of the engine is Rust
   (NATIVE CHECK). The Dafny files (FarkasCert.dfy and the four generated models) are verified MODELS.
10. The tie between the Dafny models and the Rust engines (src/airlock for money, src/primitives_v2 for rate_window,
   transfer and farkas) is a FINITE differential test: vectors computed by the Dafny-compiled Python and replayed
   against the engines. It is not a proof that the engines implement the models.
11. The TypeScript wrapper of this SDK is not built (only `sdk/py/forge_primitives.py`).
12. The cosign signature check is a stub (item 1, section 10) until the native cosign branch is merged.
13. Mistake 4 of the demo: the schedule that the agent finds is checked by a Python DEMO CHECK
   (`examples/universal_self_repair`), not by the engine. The engine has no feasibility check.
14. rate_window limits a key, not a caller (section 9, review finding M2): binding key and tenant to an
   authenticated caller is left to a wrapper outside the engine.
