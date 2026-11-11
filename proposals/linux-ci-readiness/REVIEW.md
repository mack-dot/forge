# PR #30 review and approval boundary

No stage is CURRENT. This is authorized readiness work, not Stage 12. No SPM
resources, ephemeral environments, cloud resources, approval settings, signing
policy, production services or deployed artifacts were changed.

## Verdict

**Ready for human review and approval as a narrow Linux-profile change; not
eligible for agent merge now.** No high/critical accepting-path defect was
established by the scoped diff and source review. One low-severity diagnostic
issue and two integration/measurement limits remain below. This is not an
independent-person security audit or a new Linux execution claim.

Exact head: `561d2dda904daf18f17a0fede93f28b502d72884`.
Base: `4e4112c677ec79c66f191a068f259e85c20953d3`.
Tree: `4d10677833ac3b8a407a92c95460125915a9cc55`.
Lock: `ac883083f6326b9d017f3228966f235c1108b05f4129f81c0de8020e1c127f1a`.
Fresh API reads still show zero reviews, open/unmerged, and blocked. The existing
verify check failed; report succeeded. No approval or merge was submitted.

## Findings with exact-head source references

1. **Low — unsupported hosts can exit 1 at import, contrary to the advertised
   infrastructure exit 2.** [obligations.py:25](https://github.com/mack-dot/forge/blob/561d2dda904daf18f17a0fede93f28b502d72884/gate/obligations.py#L25)
   evaluates `pin_file` when imported. [common.py:22](https://github.com/mack-dot/forge/blob/561d2dda904daf18f17a0fede93f28b502d72884/gate/common.py#L22)
   raises RuntimeError for an unsupported OS/architecture. The import at
   [incremental.py:30](https://github.com/mack-dot/forge/blob/561d2dda904daf18f17a0fede93f28b502d72884/gate/incremental.py#L30)
   occurs outside the main error handler. [refund.py:51](https://github.com/mack-dot/forge/blob/561d2dda904daf18f17a0fede93f28b502d72884/gate/refund.py#L51)
   has the same top-level selection. This is a static inference, not a run on
   an unsupported host. It refuses acceptance, but may misclassify a tooling
   error or omit operation.json. It does not block Linux/x86_64 approval. Correct
   the exit-code claim or propose a separately approved error-handling repair.

2. **Known integration limit — changed ledger PRs still lack a Linux committed
   evidence path.** [obligations.py:47](https://github.com/mack-dot/forge/blob/561d2dda904daf18f17a0fede93f28b502d72884/gate/obligations.py#L47)
   reads root evidence.json; [obligations.py:249](https://github.com/mack-dot/forge/blob/561d2dda904daf18f17a0fede93f28b502d72884/gate/obligations.py#L249)
   refuses a different profile. This is fail-closed behavior, not a false
   acceptance. Direct Linux ledger source proof can run; full changed-ledger
   acceptance needs a separately approved profile-specific evidence design.

3. **Measurement gap, pre-existing — ordinary CI artifacts do not prove warm
   dependent-obligation reuse.** [pr_check.py:81](https://github.com/mack-dot/forge/blob/561d2dda904daf18f17a0fede93f28b502d72884/gate/pr_check.py#L81)
   records replay exit and byte equality but omits the replay operation record.
   [proof-gate.yml:49](https://github.com/mack-dot/forge/blob/561d2dda904daf18f17a0fede93f28b502d72884/.github/workflows/proof-gate.yml#L49)
   uploads only build/pr. The replay operation is in build/change-run-*.
   [obligations.py:349](https://github.com/mack-dot/forge/blob/561d2dda904daf18f17a0fede93f28b502d72884/gate/obligations.py#L349)
   copies the prior command list and duration into a reused record; those are
   historical executions, not fresh work. Do not count them twice. A separate
   optional replay-retention patch is prepared; no change is installed.

## Security and lock review

- All 100 lock entries match exact commit blobs. Nine entries changed; three
  Linux pin files were added; no entry was removed. The local tracked source
  matches the commit. `integrity.json` records the fresh audit.
- The profile tables select host-specific pins. Existing Linux executable
  hashes, validator content checks, verification options, schema, policy,
  exact input sets, immutable source copies and final input checks remain.
  Input/profile changes alter reuse keys; missing profiles do not pass.
- The regenerated evidence changes only four trusted gate-input hashes.
  No source artifact, formal specification, claim or method is expanded.
- Workflow, bootstrap, provenance common.py/release.py and policy are unchanged.
  Historical fresh bootstrap checks were 0 for the new lock and 1 for the old
  lock; these were not rerun in this review. The lock covers the Stage 9 producer
  closure. It is not a claim that every PR workflow/backend is in that lock.
- [incremental.py:36](https://github.com/mack-dot/forge/blob/561d2dda904daf18f17a0fede93f28b502d72884/gate/incremental.py#L36)
  protects gate, policy, toolchain, spec, schemas and .github. Trusted base code
  runs the checks; candidate code cannot replace their policy or harness.
- [proof-gate.yml:8](https://github.com/mack-dot/forge/blob/561d2dda904daf18f17a0fede93f28b502d72884/.github/workflows/proof-gate.yml#L8)
  retains minimal permissions, immutable action SHAs, exact base/head checkouts,
  no persisted checkout credentials and a separate write-capable reporting job.
  No OIDC permission is added. PR evidence is not signed release admission.
- Run [41125456987](https://github.com/mack-dot/forge/actions/runs/41125456987)
  remains a historical protected-change rejection, gate exit 1; it did not
  execute dependent proofs. We did not rerun it or weaken the gate.

## Effective protection observations and administrator action

Fresh reads: main is protected. The branch endpoint reports classic protection
`enabled=false`, required-status enforcement `off`, and empty contexts/checks.
The ruleset collection including parents lists only active protect-main
26065125. It requires one approval, code-owner review, last-push approval,
dismissal of stale approvals, resolution of threads, linear history, no force
push/deletion, and squash merge. It has no required-status-check rule.

These observations support **no configured required check in the visible
configuration**. The full classic endpoint still returned HTTP 403, so complete
administrative settings cannot be certified from this connection. A red check
must not be represented as green or silently overridden.

As an authorized administrator, inspect Settings → Rules → Rulesets and
Settings → Branches, or run these read-only commands from an administrator's
own authenticated session and supply the JSON and HTTP status. Do not share
tokens, change protections, or switch the agent to the owner's credentials.

```sh
gh api repos/mack-dot/forge --jq '.permissions'
gh api --include repos/mack-dot/forge/branches/main/protection
gh api repos/mack-dot/forge/rules/branches/main
gh api 'repos/mack-dot/forge/rulesets?includes_parents=true'
gh api repos/mack-dot/forge/rulesets/26065125
```

An administrator-confirmed 404 for classic protection, together with the
effective rules export, can establish its absence. A 403 cannot. Record any
required context, app binding and strict/up-to-date rule if present. No setting
change is requested. Re-read protections and exact-head approval before merge.

## Smallest next changes and exact authorization

1. Owner reviews #30 at the full head above. If acceptable, `mack-dot` submits
   APPROVED at that head. Separately authorize the pinned squash merge. Neither
   action is granted by this review; no merge is attempted here.
2. A **booking-only demonstration PR** needs only the prepared booking-a.patch
   after #30 merges. [obligations.py:77](https://github.com/mack-dot/forge/blob/561d2dda904daf18f17a0fede93f28b502d72884/gate/obligations.py#L77)
   invokes Dafny booking checks; no Node process is needed. No extra workflow,
   infrastructure, signing or profile-evidence change is needed for this first
   narrow run. Authorize opening that demonstration PR; do not merge it merely
   to run CI. Its new head and future base must be recorded, not invented here.
3. **Smallest Linux Node integration PR:** node-workflow.patch changes only
   .github/workflows/proof-gate.yml. The patch SHA-256 is
   `40152314e825a7d55ffb6ec11cde5d52489c5d0ac203981a64a9c57ea53de51b`.
   It installs the archive/binary from PR #30 pins, checks bundled npm, installs
   trusted package-lock dependencies with scripts disabled, then runs the
   existing content validator. It changes no trigger, permissions, action SHA,
   gate, policy, signing workflow or implementation lock. The PR-check workflow
   is not a member of the Stage 9 lock. Revalidate the patch's preimage after
   #30 merges; any drift needs a regenerated diff and renewed review.
4. Optional replay-observations.patch is **separate** from Node integration.
   It preserves the primary artifact/report layout and copies the one replay
   operation into build/pr/observations on a fresh runner. It adds observation
   only, no acceptance or signing authority. Requires separate exact-diff review.
5. For full ledger-change acceptance, approve a separate per-profile committed
   evidence contract and exact gate diff. This package does not implement it.

Current authorization permits preparation and review only. Opening protected
PRs, applying workflow patches, executing new GitHub demonstration cases, and
merging require the stated next authorization. Stage 12 remains deferred.
