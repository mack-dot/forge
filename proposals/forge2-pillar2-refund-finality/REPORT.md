# Round 2 task 3 — refund minter (Ed25519) and SQLite sink: adversarial test (U420)

Date: 2026-11-17. Research code under `proposals/`. FINITE TEST. Nothing
here is a proof about a program. No protected file changed.
`end_to_end=false`.

## What was built

- `minter.ts`: a separate operating-system process. It creates the
  Ed25519 key pair in its own memory and prints only the public key. It
  signs a claim only when the Dafny-generated refund kernel
  (`impl/Refund.dfy` compiled by the gate to
  `build/refund-generated/model.cjs`, SHA-256 `d462e123…`) authorizes
  exactly that refund, and the claimed post-state and intent are the
  ones that follow.
- `sink.ts`: holds only the public key and two pinned hashes (refund
  spec lock, minter files plus kernel). One commit is one SQLite
  `BEGIN IMMEDIATE` transaction: signature check, pinned ids,
  compare-and-swap on the stored state hash, request-id uniqueness,
  then state, settled row and exactly one outbox row. `audit()` checks
  the whole database with the public key only.
- `common.ts`: canonical encoding (no JSON numbers; money as decimal
  strings) and the signed payload. Every claim field is bound by value
  or by hash.
- `run_suite.ts`: the suite. `commit_cli.ts`: one commit in its own
  process (for the concurrency cases).

## Result (`node --import tsx run_suite.ts <dir>`)

| Run | Suite exit | Valid sequence | Attacks | Unauthorized settlements | Audit of the untampered database |
| --- | --- | --- | --- | --- | --- |
| attempt-0001 | 0 | 4 of 4 committed, one effect each | 38 of 38 as expected | 0 | clean |
| attempt-0002 (repeat) | 0 | same | same outcomes per case | 0 | clean |

Attack classes (38 cases): A direct bypass without a valid signature
(5); B forgery with everything the sink holds, including the public key
used as a seed and every stored signature (5); C replay (3); D stale
state (2); E other spec lock or other minter (4); F proposals that the
approved refund relation rejects, for example over-refund, disallowed
reason, disabled refunds, wrong post-state, tampered intent (10); G
tampering after signing and encodings, for example numbers beyond 2⁵³
(7); H concurrency across processes: one claim from ten processes gives
exactly one effect; two valid claims on one pre-state give exactly one
commit (2).

Two cases show that the sink's own checks are needed: the minter signed
a second claim for an already settled request id, and a claim for a
stale pre-state. The sink rejected both.

## A compromised sink database (reported separately)

The sink cannot sign: it has no private key. An attacker who can write
the database file can still change rows. That is NOT prevented. The
public-key audit detected 4 of 4 tamper cases (unsigned row, overwritten
state, edited outbox amount, extra outbox row).

## Evidence classes (kept apart)

| Part | Evidence | Scope |
| --- | --- | --- |
| Protocol logic | Dafny model, 22 verified (U415) | a model, under four named assumptions |
| Refund decision | `impl/Refund.dfy` source proof by the refund gate (Stage 8) | the Dafny source; not the generated JavaScript |
| This minter, sink, encoding | 38 attack cases and one valid sequence, twice | finite test |

## Remaining trusted base (unchanged by this test)

Operating-system process and key isolation (the same user can read the
minter's memory); Ed25519 as implemented in Node/OpenSSL; SQLite
transactions; Node, tsx and the Dafny-to-JavaScript compiler; the
adapter between JavaScript values and the kernel; the canonical
encoding; the hash function. The race winner in case H is not
deterministic, so the final remaining amount differs between runs.

## NOT RUN

A minter compiled by CakeML; any proof of `minter.ts` or `sink.ts`;
key storage outside process memory; crash and power-loss tests.

## Version 2 (Round 3, U428): proved decision core and checked dispatcher

Status: research test plus one Dafny proof. `end_to_end=false`. Nothing
here is part of the gate. The version 1 files and records above are
unchanged.

### What is proved, and what is not

| Part | Status |
| --- | --- |
| `core/RefundMinterCore.dfy`, method `Decide` | PROVED at source level with the pinned Dafny (exit 0, 7 verified, audit 0 findings). A `Sign` result satisfies `Authorizes`: the approved refund specification makes the request eligible, the post-state is the pre-state minus the amount, the intent is the bound one. A `Refuse` result means that no post-state and intent are authorized. It calls the gate-verified `Refund.Assess`. |
| Two wrong cores (signs everything; keeps the remaining amount) | REJECTED by Dafny (exit 4 each) |
| Rule "remaining decreases by the amount" | this experiment's choice; the approved specification has no stored state |
| `dafny build --target js` and the Dafny JavaScript runtime | NOT proved |
| `minter2.ts`: shape check, text and number conversion, canonical JSON, Ed25519 call, the rule "one signed request per pre-state hash" | NOT proved (tested) |
| `dispatcher.ts`, `sink.ts`, SQLite, Node, OpenSSL, process isolation | NOT proved (tested) |

The caller of minter version 2 sends only the pre-state and the
request. Post-state and intent come from the core.

### Dispatcher

`dispatcher.ts` checks each outbox row before the effect, with the
public key only: canonical claim, pinned ids, Ed25519 signature, the
outbox intent is the signed intent, the claim continues the chain of
dispatched claims (start: the pinned initial state hash), and the
request id is not in the dispatcher's own ledger. The ledger is a file
outside the database. The ledger line is written before the effect: at
most once.

### Test (finite): `run_suite_v2.ts`, attempts 0001 and 0002, exit 0 and 0

31 rows, 0 failed, in both runs. Records: `records/v2/`.

- Minter: 84 (state, request) pairs against the gate-built kernel, 0
  disagreements (11 signed, 73 refused). Seven malformed inputs
  refused. A caller-supplied post-state and intent are ignored.
- Dispatcher, 12 cases with raw row changes through a second SQLite
  connection: changed outbox amount; inserted claim signed by another
  key; outbox row without a settled row; consistent rewrite of claim,
  hash, outbox and state with the old signature; copy under a new
  request id; rows re-inserted after dispatch; swapped signatures; a
  valid claim of another charge; reversed order; deleted settled row;
  a broken dispatcher ledger; crash between ledger line and effect.
  Result: 0 unauthorized effects through the checked dispatcher. The
  unchecked control dispatcher sends unauthorized effects in 8 of
  these cases, so the attacks are real.
- Three cases hold back valid effects (swapped signatures, deleted
  settled row, broken ledger). That is loss of availability, not an
  unauthorized effect.
- Crash case: the first effect is lost and never sent twice. A person
  must reconcile it.

### Limits

1. "Authorized" in this test means: signed by the minter for exactly
   the dispatcher's chain head and not sent before. It does not mean
   "the row that the sink committed".
2. Case D14: with the minter rule "one signed request per pre-state"
   switched OFF, an attacker with raw database access can insert a
   second signed claim for the same state in front of the committed
   one. The dispatcher then sends that one (800) and holds back the
   committed ones. No effect is outside definition 1 and the sum stays
   within the remaining amount, but the outside world and the sink's
   history differ. With the rule ON (default, case D13) the minter
   refuses the second claim. The rule is in unproved wrapper code and
   lives only as long as the minter process.
3. Assumed, not checked: the dispatcher's ledger file, the dispatcher
   process and its pinned configuration are out of the attacker's
   reach; the minter key does not leak.
4. A finite test. No statement about all attacks.
