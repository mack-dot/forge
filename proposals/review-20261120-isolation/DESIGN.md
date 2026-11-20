# Isolation mode for the airlock engine: a design, NOT a build

Status: 2026-11-20. Design only. NOT started. Documents only. No code, no script, no setup file.
`end_to_end=false`. Nothing here is a proof. M1-B stays OPEN. Entries U894 to U896 of `unsure.md`.
Base: `origin/main` = `33055a59`. Every line number below is on `33055a59` unless a branch is named.

This answers defect D1 and recommendation 1 of the independent review of 2026-11-20 (the review file
is not in the repository). D2 and D3 are context. The parallel engine pull request (branch
`feat/airlock-review-hardening`, stacked on `apex1/native-cosign` at `e3322303`) repairs D2 and D3
in the engine. This design builds on that work. Section 2.10 lists what it assumes from it.

## 0. The defect, checked against the code

| Claim of the review (D1) | Check on `33055a59` | Result |
| --- | --- | --- |
| The SDK starts `serve` as a child of the caller, same OS user | [forge_airlock.py](../../sdk/py/forge_airlock.py) lines 302-303 (`subprocess.Popen`); [forge_airlock.ts](../../sdk/ts/forge_airlock.ts) lines 302-303 (`childProcess.spawn`) | CONFIRMED |
| `serve_argv` and `engine_dir` are caller-chosen | Python lines 290, 293, 302; TypeScript `StoreOptions` lines 278, 281 | CONFIRMED |
| The engine binary is pinned by nothing | [PROTOCOL.md](../../src/airlock/PROTOCOL.md) section 11, "the engine binary itself: by nothing in this repository" | CONFIRMED |
| The WAL chain is unkeyed | [store.rs](../../src/airlock/store.rs) lines 5-6 (comment), 24-33 (`crc32`), 35-37 (`fnv128`) | CONFIRMED |
| A hand-written record is listed by `replay` | `main.rs` lines 274-285 list every valid effect record | CONFIRMED, with detail (a) |

Details where the review is not exact, or where the code shows more:

- (a) A forged record must pass the fold. For `REFUND` the fold checks a fresh request id, a
  canonical reason, flag `0` or `1`, and `1 <= amount <= remaining` (`ledger.rs` lines 128-135).
  The review's example (`... 5000000 0`) passes only if the key has that much left. The fold never
  runs the policy, the refund binary or the cosign check. The agent can first forge an `OPEN_MONEY`
  with any `original`. So the conclusion of D1 holds.
- (b) The ratchet does not stop an appended record. A WAL that is longer than the ratchet floor is
  "repaired" at the next open by a new ratchet entry (`store.rs` lines 158-163).
- (c) The Python SDK runs `sys.executable` (line 297), not `python3`. The TypeScript SDK runs
  `python3` from `PATH` (lines 301, 500). `PATH` is one more input of the agent.
- (d) The SDK itself needs access to the store folder. `replay`, `leases`, `sweep` and
  `cosign_message` start separate engine processes on the folder (Python lines 535-537,
  TypeScript lines 499-505). PROTOCOL.md section 2 says these commands need write access. So the
  shipped SDK cannot work against a folder that the agent cannot write. The isolation mode must
  carry these four calls over the socket.
- (e) Measured on this machine: `/opt/homebrew/bin/node` (Node 24.3.0) links 9 libraries under
  `/opt/homebrew/opt/` (`otool -L`). `/opt/homebrew` and `/opt/homebrew/bin` are owned by the
  developer account (`stat`). The genesis pin hashes only the `node` file. Code in those libraries is
  not pinned. This widens D2.

## 1. Threat model

The agent's OS user is hostile: it runs any code as that user. Trusted: the owner, root, the
service user, the human cosigner, the kernel. "Present" is the shipped child-process flow.

