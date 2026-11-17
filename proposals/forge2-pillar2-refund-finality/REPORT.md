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
