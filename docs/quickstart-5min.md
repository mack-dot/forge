# forge-airlock quickstart

`end_to_end=false`. This page shows how to build the engine, open a store, and use the
Python and TypeScript SDKs. It does not prove anything. The labels in the section
"What is proved and what is not" apply to every result on this page.

## About "5 minutes"

The commands below take a few minutes on a machine that already has the tools. They do
not take 5 minutes on a new machine. Install these first:

- macOS on ARM64 (Apple silicon). The CakeML refund binary is a macOS ARM64 binary.
- `rustc` 1.92.0 on `PATH` (rustup puts it in `~/.cargo/bin`). No Cargo and no crate are
  used. `bin/forge-airlock build` exits 127 with a message when `rustc` is not on `PATH`.
- Node.js 24.3.0. The TypeScript SDK runs through the built-in type stripping of
  Node 24.3.0. No flag is needed. No npm package is used.
- Python 3 (standard library only).
- For inventory bookings only: the pinned Dafny 4.11.0 in `.toolchain/dafny-4.11.0`, once,
  to build the booking checker (`bin/forge-airlock build --checker`). After that build, no
  Dafny process starts at run time.

All commands run from the repository root. Set the Node binary once. The example path is
the Homebrew path. Change it to your Node 24.3.0:

```sh
export FORGE_AIRLOCK_NODE=/opt/homebrew/bin/node
"$FORGE_AIRLOCK_NODE" --version
```

`bin/forge-airlock` refuses a Node that is not 24.x and tells you so.

## 1. Build

```sh
bin/forge-airlock build
```

This runs the two `rustc` commands of [the protocol](../src/airlock/PROTOCOL.md) and makes a
private 0700 copy of the pinned CakeML refund binary (SHA-256 `b8ed5ec2…7bb8`) in
`build/airlock/`. The booking checker is a separate step, because it starts Dafny:
`bin/forge-airlock build --checker`. Run one Dafny job at a time. (That step was not run
for this page: the checker model was already built. It calls
[build_checker.py](../src/airlock/node/build_checker.py).)

## 2. Open a store with two policies

```sh
rm -rf build/quickstart && mkdir -p build/quickstart
bin/forge-airlock init build/quickstart/store --store-id quickstart \
  --policy examples/unbreakable_store/policies/refunds.json \
  --policy examples/unbreakable_store/policies/payout.json \
  --node "$FORGE_AIRLOCK_NODE"
```

`--node` makes the store pin the SHA-256 of that Node binary. The engine requires it
only for a store with an inventory policy (the booking checker runs in Node). A store
with money, saga and cosign policies needs no Node at all. Each store gets a random nonce in
its genesis record, so its state hashes differ from those of every other store.

The two policies are a money policy ([refunds.json](../examples/unbreakable_store/policies/refunds.json))
and a saga policy ([payout.json](../examples/unbreakable_store/policies/payout.json)). The
store pins both files. A changed policy file makes the store refuse to open
(`CORRUPT_WAL POLICY_CHANGED`).

## 3. Python: commit, read_scoped, with_lease

The SDK is one file: [sdk/py/forge_airlock.py](../sdk/py/forge_airlock.py). It starts one
`serve` process per store and talks to it over pipes. It decides no write.

