# Product feasibility assessment (Stage 11, Phase 7; proposal, not a plan of record)

Measured numbers are in `results/stage11/eval-0003/report.md` and are quoted in REPORT.md.
This document states what the measurements mean for an engineering team. Where the
answer is "not yet", it says so.

## What Forge does today, in one sentence

For a GitHub PR against a repository whose critical code has approved formal claims,
Forge re-runs exactly the proofs and tests those claims depend on, refuses to say
anything about code no claim covers, and publishes one of four outcomes with a
per-claim scope table.

## First ideal customer

A small engineering organization that already uses AI coding agents to produce PRs in a
repository with a **security-sensitive core of modest size** (a payments ledger, an
authorization boundary, a protocol parser), where that core already has, or can get,
machine-checked specifications. Not: a large codebase with no formal claims, or a team
unwilling to maintain specifications.

## Installation friction (today)

| Item | State |
| --- | --- |
| Formal claims | Must exist as Dafny specifications with approval records. Forge supplies no spec authoring. |
| Toolchain | Pinned Dafny/Z3 (2.6 GB) and pinned Node packages; pins are recorded for macOS arm64. Linux pins exist for the Python validator only. |
| CI | The workflow runs the ledger PR gate on Linux; dependent obligations (TypeScript model, booking, refund) cannot run there until Linux pins for node and per-gate profiles exist (CONTRACT.md §5). |
| Repository layout | Fixed paths (`impl/`, `spec/`, `gate/`); the obligation registry is hand-declared per gate. Adding a new claim is a trusted-gate change under human review. |

Time to first useful VERIFIED PR for a new repository: not measured; estimated weeks
of specification work before the gate can cover any change. For this repository it is
the time of one PR check (see latency).

## Which PRs become VERIFIED

Changes to files that are inputs of at least one obligation, when every affected
obligation passes: `impl/Ledger.dfy` (with regenerated `evidence.json`), `ts/ledger.ts`,
`ts/types.ts`, `impl/Booking.dfy`, `impl/Refund.dfy`, `ts/refund.ts`,
`tests/stage5/SuccessfulExecution.dfy`, `tests/booking/SuccessfulExecution.dfy`,
`spec/booking/BookingSpec.dfy`, and approved spec changes (today blocked by fixtures
in `bugs/` that no obligation covers).

Everything else is UNSUPPORTED: documentation, new tests, new modules, `app/`,
`results/`, build configuration. For a real team this is the dominant cost: most PRs
touch at least one uncovered file. A product would need either (a) an explicit,
reviewed policy that some paths need no evidence (a change to the trust model, not
made here) or (b) obligations for those paths.

## Cost per correctly accepted change

Local, on an Apple M1 Pro: a ledger change costs about 40 s wall cold and about half
that warm (cached unaffected obligations); CPU about 10–40 s. In dollars this is cents
of compute per PR on a CI runner once Linux execution exists. Human effort per VERIFIED
PR: zero at check time; the human review that merges is unchanged by Forge.

## Does it reduce review burden?

Not yet measurably. What it removes is a class of mistakes: a reviewer no longer has to
remember which proofs a ledger change invalidates, and a wrong TypeScript ledger can no
longer pass because its proof-side twin is fine. What it adds: a PR that touches a doc
and code is UNSUPPORTED until split. No team has used it; the claim "reduces burden" is
untested.

## Comparison with existing tools

- GitHub code scanning (CodeQL, Dependabot): finds known-pattern defects in any
  repository with no specification work; Forge finds nothing without claims but, where
  claims exist, establishes behaviour rather than absence of patterns.
- Formal verification in CI (Dafny/Lean/Coq checks run on every PR): proves the same
  properties, but re-checks everything and says nothing about which files the proof
  covers; Forge adds the coverage boundary and the dependency-aware re-check.
- AI review agents: comment on anything; their output is advice, not evidence. Forge's
  output is a checker result bound to exact bytes.

Forge is therefore not a new category. It is a coverage-aware verification gate: a thin,
auditable layer that decides *which* existing checks a change requires and *what the
result may be called*.

## What a team would reasonably pay for

Nothing for the current repository-specific gate. A team would pay for: (1) a generic
obligation registry that reads existing checkers' input manifests; (2) Linux-native
pinned toolchains; (3) the UNSUPPORTED/VERIFIED report in the PR; (4) the evidence
bundle and cache. Those are the next engineering items, and none of them is research.

## Honest status

Soundness (criterion 1) has evidence: no false accept in the frozen evaluation and the
adversarial review's exploits are closed; residual risks are listed in CONTRACT.md.
Useful acceptance (criterion 2) is demonstrated for this repository's covered paths.
Explanation (criterion 3) is in the PR report. Speed (criterion 4) is acceptable locally
and not available in CI. Reproducibility (criterion 5) is shown over two runs on one
host. The product is a credible prototype for one repository, not a deployable service.