| Actor | What it can do in the present flow | What it can do in the isolation mode |
| --- | --- | --- |
| Agent user (hostile) | Choose the engine binary and its flags; run the `kill_points` build; write the WAL, the ratchet and the policy files; replace Node, its libraries, the refund binary copy and the checker model; write any tenant field; read the cosign key if it is the key owner's user | Connect to the sockets of its own tenant group; send request lines. It cannot read or write the store, the key or the pinned files, cannot start the service engine, cannot signal the service process |
| Another tenant's agent (hostile) | Same as above, on the same store | Its own sockets only. Tenant field bound to its socket |
| Service user `_forgeairlock` (trusted) | Does not exist | Owns the store, the WAL MAC key, the socket folders. Can forge anything. |
| Owner (trusted, has `sudo`) | Same user as the agent today | Installs, starts, stops, backs up. Can forge anything through `sudo`. |
| Root (trusted) | Everything | Everything |
| Human cosigner (trusted) | Holds the Ed25519 key as a file of the agent's user | Holds the key as another OS user or on hardware (section 2.9) |
| Kernel, drive (trusted) | `flock`, `F_FULLFSYNC`, file permissions | The same, plus Unix socket permissions and process separation |

Hard requirement: the agent runs as a dedicated non-admin OS user. It is not the owner's account,
not in group `admin`, and has no `sudo` rights. If the agent runs as the owner's account, nothing
in this design holds: that account can use `sudo` and can write `/opt/homebrew`.

## 2. Components

### 2.1 Service user

- macOS (the canonical-refund profile is macOS arm64). A hidden role account `_forgeairlock` with
  group `_forgeairlock`, shell `/usr/bin/false`, home `/var/empty`. `sysadminctl -addUser` has a
  `-roleAccount` flag; its usage text on this machine says "Role accounts require name starting with
  _ and UID in 450-499 range". No account uses a UID from 450 to 499 here today (`dscl . -list
  /Users UniqueID`). The fallback is `dscl . -create` for the group and the user. NOT TESTED.
- The daemon: a `launchd` plist in `/Library/LaunchDaemons` with `UserName`, `GroupName`, `Umask`
  63 (octal 077), `RunAtLoad`, `KeepAlive`, an empty `EnvironmentVariables`. Text in section 5.
  NOT TESTED.
- Linux, briefly: `useradd --system --no-create-home --shell /usr/sbin/nologin forge-airlock`, and a
  systemd unit with `User=`, `Group=`, `UMask=0077`, `NoNewPrivileges=yes`, `ProtectSystem=strict`,
  `ProtectHome=yes`, `PrivateTmp=yes`, `ReadWritePaths=/var/lib/forge-airlock`. The canonical
  refund binary is a Mach-O file, so on Linux only parametric policies work. Nobody has run the
  engine on Linux. NOT TESTED.

### 2.2 The socket and the peer's identity

Measured facts (rustc 1.92.0, this machine, one user; probes in the scratchpad, not in the repo):

| Probe | Exit | Result |
| --- | --- | --- |
| `UnixStream::peer_cred()` in a `#![forbid(unsafe_code)]` file | 1 (compile) | `E0658`: unstable feature `peer_credentials_unix_socket`. Stable std gives no peer uid. |
| `UnixListener::bind` + `connect` + `accept`, std only | 0, run 0 | works; the socket file got mode 0755 from the umask |
| bind with a 117-byte path | run 101 | "path must be shorter than SUN_LEN": a macOS socket path must stay short (`sun_path[104]` in the SDK header `sys/un.h`, line 79) |
| accepted stream given to a child as stdin and stdout (`OwnedFd` into `Stdio`), no `unsafe` | 0, run 0 | the child (`/usr/bin/head -n 1`) answered the client's line |
| Python 3.9.6 and 3.10.11 `socket.LOCAL_PEERCRED` on a socket pair | 0 | constant present (1); `getsockopt` gave the own uid 501. Two different users: NOT TESTED |

So std-only Rust with no `unsafe` cannot ask the kernel for the peer's uid on rustc 1.92. Options:

1. **One socket per tenant (RECOMMENDED; no `unsafe`).** Each tenant is one OS group whose only
   members are that tenant's agent users. Socket folder `<run>/<tenant>/` owned by
   `_forgeairlock:<tenant group>`, mode 0710: the group can pass through it but not list it. The
   socket file `<run>/<tenant>/s` is made by the engine inside it. The folder mode is the gate, not
   the socket file mode (whether macOS checks the mode of the socket file itself: NOT TESTED). The
   engine knows the tenant from the listener that accepted. Cost: one OS group per tenant.
2. **A token per tenant.** The first line is `AUTH <tenant> <token>`. The engine compares the
   SHA-256 of the token with a 0400 file of the service user. The tenant's copy is a 0400 file of the
   tenant's user. Weaker: a token can leak through logs, the environment or a backup; it is not
   bound to a uid. Use it only with option 1, never alone.