```sh
cat > build/quickstart/hello.py <<'EOF'
import os, sys, time
sys.path.insert(0, 'sdk/py')
import forge_airlock as fa

with fa.Store('build/quickstart/store', node=os.environ['FORGE_AIRLOCK_NODE']) as st:
    r = st.open_money('acme', 'order-1', 'open-1', 'store-refunds', 10000, {'shipping_paid': 1000})
    print('open:', r.code)
    h = st.get('acme', 'order-1').state_hash          # the CAS token: read it, then name it in the write
    r = st.refund('acme', 'order-1', 'refund-1', h, 'SHIPPING', 8000)
    print('shipping $80 on a $10 fact:', r.code, r.detail)
    r = st.refund('acme', 'order-1', 'refund-2', h, 'SHIPPING', 1000)
    print('shipping $10:', r.code)
    rows = [{'tenant_id': 'acme', 'order': 'order-1'}, {'tenant_id': 'globex', 'order': 'gx-9'}]
    r = st.read_scoped('acme', rows)
    print('read with a forgotten WHERE tenant_id:', r.code, r.detail, 'rows returned:', len(r.rows))

    def webhook(lease):
        h = st.get('acme', 'order-1').state_hash
        return lease.commit('refund', tenant='acme', key='order-1', pre_state_hash=h, reason='DUPLICATE_CHARGE', amount=500)
    r = st.with_lease('wh-1', int(time.time() * 1000) + 60000, 'acme', 'order-1', webhook)
    print('webhook in a lease:', r.code)
EOF
python3 build/quickstart/hello.py
```

Expected lines: `open: COMMITTED`, `shipping $80 on a $10 fact: REJECTED_POLICY REASON_CAP`,
`shipping $10: COMMITTED`, `read with a forgotten WHERE tenant_id: TENANT_ISOLATION_BREACH ROW 1 TENANT_MISMATCH rows returned: 0`,
`webhook in a lease: COMMITTED`.

`read_scoped` serializes each row once, sends those bytes, and after `OK <n>` returns new
objects parsed from exactly those bytes, never your own objects. It refuses more than
100000 rows before it sends anything. `with_lease` binds the lease to a request id, a
tenant and a key. Only a commit or a `REJECTED_POLICY` for that id on that tenant and key
closes it. A `REQUIRE_HUMAN_COSIGN` leaves it open in the state PENDING_COSIGN (the signed
retry is still expected; the sweep reports it after its deadline). One lease per request id
and tenant, ever. Keys, request ids and leases are per tenant: a key of another tenant is
`UNKNOWN_KEY`, like a key that nobody opened.

Typed results: `COMMITTED`, `REJECTED_POLICY`, `REQUIRE_HUMAN_COSIGN`, `STALE_STATE_HASH`,
`DUPLICATE_REQUEST_ID`, `TENANT_ISOLATION_BREACH` (read only), `DROPPED_OBLIGATION`. Every other outcome
raises an `AirlockError` subclass (for example `EngineRefusal`, `EngineDead`,
`ProtocolError`). An error is never a commit. After a dead engine, a timeout or a bad
answer, the client closes itself (fail closed).

## 4. TypeScript: the same three calls

The SDK is one file: [sdk/ts/forge_airlock.ts](../sdk/ts/forge_airlock.ts). It is CommonJS
TypeScript with erasable syntax only, so Node 24.3.0 runs it directly. It keeps one
`serve` child per store and has an async API (one request at a time, in call order).

```sh
cat > build/quickstart/hello.ts <<'EOF'
const path = require('node:path');
const fa = require(path.resolve('sdk/ts/forge_airlock.ts'));

async function main(): Promise<void> {
  const st = new fa.Store('build/quickstart/store', { node: process.execPath });
  const g = await st.get('acme', 'order-1');
  const r = await st.refund('acme', 'order-1', 'ts-refund-1', g.stateHash, 'DUPLICATE_CHARGE', 100);
  console.log('refund $1:', r.code);
  const stale = await st.refund('acme', 'order-1', 'ts-refund-2', g.stateHash, 'DUPLICATE_CHARGE', 100);
  console.log('same pre_state_hash again:', stale.code);
  const read = await st.readScoped('acme', [{ tenant_id: 'acme', order: 'order-1' }]);
  console.log('read:', read.code, 'rows returned:', read.rows.length);
  try {
    await st.withLease('wh-2', Date.now() + 1000, 'acme', 'order-1', (lease: unknown) => {
      const event: any = {};
      return event.data.object.amount;        // a TypeError before the sink: the lease stays open
    });
  } catch (e) {
    console.log('handler threw:', (e as Error).name);
  }
  const sweep = await st.sweep(Date.now() + 5000);
  console.log('sweep:', sweep.code, sweep.dropped.map((d: string[]) => d[0]).join(','));
  await st.close();
}
main();
EOF
"$FORGE_AIRLOCK_NODE" build/quickstart/hello.ts
```

