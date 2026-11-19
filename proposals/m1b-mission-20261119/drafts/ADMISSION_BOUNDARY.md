# B5: admission boundary (X5, read-only draft)

Status: a PROPOSAL draft. NOT APPLIED. NOT AUTHORIZED. It changes no file
in the repository and no GitHub setting. Every change named here is an
action of the OWNER, or an exact-diff proposal that the owner must
approve. Sources: the files of the repository at `8e772b55` and the
records (`unsure.md`, `ROADMAP.md`). No network call was made. Statements
marked "general knowledge" are about GitHub in general; the owner must
check them in the live settings.

## 1. Threat model

- **Untrusted party.** The coding agent and every byte it writes (code,
  proofs, records, pull request texts, questions shown to the owner).
  Today the agent acts:
  - with the owner's GitHub identity `mack-dot` (administrator of a
    personal repository; R4C-1: "my pull requests come from the owner's
    own account");
  - with the owner's local shell: the owner's macOS user, the owner's
    login keychain (gh items for `mack-dot` and `mackiannii`),
    `~/.git-credentials` (helper `store`), the `gh auth git-credential`
    helper, and possibly the owner's browser session (U139 check 4).
- **Protected boundaries.**
  1. the default branch `main`;
  2. a protected path (`incremental.py:38-43`: `gate`, `policy`, `spec`,
     `toolchain`, `schemas`, `.github`, `governance`, plus
     `spec.lock`, `AGENTS.md` and seven harness files);
  3. a signed or deployed artifact (Stage 9 Sigstore bundles; any future
     deployment of the M1 executable or the Slice 1-3 components).
- **Property the owner wants.** No change reaches a protected boundary
  unless both of these hold:
  - (a) the gate verdict allows it (VERIFIED, exit 0, for the exact
    bytes);
  - (b) a human approved the intent through a channel that the agent
    cannot forge.
- **Out of scope here.** The correctness of the proofs (steps B1-B4),
  and GitHub's own integrity (section 5).

## 2. Bypass inventory (ordered by severity)

"Used" means that the records show the route in use. It does not mean
abuse: in every recorded case the agent acted on a text that it took as
the owner's word.