3. **`getpeereid` (macOS) or `SO_PEERCRED` (Linux) through a small `unsafe` block or a C shim.**
   This breaks `#![forbid(unsafe_code)]` (`main.rs` line 1), the `-D unsafe_code` build flag
   ([bin/forge-airlock](../../bin/forge-airlock) lines 49-52) and the source rule of
   [exit_goal20_sdk.py](../../scripts/exit_goal20_sdk.py) (lines 542-561). It needs the owner's
   decision (Q-2).
4. **A Python front with `LOCAL_PEERCRED`.** It adds the Python interpreter to the service's
   trusted base. Not recommended.

The acceptor (new subcommand `serve-socket`) does no request work. For each accepted connection it
starts a fresh `airlock-engine serve <dir> --bound-tenant <t> ...` child whose stdin and stdout are
the socket (measured above). The `serve` loop (`main.rs` lines 123-141) stays as it is. Each
connection is its own process, so a crash or a fault ends one connection only. Limits in the
acceptor: a maximum of open connections per tenant; a read timeout set on the socket before the
hand-over (`set_read_timeout`; the child's blocking read then fails, and `serve` ends with
`IO_ERROR`; NOT TESTED). Flags only, no configuration file: the plist holds the full argument list.

### 2.3 The bound tenant

`serve --bound-tenant <t>` refuses every request line whose tenant field is not `<t>`, before any
file is opened: a new detail `TENANT_ISOLATION_BREACH TENANT_NOT_BOUND`. This covers the six write
verbs, `OPEN_LEASE`, `GET` and `READ`. `STATE` gives store-wide counts (`keys=`, `effects=`,
`leases=`), so a bound `serve` refuses it or answers only for its tenant (Q-5). The same applies to
the four calls of section 0 (d), carried as new verbs: `REPLAY`, `LEASES [ALL]`, `SWEEP [<now>]`,
`COSIGN_MESSAGE <action>`. Each answers only rows of the bound tenant. A multi-line answer uses
the `READ` pattern in reverse: a head line with the count `n`, then exactly `n` lines.

### 2.4 Pinned files under a root-owned prefix

- Prefix: `/usr/local/libexec/forge-airlock/<version>/`, owner `root:wheel`, folders 0755, files
  0555. `/usr/local` is `root:wheel` 0755 here; `/usr/local/libexec` does not exist yet (`stat`).
  Contents: `airlock-engine` (the production build only; never the `kill_points` build),
  `refund-binary`, `node` (only for inventory stores), `checker/model.cjs` and the
  `node_modules` copy that the model needs, the policy files that `init` reads.
- The engine build links only `/usr/lib/libSystem.B.dylib`; so does the refund binary (`otool -L`
  on a scratch build of `33055a59` and on the tracked artifact).
- Node: the Homebrew build links 9 libraries under `/opt/homebrew` (section 0 (e)). A copy of the
  `node` file alone into the prefix does not help. Either use a Node build that links only system
  libraries (whether the official macOS build does: NOT CHECKED), or keep inventory stores off the
  isolation mode (Q-6). Since `e3322303`, cosign no longer uses Node; Node runs only for `BOOK`.
- Ownership walk at start and at every exec: every part of every pinned path, from `/`, exists, is
  not a symbolic link, is owned by uid 0 (or by `_forgeairlock` for the store side), and has no group
  or other write bit. This is the walk of `cosign.rs` on `e3322303` (lines 162-187), applied to all
  pinned files by the parallel engine pull request (assumed). Note: `/var`, `/etc` and `/tmp` are
  symbolic links on macOS (`ls -ld`), so every path uses `/private/var/...`.
- A long-lived service makes "hashed once per process" (`helpers.rs` lines 87-97) weaker, because a
  process lives longer. The per-connection process of section 2.2 limits this, but a connection can
  live long. The per-exec re-check of the parallel engine pull request is required (assumed).

### 2.5 The store folder

`/private/var/db/forge-airlock/stores/<store>/`, owner `_forgeairlock`, mode 0700; the parent
folders `root:wheel` 0755 then `_forgeairlock` 0700. `init` runs once as the service user.
`/private/var/db` is `root:wheel` 0755 here (`stat`). The agent has no read access: the store holds
every tenant's records.

### 2.6 WAL MAC

- Algorithm: HMAC-SHA-256, std only, on the existing hand-written SHA-256 (`pin.rs` lines 16-75).
  HMAC is a short wrapper. It needs its own known-answer vectors (RFC 4231), like `pin.rs` has.
