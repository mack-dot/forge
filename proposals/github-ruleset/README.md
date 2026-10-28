# Proposed GitHub protection for `mack-dot/forge` (not applied)

Status: proposal only. Nothing here is applied to GitHub. Applying it changes
repository settings and needs the owner's explicit go-ahead. See U097.

## What actually stops unreviewed release inputs

A Stage 9 release is accepted only when the verifier on the controller host
finds every one of the 62 locked files (and the 45 locked Python dependency
files) at the controller-chosen commit equal to the controller's installed
implementation lock. A new lock is installed only after the owner approves its
exact bytes. So an unreviewed change to a locked file cannot become an accepted
release input, even if it reaches `main`. Branch rules below are defense in
depth: they keep `main` clean and make every change visible, but they are not
an acceptance check.

## 1. Branch ruleset `protect-main`

File: [protect-main.ruleset.json](protect-main.ruleset.json)

```sh
gh api -X POST repos/mack-dot/forge/rulesets --input proposals/github-ruleset/protect-main.ruleset.json
```

| Rule | Effect |
| --- | --- |
| `deletion`, `non_fast_forward` | `main` cannot be deleted or force-pushed. |
| `required_linear_history` | No merge commits; history stays reviewable. |
| `pull_request` | Every change to `main` goes through a pull request: 1 approval, code-owner review, stale approvals dismissed on push, last push must be approved by someone else, threads resolved, squash merge only. |
| bypass: repository admin, `pull_request` mode | The admin can merge a pull request without approval, but cannot push directly to `main`. |

**Single-maintainer limit.** `mack-dot` is the only collaborator, and GitHub
does not let an author approve their own pull request. Without the bypass, no
change could ever merge. With the bypass, changes are visible and recorded,
but they are not independently reviewed. When a second trusted reviewer has
write access, delete the `bypass_actors` entry so that every change needs a
second person.

Also delete the inert ruleset `mack` (id 25915179). Its branch list is empty,
so it protects nothing:

```sh
gh api -X DELETE repos/mack-dot/forge/rulesets/25915179
```

## 2. CODEOWNERS for trust-critical paths

File: [CODEOWNERS](CODEOWNERS) → copy to `.github/CODEOWNERS` in a pull request.
It covers `gate/`, `spec/`, `spec.lock`, `policy/`, `schemas/`, `toolchain/`,
`scripts/`, `examples/binary/` and all of `.github/` (including itself and the
provenance workflows). With `require_code_owner_review`, a pull request that
touches these paths needs a code-owner review.

Path-level push restrictions (push rulesets with `file_path_restriction`) are
not proposed. Their availability for a user-owned public repository is not
verified.

## 3. Actions settings

| Setting | Now | Proposed | Command |
| --- | --- | --- | --- |
| Fork pull-request workflow approval | `first_time_contributors` | `all_external_contributors` | `gh api -X PUT repos/mack-dot/forge/actions/permissions/fork-pr-contributor-approval -f approval_policy=all_external_contributors` |
| Require actions pinned by full SHA | `false` | `true` | `gh api -X PUT repos/mack-dot/forge/actions/permissions -F enabled=true -f allowed_actions=all -F sha_pinning_required=true` |
| Default `GITHUB_TOKEN` permissions | `read` | keep | — |
| Workflows may approve pull requests | `false` | keep | — |

## Remaining trust that branch rules cannot remove

- Anyone with write access can dispatch `workflow_dispatch` workflows,
  including the signer workflow. Today that is only `mack-dot`. A dispatch at an
  unapproved commit can produce a signature under the authorized identity, but
  the verifier rejects it, because the commit and lock do not match the
  controller's request. Identity-only verification is not supported.
- The `mack-dot` account itself (password, 2FA, tokens) is trusted.
- GitHub, its OIDC issuer, Actions runners and artifact storage are trusted, as
  the contract states.
