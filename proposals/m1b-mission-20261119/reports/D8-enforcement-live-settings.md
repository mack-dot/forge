# Step D8: the live GitHub settings (read-only), every open route, an owner runbook, and an unapplied admission rule (Y8, Opus; nothing changed on GitHub or in the repository)

Worker report, saved verbatim by the orchestrator from the worker's transcript (home and scratch paths replaced). It is model output. It is not evidence by itself: the orchestrator's checks are in `TRACKER.md`.

---

Y8 report (graph links S1, E1, E2, E4, E5). I changed nothing on GitHub or in the repo and used only GET calls. No token was printed. `TRACKER.md` shows as modified in the work tree, but I did not write it.

## Findings
1. **No rule is enforced on `main` today.** The repository is private on a personal account without Pro. `rulesets`, `rules/branches/main`, `branches/main/protection` and `required_signatures` all return HTTP 403 "Upgrade to GitHub Pro or make this repository public" (exit 1). `main` and all 62 branches report `protected: false`. From GitHub's documented behaviour, ruleset 26065125 is not in force; I could not read its body. I found no record of the most recent switch back to private.
2. **The gate status is advisory only.** PR 57 was merged by `mack-dot` at 06:02:18Z while its head had `forge/proof-gate=failure` ("Unsupported").
3. **The agent holds both identities.** The session uses the owner's macOS user. The keyring holds `mack-dot` (admin) and `mackiannii` (write). Both tokens have the scopes `repo, workflow, gist, read:org`. `osxkeychain` and `~/.git-credentials` are both present.
4. **Other live facts:**
   - Collaborators: `mack-dot` admin, `mackiannii` write.
   - Workflow token default is `read`; Actions cannot approve PRs.
   - 0 environments, 0 secrets, 0 deploy keys, 0 webhooks, 0 tags, 0 releases.
   - The variable `FORGE_SIGNING_AUTHORIZED` is `"false"`.
   - Two workflows that are not on `main` ran from `push` events on proposal branches. So a workflow pushed on a branch runs.
   - Every recent `main` commit is "verified" only by GitHub's web-flow key, not by an owner key.
5. **The open routes are R1–R17** in the runbook: plain merge, admin merge, direct push, force-push or delete, workflow edit, a forged status from a branch workflow or a token, ruleset edit, signing variable plus dispatch, tags or releases, default-branch change, new collaborator or deploy key, approving as the owner, driving the owner's browser or desktop, the second token. I tested none of them. Each row names the setting that closes it.
6. **Exit 3 design:** a new status `forge/admission`.
   - Exit 0 is ADMITTED.
   - Exit 3 is ADMITTED only when all of these hold:
     - every change is a `.md` or `.txt` file at the top level or under `proposals/`, `docs/` or `results/`;
     - no change is under a protected prefix;
     - every finding is `UNCOVERED_CHANGE`;
     - the affected obligations are exactly `['ledger-proof']`.
   - Everything else is NOT ADMITTED.
   - Option B adds a new `gate/admission.py` and one step in `proof-gate.yml`. It touches no frozen module and no file pinned in `implementation.lock`.
   - Option A edits the frozen `post_pr_report.py`, whose digest `78c1133d…` is pinned in `implementation.lock`. Do not use A.
7. **Real-data result (a test, not a proof):** on the downloaded receipt of PR 57, the rule says NOT ADMITTED. PR 57 merged `.sh`, `.py` and `.sml` drafts as "documents". Without those five files the rule says ADMITTED. PR 47 says NOT ADMITTED.
8. **S1 scheme:** the owner signs a statement with `ssh-keygen -Y sign`, using an `ed25519-sk` key with `verify-required` (PIN plus touch). The statement lists each spec input with its old and new digest, plus the proposal digest. The gate rebuilds the statement and runs `ssh-keygen -Y verify`. The signer is anchored twice: the admin-only variable `FORGE_OWNER_SIGNER` and `governance/owner-signers`. This is a design only; it needs a future exact diff to the frozen `approval.py`.

## Files (all in <session scratch folder>/m1b/Y8/)
- `LIVE_SETTINGS.md`: facts F1–F21, each with its command and exit. Raw JSON is in `live/`. `live/user.json` holds account data: do not copy it anywhere.
- `OWNER_RUNBOOK.md`: route table, Steps 1–5, admission rule, negative tests, S1 design, residual trust.
- `ruleset-main-interim.json`, `ruleset-main-admission.json` (no bypass; squash only; code-owner review; required `forge/admission` from `integration_id 15368`), `ruleset-tags.json`.
- `proposal/admission-option-B.diff` (sha256 `d6705d6d…f6f24d8`), `proposal/gate/admission.py`, `proposal/admission-option-A-NOT-RECOMMENDED.diff`.
- `test_admission.py`, `test_real.py`, and the receipts in `real/`.

## Commands run (actual exits)
- `gh api` GETs: repo, collaborators, invitations, actions permissions (3 endpoints), workflows, environments, keys, hooks, variables (2 calls), secrets, releases, tags, branches, user, commits, pulls 56 and 57, statuses, workflow runs: all exit 0.
- rulesets, rules/branches/main, protection, required_signatures: exit 1 (HTTP 403).
- tags/protection and pages: exit 1 (HTTP 404). installation: exit 1 (HTTP 401, needs an App token).
- `gh auth status`: exit not captured because of the pipe; the output was read.
- Repo GET with the `mackiannii` token: exit 0.
- `gh run download` for runs 44469061507 and 44424304046: exit 0.
- Unit test of the rule, 16 cases with negative controls: exit 0 for option A and option B. Real-receipt test: exit 0.
- `patch --dry-run` of each option against a scratch copy: exit 0. Compile of each new file: exit 0.

## Not determined
- The body and bypass list of ruleset 26065125.
- The 2FA type of `mack-dot`, and the audit log.
- Whether GitHub accepts a collaborator's fine-grained PAT for `mack-dot`'s repository. The runbook prefers a GitHub App.
- That `integration_id 15368` is GitHub Actions: from GitHub documentation, not tested here.
- Whether an old remote-only branch has a `push` workflow with `statuses: write` (local history: none).

| step | status | evidence or blocker |
|---|---|---|
| (1) live settings | DONE | `LIVE_SETTINGS.md` F1–F21 |
| (2) routes + closures | DONE (none tested) | Runbook section 1, R1–R17 |
| (3) owner runbook + rulesets + negative tests | DRAFT, NOT APPLIED | Runbook sections 2 and 4; three JSON files |
| (4) exit 3 means NOT ADMITTED | UNAPPLIED PROPOSAL | Option B diff; needs the owner's written approval of the exact digest and the owner's own merge (the gate will say REJECTED); a new `unsure.md` entry |
| (5) S1 signed approval | DESIGN ONLY | Runbook section 5; a future frozen `approval.py` diff |
| (6) residual trust | DONE | Runbook section 6 |

| link id | proposed class | evidence |
|---|---|---|
| S1 | MISSING | No owner-held key or signature check exists; design only |
| E1 | MISSING | Exit 3 is still the verdict for new code; the admission rule is unapplied (tested only on 2 real receipts) |
| E2 | MISSING | No rule enforced (403; `protected: false`); PR 57 merged with a red gate |
| E4 | MISSING | One macOS user holds admin `mack-dot` and `mackiannii`, both with `workflow` scope |
| E5 | MISSING | 0 releases and 0 tags; no tag rule; no admission at the consumer |

M1-B stays OPEN; `end_to_end=false`; Stage 9 is deferred. I approve nothing and close nothing.
