# Master idea, Pillar I, item F1.4 — cumulative diff against the approved base: analysis by reading (U416)

Date: 2026-11-17. Reading only. NO test was run. No file changed.

## Question

The source text asks for a new `gate/anchor_diff.py` so that policy
obligations come from the whole diff against the approved base, not
from the last commit ("split-edit" attack: commit 1 changes a helper or
a policy scope, commit 2 changes the implementation).

## What the existing gate does (read in `gate/pr_check.py`, `gate/incremental.py`, `gate/core.py`)

- `gate/pr_check.py` takes `base_sha` and `head_sha` from the pull
  request event. It requires that the trusted checkout is exactly
  `base_sha` on `main` and the candidate checkout is exactly
  `head_sha`, both with clean tracked files. It then runs the TRUSTED
  `gate/incremental.py` from the base on the candidate tree.
- So the unit that is checked is the whole head tree against the base.
  The gate does not look at single commits. Splitting an edit across
  commits inside one pull request changes nothing for the gate.
- `gate/incremental.py` computes a manifest of protected paths:
  directories `gate`, `policy`, `spec`, `toolchain`, `schemas`,
  `.github`; files `spec.lock`, `AGENTS.md`. This list is wider than
  the hard-rule list in `ROADMAP.md` (which names `spec/**`,
  `spec.lock`, `policy/**`, `gate/**`).
- `gate/core.py` has an explicit trusted input list and rejects when
  the trusted input set or its digests differ (`TRUSTED_INPUTS`).

## Reading-level conclusion (NOT a tested result)

- Split across commits in one pull request: not applicable to this
  design. No per-commit obligation exists.
- Split across two pull requests: the first one must change a protected
  path to change policy scope or gate behaviour; that is the case the
  protected manifest and the approval records exist for. I did not
  trace how a changed protected path in the candidate is judged, and I
  did not run a two-pull-request simulation.
- A helper outside the protected list that changes what the gate
  checks: I found none by reading the three files, but I did not audit
  every import of every gate module.

## Recommendation

Do not add `gate/anchor_diff.py` now. First run a negative control
(NOT RUN): a local two-step simulation in a scratch clone, with the
trusted gate from the base, that (1) changes a protected path in the
candidate and expects a rejection, and (2) changes only a non-protected
helper and shows that no gate decision depends on it. Add a new gate
module only if that control finds a gap.

## Uncertainty

Everything above is from reading about 260 lines of gate code. The
Stage 11 obligations logic and the approval flow were not re-read in
full. The Linux CI path was not run.

## Control run (Round 2 task 2, U422): the reading-level conclusion is now measured

`run_control.py` builds candidate trees and runs the UNCHANGED
`gate/incremental.py --profile local` with the trusted side at `HEAD`
(`c430a5c1`, protected paths clean). attempt-0001: scenario exit 0,
16 cases, 0 evasions.

| Case group | Gate exit | Gate reason |
| --- | --- | --- |
| benign implementation edit only (positive control) | 0 | ACCEPTED |
| buggy implementation only | 1 | VERIFICATION_REJECTED, Dafny exit 4 |
| "step 1 alone" (implementation unchanged): policy scope, gate code, toolchain pins, schema, `.github`, `AGENTS.md`, contract binding (7 cases) | 1 each | UNAPPROVED_PROTECTED_CHANGE |
| both halves in one head tree: policy scope, gate code or pins edit plus buggy implementation (3 cases) | 1 each | UNAPPROVED_PROTECTED_CHANGE |
| weakened spec with recomputed lock plus buggy implementation | 1 | UNAPPROVED_PROTECTED_CHANGE |
| the same plus an approval record forged inside the candidate | 1 | UNAPPROVED_PROTECTED_CHANGE (approvals are read from the trusted side) |
| non-protected evidence metadata edit plus buggy implementation | 1 | VERIFICATION_REJECTED |
| non-protected evidence metadata edit plus benign implementation | 0 | ACCEPTED (metadata is not an input) |

Result: the first half of a split edit cannot become the new base,
because every protected-path edit is rejected on its own. No new gate
module is added. `gate/anchor_diff.py` is NOT needed for these cases.

Limits: 16 cases; the local profile; the GitHub wrapper
`gate/pr_check.py` was not run (it needs a pull-request event); the
booking and refund gates were not driven; only the ledger PR gate.

Consequence for gate changes: the same rule rejects EVERY change under
`gate/` or `toolchain/` in a pull request, also an owner-approved one
(only a spec plus lock change has an approval path). A gate change such
as the print-effects diff must enter `main` by the owner's own merge
outside this check.
