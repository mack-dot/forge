# Owner runbook: the agent cannot approve or deploy around the gate (worker Y8, 2026-11-19)

Status: PROPOSAL. NOT APPLIED. NOT AUTHORIZED. Worker Y8 changed nothing on GitHub and nothing in the repository.
Graph links: S1, E1, E2, E4, E5. All of them stay MISSING until the owner applies these steps and the negative
tests in section 4 pass. Live facts F1-F21 are in `LIVE_SETTINGS.md` (same folder).

## 1. Routes that exist today (none was tested)

The present agent session runs as the owner's macOS user. It can use the `mack-dot` token (admin; `repo`,
`workflow`) and the `mackiannii` token (write; `repo`, `workflow`) from the keyring (F16-F18). GitHub enforces no
ruleset and no branch protection on this private repository (F2-F6).

| # | Route to unverified content on `main` or a release | Why it is open (fact) | Setting that closes it |
|---|---|---|---|
| R1 | Plain merge of a PR with a red gate (`gh pr merge N --squash`) | No rule is enforced (F3, F6); PR 57 merged with `forge/proof-gate=failure` (F19) | Step 1 (Pro or public) + Step 4 ruleset (required `forge/admission`, no bypass) |
| R2 | Admin merge (`gh pr merge --admin`) | `mack-dot` token is admin (F1) | Step 2 (agent has no owner credential) + `bypass_actors: []` |
| R3 | Direct push: `git push origin HEAD:main` | `main` `protected: false` (F6); HTTPS credential in `osxkeychain` and `~/.git-credentials` (F18) | Step 4 `pull_request` rule + Step 2 |
| R4 | Force-push or delete `main` | No `non_fast_forward`/`deletion` rule enforced | Step 4 `non_fast_forward`, `deletion` |
| R5 | Edit `proof-gate.yml` on `main` (via R1/R3) so the gate always says VERIFIED | Same as R1/R3; tokens have `workflow` scope | Step 3 token without Workflows permission + Step 4 code-owner review |
| R6 | Push a new workflow on any branch that posts `forge/proof-gate`/`forge/admission = success` with `statuses: write` | Branch workflows run (F11); token has `workflow` scope | Step 3 (no Workflows permission for the agent); required check pinned to `integration_id 15368` stops statuses posted by a token |
| R7 | Post a commit status directly with the token (`POST /statuses/<sha>`) | `repo` scope includes `repo:status` | `integration_id: 15368` on the required check (a token status does not count) |
| R8 | Change or delete the ruleset itself | Admin can do it (after Step 1) | Step 2: the agent is never admin |
| R9 | Set `FORGE_SIGNING_AUTHORIZED=true` (now `"false"`, F14) and dispatch `provenance.yml` (has `id-token: write`) | Admin sets variables; `workflow_dispatch` needs only Actions write | Step 2 + agent token `Actions: read-only` |
| R10 | Create a tag or a release (`git push origin v1`, `gh release create`) | 0 tags, 0 releases, no tag rule (F7) | Step 4 `ruleset-tags.json`; agent has no Contents admin |
| R11 | Change the default branch to an agent branch, or rename `main` | Admin setting; `pr_check.py` checks only base `main` | Step 2 (no admin) |
| R12 | Add a collaborator, a deploy key or a webhook with write | Admin (F8, F13 show none today) | Step 2 |
| R13 | Approve as the owner: submit a `mack-dot` review on a `mackiannii` PR (happened once, U215) | The agent holds the `mack-dot` token | Step 2 (no owner credential in the agent's user) |
| R14 | Drive the owner's signed-in browser or desktop (Claude in Chrome / computer-use tools are offered to this session) and click Approve/Merge as `mack-dot` | Same macOS user and session | Step 2: the agent runs in another macOS user or VM with no owner browser profile |
| R15 | Allow Actions to approve PRs (`can_approve_pull_request_reviews`, now `false`, F10), then a workflow approves | Admin setting | Step 2 |
| R16 | Use the second token (`mackiannii`, `workflow` scope) for R6 | Present in the same keyring (F16) | Step 3: revoke it; issue a token without Workflows |
| R17 | "Signed commit" looks like owner evidence | Every API/UI merge is signed by GitHub web-flow (F20) | Treat `required_signatures` as integrity only; owner intent needs S1 (section 5) |

## 2. Runbook (the owner does every step; the agent does none)

### Step 1. Make rules enforceable (owner, UI)
GitHub offers rulesets on this private personal repository only with GitHub Pro (F2). Pick one:
- a) github.com -> your avatar -> Settings -> Billing and plans -> Plans and usage -> Upgrade to Pro. Or
- b) Repository -> Settings -> General -> Danger Zone -> Change visibility -> Public. (Not for secret material.)