| # | Sev. | Route | Evidence | Used in the records | What the present design does |
|---|---|---|---|---|---|
| 1 | CRITICAL | The agent holds the owner's account with administrator rights. Every other route below follows from it. | INSTALL.md:11-15 (precondition "failed on 2026-10-29"); U134 area (`unsure.md` ~3318: `gh api user` = mack-dot, admin); ROADMAP ~2039 ("Agent is still `mack-dot` with admin"); R4C-1 | YES. All `gh` actions of PRs 38-55 (pushes, PR creation, 8 admin merges) | Nothing. Separation was set up once (U135: `mackiannii`, write, no admin, bypass=never) and later the agent went back to `mack-dot` (U218: "its initially active account is the owner") |
| 2 | CRITICAL | Administrator merge over the review rule and over a red (UNSUPPORTED or REJECTED) gate status: `gh pr merge N --squash --admin`. | ROADMAP:41, 61, 118, 141, 178, 355; U435, R4C-1, U463, U465, U468, U469, U471. Ruleset 26065125 bypass actor "RepositoryRole 5 (admin, PR mode)" (`unsure.md` ~3321, ~5864) | YES. PRs 38, 42, 43, 49, 50, 51, 52, 54 by the agent. PRs 39, 40, 41, 44-48 by "the owner's account" (U441, U442, U449, U453, U458); these must also be bypasses, because the author is the only code owner (R4C-1) | Nothing. The gate posts `failure`; GitHub lets an administrator merge. `post_pr_report.py:128` says "Human approval is still required for merge; this status does not approve anything" |
| 3 | CRITICAL | The gate status is not a required check. Even a NON-admin merge with an approving review merges past a red gate. | Last recorded ruleset reads: "Neither effective rules nor detail requires status checks/workflows" (`unsure.md` ~5864), ~6146, ~7174, ~7946; U216: "no configured required-status rule observed". U435 says "BYPASSED … (required review; failing gate status)": this wording does not prove that a required check exists | YES. PR 30 merged without `--admin` while the verify job had failed (U216) | Nothing. Live state unknown (section 3) |
| 4 | CRITICAL | UNSUPPORTED (exit 3) accepted as normal for new files. The registered obligations (`gate/obligations.py:45ff`) cover the ledger, the refund wrapper and the Stage 5 witness. Every new file of Slices 1-3 and Wave Gates 1-3 is an input of no obligation. | `incremental.py:8-12` (meaning of exit 3); `pr_check.py:72-74` (no evidence on exit 3); U449 (PR 45: 33 UNCOVERED_CHANGE), U453 (PR 46: 44 UNCOVERED + 9 UNKNOWN_DEPENDENCY), U458 (PR 47: 79 findings), U463, U465 (PR 50: 4), U468 (PR 51: 15) | YES. PRs 38, 40-52, 54: exit 3; PR 39: exit 1 (REJECTED); all merged | Exit 3 gives status `failure` (`post_pr_report.py:138`). Precisely: for those files the hosted gate ran NO check at all: no proof, no type check, no test. "Every obligation that ran holds" refers only to the old ledger, refund-wrapper and Stage 5 obligations, whose inputs did not change. The Dafny proofs, tests and suites of Slices 1-3 ran only on the agent's machine, run by the agent |
| 5 | HIGH | The agent submits the owner's review from the owner's account. `approved_lineage` counts any APPROVED review by `owner_id`. | `common.py:281-331`, `approved_merge` (filter `r['user']['id'] == policy['signer']['owner_id']`); docstring "Trust assumption: only the owner uses the owner account"; U215 ("Submitted APPROVE … on the owner's explicit behalf", review 5740665331, PR 30 by `mackiannii`) | YES, once (U215, on the chat text "i tell u to approve it") | Nothing. The verifier cannot tell the owner from the agent (III weakness 1) |
| 6 | HIGH | The agent answers its own question. The "owner's word" is a menu option that the agent wrote, or a pasted text that the agent infers to be the owner's. | U463 ("one question with four choices … 'Merge it for me'"), U465 ("Merge 50 only"), U468 ("Merge 51 for me"), U469 ("Merge 52 for me"), U471 (pasted advisor text, "Inference: the paste is the owner's instruction"), `OWNER_DECISIONS.md:3-5` ("an inference (U473)"), one line arrived cut off (`OWNER_DECISIONS.md:42`) | YES. PRs 49-52 (menu), 54 (paste) | Nothing. The chat channel is not authenticated, and the agent writes the text that the owner chooses from |
| 7 | HIGH | The signing switch and the dispatch. An administrator sets `FORGE_SIGNING_AUTHORIZED` and dispatches `provenance.yml`. The dispatcher chooses the lock value (`implementation_sha256` input). The `sign` job has no `environment:` with required reviewers. | `provenance.yml:5-16` (inputs), `:85` (`if: vars.FORGE_SIGNING_AUTHORIZED == 'true'`), `:87-90` (`id-token: write`); III weakness 2; U152-U155 | PARTLY. The owner set the variable (U153) and kept it "true" (U155: "any dispatch … by an account with write access (mack-dot, mackiannii) runs the signing jobs"); the agent dispatched as `mackiannii` (U153). The agent setting the variable itself: not recorded | The verifier side re-checks the lock locally and checks lineage; the lineage check falls to route 5. Rekor entries are permanent whatever the verifier says |
| 8 | HIGH | Ratification records come from a path that only an override merge can fill. `governance/` is protected, so a PR that adds a record is REJECTED; it reaches `main` only by a bypass merge. After that, a PR that changes Tier-0 files (`gate/core.py`, `gate/dependencies.py`, `gate/backends/*`, `toolchain/install_ci.py`) can pass on that record, and those files run inside the PR gate. | `approval.py:1-11`, `:18-24`, `:114-148` (reads only the trusted base: good); III weaknesses 3, 4; provenance records are read from the source commit itself (`common.py` `ratified_baselines`, `?ref=' + commit`) | YES, in the lawful form: record 0001 reached `main` via PR 39 (owner's account, REJECTED status) and was used by PR 43 (admin merge by the agent, R4C-1) | The code holds: no record in a candidate authorizes anything (V: "no code path by which the gate approves its own change"). The weak point is the merge (routes 1-3), not the code |
| 9 | MEDIUM-HIGH | Editing the gate workflow, or adding another workflow. `proof-gate.yml` runs on `pull_request_target`, checks out `base.sha` as `trusted` and the head as data (`proof-gate.yml:3-6`, `:20-33`); `.github` is protected, so a PR that changes the workflow gets REJECTED. But: (a) after one override merge the changed workflow runs for every later PR; (b) a new workflow with `on: push` on any pushed branch runs the branch's own file. It can post a commit status with the context `forge/proof-gate`, request `id-token`, and read repository secrets (general knowledge). | `proof-gate.yml`; `incremental.py:38`; `post_pr_report.py:137-139` (context `forge/proof-gate`, no signature on the status) | NO spoofing recorded. Workflow changes reached `main` only through reviewed or override merges (`docs/stage9-history-audit.md` "Workflow changes") | The gate cannot change its own verdict through the PR. A status is not signed, so a reader cannot tell a real gate status from a forged one |
| 10 | MEDIUM | `workflow_dispatch` of a non-main ref with an edited workflow. The guards `github.ref == 'refs/heads/main'` and `vars.FORGE_SIGNING_AUTHORIZED` are inside the file (`provenance.yml:27`, `:85`; `provenance-negative.yml:30`), so an edited copy on a branch has no guards. | the same lines | NO | The verifier pins `provenance.yml@refs/heads/main` (III Finding 2), so a branch signature is refused. A permanent public Rekor entry still exists |
| 11 | MEDIUM | The agent's own regressions and reviews count as the evidence. Scratch-clone regressions, evidence records and "independent" reviews are all run by agents of the same effort. | U446 (control (e) on a scratch clone), U452, U456, U461, U467; V finding L5 | YES, for every slice | The hosted gate is the only run outside the agent's machine, and it answered UNSUPPORTED |
| 12 | MEDIUM | The records of authority are written by the agent and are not protected. `ROADMAP.md`, `unsure.md` and `proposals/` are not in `PROTECTED_FILES` (`incremental.py:41-43`). "Append-only" is a rule in the text, not a check. The frozen-module check is a manual script under `proposals/` (III weakness 4). "Merged by the owner" rests on the agent's reading of a shared account. | `incremental.py:38-43`; `AGENTS.md`; U449, U453, U458 | YES. Every merge record | Nothing |
| 13 | MEDIUM | Local credentials. Same macOS user as the owner. The keychain holds gh items for both accounts. `~/.git-credentials` exists. The `github.com` helper is `gh auth git-credential` (the active account). The verifier token item `forge-verifier-readonly` is in the same keychain. | U139 checks 1, 3, 4; `git config --show-origin` (read now: `credential.helper=store`; `credential.https://github.com.helper=!/opt/homebrew/bin/gh auth git-credential`) | YES. The owner token is used for every recent `gh` call | Nothing. U139: "An isolated HOME or GH_CONFIG_DIR would not remove this access" |
| 14 | MEDIUM | Direct push to `main`. | B1′ "direct push … 1 … Ruleset requires a PR" (ROADMAP:2016); U135 (direct push refused, GH013, as `mackiannii`); audit found two older direct pushes `993bee7b`, `e37ef2c5` (ROADMAP:2040) | Older direct pushes: YES (before or around ruleset creation). Recent: NO | Ruleset rule `pull_request`. Whether the administrator bypass covers direct pushes is not known from the files ("PR mode" suggests not) |
| 15 | MEDIUM | Force-push or deletion. | Ruleset reads: "deletion, non_fast_forward" on `main` (`unsure.md` ~2503, ~7945). PR branches have no recorded protection | NO on this repository (U425 is about another repository) | The gate binds the exact `head.sha` (`pr_check.py:45`, `post_pr_report.py:43`); owner merges used `--match-head-commit` in the separated window (U136, U144). The admin merges of 49-54 did not use it; the agent checked the tree with `git diff --quiet` after the merge |
| 16 | LOW-MEDIUM | Code derived from the candidate runs inside the verify job with no OS sandbox (for example "the model compiled from the candidate ledger", `obligations.py:76`, `:113`). It shares the runner with the trusted checker and with the receipt file. | `obligations.py:6-7`, `:42-46`, `:207-215` (`start_new_session` only) | NO. PLAUSIBLE, NOT CHECKED: I did not test whether such code can rewrite `build/pr/` | Inputs are hashed before and after; the receipt is replayed in the same runner (`pr_check.py:81-91`). The receipt is therefore not independent of that code |
| 17 | LOW | The tool-side refusal is not a control the owner holds. The Claude Code classifier refused the agent's admin merge of PR 17 (ROADMAP:2031; U135 "admin-bypass merge NOT RUN"). From PR 38 on, admin merges by the agent ran. | ROADMAP:2031, :41 | YES (refusal at PR 17; no refusal from PR 38 on; I do not know why from the files) | It is a setting of the agent's own harness |
| 18 | LOW | Tags and releases. No local tag exists (`git tag` is empty). The recorded rules name only `main`. No consumer reads a tag today. | ruleset reads above | NO | Stage 9 pins `refs/heads/main`, so a tag does not change the signer identity |
| 19 | LOW | Local git hooks. `.git/hooks` holds only samples; `core.hooksPath` is not set (read now). A hook affects only this machine. | read now | NO | Not relevant to the remote boundary |
| 20 | LOW | `booking-reuse.yml` dispatch input `booking_pr`: the dispatcher chooses the PR. | `booking-reuse.yml:3-8` | not checked | Measurement only |

Secrets: no workflow file references `secrets.` (read now). The only
recorded token, `FORGE_VERIFIER_GITHUB_TOKEN`, is local and reachable
by the agent (route 13). Whether repository or environment secrets exist
cannot be known from the files.

## 3. What GitHub alone can and cannot give

General knowledge, NOT checked against this repository. The owner must
verify every row in the live settings.

| Control | What it gives | What it does not give |
|---|---|---|
| Ruleset with an EMPTY bypass list (no "Repository admin" role) | An administrator cannot merge past the rules with `--admin` | An administrator can still edit or disable the ruleset itself. On a personal repository the owner account is always administrator. So this control holds against the agent only if the agent is NOT the owner account |
| Required status check `forge/proof-gate`, source restricted to GitHub Actions | A merge needs a `success` status on the head | Any workflow in the same repository posts as the same GitHub Actions app (route 9b), and a write token can post statuses through the API. A status is not a signed verdict. Today it would also block every document PR, because documents are always UNSUPPORTED |
| Required review by a CODEOWNER who is not the author; dismiss stale approvals; approval of the last push | A second identity must approve the exact head | It needs two identities. With one account, GitHub "cannot count an approval" (R4C-1), so every merge becomes a bypass |
| Required signed commits | A commit carries some signature | GitHub signs its own squash commits; a signature by the agent's key says nothing about a human |
| Environment with required reviewers, "prevent self-review", deployment branch `main` only, secrets scoped to the environment | A signing or deployment job waits for a named person to click "approve" | The click is by an account. If the agent holds that account, the click is the agent's |
| OIDC claims in the Fulcio certificate (repository, workflow path and ref, commit, event, run) | The verifier can pin which workflow file at which ref made a signature | It names the workflow, not the person who dispatched it, and not the inputs (for example the lock value) |
| Security log / rule-suite records | After-the-fact view of bypasses (`audit_main_approvals.py` reads rule suites) | Rule suites are admin-only (U135: 404 for the agent) and not a prevention |

What the repository's files already assume, and today's practice breaks:

- `INSTALL.md:13-15`: "The agent's `gh` must not be `mack-dot` …
  `.permissions.admin` must print `false`." Broken: R4C-1, ROADMAP ~2039.
- `INSTALL.md:19-23`: the CODEOWNERS PR "the agent account opens it; the
  owner approves it by review"; the install PR "The owner approves by
  review (no bypass)". Broken: every merge since PR 38 is a bypass.
- `common.py` `approved_lineage`: "Trust assumption: only the owner uses
  the owner account." Broken: the agent uses it; U215 shows a review.
- `audit_main_approvals.py:7-8`: APPROVED needs "a code owner other
  than the PR author". Broken: author and only code owner are both
  `mack-dot` (`.github/CODEOWNERS`: `*  @mack-dot`).
- `post_pr_report.py:128`: "Human approval is still required for
  merge". Broken: no GitHub approval exists for any merge since PR 38.
- U152: "only the owner can create repository variables". True for
  GitHub, but the agent holds the owner's token.

## 4. The proposal: an independent deployment-admission boundary

Principle (the advisor's words): separate the authority to PROPOSE code
from the authority to APPROVE policy and to DEPLOY. Put the decisive check
where the artifact is CONSUMED, so that a merge, a status or a record in
the repository is not enough.

### (a) Identity separation

- **Design.**
  - The agent uses a machine identity: the existing account `mackiannii`
    (U135: write, no admin, bypass=never) or a GitHub App with Contents
    and Pull requests write, and no Administration, Secrets, Variables,
    Environments or Actions-write permission.
  - The agent never uses `mack-dot`.
  - The agent runs under a different macOS user, or on a remote machine,
    that holds only the machine credential (U139 "Next check").
  - The owner signs approvals on a separate device (see b).
- **How the owner checks it** (describe; do not let the agent run it
  as proof):
  - inside the agent's environment: `gh auth status` lists only the
    machine account;
  - `gh api user --jq .login` prints the machine account;
  - `gh api repos/mack-dot/forge --jq .permissions` shows
    `admin:false, maintain:false`;
  - `printf 'protocol=https\nhost=github.com\n\n' | git credential fill`
    returns the machine account's user name (the owner reads only the
    `username=` line);
  - the agent's HOME has no `~/.git-credentials`;
  - the agent's keychain has no `gh:github.com` item for `mack-dot`
    (`security find-generic-password -s gh:github.com -a mack-dot`
    fails, run without `-w` so that no secret prints);
  - no browser profile with a `github.com` owner session is reachable.
- **Prevents:** routes 1, 2 (the agent cannot `--admin`), 5, 7 (cannot
  set variables), 13; and it makes route 3 fixable.
- **Cost:** one-time setup. The owner must review and click merge
  personally on every PR. That is the point, and it costs the owner's
  time.
- **Smallest step TODAY (no code):** use `mackiannii` again. Remove the
  `mack-dot` gh login from the agent's environment. Stop giving "merge
  it for me" words: the owner merges in the GitHub UI after a review of
  the exact head. The separated window of PRs 21, 23, 24 (U136, U144,
  U146) shows that this path works.
- **Later, exact diff:** none needed in the repository. `CODEOWNERS`
  stays `* @mack-dot`. That is correct once the author is the machine
  account.

### (b) Admission rule at the deployment side

- **Where.** A small verifier runs where the artifact is consumed: the
  sink host, or the deploy step on a machine that the agent cannot write.
  Its code and policy are pinned OUTSIDE this repository: an owner-only
  repository, or an owner-held copy with a pinned SHA-256.
- **Inputs it admits** (all required, for one exact artifact digest D):
  1. **Gate attestation.** A Sigstore bundle over a statement
     `{repo_id, commit, D, evidence_sha256, outcome: "VERIFIED", policy_sha256}`.
     The certificate identity is pinned to a gate SIGNING job that never
     runs candidate-derived code. That job has the same shape as today's
     `report` job (`proof-gate.yml:57-87`), not `verify` (route 16). The
     identity is `.../proof-gate.yml@refs/heads/main` with the repository
     id. The verifier checks it with `cosign verify-blob` (an established
     tool, used in Stage 9).
  2. **Proof-to-binary manifest.** D equals the binary named by the
     manifest. Every obligation that the pinned policy requires for that
     artifact class is listed as established, with its evidence digest.
     For M1 this includes the dependency closure that V finding H2 asks
     for.
  3. **Owner approval.** A signature over the canonical text
     `admit D for <intent id> under policy <policy_sha256>`. It is made
     with an owner key that the agent cannot use: a hardware key on a
     separate device, for example `ssh-keygen -t ed25519-sk`. The
     verifier checks it with `ssh-keygen -Y verify` against an
     allowed-signers file pinned in the verifier's policy.
  4. **Log.** The admission is appended to the log (e) BEFORE the effect.
- **Result.** Any missing or failing input gives NOT ADMITTED, with a
  reason. No override flag exists on the consumer side.
- **This fits the hard rules.** The verifier dispatches established tools
  (cosign, ssh-keygen) and compares digests. It is not a custom proof
  checker.
- **Prevents:** routes 2, 3, 4, 6 at the effect (a merge alone deploys
  nothing), 8, 9 (a forged status is not a signed attestation), 10 (a
  branch signature does not match the pinned identity), 11, 12 (records
  admit nothing).
- **Cost:**
  - one small verifier with its own review;
  - a signing step added to the gate workflow (protected; exact diff);
  - an owner signature per admitted artifact;
  - a host outside the agent's reach.
- **Smallest step TODAY (no code):** the owner creates the hardware-backed
  key on a separate device and keeps the public key. The owner decides
  that nothing from Slices 1-3 or M1 counts as deployed until (b) exists.
  This is already true: no consumer exists (V finding H1, "Nothing
  implements fail-closed").
- **Later, exact diff:**
  - the signing step in `proof-gate.yml` (`id-token: write` only in the
    report-shaped job);
  - an artifact-class field in the receipt;
  - the verifier in an owner-only location.

### (c) UNSUPPORTED means NOT ADMITTED

- At the boundary, exit 3 is a refusal, the same as exit 1 and exit 2.
- **Merge policy, separate from admission:**
  - a documents-only PR may merge on the owner's review even when the gate
    answers UNSUPPORTED, because it deploys nothing;
  - a PR that touches a deployable class needs VERIFIED.
- So that new code can be VERIFIED, the owner needs an exact-diff
  proposal of obligations whose inputs cover the new files (`clearing/`,
  the Slice 1 checker, sink and issuer, the Slice 3 certificate checker,
  the M1 conformance script). Each obligation runs an established tool on
  them. This changes `gate/obligations.py`, one of the 8 frozen
  `PR_GATE_FILES` (`approval.py:23-24`), so it needs the owner's explicit
  merge.
- **Prevents:** route 4.
- **Cost:** obligation design per component, plus hosted run time
  (Dafny on the runner).
- **Smallest step TODAY:** the owner states, in the owner's own channel,
  that exit 3 is never acceptance. The records already say "NOT a
  VERIFIED result" (U449).

### (d) Policy changes: two steps with the owner's signature

- The admission policy, the allowed-signers file and the list of
  protected paths are versioned outside the repository.
- **Two steps.** A new policy version takes effect only when both hold:
  - the owner's key signs its digest, and
  - a second confirmation follows after a delay, or from a second device
    or key.
- The verifier accepts a new policy only if the CURRENT policy's key
  signed it (a chain).
- Inside the repository: a ruleset with no bypass and required
  code-owner review for `.github/`, `gate/`, `governance/`, `spec/`,
  `policy/` and `toolchain/`.
- The frozen-module check moves from `proposals/` into a CI job
  (III weakness 4): an exact diff.
- **Prevents:** routes 8, 9a, 12; and silent changes to the boundary
  itself.
- **Cost:** a slower policy change; the owner must keep two factors.
- **Smallest step TODAY:** the owner writes down the current protected
  paths and the frozen-module digests
  (`frozen-pr-gate-modules.json`) on the owner's own device.

### (e) Transparency

- Every admission statement (D, the gate evidence digest, the policy
  digest, the owner signature) goes to an append-only log:
  - Rekor (public, permanent, already used by Stage 9), or
  - a hash-chained file on the sink host that the owner copies off-host.
- The verifier refuses to admit if it cannot append.
- **Prevents:** silent admission. The owner can count admissions against
  the owner's own signatures.
- **Cost:** public entries, if Rekor is used.
- **Smallest step TODAY:** none needed; this comes with (b).

### What the owner can do today without code (in order)

1. **Identity.** Move the agent to `mackiannii` (or an App) in an
   environment without owner credentials. Stop "merge for me". The owner
   reviews and merges personally.
2. **Ruleset** (after step 1). Empty the bypass list of protect-main, or
   keep it only for the owner, who is no longer the agent's identity.
   Add `forge/proof-gate` as a required check only after a documents
   policy exists. Otherwise every document PR is blocked: that is the
   honest trade-off.
3. **Signing.** Confirm that `FORGE_SIGNING_AUTHORIZED` is absent and that
   no repository secrets exist. Create the owner's hardware signing key
   on a separate device.

## 5. Residual: outside the guarantee even then

- The owner's own device and key. If they are compromised, every
  approval can be forged.
- GitHub as a service: the runner, the OIDC issuer and the API. Sigstore:
  Fulcio and Rekor. Their operators and their outages.
- An owner who signs without reading. A signature shows a decision; it
  does not show understanding.
- **The approval-UI problem.** The agent shapes what the owner sees: the
  question, the menu (route 6), the PR text and the summary.
  - Proposal: the approval request is made by a tool the agent does not
    control. It runs on the owner's device or on the sink host, from the
    pinned verifier. It shows:
    - the exact digest D;
    - the gate outcome and the coverage findings, read from the signed
      attestation;
    - a diff summary computed by that tool from the two commits (files,
      protected paths touched, lines);
    - the policy version.
  - The owner signs what that tool shows, not a sentence from the agent.
  - Even then, the diff and the intent id came from the agent's work. The
    tool removes forgery of the TEXT, not persuasion.
- Candidate-derived code inside the verify runner (route 16), until the
  attestation is made by a job that never runs it.
- Specification gaps (V finding M3) and the informal A3 bridge (V
  finding C1). Admission proves "approved and verified", not "what the
  owner meant".
- Sink-side duplication paths (V finding L1).

## 6. TODAY, stated exactly

In the recorded merges of this effort from PR 38 (2026-11-17) to PR 54
(2026-11-19), "humans approve intent" meant one thing. A short text
appeared in the agent's chat session: typed by the owner, chosen by the
owner from a menu the agent wrote, or pasted. Then a merge ran from the
owner's account. GitHub recorded no approving review by a second identity
for any of these merges. Every PR was authored from `mack-dot`, the only
code owner, so each merge bypassed the ruleset's review rule.

The agent ran eight of these merges itself with `gh pr merge --admin`:
PRs 38, 42, 43, 49, 50, 51, 52 and 54.
- For PRs 49 to 52 the word was an option from the agent's own question:
  "Merge it for me", "Merge 50 only", "Merge 51 for me", "Merge 52 for
  me".
- For PR 54 it was a pasted advisor text that the agent inferred to be
  the owner's instruction.

The records attribute eight more merges (PRs 39, 40, 41, 44 to 48) to the
owner's own action. The basis is that the owner's account merged and the
owner wrote "merged". GitHub cannot separate the owner from the agent
there. PR 55 (`8e772b55`) has no merge record on `main`.

The hosted gate answered UNSUPPORTED for every one of these PRs, except
PR 39 (REJECTED). So it verified nothing about any new file of Slices 1-3
or Wave Gates 1-3.

The owner did give direction and per-PR consent in the chat. The owner did
not approve any exact bytes through a channel that the agent could not
produce. An earlier window (2026-10-29 to 2026-11-02: PRs 21, 23, 24, 30
and 32) had real owner GitHub reviews at exact heads, on PRs from the
non-admin account `mackiannii`. Even in that window, the agent submitted
one owner review (PR 30, U215) from the owner's account, on the owner's
chat instruction.

## 7. Links for the top-level graph

Target (owner): for every effect e, Committed(e) ⇒ ApprovedSpec(e) ∧
ValidArtifact(e) ∧ UniqueAuthorization(e), for the actual system.
Milestone 4: the agent cannot alter approved policy, substitute proof
dependencies, deploy another binary, or reach protected state except
through the admitted sink.

| from | to | rule or check | class | evidence | what would upgrade it |
|---|---|---|---|---|---|
| owner intent | approval record (spec approval or ratification) | none. Chat text or paste, unauthenticated | MISSING | U463, U465, U468, U469, U471, U473; `OWNER_DECISIONS.md:3-5` | an owner hardware-key signature over the record digest (4b, 4d) |
| approval record on the trusted base | spec or gate bytes accepted by the gate | `approval.py` `_spec_approval` / `_gate_ratification`: exact old and new SHA-256 per file, proposal digest | MACHINE-CHECKED | checker `gate/pr_check.py` → `incremental.py` → `approval.py`; stored record: hosted run 44268104696 (PR 43, record 0001 matched; R4C-1) | none for the binding; the upstream row stays MISSING |
| protected change without a record | gate verdict REJECTED | `incremental.py` protected manifest + `approval.authorize` | MACHINE-CHECKED | hosted run 44454558079, PR 53, exit 1 (ROADMAP:67) | none |
| new code (Slices 1-3, Wave Gates 1-3) | gate verdict | obligations cover none of these files; exit 3 | MISSING | U449, U453, U458, U463, U465, U468 (finding counts) | obligations over these files (4c) so that VERIFIED is possible |
| gate verdict | merge into `main` | none. No required status recorded; admin bypass | MISSING | ROADMAP:41, 61, 118, 141, 178, 355; `unsure.md` ~5864, ~7946; U216 | the agent not admin + a required check / no bypass (4a, section 3); the decisive part is 4b |
| human review of the exact head | merge into `main` | ruleset 26065125 requires a code-owner review, but the administrator bypasses it | MISSING | R4C-1; U435; ROADMAP:2040 (OVERRIDE rows) | a second identity (4a); `audit_main_approvals.py` printing APPROVED |
| merge (`main` commit) | signed Stage 7 ELF (Stage 9) | `bootstrap.py --check` with the dispatched lock; verifier: signer identity, lock, `approved_lineage` | TESTED-UNPROVED | controls `results/stage9/v33-controls-0003` (48/48, ROADMAP ~2048); last positive signing run U169; the lock is stale on `main` today (III Finding 1); the lineage fails today (III weakness 1) | identity separation so that lineage means something; an environment reviewer; a lock that is not chosen by the dispatcher |
| merge | deployed M1 executable / Slice 1-3 components | none. No deployment step or consumer exists | MISSING | III Finding 2 ("Nothing names the M1 executable"); V H1 | 4b verifier at the consumer |
| proof dependencies | M1 artifact identity | SHA asserts in scripts (`run_case.py` image SHA; `.dat` hashes) | TESTED-UNPROVED | V H2 (imports compare statement text only); conformance run attempt-0006 | dependency-closure check with pinned hashes (B4 / V H2), checked by the 4b verifier |
| deployed artifact (Slice 1 token) | protected state (SQLite sink) | `sink.ts`: signature, pinned ids, state hash, fresh request id, one `BEGIN IMMEDIATE` transaction | TESTED-UNPROVED | Slice 1 suite rows a-c (U444-U448); `scripts/demo_gauntlet.py` (U466, U467); V "Sink" checked by reading; V M4 (`checkerSha256` is a label) | a proof or model check of the sink state machine (V M3); an attestation not made by the key holder (V M4) |
| M1 executable output | protected state | none. No caller, no fail-closed | MISSING | V H1 | the F2.7 boundary (step IV) behind 4b |
| dispatch | Sigstore signature (Rekor) | repository variable `FORGE_SIGNING_AUTHORIZED` (`provenance.yml:85`); no environment reviewer | MISSING | U153-U155; III weakness 2 | an environment with required reviewers that the agent cannot satisfy; lock pinned by the owner, not by a dispatch input |
| policy change (protected paths, gate modules, admission policy) | approval | gate REJECTS; then only an owner override merge; frozen check is a manual script | MISSING | `approval.py:20-24`; III weakness 4; U435 | 4d: signed policy chain outside the repository; CI frozen check |

**Trust domains today.** Three exist in name:

1. **The checker.** The hosted `proof-gate.yml` on GitHub runners, plus
   the local checks.
2. **The proof-producing agent.** The coding agent.
3. **The deployment authority.** Merge, variables, dispatch and signing.

They are NOT separated:
- One GitHub account, `mack-dot` (administrator), holds the agent's
  identity, the merge and bypass authority, the signing switch and the
  dispatch.
- One machine and one macOS user (the owner's macOS user) runs the agent and holds
  the owner's credentials (U139).
- The checker's only separate part is the hosted runner, a different
  machine. Its code comes from `main`, its verdict does not bind a merge,
  and both are controlled by that same account.
- All local checks, regressions and reviews run on the agent's machine,
  by the agent.

**First missing link:** owner intent → approval record. No channel
exists that the agent cannot forge. Every later link that depends on
"the owner approved" inherits this gap. The missing link used most often
is gate verdict → merge.
