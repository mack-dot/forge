# Coverage contract for the ledger PR gate (proposal v1; not installed)

Owner authorization 2026-10-30: a minimal, separately reviewed coverage-soundness
repair. This document defines what the PR gate may claim. The code in
`proposals/coverage-soundness/candidate/` is the candidate that enforces it.

## 1. The defect

`gate/incremental.py` compares the trusted base and the PR candidate on exactly
three files (`impl/Ledger.dfy`, `spec/LedgerSpec.dfy`, `gate/ContractBinding.dfy`)
plus the protected manifest (`gate/`, `policy/`, `spec/`, `toolchain/`, `schemas/`,
`.github/`, `spec.lock`, `AGENTS.md`). A PR that changes any other file is invisible
to it. The ledger proof then passes, the gate prints `ACCEPTED: C1 C2 C3 C4 C5` and
the PR report publishes "Forge: accepted" for the whole revision. Reproduced in
`results/coverage-repair/phase1-repro-0001/` for the four frozen Stage 10 cases.

## 2. Outcomes

The gate returns exactly one terminal outcome per run. Each has one exit code.

| Outcome | Exit | Meaning | Evidence written |
| --- | ---: | --- | --- |
| `VERIFIED` | 0 | Every required claim is established by the checker on the exact candidate bytes, and every change in the PR is covered (section 4). | yes |
| `REJECTED` | 1 | A required verification, binding, or policy obligation fails (unchanged reasons: `VERIFICATION_REJECTED`, `AUDIT_REJECTED`, `SOURCE_SCOPE`, `SPEC_LOCK`, `UNAPPROVED_PROTECTED_CHANGE`, `INPUT_CHANGED`, …). | no |
| `NOT_ESTABLISHED` | 2 | The check could not finish: tool, dependency pin, toolchain, I/O or revision error. | no |
| `UNSUPPORTED` | 3 | Every required claim is established, but at least one change is not covered. Not a defect finding. | no |

`UNSUPPORTED` is new. `REJECTED` and `NOT_ESTABLISHED` keep their old reasons and
exit codes. `VERIFIED` keeps exit 0 but is strictly narrower than the old `ACCEPTED`.

## 3. The invariant

```
Verified(change) =>
    ProofValid(change)            Dafny audit and verifier pass on the candidate bytes;
                                  required obligations present; two snapshots; cold baseline
AND SpecApproved(change)          spec/spec.lock unchanged, or changed exactly as an
                                  approval record in the trusted base states
AND ArtifactBound(change)         evidence artifact = digest of the candidate source manifest;
                                  trusted inputs re-hashed after the check
AND CoverageEstablished(change)   section 4
AND AuthorizationValid(change)    the trusted base is obtained outside the PR; protected
                                  inputs change only with a bound approval
```

The first three conjuncts and the last are the existing gate, unchanged. The repair
adds `CoverageEstablished` and makes its failure a distinct outcome instead of
silently passing.

## 4. CoverageEstablished

Let `B` be the trusted base tree and `C` the candidate tree. The inventory of a tree
is the map from every path to `mode || SHA-256(content)`, where a symbolic link is
recorded by its target text and never followed. Under git, the inventory lists
tracked paths and requires a clean tracked tree; otherwise it lists every file
except the base's untracked folders (`.git`, `.toolchain`, `build`, `node_modules`,
`TestResults`). Both inventories are taken before the check and again after it;
a difference is `REJECTED: INPUT_CHANGED`.

`Changed(B, C)` is the set of paths whose inventory entries differ (added, deleted,
or modified).

`Established(B, C)` is the set of paths whose behavior the check itself
re-establishes for the candidate bytes:

