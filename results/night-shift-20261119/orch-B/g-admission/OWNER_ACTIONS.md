# Owner actions for OWNER_REQUIRED (g-admission, 2026-11-19). TEXT ONLY. The agent executed NONE of these.

Do every step from the OWNER's device and user, never from an agent session. Check every SHA-256 with
`shasum -a 256 <file>` before you use the file. Paths are relative to the repository root.
E = `proposals/m1b-mission-20261119/drafts/enforcement`. G = `results/night-shift-20261119/orch-B/g-admission`.

O1. Make rules enforceable.
- Do: github.com -> avatar -> Settings -> Billing and plans -> Plans and usage -> Upgrade to GitHub Pro.
  (Making the repository public also works, but it publishes everything.)
- Verify: `gh api repos/mack-dot/forge/rulesets` gives exit 0. Tonight it gave HTTP 403.
- Roll back: downgrade the plan. The rules then stop being enforced again.

O2. Read the old ruleset 26065125.
- Do: `gh api repos/mack-dot/forge/rulesets/26065125`. Record `bypass_actors` and `enforcement`.
- After O9 is done: Settings -> Rules -> Rulesets -> 26065125 -> Enforcement status: Disabled.
- Verify: `gh api repos/mack-dot/forge/rulesets/26065125 --jq .enforcement` prints `disabled`.
- Roll back: set it to Active again.

O3. Give the agent its own macOS user.
- Do: `sudo sysadminctl -addUser forgeagent -fullName "Forge agent" -password -`. Do not make it an admin.
  Do not sign it in to the Apple ID, iCloud Keychain or Chrome. Run Claude Code only there.
- Verify, inside `forgeagent`:
  - `gh auth status` reports no account;
  - `security find-internet-password -s github.com` exits 44;
  - `test -f ~/.git-credentials` exits 1;
  - `ls ~/.ssh` lists no owner key.
- Roll back: `sudo sysadminctl -deleteUser forgeagent`.

O4. Remove the agent-usable credentials from the owner's user.
- Do:
  - `gh auth logout -h github.com -u mackiannii`;
  - revoke the classic token of `mackiannii` at github.com/settings/tokens (it has `workflow`);
  - `git config --global --unset credential.helper '^store$'`, then `rm ~/.git-credentials`.
- Verify: `git config --get-all credential.helper` prints only `osxkeychain`.
- Roll back: log in again. This is NOT recommended.

O5. Create the agent App.
- Do: github.com/settings/apps -> New GitHub App `forge-agent-<suffix>`, webhook off.
  - Repository permissions: Contents RW, Pull requests RW, Issues RW, Metadata R, Actions R, Checks R, Commit
    statuses R. Every other permission No access. Workflows and Administration MUST be No access.
  - Install it only on `mack-dot/forge`. Copy the private key only into `forgeagent`.
- Verify, as the App, on a scratch branch: `gh api -X PUT repos/mack-dot/forge/contents/.github/workflows/neg.yml`
  `-f message=neg -f content=bmVn -f branch=scratch/app-neg`. Expect HTTP 403 or 404 (no workflows permission).
  `gh api repos/mack-dot/forge/actions/variables` must also give 403.
- Roll back: uninstall the App, then delete it.

O6. Run the negative tests of the admission ruleset on scratch refs FIRST.
- Do:
  1. Create the branch `scratch/admission-test` from `main`.
  2. Settings -> Rules -> Rulesets -> New ruleset -> Import a ruleset ->
     `G/owner-test-rulesets/ruleset-scratch-admission.json`
     (sha256 `7b27662b80150a5cc2117f68880b6bf4922d29559814389f91854e35cf0051bd`).
- Verify, from `forgeagent` and again as the owner:
  - `git commit --allow-empty -m neg && git push origin HEAD:scratch/admission-test` is rejected (GH013);
  - `git push --force origin HEAD~1:scratch/admission-test` is rejected;
  - `git push origin :scratch/admission-test` is rejected.
  - Then open a PR into `scratch/admission-test`, post
    `gh api -X POST repos/mack-dot/forge/statuses/<head> -f context=forge/admission -f state=success`
    with a PAT, and try `gh pr merge <N> --squash --admin`. Expect a refusal: the status does not come from the
    pinned app.
