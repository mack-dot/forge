# Threat table: routes to unverified content in `main`, a release, a signed artifact or an effect (g-admission, 2026-11-19)

Status words: BLOCKED (evidence named) / OPEN / UNKNOWN. "Today" = live state read tonight by GET (`live/gets.log`)
or a code line. "After" = after the draft rulesets (`drafts/enforcement/ruleset-*.json`) and option B or B2.
Rulesets CANNOT be applied today: `rulesets`, `rules/branches/main`, `branches/main/protection` all gave HTTP 403
"Upgrade to GitHub Pro or make this repository public" (exit 1, tonight). So every "after" needs owner action O1.
Ruleset effects come from a LOCAL MODEL of GitHub (`test_admission_suite.py`, group R): ASSUMPTION, not GitHub.

| # | Route | Today | Evidence today | After rulesets + B2 | Still open after |
|---|---|---|---|---|---|
| T1 | Direct push to `main` | OPEN | `branches/main` `protected:false`; 403 on rules; credential helper `osxkeychain`+`store`, `~/.git-credentials` present (`live/local-cred.log`) | BLOCKED in model (R01, R02 PASS) | Admin can edit or disable the ruleset; this session's token is admin |
| T2 | Admin merge with red or UNSUPPORTED check | OPEN | repo GET as this session: `permissions.admin:true`; PR 58 head `985f5eaf`: `forge/proof-gate=FAILURE`, open, no rule; PR 57 merged red (D8 F19) | BLOCKED in model (R05, R06, R07, R11; `bypass_actors:[]`, R25) | Same as T1: the agent holds the admin credential |
| T3 | Success status from a workflow the PR changed | BLOCKED for the gate's own run; OPEN for a new workflow | `proof-gate.yml:4` is `pull_request_target`, checks out `base.sha` (lines 22, 70); all 98 local refs filter it to `branches: [main]`. But branch workflows run (D8 F11) and both keyring tokens have `workflow` scope (D8 F16) | OPEN: `integration_id 15368` names the GitHub Actions app, not a workflow (R21 FAIL) | Closed only if the agent identity has no Workflows permission AND no ref holds a status-writing workflow it can trigger (local refs: only `proof-gate.yml`; remote-only refs NOT checked) |
| T4 | Edit `proof-gate.yml` or add `pull_request_target` workflows on `main` | OPEN | Needs T1/T2, both open | BLOCKED by code-owner review (R13-R16) + App without Workflows | Owner review attention; owner account held by agent (T6) |
| T5 | Forged approval / ratification record | OPEN | `approval.py:45` reads records only from the trusted base: a record added in the same PR is ignored (A01 PASS). Nothing binds a record to the owner except its presence on `main`: an unsigned record in the base is accepted (A02 FAIL). Two-PR route: record PR (REJECTED, merge not blocked) then spec PR | Record PR needs a code-owner review | OPEN until S1 signed approval (design E5); a review by the owner account is the agent's if the agent holds that account |
| T6 | Agent uses the owner's `gh` token or git credential helper | OPEN | Tonight `gh api user` = `mack-dot`, repo `admin:true`; `credential.helper` = `osxkeychain`, `store` | Not affected by rulesets | OPEN until a separate OS user/VM (O3, O4) |
| T7 | Force-push or delete `main` | OPEN | No enforceable rule (403) | BLOCKED in model (R03, R04) | Other branches stay writable (evidence branches) |
| T8 | Tags and releases | OPEN | 0 tags, 0 releases (GET); no tag rule enforceable | BLOCKED in model (R18-R20) | Owner toggles the rule to release; draft releases not modelled (UNKNOWN) |
| T9 | Actions secrets readable by PR workflows | BLOCKED | `actions/secrets` total 0; `environments` 0; `default_workflow_permissions: read` | same | New secrets later must go to an environment limited to `main` |
| T10 | OIDC signing via variable + dispatch | OPEN | `FORGE_SIGNING_AUTHORIZED="false"` (GET); `provenance.yml:85-90` `id-token: write` gated only by that variable; an admin token can set it | Not affected by rulesets | OPEN until the agent has no admin and Actions write (O3-O5) |
| T11 | Self-approval of reviews | OPEN | GitHub refuses author self-approval (model R14), but the agent can approve as `mack-dot` on a `USERi` PR (U215) | BLOCKED for a true second identity (R14-R16) | OPEN while the agent holds `mack-dot` |
| T12 | Bypass actors in rulesets | UNKNOWN | Live ruleset 26065125 body: 403, unreadable | Drafts: `bypass_actors: []` (R25 PASS) | Admin edits the ruleset (personal repo: owner is always admin) |
| T13 | Exit 3 UNSUPPORTED treated as non-blocking | OPEN | PR 58 `forge/proof-gate=FAILURE` and mergeable; no required check | BLOCKED: exit 1/2/3/4 or code under exit 3 posts `failure` (B17-B20); missing check blocks (R06) | Interim ruleset does not block (R22 FAIL, by design); option B needs an owner merge of a REJECTED PR |
| T14 | Signing keys on this machine | UNKNOWN | No `user.signingkey`, no `gpg.format`, no gpg, no cosign; `~/.ssh/id_ed25519` file key readable by this user; one unrelated expired 2024 user certificate; no tracked private key (`git grep` exit 1). Whether `id_ed25519` is registered on GitHub (auth or signing): NOT checked | — | Any future owner key stored as a file in this user is agent-usable |
| T15 | Status posted directly by a token | OPEN (statuses advisory) | `repo` scope includes statuses | BLOCKED in model (R09, R10): pin to integration id | Depends on GitHub honouring the pin (ASSUMPTION) |
| T16 | Stale head or base SHA | BLOCKED (code) | `admission.py` binds event/receipt and re-reads the PR (B04-B10, B23 PASS) | + strict policy (R08, R12) | — |
| T17 | Default branch change, ruleset edit, new collaborator/deploy key | OPEN | Admin token in this session | Not affected | OPEN until T6 closed |
| T18 | Deploy an unverified artifact / sink effect | OPEN | No deployment exists; Slice 3 sink trusts a key the minter process generates itself (`minter.ts:44`); no consumer-side verifier | Not affected | OPEN (design E6) |
| T19 | Drive the owner's browser or desktop | OPEN | Same macOS user; such tools are offered to sessions | Not affected | OPEN until T6 closed |
| T20 | Candidate code in the verify job forges the receipt | UNKNOWN | B5 item 16; not checked here | — | — |
| T21 | Merge of a PR whose base is an old branch with a status-writing workflow | UNKNOWN | 98 local refs: only `proof-gate.yml` writes statuses, always filtered to `main`; 63 remote heads, remote-only refs NOT checked | — | Owner check O12 |

Counts (Today column): BLOCKED 2 (T9, T16), OPEN 15 (T1, T2, T4, T5, T6, T7, T8, T10, T11, T13, T15, T17, T18, T19; T3 split: counted OPEN), UNKNOWN 4 (T12, T14, T20, T21).
After rulesets + B2 + no identity separation: still OPEN T1-T6, T10, T11, T17-T19 (the agent holds the admin account).
