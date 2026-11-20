# Engine hardening after the review of 2026-11-20 (D2, D3, D6, D7)

Status: NOT merged, NOT pushed. `end_to_end=false`. M1-B is OPEN. Nothing here is a proof:
every result is a finite test of unproved Rust, JavaScript and Python on one machine.

Stacking. This branch (`feat/airlock-review-hardening`) is stacked on `apex1/native-cosign`
at `a96c916f` (pull request 72, base `main`; NOT merged). The code commits were made on
`e33223032e525ba878fc35a0f7585ea8d98d9be2` (Goal 21, phase 1: the native cosign check);
`a96c916f` is `e3322303` plus one records-only merge of `main` `33055a59`, and this branch
merged it (`5685b673`, records only: `git diff 8fc0de2f 5685b673 -- src sdk bin tests
scripts docs examples` is empty). Every "before" run below used the engine built from
`e3322303` with unchanged sources. If that branch moves again, this branch needs another
merge or a rebase.

The one fresh-context review of this branch and its repairs: [REVIEW.md](REVIEW.md).

Source: the independent review `REVIEW.md` of `origin/main` `33055a59` (session scratch
folder; not in the tree). Its line numbers are for `33055a59`; the lines below are for
`e3322303`. Each finding was checked against the code before a change. No finding was
rejected. One part of a suggested fix was rejected (D2: exec through `/dev/fd`).

Logs: [logs/](logs/). Each "before" log is the new test on the `e3322303` engine; each
"after" log is the same test on the commit of the fix. Uncertainty entries: `unsure.md`
U887 to U892.

## D3: per-tenant namespaces (keys, request ids, leases)

