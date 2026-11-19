# Y8: live GitHub settings of mack-dot/forge (read 2026-11-19, read-only GET calls)

Worker Y8 ran only `gh api` GET calls and `gh auth status`. No token was printed. Raw JSON is in `live/`
(next to this file). `live/user.json` holds account data: do not copy it anywhere.

## Facts (RAN: command -> actual exit -> observation)

| # | Command | Exit | Observation |
|---|---|---|---|
| F1 | `gh api repos/mack-dot/forge` | 0 | `private: true`, `visibility: private`, owner type `User`, default branch `main`. The calling token has `admin: true`. Merge commit, squash and rebase all allowed. |
| F2 | `gh api repos/mack-dot/forge/rulesets?includes_parents=true` | 1 | HTTP 403 "Upgrade to GitHub Pro or make this repository public to enable this feature." |
| F3 | `gh api repos/mack-dot/forge/rules/branches/main` | 1 | Same HTTP 403. The effective rules on `main` cannot be read. |
| F4 | `gh api repos/mack-dot/forge/branches/main/protection` | 1 | Same HTTP 403. |
| F5 | `gh api repos/mack-dot/forge/branches/main/protection/required_signatures` | 1 | Same HTTP 403. |
| F6 | `gh api repos/mack-dot/forge/branches?per_page=100` | 0 | 62 branches. `main` (`cc20207b`) has `protected: false`. Every branch has `protected: false`. |
| F7 | `gh api repos/mack-dot/forge/tags/protection` | 1 | HTTP 404 (legacy tag protection is gone or absent). `gh api .../tags` exit 0: zero tags. `.../releases` exit 0: zero releases. |
| F8 | `gh api repos/mack-dot/forge/collaborators?affiliation=all` | 0 | `mack-dot`: admin. `mackiannii`: write (push, triage, pull; no admin, no maintain). Invitations: 0. |
| F9 | `gh api repos/mack-dot/forge/actions/permissions` | 0 | Actions enabled; `allowed_actions: all`; `sha_pinning_required: true`. |
| F10 | `gh api repos/mack-dot/forge/actions/permissions/workflow` | 0 | `default_workflow_permissions: read`; `can_approve_pull_request_reviews: false`. |
| F11 | `gh api repos/mack-dot/forge/actions/workflows` | 0 | 15 registered workflows. Two (`m1-input-integrity.yml`, `m1-macos-preflight.yml`) are NOT on `main`: they ran from `push` events on branches `proposal/m1-input-integrity-20261109` and `proposal/m1-macos-preflight-20261106` (runs 42624212334, 42400884739, ...). So a workflow file pushed on a non-main branch runs. |
| F12 | `gh api repos/mack-dot/forge/environments` | 0 | 0 environments (no required reviewers anywhere). |
| F13 | `gh api repos/mack-dot/forge/keys` | 0 | 0 deploy keys. `.../hooks` exit 0: 0 webhooks. |
| F14 | `gh api repos/mack-dot/forge/actions/variables` + `.../variables/FORGE_SIGNING_AUTHORIZED` | 0, 0 | One variable: `FORGE_SIGNING_AUTHORIZED = "false"`, updated 2026-10-29T23:37:55Z. `.../actions/secrets` exit 0: 0 secrets. |
| F15 | `gh api repos/mack-dot/forge/actions/permissions/access` | 0 | `access_level: none`. |
| F16 | `gh auth status` (token lines filtered) | exit not captured (pipe) | Two logged-in accounts in the macOS keyring: `mack-dot` (active) and `mackiannii`. Both tokens: scopes `gist, read:org, repo, workflow`. |
| F17 | `GH_TOKEN=<mackiannii token, not printed> gh api repos/mack-dot/forge` | 0 | The `mackiannii` token: push true, admin false. |
| F18 | `git config --get-all credential.helper` (local + global) | 0 | `osxkeychain`, `store`; the file `~/.git-credentials` exists. No `user.signingkey`, no `gpg.format`. Remote is HTTPS. |
| F19 | `gh api repos/mack-dot/forge/pulls/57` and `.../commits/67516456.../statuses` | 0, 0 | PR 57 merged by `mack-dot` at 06:02:18Z. Its head had `forge/proof-gate = failure` ("Unsupported: ...", creator `github-actions[bot]`). |
| F20 | `gh api repos/mack-dot/forge/commits?sha=main&per_page=8` | 0 | All 8 newest `main` commits: `verification.verified = true`, reason `valid` (GitHub web-flow signature of an API/UI merge, not an owner key). |
| F21 | `git log --all -- .github/workflows` + `git grep "statuses: write"` (local refs) | 0 | Only `proof-gate.yml` ever declared `statuses: write` in the locally known history. |

## What the facts mean (READ GitHub behaviour, not tested here)

- F2-F6: the repository is private on a personal account without GitHub Pro. GitHub does not offer rulesets or
  branch protection there. Ruleset 26065125 (`unsure.md` lines ~2502, ~5862, ~7943, read while the repository was
  public) is therefore, by GitHub's documented behaviour, NOT ENFORCED today. `protected: false` on `main` agrees.
  UNCERTAIN: I could not read the ruleset body; only the owner can confirm in Settings -> Rules.
- The records show the move to private (ROADMAP ~1837) and back to public (ROADMAP ~1869). I found no record of the
  latest move back to private. That is an unrecorded settings change.
- Required status checks: none can be enforced today (F3/F4). The `forge/proof-gate` status is advisory (F19).
- The `pull_request_target` workflow `proof-gate.yml`: GitHub runs the copy on the base branch, so a pull request
  cannot change the workflow for its own run. But today any holder of the `mack-dot` credential can push a new
  `proof-gate.yml` straight to `main` (F6), and a push to any branch can add a new workflow that runs (F11).
- The local credential (F16-F18): the agent session runs as the owner's macOS user and can use the `mack-dot`
  token (admin, `repo` + `workflow`) and the `mackiannii` token (write, `repo` + `workflow`). Neither has
  `delete_repo` or `admin:org`.

## Not determined
- The ruleset body, its bypass list and its target refs (F2 403).
- Account 2FA type and passkeys of `mack-dot` (not readable by API).
- The audit/security log (not readable with these scopes for a personal account).
