# Human-approval integrity for protected changes (proposal; nothing here is applied)

## Finding (observed 2026-10-29, results/stage9/approval-audit-0001)

- The coding agent's `gh` CLI is logged in as `mack-dot` (owner, admin; scopes
  repo, workflow). A second account, `mackiannii`, is also in the keyring.
- So every agent PR is authored by the owner. GitHub never lets an author approve
  their own PR, so no approval was possible and every merge used the admin bypass.
- GitHub's rule-suite records (the ruleset audit log) show `result=bypass` for
  PRs #16, #17 and #18, with the pull-request rule failing: "New changes require
  approval from someone other than the last pusher." PR #17 has 0 reviews.
- No `.github/CODEOWNERS` exists on main, so `require_code_owner_review` has no effect.
- Earlier main commits `993bee7b` and `e37ef2c5` were direct pushes with no PR.
- The agent can also act in the owner's browser (Claude in Chrome), so it can reach
  the owner's signed-in github.com session.

## Root of trust and administrative authority

- **Root of trust:** the person who holds the `mack-dot` credentials (password and
  2FA/passkey), acting through github.com or their own terminal. GitHub, as the
  platform, enforces rulesets and keeps the rule-suite records.
- **Administrative authority:** only `mack-dot` (repository owner). For a personal
  repository, only the owner can create Actions variables
  (`FORGE_SIGNING_AUTHORIZED`), edit rulesets or add collaborators.
- **Limit:** GitHub can tell accounts apart, not people. "The agent cannot approve"
  holds only while the agent cannot use any `mack-dot` credential or session. Today
  that is false (gh keyring, browser extension).

## Mechanism (GitHub-native; no custom cryptography)

| Requirement | Mechanism | Who enforces it |
| --- | --- | --- |
| Explicit human authorization | Ruleset `protect-main`: PR required, 1 approval, code-owner review; `CODEOWNERS` = `* @mack-dot` | GitHub |
| Binds the exact diff | `dismiss_stale_reviews_on_push` and `require_last_push_approval` (both already on); squash only; linear history | GitHub; the audit checks review `commit_id` = merged head and merged tree = head tree |
| Binds the base revision | Linear history and a squash merge; the audit checks the merged tree against the approved head tree | Audit |
| Binds policy and artifact identities | `policy/**`, the lock and the workflows are files in the approved commit; the release request binds commit, lock, policy, package and artifact digests | Approval + `producer.request_create` |
| The agent cannot approve its own work | The agent uses a separate machine account with the Write role (not admin, not a code owner, not a bypass actor); GitHub rejects author approval | GitHub + identity separation |
| A candidate cannot change its own authorization | Rulesets live in GitHub settings, not in the repo; GitHub reads `CODEOWNERS` from the base branch; the proof gate runs `pull_request_target` (base code) | GitHub |
| Stale, replayed, substituted or revoked approval | Stale: dismissed on push. Replayed: the approval is per PR and per head SHA. Substituted: tree equality. Revoked: the latest review state per reviewer before the merge | GitHub + audit |
| Changes to the mechanism itself | Ruleset edits: owner only (in settings, outside any PR). `CODEOWNERS` changes are themselves covered by `*` | GitHub |
| Emergency override | The admin bypass stays possible but is recorded by GitHub as `bypass` and classified OVERRIDE, never APPROVED. Disabling the ruleset leaves no rule-suite record, which classifies as UNKNOWN, never APPROVED | GitHub records + audit |

## Exact changes

1. **Owner, outside the repo (identity separation):**
   1. Create a machine account for the agent (GitHub allows one free machine
      account per person). Invite it to `mack-dot/forge` with the **Write** role.
   2. Give it a fine-grained token, limited to `mack-dot/forge`: Contents
      read/write, Pull requests read/write, Actions read, Metadata read.
   3. Give the agent only that token. Remove `mack-dot` (and `mackiannii`) from
      the agent's `gh` keyring, or run the agent as a separate macOS user.
   4. Turn off Claude in Chrome for `github.com`.
2. **Repo, protected (needs your approval; replaces nothing; PR #15 stays unmerged).**
   New file `.github/CODEOWNERS`:
   ```
   # GitHub reads this file from the base branch of each pull request.
   *  @mack-dot
   ```
3. **Ruleset:** no change is needed for review binding (all rules are already on).
   Keep the admin bypass (`RepositoryRole 5`, pull_request mode) only for
   emergencies; every use is recorded as `bypass`.
4. **Audit (unprotected, implemented):**
   `proposals/approval-integrity/audit_main_approvals.py`. It classifies each main
   commit as APPROVED / OVERRIDE / UNAPPROVED / UNKNOWN from GitHub's own records.
   Rule-suite records expire, so the verifier archives the output after each merge.
5. **Later, protected (v3.3):** `release.py verify` refuses a source commit whose
   lock-introducing commit is not APPROVED, or not ratified by a later APPROVED PR
   that names the override commit, its tree and its lock. The current OVERRIDE
   commits (#16, #17, #18) need that ratification after step 1.

## Untested

The APPROVED path cannot run until steps 1–2 exist: no exact-head code-owner
approval exists on any main commit.
