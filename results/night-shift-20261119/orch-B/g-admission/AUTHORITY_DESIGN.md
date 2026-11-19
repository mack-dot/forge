# Independent authority design (g-admission, 2026-11-19). DESIGN ONLY. NOT APPLIED. NOT AUTHORIZED.

Goal G: the agent must LACK the authority to admit, not only the instruction. Principle: every decisive
step needs a secret or a device that never enters the agent's trust domain. A rule that the agent's own
credential can edit is an instruction, not an authority boundary.

Trust domains:
- D-owner: the owner's own device and macOS user, the `mack-dot` account (admin, sole code owner), and a FIDO2
  hardware key (PIN + touch).
- D-agent: a separate macOS user `forgeagent` (or a VM or remote container). It holds only a GitHub App
  installation token. It holds no owner credential, no owner browser profile, and no admin.
- D-github: rulesets, the GitHub Actions runner, and `pull_request_target` runs from the base ref.
- D-consumer: a pinned verifier at the deployment or sink. It is not in the repository and not on the agent machine.

## E1. Identities and merge rights
- Merge rights: `mack-dot` only. The rulesets have `bypass_actors: []`. The agent App has no Administration
  permission, so it cannot edit a ruleset, a variable, the default branch or collaborators.
- The agent App's permissions: Contents RW, Pull requests RW, Issues RW, Metadata R, Actions R, Checks R,
  Statuses R. Workflows, Administration, Secrets, Variables, Environments and Deployments: none.
- Testable now, without the owner: from inside D-agent, `gh auth status`, `security find-internet-password -s
  github.com`, `test -f ~/.git-credentials` and `git config --get-all credential.helper` must show no owner
  entry. Done tonight in the CURRENT session: FAIL. `gh api user` = `mack-dot`, `admin:true`; the helpers
  `osxkeychain`+`store` are set (`live/local-cred.log`). That is the evidence for T6.
- Needs the owner: O3, O4 and O5 (OWNER_ACTIONS.md).

## E2. Rules that bind the admin account too
- First make rules enforceable (Pro or public; tonight: HTTP 403). Then import the interim ruleset, the
  admission ruleset and the tag ruleset.
- Limit of this element: on a personal repository the owner can always edit the rules. E2 binds the agent only
  together with E1.
- Testable now: JSON validity (exit 0); the local model, group R: 22 PASS, R21 and R22 FAIL (the model is an
  ASSUMPTION about GitHub).
- Needs the owner: O1, O6, O9 and O10, with the negative tests on scratch refs.

## E3. Required check pinned to an identity the agent cannot run
- The draft pins `forge/admission` to `integration_id 15368` (GitHub Actions). Every workflow in the repository
  posts as that app, so the pin does not name the workflow (R21 FAIL).
- Minimal fix A (no new secret): E1 removes the agent's Workflows permission. Also keep every ref free of
  status-writing workflows that the agent can trigger (local refs: only `proof-gate.yml`, filtered to `main`).
  The residual is any workflow that a future merge adds.
- Stronger fix B: a dedicated App `forge-admission` posts the status. Its private key is a secret of an
  environment `admission`. That environment allows deployment branch `main` only, so only base-ref runs reach it.
  The required check pins THAT App's id. A workflow on another branch cannot read the key. Environments on a
  private repository need Pro: UNCERTAIN, the owner confirms it.
- Testable now: the model shows that the 15368 pin admits a foreign workflow (R21). The fix-B pin is the same
  model with another app id (R10 PASS shows that a foreign app id is refused).
- Needs the owner: create the App, the environment and the secret, and change the ruleset id (a new exact diff).

## E4. Fail-closed admission rule (exit 3 = NOT ADMITTED for code)
- `forge/admission` gives success only for exit 0 with established coverage, or for exit 3 with documents only.
  Any other exit, receipt or binding gives failure or no status. A missing status blocks the merge.