- What is MACed: each record gets a 32-byte tag after its CRC. The tag covers the record bytes and
  the previous record's tag (a tag chain). Each ratchet entry becomes epoch, tag of the record at
  that epoch, and an HMAC of both. The FNV-1a-128 state hash stays unchanged on the wire: it is the
  compare-and-swap value of the SDKs and of the cosign message.
- Key: 32 bytes from `/dev/urandom`, made by a new subcommand as the service user, in
  `/private/var/db/forge-airlock/keys/<store_id>.key`, mode 0400, folder 0700, outside the store
  folder (so a copy of the store holds no key). The genesis record holds a key id (a SHA-256 of a
  fixed label and the key, cut to 16 hex). A wrong or missing key: `CORRUPT_WAL MAC_KEY ...`; never
  a silent unkeyed open.
- Rotation: a `REKEY <new key id>` record, tagged with the old key; records after it use the new key;
  the old key stays read-only for the prefix. Loss of the key: the store cannot be verified and is
  refused. Recovery is the owner's decision: migrate the fold into a new store with a new key, and
  record that the prefix was not verified (Q-8).
- What the MAC adds when the agent cannot write the folder anyway: defence in depth. A record that
  someone without the key plants (a mistaken permission, a restored or edited backup, a copied
  folder) is refused, loudly. What it does NOT add: the service user and root hold the key and can
  forge. A restore of the WAL and the ratchet together, both validly tagged, is still not detected.
  A copy of the floor in the key folder would detect a restore of the store folder alone, not of both.
- Format: a new genesis version (the next free one after `e3322303`, which made version 3, and after
  the parallel engine pull request), a new record magic, a new ratchet entry size. An older engine
  refuses the new store. Migration: a new subcommand reads the old store (fold), writes a new store
  and re-appends every payload in order, so the fold checks each record again. All state hashes
  change; clients must `GET` again. The old store stays, read-only. The migration trusts the old
  unkeyed file: that is stated in its record.

### 2.7 Per-tenant authentication

With option 1, the credential is the OS group and the socket folder. The tenant label comes from the
listener, not from the caller (section 2.3). D3's shared key and request-id namespaces are repaired
by the parallel engine pull request (assumed: per-tenant names for keys and request ids). Simplest
strong form: one store per tenant. Then no epoch, count or lock is shared (Q-4).

### 2.8 SDK changes

- A `socket=` mode (Python) and `socket:` option (TypeScript) beside the child-process mode. In the
  socket mode `serve_argv`, `engine_dir`, `env` and `python` are refused, and `replay`, `leases`,
  `sweep`, `cosign_message` use the verbs of section 2.3. The answer parsing is unchanged.
- The child-process mode stays for development. Its docstring and the quickstart label it
  "no isolation: every rule holds only against a buggy caller, not a hostile one".
- The SDK runs in the agent's process, so its checks are a convenience, not a control. The control is
  the server: the socket permissions, the bound tenant, the store permissions.

### 2.9 The human cosign key (reference only)

The private key is held by another OS user (for example the owner's account, when the agent runs as
its own user) or on hardware. The engine never reads it. Since `e3322303` the engine accepts only
`ssh-ed25519` SSHSIG signatures (`cosign.rs` lines 129-146). Whether a given hardware key can make
that exact signature type: NOT CHECKED (Q-9).

### 2.10 What this design assumes from other work (not repeated here)

From `apex1/native-cosign` (`e3322303`): cosign through `/usr/bin/ssh-keygen` with its ownership walk;
genesis version 3; the `kill_points` build only in a test folder. From the parallel engine pull
request (`feat/airlock-review-hardening`): per-tenant namespaces for keys and request ids; a
pending-cosign lease state; a loud, fail-closed ratchet CRC rule; an ownership walk or a per-exec
re-check for every remaining pinned helper. If that pull request does not merge, sections 2.4 and 2.7
must carry these items themselves.

## 3. What it closes and what it does NOT close

"Closed" means: the agent's OS user cannot do it in a correct deployment. It is a deployment
property, tested by section 4, never proved.

