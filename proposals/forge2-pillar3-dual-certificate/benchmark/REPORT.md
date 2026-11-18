# Round 2 task 4 — 25 untrusted solver versions against the Dafny-verified checker (U421)

Date: 2026-11-17. FINITE BENCHMARK of research code. The only proved
part is the checker (`../BookingDualCert.dfy`, F3.1). `end_to_end=false`.

## Setup

- `build_checker.py`: pinned Dafny, gate options. `dafny verify` exit 0
  (46 verified, 0 errors) in 3.1 s; `dafny build --target js` exit 0.
  Module `build/round2-dualcert/model.cjs`, SHA-256 `e705ec49…`; source
  SHA-256 `55e7df9f…`. Record: `records/build-record.json`.
- `bench.ts`: 46 deterministic instances (40 interval-scheduling
  instances, 6 general 0/1 instances including a triangle), 25 solver
  functions, two gaps (0 and 2000 basis points). The only accept
  decision is the compiled Dafny predicate `Accepts`. Ground truth for
  the cross-checks is an independent brute force over all subsets.
- "25 versions" are 25 distinct solver functions in one file. They are
  not 25 git commits.

## Result (`node --import tsx bench.ts <dir>`, attempt-0001, exit 0)

| Group | Versions | Accepted at gap 0 (of 46) | Accepted at gap 2000 | Infeasible proposals accepted |
| --- | --- | --- | --- | --- |
| naive greedy | 1–5 | 0, 0, 0, 0, 2 | 0, 2, 2, 2, 20 | 0 |
| buggy (overbooking, negative duals, empty dual, double booking) | 6–10 | 0 each | 0 each | 0 of 138 infeasible proposals |
| local search with dual ascent | 11–15 | 17, 19, 20, 24, 24 | 39, 44, 44, 44, 44 | 0 |
| exact rational simplex variants | 16–25 | 44 each | 44 each | 0 |

- Runtime checks: 2,300; mean 91 µs per check.
- Accepted overbookings: 0. Accepts that contradict the brute-force
  optimum: 0 (the theorem says this cannot happen; this is a test of
  the compiled module and the adapter).
- Exact versions: zero-gap certificate accepted on 40 of 40 interval
  instances. On 2 of the 6 general instances no version gets a
  zero-gap certificate; those are rejected at gap 0. This is the
  expected limit: the check is sound for every shape, complete only
  where an integer optimal dual exists.

## Comparison with Stage 6 (different quantity; stated as such)

Stage 6 (`docs/reuse-benchmark.md`): 25 proof edits cost 269.713 s cold
and 175.828 s with dependency reuse, because each edit changed a proved
file. Here no solver version changes the proved file, so the number of
Dafny runs per solver version is 0. The cost that remains is the
one-time verification (3.1 s) and one runtime check per answer (about
91 µs). The two numbers measure different things: Stage 6 measures
re-proving changed proofs; this measures checking answers.

## Limits

One run. Small instances (at most 14 requests). The solvers, the
harness, the JavaScript adapter and the Dafny-to-JavaScript compiler
are not proved. A rejected answer needs a fallback; none is built. The
approved `BookingSpec` has no batch, value or optimum.
