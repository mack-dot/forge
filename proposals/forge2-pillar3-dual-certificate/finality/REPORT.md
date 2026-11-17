# Booking finality: untrusted solvers, proved checker in the minter, signed receipts (Round 3, U431)

Status: research test. `end_to_end=false`. Not part of the gate. No new
approved intent: the batch booking problem is still this experiment's
own (see `../REPORT.md`).

## Path

1. An untrusted solver (25 functions, copied mechanically from
   `../benchmark/bench.ts` by `extract_solvers.py`) proposes an
   allocation `x` and dual values `y`, `z` for a batch `(A, c, w)`.
2. `minter3.ts` runs as its own process and holds the Ed25519 private
   key in memory. Its only decision is the compiled Dafny method
   `BookingDualCert.VerifyCertifiedBooking` (`ensures ok == Accepts`).
   It signs a claim: checker hash, minter hash, batch id, batch hash,
   allocation, gap `alpha_bps`, value, certificate hash.
3. `sink3.ts` holds only the public key. One SQLite transaction checks
   the signature, the pinned hashes, that the batch is pending, that
   the stored batch hash is the signed one, and the gap policy.
4. `verifyReceipt` needs only the public key, the batch and the
   receipt.

## What a receipt means, and what carries it

Proved in Dafny (`../BookingDualCert.dfy`, 46 verified, Round 1):
`Accepts` implies that `x` is feasible and that
`(10000 - alpha) * value(alt) <= 10000 * value(x)` for every feasible
`alt`. With `alpha = 0`, `x` is a global optimum of the integer
problem. A receipt therefore says "the proved check accepted this
allocation for the batch with this hash", PROVIDED the unproved parts
are right: the Dafny JavaScript back end and runtime, the wrapper
(shape check, conversion, canonical JSON, signing call), Node, OpenSSL,
process isolation, SQLite.

## Test (finite): `run_integrated.ts`, attempts 0001 and 0002, exit 0 and 0

| Quantity | Value |
| --- | --- |
| Solver functions × batches | 25 × 46 = 1,150 proposals |
| Proposals by brute-force reference | 138 overbooked, 167 feasible but not optimal, 845 optimal |
| Mint requests (gaps 0 and 2000 bps) | 2,300 |
| Signed = committed = receipts that verify | 1,227 |
| Overbooked proposals signed | 0 |
| Non-optimal proposals signed at gap 0 | 0 |
| Committed allocations outside the proved bound (reference check) | 0 |
| Optimal proposals REFUSED at gap 0 | 299 |
| Dafny runs in the suite | 0 (checker module hash equals the Round 2 build record) |
| Committed counts per solver equal the Round 2 benchmark | yes, both gaps |
| Attacks | 12 of 12 as expected |

Attacks: allocation changed after signing; receipt moved to another
batch; receipt used twice; batch stored with other capacities; other
signing key; gap 2000 offered to the zero-gap sink; four malformed or
overbooking mint requests; raw change of a stored allocation (the
public receipt check fails).

## Limits

1. 299 optimal proposals got no signature at gap 0. The check is sound,
   not complete: the solver's dual values were too weak, or the batch
   has no zero-gap integer certificate. A system needs a fallback.
2. Several different certified allocations can exist for one batch.
   The sink commits the first. An attacker with raw database access
   can exchange one certified allocation for another certified one.
3. The minter does not know the database. The sink binds the receipt
   to the stored batch.
4. A finite test: 25 functions, 46 batches of at most 14 requests.