| Attack | Present flow | Isolation mode |
| --- | --- | --- |
| Swap the engine or `serve_argv` | OPEN | CLOSED for the agent: the service engine is started by `launchd` from the root-owned prefix; the agent holds only a socket |
| Append a forged WAL record | OPEN (CRC and FNV unkeyed) | CLOSED for the agent by the 0700 folder; the MAC (phase 2) also refuses a planted record. NOT closed against the service user or root |
| Replace a pinned helper after the first check | OPEN (D2) | CLOSED for the agent if every pinned file and every library it loads is under root-owned paths and the walk passes. Homebrew Node: OPEN (its libraries) |
| Name another tenant | OPEN (free field) | CLOSED by the bound tenant. Two tenants that share one OS group are one tenant |
| Probe another tenant | OPEN (D3 oracles) | Key and request-id oracles: CLOSED by the per-tenant namespaces (assumed). Epoch numbers in answers, `STATE` counts and lock wait times of a shared store: NOT closed; one store per tenant closes the first two |
| Restore old WAL plus ratchet | not detected | CLOSED for the agent (no write access). By the owner or root: NOT detected, also with the MAC |
| Flood leases and WAL growth | OPEN | PARTLY: a cap of open leases per tenant and of connections. Valid commits still grow the WAL; the full re-fold per request (D4) stays |
| A hostile root | n/a | NOT closed |
| The owner's own `sudo` | n/a | NOT closed |
| A compromised service user | n/a | NOT closed (it holds the key and the store) |
| A kernel bug | NOT closed | NOT closed |
| The agent asks the owner to run something | NOT closed | NOT closed. Rule: the owner runs only the fixed text of section 5, never a command that an agent wrote |
| Denial of service by many connections | n/a | PARTLY: a connection cap per tenant and a read timeout. The global store lock is shared |
| Backups readable by the agent | n/a (it owns all) | CLOSED if backups are owned by root or the service user. A backup that the agent can write and that is restored later: the MAC refuses planted records only if the key is not in that backup |

## 4. One end-to-end "malicious agent" test (a plan only)

Deployment: the setup of section 5, two tenants `t1` and `t2`, agent users `forgeagent1` and
`forgeagent2`. The suite runs as `forgeagent1`. Each case records an actual exit code or `errno`.
Pass: every hostile case fails as expected, and a `replay` run by the owner as the service user shows
only the control records.

| Case | Action as `forgeagent1` | Expected |
| --- | --- | --- |
| M1 | valid `OPEN_MONEY` and `REFUND` on the own socket (control) | `COMMITTED` |
| M2 | connect to `t2`'s socket | `EACCES` |
| M3 | a request with tenant `t2` on the own socket | `TENANT_ISOLATION_BREACH TENANT_NOT_BOUND`, no record |
| M4 | list, read, write or rename the store folder, WAL, ratchet, policy files, key file | `EACCES` each |
| M5 | write, rename or replace every pinned file, every library it loads, every folder on each path | `EACCES` or `EPERM` each; the walk reports OK |
| M6 | run its own engine build (also `kill_points`) on the store path | refused by permissions; no record |
| M7 | `kill -9` or attach a debugger to the service process | `EPERM` |
| M8 | remove or replace the socket file or its folder | `EACCES` |
| M9 | open connections above the cap; open leases above the cap; stay idle past the timeout | refused; refused; connection closed |
| M10 | read the human's key file; send a forged signature | `EACCES`; `REQUIRE_HUMAN_COSIGN COSIGN_INVALID` |
| M11 | set `PATH`, `DYLD_INSERT_LIBRARIES`, `FORGE_AIRLOCK_NODE` in its own environment | no effect on the service (its log shows the prefix paths) |
| M12 | OWNER step, as root: append a CRC- and FNV-valid record to the WAL (a mistaken permission) | phase 2: `CORRUPT_WAL MAC_MISMATCH`; before phase 2: accepted (records the gap) |

What the test needs from the owner: the setup of section 5 once; a start of the suite as
`forgeagent1` (OWNER: `sudo -u forgeagent1 -H ...`, or a login as that user); M12 as root; the
final `replay` as the service user.

## 5. Owner setup steps (text only; none was run)

Every step marked OWNER needs `sudo` and is the owner's. Names in angle brackets are the owner's
choice. Check a free UID first: `dscl . -list /Users UniqueID` (no `sudo`). NOT TESTED as a whole.

1. (no `sudo`) In a clean checkout of the merged commit: `bin/forge-airlock build`. Record
   `build/airlock/airlock-engine sha256 build/airlock/airlock-engine`.