Check (owner): `gh api repos/mack-dot/forge/rulesets` returns exit 0 and a list (it returned 403 on 2026-11-19).
Then read the old ruleset 26065125: `gh api repos/mack-dot/forge/rulesets/26065125`. Delete it or set
`enforcement: disabled` after Step 4 exists, so its bypass list cannot matter.

### Step 2. Separate the agent from every owner credential (owner)
1. Create a separate macOS user for the agent:
   `sudo sysadminctl -addUser forgeagent -fullName "Forge agent" -password -`
   Do not make it an administrator. Do not sign it into the owner's Apple ID, iCloud Keychain or Chrome profile.
2. Run Claude Code only inside `forgeagent` (or a VM / remote container). Clone the repository there.
   Cost: the local HOL toolchain under the owner's home must be rebuilt or shared read-only.
3. In the OWNER's user, remove the agent-usable logins from the shared keyring:
   `gh auth logout -h github.com -u mackiannii`, and delete `~/.git-credentials` after the owner moves to
   `osxkeychain` only. Revoke the old `mackiannii` classic token (it has `workflow`) at
   github.com/settings/tokens while signed in as `mackiannii`.
4. Account `mack-dot`: Settings -> Password and authentication -> add a passkey or a hardware security key;
   make it the 2FA method; remove SMS. Settings -> Sessions: sign out sessions you do not know.