- `impl/Ledger.dfy` always (the checker verifies the candidate's bytes);
- `spec/LedgerSpec.dfy` and `spec.lock` only when an approval record in `B` binds
  their exact candidate digests (`gate/approval.py`).

`Dependents(C, p)` is the set of readers of `p` whose claims this check does not
re-establish:

1. every tracked `.dfy` file in `C` that `include`s `p` directly or transitively
   (parsed from `include "…"` lines, resolved relative to the including file; a
   symbolic link is never read), except the ledger scope files and
   `gate/ContractBinding.dfy`, which the check itself verifies;
2. every approved `spec/**/spec.lock` in `B` that pins `p`'s digest;
3. the declared consumers of `p` listed in `gate/coverage.py` (`DECLARED_CONSUMERS`):
   the booking gate, the TypeScript model gate, the model build, the Stage 5 witness
   tools, `tests/Basic.dfy` (imports `Ledger` without an include) and the committed
   `evidence.json`. This list is part of the trusted gate, reviewed with
   it; the PR cannot change it (protected manifest).

```
CoverageEstablished(B, C) <=>
    Changed(B, C) ⊆ Established(B, C)
AND forall p in Changed(B, C) ∩ Established(B, C): Dependents(C, p) = ∅
```

Anything else is `UNSUPPORTED`, with one finding per violation:

- `UNCOVERED_CHANGE path`: the path changed and no claim established here covers it;
- `DEPENDENT_NOT_REESTABLISHED path (reader)`: the path is covered, but `reader`
  builds a claim on it that this check did not re-run.

The gate writes the complete assessment to `operation.json` (`coverage`: inventory
method, changed paths, established paths, findings). `UNSUPPORTED` writes no
evidence file.

## 5. What this does and does not establish

- `VERIFIED` means: the ledger claims C1–C5 hold for the candidate's `impl/Ledger.dfy`,
  and the PR changes nothing else. It is the only acceptance.
- The gate does not decide whether an uncovered change is correct. `UNSUPPORTED`
  is a statement about evidence, not about defects.
- A PR that changes `impl/Ledger.dfy` is `UNSUPPORTED` today, because the
  TypeScript model, the Stage 5 witness and the committed `evidence.json` build
  claims on it that the PR gate does not re-run. This is conservative and
  intended: those claims become stale, and a separate run of their own gates is
  the way to re-establish them. The old gate called such a PR accepted.
- Coverage is by exact bytes. Renaming a file is a deletion plus an addition, both
  uncovered. Changing only a file mode (for example making a file executable) is
  a change.
- The declared-consumer list is a trusted, reviewed allow-list of *readers*, not of
  files that may change. It can only add findings; it never makes a change covered.
  Missing entries are the main residual risk (section 7).

## 6. Decision procedure (state machine)

```
START
 → pins, toolchain, revision checks fail        → NOT_ESTABLISHED (2)
 → protected change without bound approval      → REJECTED (1)
 → source scope / spec lock / audit / verifier  → REJECTED (1)
 → evidence validation, input re-hash fails     → REJECTED (1)
 → coverage findings non-empty                  → UNSUPPORTED (3)   [no evidence]
 → otherwise                                    → VERIFIED (0)      [evidence written]
```

Coverage is assessed after the proof and after the input re-hash, so an
`UNSUPPORTED` result always rests on a complete, successful ledger check. Any
exception not mapped above is `NOT_ESTABLISHED`. The CI wrapper
(`gate/pr_check.py`) accepts exit 3 and passes the outcome to the report job, which
publishes `UNSUPPORTED` as a failing status with the finding list.

## 7. Assumptions and residual risks

1. The trusted base is obtained outside the PR (existing assumption).
2. Git inventories are trusted to list every tracked path; a path that git ignores
   in the candidate is invisible. In CI both trees are fresh clones.
3. The Dafny `include` scan is a byte-level regular expression
   (`^\s*include\s+"…"`), not a parser. A line-commented `// include` does not
   count; an include inside a block comment does (over-approximation). It misses an
   include preceded by a byte-order mark or written with an absolute path; the
   repository has neither, and both would be odd in a reviewed PR.
4. `DECLARED_CONSUMERS` must list every non-Dafny reader of the ledger files. The
   adversarial review checked the repository for readers; a future reader added
   outside the list would make its claims stale without a finding. Adding a reader
   is a trusted-gate change.
5. The gate does not run the TypeScript, booking or refund gates. It reports that
   their claims are not re-established; it does not claim they fail.
6. Coverage does not reach compiled artifacts, deployment or runtime. `end_to_end`
   stays `false`.

## 8. Trusted computing base change

Added: `gate/coverage.py` (inventory, change set, dependents, assessment).
Changed: `gate/incremental.py` (outcome mapping, coverage call, full-tree replay
input), `gate/pr_check.py` (exit 3), `gate/post_pr_report.py` (UNSUPPORTED report).
The implementation lock gains these PR-gate files, which it did not bind before.
Exact digests are in the PR.