2. OWNER: `sudo sysadminctl -addUser _forgeairlock -roleAccount -UID <4xx> -GID <4xx> -shell /usr/bin/false -home /var/empty`
   (if the group is not made by it: `sudo dscl . -create /Groups/_forgeairlock PrimaryGroupID <4xx>`).
3. OWNER: per tenant, a non-admin agent user and a group: `sudo sysadminctl -addUser forgeagent1 ...`;
   `sudo dseditgroup -o create forge-t1`; `sudo dseditgroup -o edit -a forgeagent1 -t user forge-t1`.
4. OWNER: the prefix: `sudo install -d -o root -g wheel -m 0755 /usr/local/libexec/forge-airlock/<v>`;
   then `sudo install -o root -g wheel -m 0555 <file> /usr/local/libexec/forge-airlock/<v>/` for the
   engine, the refund binary, the policy files, and (inventory only) Node, the model, `node_modules`.
5. OWNER: data folders: `sudo install -d -o root -g wheel -m 0755 /private/var/db/forge-airlock`;
   `sudo install -d -o _forgeairlock -g _forgeairlock -m 0700 /private/var/db/forge-airlock/stores`
   and `.../keys` and `.../log`.
6. OWNER: socket folders: `sudo install -d -o root -g wheel -m 0755 /private/var/db/forge-airlock-run`;
   per tenant `sudo install -d -o _forgeairlock -g forge-t1 -m 0710 /private/var/db/forge-airlock-run/t1`.
7. OWNER: the store: `sudo -u _forgeairlock /usr/local/libexec/forge-airlock/<v>/airlock-engine init /private/var/db/forge-airlock/stores/<s> --policy <prefix>/<policy.json> --cosign-pubkey <human's key>`.
   Phase 2: the key subcommand, as the same user, into `.../keys/`.
8. OWNER: write `/Library/LaunchDaemons/local.forge-airlock.plist` (`root:wheel` 0644). Content: a
   `dict` with `Label` `local.forge-airlock`; `UserName` and `GroupName` `_forgeairlock`;
   `ProgramArguments`: the engine path, `serve-socket`, the store path, one `--tenant
   t1=/private/var/db/forge-airlock-run/t1/s` per tenant, `--refund-binary`, and the caps;
   `Umask` 63; `RunAtLoad` and `KeepAlive` true; `EnvironmentVariables` an empty dict;
   `StandardErrorPath` `/private/var/db/forge-airlock/log/engine.err`.
9. OWNER: `sudo plutil -lint /Library/LaunchDaemons/local.forge-airlock.plist`;
   `sudo launchctl bootstrap system /Library/LaunchDaemons/local.forge-airlock.plist`;
   `sudo launchctl print system/local.forge-airlock`.
10. Run the agent only as `forgeagent1` (or `forgeagent2`), never as the owner's account. Then run
    section 4.

Rollback:

1. OWNER: `sudo launchctl bootout system/local.forge-airlock`; `sudo rm /Library/LaunchDaemons/local.forge-airlock.plist`.
2. OWNER: keep the store. Copy it as the service user to a root-owned backup before any change.
3. OWNER: `sudo rm -r /usr/local/libexec/forge-airlock/<v>` (that version only).
4. OWNER: `sudo sysadminctl -deleteUser forgeagent1`, `sudo dseditgroup -o delete forge-t1`,
   `sudo sysadminctl -deleteUser _forgeairlock` (only after step 2).
5. The SDK returns to the child-process mode ("no isolation"). After phase 2, an older engine
   refuses the new store format: roll back to the pre-migration copy, which stayed read-only.

## 6. Build estimate from measured line counts

Measured with `wc -l` and `sed -n <range> | wc -l` on `33055a59` unless the commit says `e3322303`
(`git show`). The judgement column is mine. No hours, days or money.

