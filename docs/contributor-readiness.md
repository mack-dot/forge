# Contributor-readiness report

Date: 2026-10-28. Repository: `mack-dot/forge` (public, owner type User).
Scope: documentation, onboarding and repository settings. No protected file,
release workflow, policy, contract or lock was changed. Stage 9 stays CURRENT.
Records: `results/contributor-readiness/`; uncertainty entry U098.

**Acceptance criterion:** a new developer can clone Forge, understand what is
and is not proven, reproduce a small verification example, and open a safe
contribution without privileged access. **Result: PASS on macOS Apple
Silicon**, with the limits listed under FAIL and UNVERIFIED.

## Findings

| # | Item | Result | Evidence |
| --- | --- | --- | --- |
| 1 | README: mission, verified capabilities, limits, architecture, quickstart | PASS | Every quickstart command ran in a fresh clone: checksum 0, gate on `impl/Ledger.dfy` 0 (`ACCEPTED: C1 C2 C3 C4 C5`), gate on `bugs/off_by_one.dfy` 1 (`VERIFICATION_REJECTED: C4`); clean tree afterwards. |
| 2 | Contributor guide | PASS | `CONTRIBUTING.md`; its scenario command `scripts/exit_stage_1.py --case planted-bugs` returned 0 in the fresh clone. |
| 3 | License | PASS | Owner chose Apache-2.0. `LICENSE` is the official text (sha256 `cfc7749b…`). `NOTICE` and `THIRD_PARTY_NOTICES.md` added; upstream MIT texts checked at the pinned commits. |
| 3a | Copyright holder's legal name in `NOTICE` | UNVERIFIED | "Superpower Mentors" is the owner's statement; the exact legal entity name is not confirmed. Confirm before merging. |
| 4 | Security policy and reporting | PASS | `SECURITY.md`; private vulnerability reporting enabled (read back `enabled: true`). The issue chooser link to it is in PR #15. |
| 5 | Starter issues | PASS | Eight issues, #6–#13, including two reusable proof-carrying components (#11, #12) and two protected-change proposals (#8, #9). |
| 6 | Broken implementation rejected, corrected accepted | PASS | Four planted bugs rejected with exit 1 (C4; C1 C3; C1 C5; audit for `assume`); correct ledger accepted with exit 0; new evidence byte-identical to `evidence.json` (`ed015ad9…`). |
| 7a | External PRs cannot get signing credentials | PASS | `id-token: write` appears only in `provenance.yml` (sign job) and `provenance-negative.yml`, both `workflow_dispatch` only; dispatch needs write access (only `mack-dot`). No secrets, variables, environments, deploy keys or webhooks. |
| 7b | External PRs cannot change approved provenance | PASS | `main` requires a pull request (ruleset `protect-main`, id 26065125). Even a merged change to a locked file cannot become an accepted release input: the verifier checks all 62 locked files at the controller's commit against the owner-approved lock. |
| 7c | External PRs cannot trigger deployment | PASS | No workflow deploys. Deployment observation runs only on the controller host (`gate/provenance/observe.py`). |
| 7d | `pull_request_target` gate does not run PR code with privileges | PASS (design) / UNVERIFIED (depth) | It checks out the base commit for code and the PR head only as data, both with `persist-credentials: false`; the check job is `contents: read`; the write-capable report job runs base code. Not audited: whether hostile Dafny input can exhaust runner resources beyond the pinned limits. |
| 8 | Code-owner review on trust-critical paths | FAIL until PR #15 merges | `.github/` is a protected input of the PR gate. The first version of this PR added CODEOWNERS and templates there, and the gate rejected it (run 40743715513, exit 1, `UNAPPROVED_PROTECTED_CHANGE`). They moved to PR #15, which needs exact-byte approval. Until then `require_code_owner_review` has no effect. |
| 8a | PR gate on protected paths | Note | The gate's approval hook accepts only approved spec text, so any change under `.github/`, `toolchain/` or `schemas/` is always reported as rejected. Owner-approved protected changes therefore merge with that rejection visible. |
| 9 | Independent review | FAIL | One collaborator. The ruleset lets the admin merge their own pull request (bypass in pull-request mode). A second trusted reviewer is needed for two-person review. |
| 10 | Linux quickstart | UNVERIFIED | Linux runs only in CI through `toolchain/install_ci.py`; not run by hand (issue #6). |
| 11 | TypeScript demo (`build_model.py`, `node app/main.ts`) | UNVERIFIED | Not run in this check. |
| 12 | Clean-machine test | UNVERIFIED | Tests ran in fresh clones on the maintainer's host, which already had the pinned Node and Python. |
| 13 | Toolchain checksum manifest | FAIL | `toolchain/checksums.sha256` hard-codes host paths (issue #10). |
| 14 | Leftover measurement workflows | Note | Four Stage 9 probe/dry-run workflows remain on `main`. They are dispatch-only with `contents: read`. Remove them after Stage 9. |

## GitHub settings that repository source cannot show

Values below were read through the GitHub API on 2026-10-28 by the admin.
Anyone else must take them on trust or ask the owner.

| Setting | Value |
| --- | --- |
| Visibility / owner | public / user `mack-dot` |
| Collaborators | `mack-dot` (admin) only |
| Branch ruleset | `protect-main` on the default branch: no deletion, no force push, linear history, pull request with 1 approval, code-owner review, stale approvals dismissed, last push approved, threads resolved, squash only; admin bypass in pull-request mode |
| Branch protection (classic) | none |
| Actions enabled / allowed actions | yes / all, with full-SHA pinning required |
| Default `GITHUB_TOKEN` permissions | read; workflows cannot approve pull requests |
| Fork pull-request workflows | approval required for all outside contributors |
| Secrets, variables, environments | none |
| Deploy keys, webhooks | none |
| Private vulnerability reporting | enabled |
| Secret scanning / push protection | enabled / enabled |
| Dependabot alerts / security updates | enabled / disabled |
| Account security of `mack-dot` (2FA, tokens) | not readable here; trusted |