### Step 3. A machine identity with write, never admin (owner)
Preferred: a GitHub App owned by `mack-dot` (works on a personal repository; no repository transfer, so
`pr_check.py`'s check `repository == 'mack-dot/forge'` stays valid).
- github.com/settings/apps -> New GitHub App. Name `forge-agent-<suffix>`. Webhook: off.
- Repository permissions, exactly:
  `Contents: Read and write` · `Pull requests: Read and write` · `Issues: Read and write` (PR comments only) ·
  `Metadata: Read-only` (mandatory) · `Actions: Read-only` · `Checks: Read-only` · `Commit statuses: Read-only` ·
  `Workflows: No access` · `Administration: No access` · `Secrets: No access` · `Variables: No access` ·
  `Environments: No access` · `Deployments: No access` · `Pages: No access` · `Webhooks: No access` ·
  every other permission `No access`. Account permissions: none.
- "Where can this app be installed": Only on this account. Install it on `mack-dot/forge` only.
- Generate a private key; copy it ONLY into the `forgeagent` user. The agent mints 1-hour installation tokens.
Fallback A: a classic PAT of `mackiannii` with scope `repo` only (no `workflow`, no `admin:*`, no `delete_repo`,
no `gist`), stored only in `forgeagent`. Fallback B: a fine-grained PAT. UNCERTAIN: GitHub may not list
`mack-dot` as a resource owner for a collaborator's fine-grained PAT; if the dropdown does not show it, use the App.
If it does: Repository access "Only select repositories: forge", the same permission list as the App.
Check (owner): `GH_TOKEN=<agent token> gh api repos/mack-dot/forge --jq .permissions` -> `admin: false`.

### Step 4. Import the rulesets (owner, UI)
Repository -> Settings -> Rules -> Rulesets -> New ruleset -> Import a ruleset -> pick the file.
1. First `ruleset-main-interim.json` (pull request + code-owner review, no status check, no bypass).
2. Merge the admission change (section 3) under the interim ruleset, by your own review and merge.
3. Open one documents-only PR from the agent identity. Confirm that a `forge/admission` status appears from
   `github-actions`. Then import `ruleset-main-admission.json` and set the interim one to Disabled.
4. Import `ruleset-tags.json` (no tag create/update/delete for anyone). To release, the owner switches it to
   Disabled, tags, and switches it back; GitHub logs both changes.
Notes: `bypass_actors: []` means no bypass, admins included. The admin can still edit the ruleset; that is why
Step 2 matters. `integration_id 15368` is the GitHub Actions app (READ from GitHub documentation, not tested
here; the owner confirms it in the ruleset UI: the check must show "GitHub Actions" as its expected source).
`require_last_push_approval` is `false` on purpose: with `true`, a PR whose last push is the owner's cannot get
the owner's approval. `dismiss_stale_reviews_on_push` still voids an approval after any new agent push.
Owner-authored PRs cannot be self-approved: the owner pushes a branch, the agent identity opens the PR, the owner
approves and merges.

### Step 5. The owner's hardware-backed signing key (owner)
Preferred: a FIDO2 security key the agent cannot touch.
`ssh-keygen -t ed25519-sk -O resident -O verify-required -O application=ssh:forge-owner -C forge-owner -f ~/.ssh/forge_owner_sk`
(PIN plus a physical touch on every signature.) Register it: github.com -> Settings -> SSH and GPG keys -> New SSH
key -> Key type "Signing Key". Record the public line as the repository variable `FORGE_OWNER_SIGNER`
(Settings -> Secrets and variables -> Actions -> Variables; only an admin can write it).
Secure Enclave variant (macOS app "Secretive", with "Require authentication"): acceptable only if every signature
needs Touch ID; UNCERTAIN for a process in the same macOS user, so keep the agent in `forgeagent` (Step 2).

## 3. Exit 3 becomes NOT ADMITTED for code; documents still merge

Rule (new status context `forge/admission`, computed only from the trusted receipt):
- exit 0 (VERIFIED) -> ADMITTED.
- exit 3 (UNSUPPORTED) -> ADMITTED only if (a) every changed path matches
  `(top-level name | proposals/… | docs/… | results/…)` + `.md` or `.txt`, (b) no path starts with `.github/ gate/
  toolchain/ spec/ impl/ governance/ clearing/ bugs/ policy/ scripts/ schemas/`, (c) every finding is
  `UNCOVERED_CHANGE` on one of those paths, and (d) the affected obligations are exactly `['ledger-proof']`
  (always run). Otherwise NOT ADMITTED.
- exit 1, exit 2, a missing receipt, a stale head -> NOT ADMITTED (no success status; the required check blocks).
- ADMITTED never approves: code-owner review by `mack-dot` stays required.

Proposal (UNAPPLIED, files in `proposal/`): option B `admission-option-B.diff`
(sha256 `d6705d6d…f6f24d8`): adds `gate/admission.py` and one step to the `report` job of `proof-gate.yml`.
It changes no frozen PR-gate module and no file pinned by `gate/provenance/implementation.lock`.
Option A (`admission-option-A-NOT-RECOMMENDED.diff`) edits frozen `gate/post_pr_report.py`, whose digest
`78c1133d…` is pinned in `implementation.lock` and in `proposals/round4-20261117/frozen-pr-gate-modules.json`; it
would also need the deferred Stage 9 lock rebind. Do not use A.
Approval needed for B: the owner's written approval of the exact diff digest, then the owner's own merge. The hosted
gate will answer REJECTED for that PR (`.github/` and `gate/` are protected and `.github/` is not Tier-0
ratifiable), so this is an explicit owner merge, recorded with a new `unsure.md` entry.
Real-data check (TESTED-UNPROVED): on the downloaded receipt of PR 57 (run 44469061507) the rule says NOT ADMITTED,
because PR 57 carried `go-routeA.sh`, `hash_parents.py` and three `.sml` drafts; without those five files it says
ADMITTED. On PR 47 (run 44424304046, Slice 3 code) it says NOT ADMITTED. Consequence: drafts of runnable code must
go into `.md` code blocks or stay off `main`.

## 4. Negative tests the owner runs after Steps 1-5 (as the agent identity, from `forgeagent`)
| Test | Expected |
|---|---|
| `git push origin HEAD:main` | rejected (`GH013` ruleset violation) |
| `git push --force origin <old>:main`; `git push origin :main` | rejected |
| `gh pr merge <N> --admin --squash` | refused (not admin / ruleset) |
| PR with exit 3 on code: `gh pr merge <N> --squash` (also try as owner) | blocked: `forge/admission` failure; no one can bypass |
| `gh api -X POST repos/mack-dot/forge/statuses/<head> -f context=forge/admission -f state=success` | 403, or the status appears but the PR stays blocked (wrong source) |
| push a branch that adds `.github/workflows/x.yml` | rejected: no `workflows` permission |
| `gh api -X PUT repos/mack-dot/forge/rulesets/<id> ...`; `gh api -X PATCH repos/mack-dot/forge -f default_branch=x` | 403/404 |
| `gh variable set FORGE_SIGNING_AUTHORIZED -b true`; `gh workflow run provenance.yml ...` | 403 |
| `git push origin refs/tags/test-y8` ; `gh release create test-y8` | rejected |
| `gh pr review <N> --approve` on an agent PR | does not satisfy the code-owner rule |
| `security find-internet-password -s github.com` and `gh auth status` inside `forgeagent` | no `mack-dot` entry |
| `ssh-keygen -Y sign -f ~/.ssh/forge_owner_sk -n forge-approval-v1 x` inside `forgeagent` | fails (no key handle, no touch) |
| Documents-only PR | `forge/admission` success; merge still waits for the owner's approval |

## 5. S1: owner intent bound to an exact spec digest
Smallest scheme (DESIGN, not applied, no diff for frozen `approval.py` here):
1. The owner computes digests on the owner's own machine from a fresh fetch, not from the agent's text:
   `git fetch origin && git show <head>:spec/refund/RefundSpec.dfy | shasum -a 256` (same for `spec.lock` and the
   proposal file).
2. The owner writes a canonical statement (LF endings, fixed order):
   `forge-approval-v1` / `repository mack-dot/forge` / `decision approved_as_written` /
   `input <path> <old_sha256> <new_sha256>` (one line per file, sorted) / `proposal_sha256 <hex>`.
3. Sign: `ssh-keygen -Y sign -f ~/.ssh/forge_owner_sk -n forge-approval-v1 statement.txt` (PIN + touch) ->
   `statement.txt.sig`. The record `gate/approvals/<id>.json` carries the fields and the armored signature.
4. Gate check (a future exact-diff change to `approval.py` and `proof-gate.yml`; frozen, so it needs the owner's
   written approval and own merge): `_spec_approval` rebuilds the statement ONLY from the record fields it already
   checks, writes `allowed_signers` = `forge-owner namespaces="forge-approval-v1" <FORGE_OWNER_SIGNER>` from the
   repository variable passed by the workflow, and requires exit 0 from
   `ssh-keygen -Y verify -f allowed_signers -I forge-owner -n forge-approval-v1 -s sig < statement`.
   It also requires the variable to equal `governance/owner-signers` in the trusted base (two anchors; the
   variable needs admin, the file needs code-owner review). No valid signature -> REJECTED.
5. Key rotation: a new signer line is valid only with a signature by the old key over the new line.
Negative controls the owner can run once it exists: flip one byte of the spec (REJECTED), sign with a fresh non-
registered key (REJECTED), reuse a valid signature with another namespace (REJECTED).

## 6. Residual trust after all steps
- GitHub: it enforces rulesets, keeps the App's permissions, and reports statuses honestly. The `github-actions`
  source pin is only as strong as "the agent cannot change any workflow" (residual: old branch refs whose workflow
  files run on `push`; F21 found no other `statuses: write` workflow in local history; remote-only refs not checked).
- The owner's account security (passkey, sessions) and the owner's own machine for digests and signing.
- The trusted gate code on `main` and the hosted runner image; `exit 0` means only the ledger obligations
  (`end_to_end=false`); it says nothing about native execution.
- The path-class rule: it assumes no deployable build reads `*.md`/`*.txt` outside the listed prefixes
  (`git grep` found gate reads of `proposals/refund-decision.md`, `proposals/booking-decision.md`,
  `proposals/fees.md`; those are obligation inputs, so condition (d) rejects them).
- The owner's review attention: ADMITTED documents still change `ROADMAP.md`, `unsure.md` and `AGENTS.md` (the
  last is protected and gives REJECTED without approval).
- E5: nothing is deployed today. A release needs the tag ruleset toggle by the owner plus, later, the consumer-side
  verifier of report B5 (not designed here).