- Roll back: delete the scratch ruleset, then the scratch branch.

O7. Import the interim ruleset for `main`.
- Do: import `E/ruleset-main-interim.json`
  (sha256 `05c9386fe40c1ce0f4aec1b25046fe94baab2afca9082edc1224688cf6f50d01`).
- Verify: as the owner, `git push origin HEAD:main` with an empty commit is rejected (GH013).
  Note: this interim ruleset does NOT block a red gate (test R22).
- Roll back: Enforcement -> Disabled.

O8. Apply the admission rule. Use B2.
- Do, in the owner's own clone:
  1. Check `G/proposal-B2/admission-option-B2.diff`: sha256 must be
     `4e02fddbbeade631c58bf9189469c0e9fc34c0d602a2b271f0170dbcf5f34056`
     (`git apply --check` gave exit 0 at `985f5eaf`).
  2. `git apply G/proposal-B2/admission-option-B2.diff`, then commit and push from the owner.
  3. Open the PR from the App and merge it personally. The gate says REJECTED, because `.github/` and `gate/` are
     protected. Record a new `unsure.md` entry.
- The original draft B is `E/unapplied-proposal/admission-option-B.diff`
  (sha256 `d6705d6dc0157268e8d2ef9d9d09c0f9ba5957d33b342eb3b3178a570f6f24d8`). It has 5 defence-in-depth
  failures (N08, N09, N36, B15, B16).
- Verify:
  - a docs-only App PR gets `forge/admission=success` from GitHub Actions;
  - a PR that changes `impl/*.dfy` (exit 3) gets `forge/admission=failure`.
- Roll back: revert the commit by an owner PR.

O9. Require the admission check on `main`.
- Do: import `E/ruleset-main-admission.json`
  (sha256 `8e242bb599858ac2911739c5cf4a640ea7670ca891f4422b89ecb5afc0d96b01`), then disable the interim ruleset.
  In the UI, confirm that the check's source shows "GitHub Actions" (id 15368 comes from documentation only).
- Verify:
  - as the owner, `gh pr merge <exit-3 code PR> --squash --admin` is refused;
  - an App PR that adds `.github/workflows/x.yml` cannot be pushed (O5).
- Roll back: Disabled.

O10. Lock the tags.
- Do: first test `G/owner-test-rulesets/ruleset-scratch-tags.json`
  (sha256 `6258200f864ce6472615cffaf29955d3bc38a6923390399b25b5c2be95dd18be`) with
  `git tag scratch-neg && git push origin scratch-neg`. Expect a rejection. Then import `E/ruleset-tags.json`
  (sha256 `09f5f92b859957597c5a84567d1487e5e5d59b02a823d3ae833233b765176b9e`).
- Verify: `git push origin refs/tags/neg-1` is rejected for the owner and for the App;
  `gh release create neg-1` fails.
- Roll back: Disabled. To make a release on purpose: disable, tag, enable again.

O11. Create the owner's approval key, on hardware only.
- Do, on the owner's device: `ssh-keygen -t ed25519-sk -O resident -O verify-required -O application=ssh:forge-owner
  -C forge-owner -f ~/.ssh/forge_owner_sk`.
  - Register it: GitHub -> Settings -> SSH and GPG keys -> Signing Key.
  - Set the repository variable `FORGE_OWNER_SIGNER` to the public line.
- Verify:
  - run `G/s1-demo/run.sh` with the real key in place of `owner`; the positive line gives 0 and the negatives
    give 255;
  - in `forgeagent`, `ssh-keygen -Y sign -f ~/.ssh/forge_owner_sk -n forge-approval-v1 x` fails.
- Roll back: delete the variable and the GitHub key, and reset the FIDO2 credential.
- Gate use of the key needs a later exact diff to frozen `approval.py` (design E5).

O12. Check the refs the agent did not check.
- Do: `git fetch origin --prune`, then for each `refs/remotes/origin/*`:
  `git grep -l -E "statuses: +write|pull_request_target" <ref> -- .github/workflows`.
- Verify: only `proof-gate.yml` with `branches: [main]` appears. Delete stale branches that you do not need.
- Roll back: none is needed (read only).