Expected lines: `refund $1: COMMITTED`, `same pre_state_hash again: STALE_STATE_HASH`,
`read: OK rows returned: 1`, `handler threw: TypeError`, `sweep: DROPPED_OBLIGATION wh-2`.

## 5. Look at the store

```sh
bin/forge-airlock replay build/quickstart/store
bin/forge-airlock leases build/quickstart/store
```

`replay` lists every effect record of the WAL. `leases` lists the open leases
(`leases --all` also lists the closed ones with the verdict that closed them). The
command `bin/forge-airlock leases build/quickstart/store --sweep` reports each open
lease past its deadline as `DROPPED_OBLIGATION` and exits 24 when there is at least one. It
lists a lease in the state PENDING_COSIGN as `PENDING_COSIGN` before its deadline.

## 6. diff-policy on two policies

```sh
bin/forge-airlock diff-policy examples/unbreakable_store/policies/refunds.json \
  examples/unbreakable_store/policies/refunds-v2.json --no-clearing
```

The table shows each boundary scenario under the old and the new policy, from the engine
and from an independent Python evaluator. Here the goodwill limit moves from $20 to $50,
so 4 rows change. With `--no-clearing` no Dafny process starts and the exit code is 3
(`CLEARING_NOT_RUN`: nothing proved). Without `--no-clearing`, the command also runs the
NO_CHOICE check through the pinned Dafny (heavy; one Dafny job at a time; that form was
not run for this page). See
[diff_policy.py](../src/airlock/py/diff_policy.py) for its exit codes.

## 7. The demo

```sh
bin/forge-airlock demo --json build/quickstart/demo.json
```

The demo ([run_demo.py](../examples/unbreakable_store/run_demo.py)) runs valid traffic and
the eight disasters of [the brief](../proposals/forge2-goal20-sdk/BRIEF.md) against a real
store, through both SDKs, and a short fuzz pass. Every block is a real engine answer. The
money that moved is read back from the WAL after each disaster. The Stripe and PayPal
processors in the demo are LOCAL FAKE in-process stand-ins, not real APIs. Exit 0 only if
all eight disasters and the valid traffic behaved as stated. The fuzz pass alone:
`bin/forge-airlock fuzz --seed 20 --rounds 3`.

## What is proved and what is not

Three labels. Each result has one or more of them.

- **PROVED CORE**: only two decisions.
  - A refund on a key whose policy has `"profile": "canonical-refund"`: the CakeML ARM64
    refund binary (SHA-256 `b8ed5ec2…7bb8`) decides. The engine sets the binary's three
    flags itself, so the flag logic of the binary is not exercised through the engine.
  - An inventory booking: the Dafny-compiled `BookingDualCert` checker must accept. This
    is a proved SOURCE. The Dafny compiler and Node are trusted.
  - The NO_CHOICE verdict of `diff-policy` holds for the GENERATED Dafny model only.
- **NATIVE CHECK**: the Rust engine (WAL, compare-and-swap, per-tenant namespaces, parametric money
  rules, saga table, read airlock, leases). It is not proved.
- **FINITE TEST**: the test suites, the fuzz pass and the demo. They try a finite set of
  inputs. They prove nothing.

`end_to_end=false`. No figure of the form "% of bugs" is claimed anywhere.

## Trust boundary

Every rule on this page holds only against a caller that reaches the store THROUGH the
engine. A process that can write the store folder can append records itself: the CRC
and the hash chain authenticate nothing. A process that can start its own engine on the
folder can ignore every check. To hold these rules against an agent, keep the agent from
writing the store folder and from running another engine on it. Example: `serve` runs
under another OS user that owns the folder, and the agent holds only its pipe. The
engine cannot check this. See section 11 of [the protocol](../src/airlock/PROTOCOL.md).

