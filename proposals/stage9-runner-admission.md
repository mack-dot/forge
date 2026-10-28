# Stage 9 runner admission amendment (unapplied)

Status: proposal only. It needs exact user approval. It does not authorize
runner registration, workflow dispatch, Sigstore signing or deployment.
Stage 9 remains CURRENT. `end_to_end=false`. See U083 and U084.

**Correction (U085):** option A below is withdrawn as written. The release
verifier (`release.py` `verify()` → `repository_identity()`) must not use the
producer workflow's token. A corrected design needs a verifier-owned read-only
token on the controller host. Preparation is paused for a platform decision.

## Reason

The [runner plan](stage9-runner-provisioning.md) blocks registration until an
enforceable admission mechanism exists. It also forbids a visibility change
under the earlier approval. On 2026-10-28 the user chose to make
`mack-dot/forge` private ("go private for now"). This amendment records that
decision and states what it does and does not enforce.

## Proposed admission rule

Replace the mechanism requirement in "Admission prerequisite" with all of the
following. Each item is a check that must pass before registration and again
before each dispatch. A failed check stops the run.

1. **Private repository.** `GET /repos/mack-dot/forge` returns
   `visibility=private`, `id=1434789853` and `owner.id=235131950`.
2. **One collaborator.** `GET /repos/mack-dot/forge/collaborators` returns
   exactly `mack-dot`.
3. **No fork pull-request jobs.** Workflows from fork pull requests are
   disabled for this private repository. Verify the exact API endpoint and its
   response before use; it has not been called.
4. **Label scan.** On the expected `main` commit, only
   `.github/workflows/provenance.yml` and
   `.github/workflows/provenance-negative.yml` contain `self-hosted` or
   `forge-stage9`. Today the other three workflows use `ubuntu-22.04`.
5. **Empty queue.** No queued or in-progress run exists other than the one
   dispatched run.
6. **One job per runner.** Register an ephemeral just-in-time runner only after
   the dispatched job is queued. Remove it after that job. Restore the host
   baseline before the next job (unchanged from the runner plan).

## Residual risk (not enforced)

- This is not a GitHub-enforced workflow allowlist. Anyone with write access,
  or a stolen `mack-dot` token, can push a workflow that targets the runner.
  Checks 4–5 detect this at check time only.
- Branch rules on `main` can be bypassed by the owner.

## Required protected change (separate exact proposal, not prepared)

The installed gate fetches GitHub data without a token:
`gate/provenance/common.py` (`repository_identity`, lines 150 and 154) and
`gate/provenance/preflight.py` (line 32). For a private repository these
requests return 404, so the gate fails closed. Observed: an unauthenticated
`GET /repos/mack-dot/forge` returned 404 after the change.

Options:

- **A (recommended).** An authenticated fetch that uses the workflow's
  read-only `GITHUB_TOKEN`. This changes `common.py`, `preflight.py`,
  `clean_environment()`, both provenance workflows and the implementation
  lock. It needs exact-byte approval. The token must never enter records.
- **B.** Make the repository public only for the signing window. This gives up
  admission rule 1 during that window.

## Hardware (open)

The runner plan requires a dedicated Mac. The user has not yet chosen between
a second Mac and a separate non-admin macOS account on the working Mac. The
second option needs a further plan amendment, because jobs share the host.

## Approval

Approve this amendment, choose option A or B, and choose the hardware. Each is
a separate decision.
