# Stage 4 change loop: current implementation

Stage 4 is incomplete. The incremental gate works for the fixed ledger layout.
Real implementation-edit and unapproved-spec PR checks passed their EXITs.
The exact fee proposal and revision-bound spec approval remain pending.

Run the gate from a trusted checkout. Pass a complete candidate checkout as data:

```sh
python3 gate/incremental.py --candidate /path/to/candidate \
  --evidence build/change-evidence.json --work build/change-run
```

Use a new work directory for each run. The gate preserves raw checker output.
It removes stale evidence before checking. A rejected candidate emits no accepted
evidence. The candidate's Python, scripts, and workflow files never execute.
Accepted runs save exact candidate inputs in a directory named by their content
digest under `build/change-inputs/`. The evidence's reproduction command uses
that directory and allocates a new work directory automatically. Execute it
from the same trusted checkout with the recorded toolchain. The local controls
run this exact command and compare the resulting evidence bytes.
For the archived example on a fresh checkout, first run
`python3 scripts/check_stage_4_local.py` to reconstruct its inputs.

The current path rejects any difference in `spec/**`, `spec.lock`, `gate/**`,
`policy/**`, toolchain pins, schemas, workflow configuration, or project
instructions. This is an external baseline check. Editing both a spec and its
lock cannot authorize a change. There is no spec-approval bypass or approval-label
override. The approved-spec path still needs implementation after the concrete
fee proposal and human approval.

## Established checker and reuse

The gate audits both versions with Dafny and compares each report with the
trusted empty audit baseline. It then invokes the pinned Dafny 4.11.0 legacy
snapshot mode at cache level 1. Dafny fully verifies the baseline first, then
processes the candidate in the same process. There is no imported result cache.

Dafny creates member checksums. Bundled Boogie 3.5.5 collects dependencies and
chooses whether a result can be reused. Forge checks the command result and the
coverage reported by the checker. It does not build a language parser,
dependency verifier, or solver wrapper that decides program correctness.

The staging files include exact copies of the source and contract-binding
harness. Both snapshots receive both inputs. This is necessary because the
upstream snapshot discovery code can omit an input that lacks a numbered
snapshot. The gate requires two complete verification summaries and all twelve
ledger obligations. It rejects skipped, missing, or inconsistent coverage.

Relevant pinned upstream code:

- [Dafny snapshot driver](https://github.com/dafny-lang/dafny/blob/v4.11.0/Source/DafnyDriver/Legacy/SynchronousCliCompilation.cs)
- [Dafny checksum generation](https://github.com/dafny-lang/dafny/blob/v4.11.0/Source/DafnyCore/Verifier/BoogieGenerator.cs)
- [Boogie dependency collector](https://github.com/boogie-org/boogie/blob/v3.5.5/Source/ExecutionEngine/Caching/DependencyCollector.cs)
- [Boogie cache lookup](https://github.com/boogie-org/boogie/blob/v3.5.5/Source/ExecutionEngine/Caching/VerificationResultCache.cs)

## Scope and limits

All five claims share `Ledger.Apply`. A body edit to that member causes both of
its obligations to be checked. The claims table reports that shared granularity.
It does not claim five independent proof runs. Helper contracts can invalidate
the Apply proof. A broken helper body must also reject the entire candidate,
even when the Apply obligation itself is reused.

The cache is part of the trusted checker. Its internal checksums use MD5. MD5 is
not a security-grade artifact hash. The evidence explicitly assumes that no
cache-checksum collision occurs among the run's inputs. This does not establish
protection against an adversarial cache collision. User attributes are excluded
from this initial implementation scope. Artifact and baseline identities use
SHA-256. The default full gate remains available without this cache assumption.

Upstream cache entries expire after an idle interval. Work counts can therefore
change under a delayed run. The canonical evidence contains the checked scope
and input identities, but excludes cache hit counts and timing. `operation.json`
and `claims.md` report actual checked/reused counts separately. The baseline
warm-up cost is real and must be included in later measurements.

The selected tests establish specific observed behavior. They do not prove the
cache implementation or complete dependency tracking for arbitrary Dafny code.
Compiler, binary, and deployed-artifact coverage remain unestablished.

## Local validation and CI

`python3 scripts/check_stage_4_local.py` runs real audits, incremental checks,
fresh checks without caching, and protected-change rejection controls. It also
compares canonical evidence from two identical candidate runs. Results are
recorded in `results/stage4-local.json`. The initial test expectation error is
retained in `results/stage4-local-attempt1.json`.

The Linux inventory workflow is a preparation step. It pins actions to commits,
checks the official Dafny archive digest, runs true and false lemma checks,
and records Python, solver, and validator file digests. It runs only trusted
main-branch code and has read-only repository permission. It accepts no PR or
artifact. The Linux profile must be pinned before the PR gate uses it.

The inventory completed successfully in
[run 40397041174](https://github.com/mack-dot/forge/actions/runs/40397041174).
`results/stage4/ci-inventory.json` records the actual commands and exit codes.
The observed Linux profile and wheel hashes are recorded under `toolchain/`.
The incremental gate now selects this fixed profile with `--profile linux`.
The CI installer checks the archive, executable, and installed package digests.

The PR workflow runs trusted base-revision code on an exact candidate revision.
It checks tracked files against each Git commit before and after verification.
The verification job has read-only repository permission. Checker subprocesses
receive an environment allowlist without API credentials. Candidate code is
input to Dafny; candidate scripts and dependencies do not execute.

A separate reporting job reads the receipt as data, checks the revision bindings,
and posts the claims table and `forge/proof-gate` status. This job checks out only
trusted reporting code. A base or head change before reporting requires a new run.
Repository settings must require the status before it can enforce merge policy;
posting a status alone does not prevent a repository administrator from merging.

`scripts/exit_stage_4.py` checks actual GitHub jobs, checker log receipts, source
bytes, published comments, and commit statuses. It records real gate and replay
codes. The EXIT workflow runs it against frozen PR/run references. The first two
cases require one accepted implementation edit and two rejected spec changes.
The approved-spec case remains pending exact-text human approval.

The archived local proof example belongs to trusted revision
`bafcd92533034dc342c53688f058ab8cfbc577a6`. Use that revision to reproduce its
exact evidence. Later changes to protected inputs produce a different evidence
identity even when the ledger source is unchanged.

## Actual PR results

- [PR 1](https://github.com/mack-dot/forge/pull/1): gate exit 0; baseline checked
  12 obligations; candidate checked 2 and reused 10. Literal replay exited 0
  and reproduced identical evidence. Verification and reporting jobs succeeded.
- [PR 2](https://github.com/mack-dot/forge/pull/2): changed spec and matching lock
  rejected with gate exit 1 and `UNAPPROVED_PROTECTED_CHANGE`.
- [PR 3](https://github.com/mack-dot/forge/pull/3): C2 weakening rejected with
  gate exit 1 and the same protected-change reason. Neither rejected PR emitted
  accepted evidence. Both reporting jobs posted the failure and claims table.

The exact `affected-claims` and `unapproved-spec` EXIT commands each exited 0 in
[run 40403180524](https://github.com/mack-dot/forge/actions/runs/40403180524).
`results/stage4/exit-run.json` and the per-case reports retain the actual records.
These runs concern their recorded base/head revisions; later documentation
commits do not turn them into checks of another revision.

The `approved-spec` EXIT remains **NOT RUN**. Review [the exact fee proposal](../proposals/fees.md)
before applying its spec and lock changes. No later stage has started.