The opener of a key is trusted. The `original` amount, the facts (for example
`shipping_paid`) and the tenant of a key are inputs of whoever opens the key. Nothing
authenticates the tenant field: the per-tenant namespaces stop accidents, squatting and
probes only between callers that something outside the engine holds to their tenant. The money caps (for example disasters 2 and 3 of the
demo) block only relative to the values given at open.

What pins what: the engine pins the refund binary (compiled-in SHA-256) and the Node
booking helper (compiled in); the booking helper pins the checker model; the store pins the
SHA-256 of the Node binary at `init` (inventory only). At every run, the engine checks the
path of the refund binary and of Node (owner root or the engine's own user, no group or
other write bit up to `/`), hashes the refund binary again, and hashes Node again when its
file identity changed. The Homebrew Node is under a folder that the `admin` group may
write, so `bin/forge-airlock` passes a private copy of it. The engine checks
`/usr/bin/ssh-keygen` before every cosign (owned by root, not writable by group or other,
no symbolic link on its path) but does not pin it: an OS update must not lock every store.
`bin/forge-airlock cosign-info` prints its SHA-256 and version so that you can record them.
The files are still run by path: your own user (or root) can change them between the check
and the run, so these checks matter only when `serve` runs as another user. Nothing in this
repository pins the engine binary itself.

## Cosign: the same-OS-user limit

A refund above the cosign limit commits only with an Ed25519 signature that verifies
against the public key pinned at `init`. The human makes a key with
`bin/forge-airlock cosign-keygen <new-key-file>` (OpenSSH `ssh-keygen`; it prints the token
for `init --cosign-pubkey`) and signs the output of `cosign-message` with
`bin/forge-airlock cosign-sign <key-file>` (a 0600 key file without a passphrase, opened
with `O_NOFOLLOW` and checked with `fstat`). The tool prints one token: the base64 body of
the SSHSIG armor without line breaks. The engine holds only the public key and verifies
with `/usr/bin/ssh-keygen -Y verify`. No Node runs for a cosign.

Limit: if the agent runs as the same OS user as the key owner, it can read a 0600 file.
"The agent cannot self-cosign" holds only if BOTH conditions hold:

1. the private key is outside the agent's reach: another OS user, a hardware key, or a
   separate machine;
2. the agent cannot write the store folder and cannot run another engine on it (see
   "Trust boundary").

In the demo, the agent and the human key belong to the same OS user. The demo shows the
cosign mechanism, not that separation.

## Trusted assumptions

- The Dafny compiler, for the compiled booking checker.
- The system OpenSSH, `/usr/bin/ssh-keygen` with its LibreSSL (Ed25519 verify for the
  cosign). It is smaller than Node and widely reviewed, but it is not zero.
- Node.js (the booking checker runs in Node; inventory only).
- `bignumber.js` from the pinned `node_modules`, used by the Dafny JavaScript runtime.
- The small JSON-to-Dafny generator of `diff-policy` (owner decision; limited by negative
  controls, not proved).
- The macOS kernel and the drive for `F_FULLFSYNC` and `flock`.
- Whoever can write the store folder, the engine binary, the refund binary, Node, the
  booking helper, the checker model and `/usr/bin/ssh-keygen`.

## Limits

- The read airlock sees only the rows passed to it. A query that never goes through
  `read_scoped` is not checked. It checks only the top-level `tenant_id` of each row: a
  nested object of another tenant inside a row of the right tenant passes. It returns
  parsed copies of the checked bytes.
- A lease is bound to (request id, tenant, key). Leases cover only handlers that opened
  one with `with_lease`.
- The opener of a key is trusted for its tenant, `original` and facts.
- The CakeML refund binary runs on macOS ARM64 only.
- The kill tests use SIGKILL. A SIGKILL is not a power loss.
- Whoever can write the store folder is trusted. FNV-1a-128 is not cryptographic.
- A helper process runs while the store lock is held (up to 10 s for the binary, 30 s
  for Node or ssh-keygen).
- `end_to_end=false`.