Finding as verified at `e3322303`. One global map for keys, one global set of used request
ids, one global map of leases: `ledger.rs:52-54` (fields), `:67-73` (`fresh`, `can_open`:
`!self.keys.contains_key(key)`), `:83-86` (`key_mut`), `:176-187` (`LEASE`, `CLOSE`);
`verbs.rs:68-74` (`check_key`), `:77-88` (`check_open`: `KEY_OF_ANOTHER_TENANT`),
`:266-276` (`open_lease`), `:279-282` (`get`). Confirmed by a run: tenant B opened
`order-1`, then tenant A's `OPEN_MONEY tA order-1 ...` got `TENANT_ISOLATION_BREACH
KEY_OF_ANOTHER_TENANT`; all 11 lines of a tenant-B script answered differently on a store
where tenant A was busy ([before](logs/d3-tenant_namespace-before.log),
[probe](logs/d3-probe-before-after.log)).

Change. The fold indexes keys, used request ids and leases by (tenant, name). A key of
another tenant is `UNKNOWN_KEY`, exactly like a key that nobody opened. The `CLOSE` record
names its tenant (`CLOSE <request_id> <tenant> REJECTED_POLICY <detail>`).
`TENANT_ISOLATION_BREACH` stays only where it is true: the read airlock (a row set that
holds a row of another tenant); `main.rs` notes it at the code. The SDKs no longer type
`TENANT_ISOLATION_BREACH` for a write, `GET` or a lease (that answer cannot come any more;
an unknown answer is a `ProtocolError`, fail closed). The fuzz pass checks `UNKNOWN_KEY`
across tenants and opens a lease of the other tenant with an id that the first tenant used.
The Python policy model and diff-policy model only the money rules: no change.

Checked answers (case `tenant_namespace` part 2 runs one tenant-B script on a busy and on a
quiet store and compares the answers up to epochs and state hashes): every verb with a
tenant (`OPEN_MONEY`, `REFUND`, `OPEN_SAGA`, `SAGA`, `OPEN_INVENTORY`, `BOOK`, `OPEN_LEASE`,
`GET`), `leases` and sweep lines, the `CLOSE` and the commit that close a lease. `READ`
reads no store state. Store-wide values stay store-wide and are NOT per tenant: the epoch in
`COMMITTED` and `LEASE_OPENED`, the state hash (it chains the whole store), the `STATE` verb
(epoch, tail hash, counts of the whole store), and the time a request waits for the lock.
They show that other records were written and how many. Worse (fresh review, finding 2): the
unkeyed FNV chain lets a tenant CONFIRM A GUESS of another tenant's record offline, from the
`STATE` tail or from two of its own `COMMITTED` answers ([log](logs/f2-oracle.log)); `STATE`
is not changed because that would not close it. A keyed chain belongs to the isolation
design. The
subcommands `state`, `replay`, `leases`, `cosign-message` are operator views of the whole
store. Saga processor idempotency keys were never unique across keys; two tenants can hold
the same pair; a real processor that de-duplicates across one merchant account could merge
them (stated in PROTOCOL.md section 5).

How the tenant is authenticated: it is NOT. The tenant is a field of the request line. In
the shipped flow the engine is a child process of the caller, under the caller's OS user
(`bin/forge-airlock serve`, both SDKs). The namespaces stop accidents, squatting and probes
between callers that something OUTSIDE the engine holds to their tenant label. A caller
that can name any tenant acts as that tenant; a caller that can read the WAL file reads every
tenant. Real per-tenant authentication needs an isolation mode (a service user, a socket,
per-tenant credentials): a separate design PR. No isolation is claimed.

WAL compatibility. No genesis version change. A WAL written by `e3322303` folds to the same
keys, ids, effects and leases (`compat_wal.py`, [log](logs/d3-compat_wal.log); case
`legacy_wal`). The old `CLOSE <request_id> <verdict> <detail>` (no tenant) is still read, but
only while exactly one lease in the whole store has that id; that engine allowed one lease
per id per store, so its WALs always meet the rule; otherwise `CORRUPT_WAL`. The fold stays
deterministic (every map lookup is by key; the lease list is sorted by epoch). The
`e3322303` engine answers `CORRUPT_WAL` for each record that only this engine writes (a
`CLOSE` with a tenant, a key name or id in a second tenant, `COSIGN_PENDING`): a mixed
deployment fails closed, it never folds to another state.

Tests: `tenant_namespace` and `legacy_wal` (new); changed on purpose: engine cases
`tenant` (cross-tenant writes and `GET` are `UNKNOWN_KEY`; an open of the same key name
makes the other tenant's own key), `leases` (one line: the cross-tenant lease opens; the
`CLOSE` records name `t1`), `lease_binding` (a verdict on another key of the same tenant:
since D3 only that form can reach a lease); SDK cases `py_typed`, `ts_typed` (another tenant
is `UNKNOWN_KEY`), `py_lease_bound` (another tenant's lease with the same id is its own).
Before/after: [before](logs/d3-tenant_namespace-before.log) exit 1;
[after](logs/d3-tenant_namespace-after.log) exit 0.

Not closed: authentication (above); the store-wide side channel (above); the WAL is one file
for all tenants.

## D6: `REQUIRE_HUMAN_COSIGN` closed a lease whose action was still pending

Finding as verified at `e3322303`: `verbs.rs:93-103` writes `CLOSE <id> REQUIRE_HUMAN_COSIGN
<detail>` for a bound lease, `ledger.rs:183-187` accepts it, and the refusal leaves the id
fresh (PROTOCOL.md section 5). Confirmed by a run: the first cosign verdict answered
`LEASE_CLOSED 3` ([before](logs/d6-lease_cosign_pending-before.log), exit 1).

Change. A cosign verdict does not close a lease. The first one on a bound lease writes one
durable `COSIGN_PENDING <request_id> <tenant> <detail>` record and answers
`... LEASE_PENDING <epoch>`; a later one (also `COSIGN_INVALID`) writes no record and names
the same epoch (no record loop). A PENDING_COSIGN lease is open: `leases` shows it with its
state; the sweep lists it as `PENDING_COSIGN <id> <deadline> <tenant> <key> <detail>` before
its deadline (exit 0) and as `DROPPED_OBLIGATION` after it (exit 24); the signed commit or a
`REJECTED_POLICY` closes it. The new `CLOSE` form takes only `REJECTED_POLICY`. Both SDKs
parse `LEASE_PENDING` (`lease_pending` / `leasePending`) and the sweep's `PENDING_COSIGN`
lines (`pending`); a sweep line of another form is a `ProtocolError`.

Old records. A `CLOSE <id> REQUIRE_HUMAN_COSIGN <detail>` in an existing WAL is read as
`COSIGN_PENDING`: the action of that lease was pending when the old engine closed it. So the
sweep now reports such old work after its deadline. If the old engine later rejected that
request, it wrote no record (the lease was closed for it): the sweep then reports a dropped
lease that was in fact rejected. That is a false alarm, never a hidden drop. Measured with
`compat_wal.py`: `state`, `leases --all` and the sweep differ from the old engine exactly by
this rule; `replay` and `get` are equal ([log](logs/d6-compat_wal.log)).

Tests: `lease_cosign_pending` (new); changed on purpose: `leases` (the cosign verdict leaves
L7 pending: `LEASES 3`), `legacy_wal` (an old cosign close is pending, later closed by a
commit), SDK `py_lease` and `ts_lease` (a cosign handler leaves the lease pending; the sweep
lists it). Before/after: [before](logs/d6-lease_cosign_pending-before.log) exit 1;
[after](logs/d6-lease_cosign_pending-after.log) exit 0.

After the fresh review (finding 3): any `REJECTED_POLICY` on the lease's tenant, key and id
still closes a PENDING_COSIGN lease (also one caused on purpose), but the sweep keeps it
visible as `REJECTED_AFTER_PENDING` (case `lease_pending_rejected`).

Not closed: the engine still sees only handlers that opened a lease. A cosign without a
lease is not tracked.

## D7 (first bullet): a full-length ratchet entry with a bad CRC was skipped silently

Finding as verified at `e3322303`: `store.rs:145-158` takes the floor from the entries with
a good CRC and skips the others. Confirmed by a run: one bit flipped in the newest entry (3)
and the WAL of epoch 2 restored: the old engine answered `STATE 2` (the rollback passed
`EPOCH_REGRESSION`) ([before](logs/d7-ratchet_entry-before.log), exit 1).

Crash states, from the write order (`Store::append`: WAL record, `sync_all`, ratchet entry,
`sync_all`; the recovery in `store::open`). The owner's unverified idea was: a bad last entry
with WAL epoch = previous good entry cannot come from a crash, but WAL epoch = previous
good + 1 can. Result: half right. In the `e3322303` order the recovery after a torn WAL
record pushed the SAME epoch again (`store.rs:161-167` pushes whenever it repairs). A power
loss during that push leaves a bad last entry with WAL epoch = previous good entry. So that
shape CAN come from a crash in the old order. This change removes the duplicate push: a
recovery pushes an entry only when the ratchet is below the WAL epoch (a torn ratchet tail is
cut and synced without a push). Then the only entry that a crash can damage is the last one,
and it was meant to hold the WAL epoch = last good entry + 1.

Choice (matches the recovery design: only a crash artifact is repaired; any other damage
fails closed, as for a whole bad WAL record):

- exactly one bad entry, the last one, no torn bytes after it, WAL epoch = floor + 1:
  repaired (the entry is cut, the WAL epoch is pushed again; the floor does not go down);
- every other full-length bad entry (in the middle; or last with WAL epoch = floor):
  `CORRUPT_WAL RATCHET_ENTRY_BAD entry <i> of <n>`. The engine cannot tell bit rot from an
  edit; an operator decides. A torn (short) last entry is cut as before.

Assumptions: a power loss damages at most the entry being written; `F_FULLFSYNC` works. Cost:
a store of the old engine can hold a bad middle entry (the old engine skipped a bad last
entry and pushed after it) or a bad duplicate last entry; it now answers `CORRUPT_WAL` until
repaired. No such store is known. Power loss is NOT tested (a SIGKILL keeps the page cache).

Tests: `ratchet_entry` (new: the review's attack; two middle entries; three crash-shaped
last entries; torn entries; no duplicate push; a missing last entry is pushed); changed on
purpose: `trace` (the recovery order of a torn record no longer writes a ratchet entry; a
new traced recovery where the entry is missing). Before/after:
[before](logs/d7-ratchet_entry-before.log) exit 1; [after](logs/d7-ratchet_entry-after.log)
exit 0.

Open (out of scope, review D7 second bullet): a full-length last WAL record with a bad CRC
(for example zero fill after a power loss) is `CORRUPT_WAL` with no repair tool.
`src/silicon_sink/sink.rs` (Goal 19, pinned by its bundle) still skips a bad ratchet entry;
not changed here.

## D2: the pin window of the helper files

Finding as verified at `e3322303`: `helpers.rs:94-104` hashes each pinned file once per
process (`OnceLock`), and `:110-116` and `:130-137` later run the same PATH; `cosign.rs:191-196`
checks `/usr/bin/ssh-keygen` once per process; `booking_check.cjs:166-169` lets the model find
`bignumber.js` from `node_modules` folders above the caller-chosen `--checker` model;
`bin/forge-airlock:94-124` takes Node from `--node`, `$FORGE_AIRLOCK_NODE` or `PATH`.
Confirmed by runs on the `e3322303` engine: in one `serve` process, a refund binary changed
in place after its first use was run (`REJECTED_POLICY CAKEML_REJECTED` from the stand-in);
a Node binary replaced after its first use was run (`CHECKER_REJECTED` from the stand-in);
files in a 0777 folder committed; a changed `bignumber.js` beside a model copy gave
`ACCEPT`; the Homebrew Node committed ([before](logs/d2-pin_window-before.log),
[scenarios](logs/d2-scenarios.log)).

Exec of the opened file: tested, not possible here. macOS has no `fexecve`; exec of
`/dev/fd/N` gave `EACCES` for a Mach-O copy of `/bin/echo`, the Node binary, the refund
binary and a shell script ([log](logs/d2-fdexec.log)). The review's suggestion to exec
through `/dev/fd` is rejected for this platform.

Change (refuse writable pins, check at every run):

1. The given path is resolved once (`canonicalize`); the RESOLVED path is checked and run.
2. `cosign::binary_checks` is generalised to `path_checks(path, Owners)`. For ssh-keygen
   (`Owners::Root`) the checks are unchanged (uid 0 only, no sticky exception) and now run
   before every verification instead of once per process. For the refund binary and Node
   (`Owners::RootOrUid(engine uid)`): every part from `/` is not a link, is owned by root or
   by the engine's own uid, and has no group or other write bit; a root-owned sticky folder
   (`/private/tmp`) is allowed (no other user can rename or remove an entry it does not own
   there). The engine uid is the owner of a private folder that the engine creates in the
   store folder (std has no `geteuid`, and `unsafe` is forbidden); uid 99 is never trusted.
3. Cost, measured with the engine's own `sha256` (load average 37 to 116, so wall time is
   not valid): Node 24.3.0 (89,025,440 bytes) took 0.49 to 0.50 s user CPU per hash; the
   refund binary (238,776 bytes) 0.00 to 0.01 s wall. So the refund binary is hashed at
   every run; Node is hashed at its first run and whenever its identity (device, inode,
   size, mtime and ctime with nanoseconds) differs; its identity is read at every run. The
   walk itself is one `lstat` per path part; not measured separately.
4. `booking_check.cjs` pins `bignumber.js` 9.3.1 (SHA-256 `08ff132b…f0ce`): found the usual
   way, read once with `O_NOFOLLOW`, checked, the same bytes compiled; the model's
   `require` returns only that module.
5. The Homebrew Node lies under `/opt/homebrew/Cellar` (mode 0775, group `admin`): the engine
   now refuses it (`HELPER_FAILED PIN_PATH_UNTRUSTED Node binary WRITABLE /opt/homebrew/Cellar
   mode 775`). `bin/forge-airlock` passes a private copy
   (`build/airlock/node-private/node-<16 hex>`, folder 0700, file 0500, same bytes, same pin).
   The engine suite copies Node into its work folder. Test seams stay only in the
   `--cfg kill_points` build.

What this closes, exactly. With a separate service user that owns the store, the engine
build and the helper files, the agent's user can no longer change a pinned FILE after its
check, and a later swap is seen at the next run. The libraries that a helper loads are NOT
covered (fresh review, finding 1): the Homebrew Node loads 9 libraries from
`/opt/homebrew/opt` (mode 775, group `admin`), and the private copy loads the same paths, so
any admin-group user can still run code inside the booking checker. OPEN, owner decision (a
Node that links only system libraries, or no inventory store where the pin must hold). The
refund binary loads only `/usr/lib/libSystem.B.dylib`. macOS ACLs are not read (finding 4). In the one-user flow (the shipped flow) the
engine's uid IS the caller's uid: the walk accepts files of that uid, so it closes nothing
against that caller. Files are still run by path: root or the engine's uid can change one
between the check and the exec.

Tests: `pin_window` (new: in-place change of the refund binary and rename of Node between
two requests of one process; 0777 and 0775 folders; a changed `bignumber.js` beside a model
copy; a link to a good Node copy); the engine suite uses a private Node copy. Before/after:
[before](logs/d2-pin_window-before.log) exit 1; [after](logs/d2-pin_window-after.log) exit 0.
Not tested: the per-run check of ssh-keygen (a root-owned stand-in needs sudo); a change
between the check and the exec (a race).

## Results

Single test files, one at a time, outside the heavy lock, on the repair commit after the
fresh review (production engine and kill-points build of this tree; load average above 100):

| Check | Actual exit | Result |
| --- | --- | --- |
| `bin/forge-airlock build` | 0 | both rustc builds, refund binary copy |
| `tests/airlock/test_engine.py` (all cases, race included) | 0 | 33 of 33 PASS |
| `tests/airlock/test_node_helpers.py` | 0 | 68 of 68 PASS |
| `tests/airlock/test_cosign.py` | 0 | 56 of 56 PASS |
| `tests/airlock/test_diff_policy.py` | 0 | all cases PASS (it starts Dafny for case `choice`) |
| `tests/airlock/test_sdk.py` | 0 | 21 of 21 PASS |
| `compat_wal.py` (`e3322303` engine vs this tree) | 0 | PASS ([log](logs/compat_wal-final.log)) |
| new cases on the `e3322303` engine (before) | 1 each | `tenant_namespace`, `lease_cosign_pending`, `ratchet_entry`, `pin_window` |
| `lease_pending_rejected` on the `aaaca9e6` engine (before) | 1 | finding 3 of the fresh review |

Heavy runs (fuzz, the changed copies, the scratch-clone regression with the Goal 20
`evidence` case) ran under the heavy lock on the commit named in the ROADMAP section; their
results are in the ROADMAP section and in `unsure.md` U893.

## Evidence bundle digest

- OLD: `1e75ab471b5fe3cede67f2746fa8c0542fbafff6959bd5a8199cfca3338a70fa`, the tracked record
  `proposals/forge2-goal20-sdk/records/evidence.json` on `main` (`33055a59`) and in
  `proposals/forge2-goal20-sdk/REPORT.md`. It describes the Goal 20 tree before Goal 21.
- `e3322303`: NO digest. The native-cosign branch did not run the evidence case (owner
  decision, U752).
- NEW: see the ROADMAP section and `unsure.md` U893 (the `evidence` case inside the
  scratch-clone regression of the final code commit).
  The tracked bundle and the tracked digest are NOT replaced; the owner decides.

## Deferred, open, not handled

- D4 (deferred): every request folds the whole WAL under the one store lock. A small, safe
  change does not exist: a snapshot or an incremental fold changes the recovery and
  ratchet design that this PR just tightened, and it needs its own crash tests and review.
  A cache in a long `serve` process would have to prove that no other process wrote since
  (the lock is per request, and many `serve` processes may share a store), which is the
  same recovery problem. Not started here.
- D7 second bullet (open): a full-length last WAL record with a bad CRC is `CORRUPT_WAL`
  with no repair tool.
- D8 (not handled): hand-written primitives (SHA-256, JSON, CRC-32, FNV) and the SDK
  bigint difference.
- D1 and D5 belong to other PRs of this round.

## Weak points for a fresh reviewer

1. Node's libraries (fresh review, finding 1) are outside every check: OPEN.
2. The engine uid comes from a probe folder in the store folder (std has no `geteuid`);
   uid 99 is refused. Attack the case of a store folder owned by another user.
3. The sticky-folder exception (root-owned, sticky, other-writable folders on a helper
   path are allowed; never for ssh-keygen).
4. `canonicalize`, then the walk, then the exec by path: a window for root or the engine
   uid; and the Node identity cache (device, inode, size, mtime, ctime).
5. The old `CLOSE` form (unique-id rule) and a mixed deployment of the old and new engine.
6. An old cosign `CLOSE` read as pending: false dropped reports.
7. The guess oracle of the unkeyed chain and the store-wide `STATE`, epoch and lock timing.
8. The ratchet rule rests on "a power loss damages at most the entry being written";
   power loss is not tested; old stores with a bad middle entry now fail closed.
9. `booking_check.cjs` still resolves `bignumber.js` through `node_modules` from the
   caller-chosen folder (content pinned); the model's `require` override.
10. `REJECTED_AFTER_PENDING` does not change the sweep exit code.
11. In the one-user flow D2 closes nothing; the tenant is not authenticated (D3).