- Use B2 (`proposal-B2/admission-option-B2.diff`), not B. B admits a bool or float exit inside `admission()`
  (N08, N09). B posts success for exit 0 without a coverage record when its step runs alone (B15, B16). B
  admits the protected `AGENTS.md` as a document (N36). In the workflow, earlier steps guard these cases.
  B2 closes them in the function itself.
- Testable now: 95 tests, B2: 92 PASS. The 3 FAIL are R21, R22 and A02 (not in the function). 16 mutants of
  B: 13 killed. 3 survived; all 3 are equivalent on 5223 enumerated inputs (`equiv_check.log`).
- Needs the owner: review the exact digest, merge B2 personally (the gate will say REJECTED), then O8 and O9.

## E5. Spec approval bound to a key, not to a merge
- Today a record in `gate/approvals/` binds only because it is on `main` (A02 FAIL). Whoever can merge can
  write approval.
- Design: the owner signs a canonical statement with `ssh-keygen -Y sign` and an `ed25519-sk` key with the
  `verify-required` option. The statement lists repository, decision, `input <path> <old> <new>` for each file,
  and `proposal_sha256`.
- The gate rebuilds the statement only from the record fields that it already checks. It verifies the
  statement with `allowed_signers`, built from `governance/owner-signers` in the trusted base AND the admin-only
  variable `FORGE_OWNER_SIGNER`; the two must be equal. The verify uses the namespace `forge-approval-v1`.
  No valid signature means REJECTED.
- Key rotation: a new signer line needs a signature by the old key.
- Testable now: `s1-demo/run.log` uses TEST keys only. The genuine signature verifies (exit 0). Five negatives
  give exit 255: one changed byte, an unregistered key, another namespace (two forms) and a wrong principal.
  Not shown: the hardware PIN and touch, and the frozen `approval.py` diff (it needs an exact owner-approved diff).
- Needs the owner: O11 (key on a hardware token, never in D-agent), and an exact diff to frozen `approval.py`
  and `proof-gate.yml`.

## E6. Deployment and sink admission check the same record
- The consumer verifier admits a digest D only when all of these hold:
  (1) a Sigstore attestation of VERIFIED for D, whose certificate identity is pinned to
  `mack-dot/forge/.github/workflows/<gate>.yml@refs/heads/main`, with the event and the commit;
  (2) the owner's `forge-approval-v1` signature covers the spec digests that the attestation names;
  (3) the binary-to-proof manifest matches D;
  (4) an append-only log entry exists before the effect.
- The verifier code and the pinned owner key live in D-consumer, not in the repository. A repository edit
  cannot widen the verifier.
- The sink (Slice 3) must stop trusting a key that the minter process creates for itself (`minter.ts:44`).
  It needs an issuer key in D-github or D-owner, and it checks (1) and (2).
- Testable now: none against a real deployment (none exists: 0 environments, 0 releases). The signature parts
  are the same as E5.
- Needs the owner: where D-consumer runs; issuer key custody.

## E7. Fail-closed table
| Condition | GitHub merge | Consumer |
|---|---|---|
| Gate exit 1/2/3-code/4, timeout, crash, no receipt | `forge/admission` failure or absent -> blocked | no VERIFIED attestation -> refuse |
| Stale head/base, foreign run/PR/repo | no status posted -> blocked | attestation commit != D's commit -> refuse |
| Approval record without valid owner signature | gate REJECTED (E5) -> failure | signature check fails -> refuse |
| Gate unavailable (Actions outage, 403 rules) | status absent -> blocked (only once rules are enforceable) | refuse; no override path in the verifier |
| Owner absent | nothing merges, nothing deploys | same |

## E8. What this design still trusts
GitHub's enforcement of rulesets and App permissions; the hosted runner; the owner's account security (passkey);
the owner's own device for digests and signing; the owner's review attention for documents admitted under exit 3;
`end_to_end=false` stays: exit 0 covers only the ledger obligations.