| Component (phase) | Measured comparable piece | Lines (measured) | Judgement: the new piece |
| --- | --- | --- | --- |
| `serve-socket` acceptor (1) | `helpers.rs` `run`, lines 31-83 (spawn, pipes, threads, time limit) | 53 | same kind; about that size |
| `--bound-tenant` check (1) | `main.rs` `flag_values`, lines 218-240 | 23 | smaller; one check before dispatch |
| socket verbs `REPLAY`, `LEASES`, `SWEEP`, `COSIGN_MESSAGE` (1) | `main.rs` `leases`, lines 193-215; `replay` arm, lines 274-285 | 23; 12 | four pieces of that kind, plus a tenant filter |
| ownership walk of the install (1) | `cosign.rs` `walk` + `binary_checks`, lines 162-187 (`e3322303`) | 26 | reuse; the parallel PR may already generalize it |
| Python SDK socket transport (1) | `Store.__init__` to `_exchange`, lines 290-398; `_sub`, lines 535-537 | 109; 3 | a second transport of the same kind; parsing reused |
| TypeScript SDK socket transport (1) | constructor to `exchange`, lines 297-375; `sub` 499-505; `close` 545-553 | 79; 7; 9 | same kind |
| HMAC-SHA-256 (2) | `pin.rs` `Sha256`, lines 16-75 | 60 | much smaller; a wrapper plus vectors |
| record and ratchet format with tags (2) | `store.rs` `encode` 56-66, `scan` 90-124, `open` 137-175, `append` 189-213 | 11; 35; 39; 25 | changes inside each of these four |
| key file creation and load (2) | `cosign.rs` `private_folder`, lines 198-213 (`e3322303`) | 16 | same kind |
| migration subcommand (2) | `store.rs` `init`, lines 217-288; `scan` 90-124 | 72; 35 | same kind as `init` plus a replay loop |
| per-tenant caps, bound `STATE` (3) | `main.rs` `serve`, lines 123-141 | 19 | small changes in the acceptor and verbs |
| dispatcher `serve` path (1) | `bin/forge-airlock` `cmd_serve`, lines 165-181 | 17 | small; or none (the plist calls the engine) |
| malicious-agent suite (4) | `tests/airlock/test_sdk.py`; `test_engine.py` | 691; 1293 | a new suite of 12 cases; smaller than `test_sdk.py` |

Whole files for scale: `main.rs` 310, `store.rs` 303, `pin.rs` 106, `helpers.rs` 145,
`bin/forge-airlock` 250, Python SDK 581, TypeScript SDK 559, `tests/airlock/*.py` 3,068 in total; on
`e3322303`: `cosign.rs` 252, `helpers.rs` 148, `pin.rs` 113, `store.rs` 309, `main.rs` 316.

Phases:

1. Socket server, bound tenant, socket verbs, SDK socket mode, install walk. No WAL format change.
2. WAL MAC, key, migration. CHANGES the WAL format (genesis version, record, ratchet entry).
3. Per-tenant groups, caps, bound `STATE`. No WAL format change if the caps stay in the verb layer.
4. The malicious-agent suite and its owner run. New test file only.

Evidence bundle: [exit_goal20_sdk.py](../../scripts/exit_goal20_sdk.py) (lines 56-98) hashes 64
subject files, among them every `src/airlock/*.rs` of its list, both SDKs, `bin/forge-airlock`,
`PROTOCOL.md` and the quickstart. So phases 1, 2 and 3 change the Goal 20 bundle digest. A new Rust
file is not in its list `RUST` (line 56) until the script changes; its unsafe rule then misses it.
Phase 4 adds a test file outside the subject list. `e3322303` changes the digest already.

## 7. Open questions and owner decisions

1. Q-1. Approve the design for a build, and which phases (1 to 4)?
2. Q-2. Peer identity: option 1 (one socket and one OS group per tenant, no `unsafe`), or option 3
   (`getpeereid` through `unsafe` or a C shim, which changes the "std only, no unsafe" rule and the
   Goal 20 source rule)?
3. Q-3. Is the agent moved to its own non-admin OS user? Without it nothing here holds.
4. Q-4. One store per tenant, or one shared store with bound tenants?
5. Q-5. In bound mode, does `STATE` refuse, or answer only for the tenant?
6. Q-6. Inventory (Node) in the isolation mode: a Node build with only system libraries in the
   prefix, or no inventory stores there?
7. Q-7. The WAL MAC (phase 2): build it, given that it does not stop root or the service user?
8. Q-8. Key loss: refuse forever, or allow an owner-signed migration that records an unverified
   prefix?
9. Q-9. Hardware for the human key: which device, and can it make `ssh-ed25519` SSHSIG signatures?
10. Q-10. Linux: in scope now, or macOS only?
11. Q-11. The caps: values for connections per tenant, open leases per tenant, read timeout.
12. Q-12. The order against the parallel engine pull request: build after it merges (this design
    assumes so), or carry its items here?
