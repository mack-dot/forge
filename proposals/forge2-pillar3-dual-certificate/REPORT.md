# Master idea, Pillar III, item F3.1 — integer dual-certificate check (U410)

Date: 2026-11-17. Diagnostic outside the gate. NOT an approved spec. No
protected file changed. No evidence bundle. Not committed.
`end_to_end=false`. Pinned Dafny with the gate's options. Raw logs:
`results/forge2-pillar3-20261117/attempt-0001..0002`.

## 1. What is proved (`BookingDualCert.dfy`; checker exit 0; 46 verified, 0 errors)

Problem: maximise `Dot(w, x)` subject to `A x ≤ c`, `x ∈ {0,1}ⁿ`, over
mathematical integers. No floating point.

    Accepts(A, c, w, x, y, z, alpha_bps) ⇔
      shapes agree ∧ alpha_bps ≤ 10000 ∧
      Feasible(A, c, x) ∧                    -- x is 0/1 and no row exceeds its capacity
      DualFeasible(A, w, y, z) ∧             -- y ≥ 0, z ≥ 0, Aᵀy + z ≥ w
      (10000 − alpha_bps) · (Dot(y, c) + Sum(z)) ≤ 10000 · Dot(w, x)

- `WeakDuality`: for every feasible `x`, `Dot(w, x) ≤ Dot(y, c) + Sum(z)`.
- `Quality` and `QualityAll`: if `Accepts(…)`, then `x` is feasible and
  for EVERY feasible `alt`,
  `(10000 − alpha_bps) · Dot(w, alt) ≤ 10000 · Dot(w, x)`.
  With `alpha_bps = 0`, `x` is a global optimum.
- `VerifyCertifiedBooking` returns exactly `Accepts(…)`.

The proof uses integer algebra only. It holds for every integer `A`,
`c`, `w`. No solver, no linear-programming theorem and no
total-unimodularity fact is used or trusted. `dafny audit`: exit 0,
0 findings.

## 2. Witnesses (proved lemmas on one instance with a real conflict)

Two slots of capacity 1. Request 0 (value 3) needs both. Requests 1 and
2 (value 2 each) need one slot each.

| Lemma | Statement |
| --- | --- |
| `OptimumAcceptedWithZeroGap` | `x = [0,1,1]`, `y = [2,2]`, `z = [0,0,0]`, gap 0: accepted |
| `OverbookingRejected` | `x = [1,1,0]`: rejected at gap 0 and at gap 10000 |
| `InvalidDualRejected` | `y = [1,1]` (too small) and `y = [2,−1]` (negative): rejected |
| `SuboptimalRejectedAtZeroGapAcceptedAtQuarterGap` | `x = [1,0,0]` (value 3 of 4): rejected at 0, accepted at 2500, rejected at 2499 |
| `FractionalAllocationRejected` | `x = [0,2,0]`: rejected |

## 3. Negative controls for the proof

| Control | Expected | Checker exit | Result |
| --- | --- | --- | --- |
| `fixtures/NoUpperBoundOnAllocation.dfy`: the bound without `x ≤ 1` | reject at the planted lemma | 4 (47 verified, 1 error) | PASS |
| `fixtures/QualityWithoutDualCheck.dfy`: quality from a check that skips dual feasibility | reject at the planted lemma | 4 (48 verified, 1 error) | PASS |

A rejection here is "could not be proved". Both planted statements are
also false by simple examples (`z = [1], x = [2]`; any `y = 0, z = 0`).

## 4. Limits

- A certificate must exist. For shapes without an integer optimal dual
  the check can reject an optimal answer. Existence is not proved here
  for any class.
- It certifies one objective on one batch. It says nothing about the
  solver, and nothing about the program that will run this check.
- `Accepts` is a compilable predicate. It was NOT compiled or run.
- The approved `BookingSpec` has no batch, value or optimum. Use of
  this check as Forge evidence needs a new approved spec and a new
  evidence method (`policy/`, `schemas/`: protected).
- One passing run. Same machine.

## 5. Actual exits

| Attempt | Scenario exit | Note |
| --- | --- | --- |
| attempt-0001 | 1 | `DotLinearFrom` out of resource (nonlinear arithmetic); all other lemmas verified |
| attempt-0002 | 0 | explicit calculation added; three cases pass |

NOT RUN: compile and run; solver benchmark (F3.2); gate integration.
