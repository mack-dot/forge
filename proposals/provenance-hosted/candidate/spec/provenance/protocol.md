# Forge Stage 9 provenance contract, version 1.0.0

## Scope and activation

This contract governs one research release of the exact Stage 7 C self-test ELF.
It adds provenance and observed deployed-file identity. It does not add a proof
method, authorize production deployment, execute payments, or establish whole
application correctness. Every canonical result has `end_to_end=false`.

The associated policy is `policy/provenance.json`. Its identifier is
`forge-stage9-provenance`, version `2.0.0`, epoch `2`. The lock is
`spec/provenance/spec.lock`. A release verifier uses its independently installed,
approved policy and lock. Candidate bundles cannot supply replacement trust.

This contract alone cannot authorize a release. An exact, separately approved
`gate/provenance/implementation.lock` must bind every executable acceptance and
signing input, including workflow bytes, helper code, schemas, container and
action pins, deployment observer, and dependency locks. Missing approval or any
missing/mismatched input is rejection. Approval of this contract does not approve
future gate code, workflows, or an implementation lock with unspecified bytes.

## Authorized signer and root of trust

The sole positive signer is the GitHub Actions workload identity:

`https://github.com/superpowermentors-1/forge/.github/workflows/provenance.yml@refs/heads/main`

The OIDC issuer is exactly `https://token.actions.githubusercontent.com`.
The repository is `superpowermentors-1/forge`, repository ID `1434789853`, owner ID
`235148649`. The event is `workflow_dispatch`; the ref is `refs/heads/main`.
No wildcard identities, local agent keys, alternate issuers, forks, pull-request
jobs, or user-entered certificate identities are authorized.

Cosign must authenticate the issuer, certificate identity, workflow repository,
ref, event and exact workflow commit. The expected commit comes from a trusted
release request, not from the candidate attestation. The verifier retrieves the
workflow and its entire approved executable input set at that authenticated
commit and checks them against the separately approved implementation lock.
An approved workflow path at an unapproved revision is insufficient. The GitHub
repository/owner IDs must also match authenticated GitHub API metadata; these
API checks are a distinct HTTPS/GitHub trust assumption, not a claim that Cosign
checks numeric IDs. Unknown identity fields or absent required checks reject.

The producer has `contents: read` and `id-token: write` only where needed. It
does not check out or execute candidate-controlled workflow code. It runs the
approved checkers in an isolated job with pinned tools. Signing occurs only
after actual checks pass for the exact bytes to be signed. The OIDC token and
ephemeral signing key must not enter logs or published evidence. The public
certificate, signature and transparency records are published.

Cosign is version 3.1.4, with executable hashes in the policy. Its embedded
Sigstore public-good TUF bootstrap is the initial trust anchor. Its established
TUF client must authenticate updates, versions and expiration using a trusted
clock. TUF-authorized root rotation is explicitly within this trust delegation.
Archive the actual validated root, target and metadata bytes and their hashes
for each run. Neither a candidate-supplied root nor a silently substituted local
root is trusted. Environment overrides and insecure verification flags reject.

Require certificate-chain verification, certificate transparency verification,
Rekor inclusion verification and authenticated signing time. A certificate must
be valid at the authenticated signing time. An expired leaf certificate does
not, by itself, invalidate a historical signature. Historical authenticity does
not authorize a fresh release. Current release checks also require current TUF
validation and the freshness rules below. Historical offline verification is
reported separately and cannot substitute for a fresh release decision.

Trust includes GitHub account/workflow controls, GitHub OIDC and API services,
Sigstore Fulcio, CT and Rekor services, TUF threshold authorities, the pinned
Cosign build/distribution, HTTPS bootstrap, the release controller, its clock
and state, isolation of the checker job, and host OS/hardware. A compromised
authorized producer can sign lies; a signature alone does not prove a theorem.

## Claims and independent proof requirements

The only release artifact is the 1,240-byte ELF with SHA-256
`8ced2ab6c7160338899056fe51bacb23d86d81705eacfdd1e992cf5252bdaeb6`.
Its locked Stage 7 evidence contains two required claims:

- `S7-OWN-TERMINATION`: every valid modeled input and entry of this fixed-input
  ELF terminates normally with status 0 under the pinned LPS `may_fail` model.
- `S7-OWN-VALID-EXECUTION`: a genuine valid input and entry exists, and all valid
  executions from it terminate normally with status 0 in that model.

Both require `kernel_checked_proof`. No other evidence method is a substitute.
The exact statements, proof sources, executable, build provenance, input
identities, toolchain and complete assumption audit are locked. Retain the full
13 assumptions for each theorem and 86 permitted assumptions in the independent
closure. Counts are descriptive; equality of names and identities is required.
Do not enlarge an allowlist or omit dependencies to obtain acceptance.

Before signing, the approved producer must freshly execute real proof
compilation, theorem/witness binding checks, independent `rocqchk` over the
complete dependency closure, and the final assumption audit. This is a Stage 9
replay of the accepted Stage 7 result, not a new theorem or a completed result
in advance. Check ELF and source identities before and after. Record commands,
codes, all output, dependency membership and digests. Reusing compiled inputs
does not count as fresh kernel execution. A `passed` field or a historical log
alone never satisfies this producer requirement. The release verifier freshly
verifies the actual signature and enforces this approved producer and proof
receipt policy; it does not pretend to run a kernel if it only verifies a receipt.
Independent replay remains possible from the archived exact inputs.

The model and primitive assumptions remain those in the locked Stage 7 audit:
Rocq 9.2.0, the published ELF loader and pinned RISC-V/LPS execution model,
valid-input/entry restrictions, single-thread execution, no external interference,
and the recorded allocation/environment limits. Compiler correctness, general
GCD correctness, physical model fidelity and whole-service behavior stay unproved.

Locked Stage 8 source and property evidence are supplementary only. Preserve
`source_proof` for R1–R5 and `property_tested` for T1–T3. Model recommendation
quality remains unmeasured. Neither Stage 8 artifact authorizes this ELF or
converts a refund-source claim into a binary or deployment claim.

## Signed statement and deterministic evidence

Use the established in-toto Statement v1 and Sigstore DSSE bundle formats.
The statement type is `https://in-toto.io/Statement/v1`; the predicate type is
`https://github.com/superpowermentors-1/forge/attestations/provenance/v1`.
Use pinned Cosign `attest-blob` and `verify-blob-attestation`; do not implement
cryptography, signature validation, certificate validation, or proof semantics.

The statement must bind the exact ELF subject and the packaged image subject
with SHA-256 digests. The predicate binds the claim IDs and required methods,
the exact existing proof evidence and audit, fresh proof-replay receipts, all
specification hashes, policy ID/version/epoch/hash, contract and lock hashes,
implementation-lock hash, dependency/toolchain identities, source revision,
build and packaging commands, package-to-ELF mapping, and a trusted release
request. All referenced bytes are available and hash-checked. No digest is
accepted merely because it occurs in a signed JSON document.

Canonical JSON uses sorted keys, compact separators, ASCII escaping and one
final newline. Reject duplicate keys, non-finite numbers and ambiguous fields.
Canonical evidence is a separate file. The signed statement is a provenance
envelope input and may bind external request and execution-receipt digests.
Canonical evidence excludes timestamps, certificates, signatures, log entries,
random deployment IDs and resource timings. Archive those external records and
fresh-execution receipts separately. Reproduction compares canonical evidence
for identical explicit inputs; it does not demand identical signatures or
identical network metadata. Changes to an explicitly bound input change the
corresponding digest. Existing Stage 7–8 canonical files remain unchanged.

## Freshness and release authorization

The trusted release controller supplies the expected source commit, exact
artifact/package hashes, approved policy version/epoch/hash, implementation-lock
hash and a fresh 256-bit challenge. The controller stores the pending challenge
and consumes it atomically at admission. It never takes expected values from
the candidate it is deciding upon. The signed release request binds these
values and the canonical-evidence digest. It is external request metadata;
the deterministic proof evidence does not gain random fields or timestamps.

A stale policy, old specification, substituted evidence, wrong expected commit,
unknown/consumed challenge, or changed artifact rejects even with a valid
signature. Loss of controller state requires rejection, not challenge reuse.
Repeated independent verification of a historical bundle is allowed as an
audit operation; it cannot repeat deployment admission. This controller is a
Stage 9 research fixture with explicit trusted state, not production rollout
authorization. Remote attestation of the controller is not established.

## Packaging and observed deployment identity

Build a research-only container that stores the exact ELF at
`/opt/forge/gcd-selftest.elf`. Record the base image digest and platform manifest,
build recipe, resulting image/config/layer digests and ELF mapping. Packaging
may add metadata and layers; it must not strip, relink or otherwise alter the ELF.
Inspect actual package contents with established container tooling and hash
the extracted ELF. The planned base is the existing pinned Stage 7 checker
image; all final runtime/tool pins require the separate implementation approval.

Create and start a local, isolated non-production container from that package.
Use no network, no privilege escalation, a non-root user, a read-only root
filesystem and explicit CPU/memory/PID limits. Do not modify global Docker
configuration. The container may run an idle supervisor: this demonstration
claims materialization of the ELF, not execution of RISC-V instructions.

Observe the actual container ID, state, image and configuration. Read the ELF
bytes through the actual running container filesystem namespace, then hash
the observed bytes and compare with the accepted ELF. Record mounts before
and after; reject mounts or transformations that replace or obscure the target.
Bind the observation to the exact container, path, package and release request.
An intended manifest, image tag or `docker export` alone is insufficient.
Require pre/post identity checks; reject instability or unobserved targets.

The observation supports only `deployed_file_identity` at that observation.
It does not prove that the guest ELF ran, that every executed byte came from
the image, that a live process is unmodified, or that the state persists later.
The observer, container engine/runtime, filesystem namespace, loader if used,
host kernel, hardware and possible emulation remain explicit trusted boundaries.
Do not label an emulator's `/proc/.../exe` as the guest ELF. There is no deployment
correctness proof or remote platform attestation. Keep `end_to_end=false`.

## EXIT controls and records

Each of the six ROADMAP EXIT commands records the harness code separately from
every real Cosign, policy, proof and deployment command code. Where no tool ran,
record `not_run` and its reason, never an invented nonzero code. Preserve every
attempt, including setup failures, exact inputs, seeds where used and raw output.

- `valid-bundle`: actual authorized signature, fresh proof receipt, all locked
  claims and identities, current request and policy pass. Repeat canonical
  construction and fresh signature verification. Reject altered evidence and
  a validly signed unsupported/mislabeled property; no method upgrade is allowed.
- `unsigned`: valid statement and available inputs but no signature; the real
  Cosign verification path rejects unsigned material for absence of signature.
- `wrong-signer`: a genuinely signed, otherwise valid fixture verifies under
  its own identity, then fails under the unchanged authorized signer policy.
  No private key is silently authorized to make the positive case pass.
- `wrong-digest`: a genuinely authorized signature for a different real blob
  verifies against that blob, then fails binding to the expected artifact. Also
  reject tampering with signed evidence. Record the cryptographic verifier's
  code and any separate policy rejection; they need not be the same code.
- `wrong-policy`: an authenticated signature covering a wrong ID/version/epoch
  or policy hash must pass signature verification and fail release policy.
  Include stale/consumed-request, changed-spec and unsupported-method controls.
- `deployed-identity`: the observed deployed ELF matches. Deliberately replace
  it in the actual deployed view and require refusal of the coverage claim.
  A test against an unchanged intended manifest is not this negative control.

Negative fixtures may be signed by a separate, exactly approved test-only
workflow. That workflow never has the authorized positive identity. A negative
control that needs an authorized signature over a disallowed statement must
be an explicitly reviewed test path in the separately approved workflow. Its
output cannot authorize a release without all independent policy checks.
These fixtures must be explicitly marked as security controls and can never
authorize deployment. Check the intended signature/digest/policy rejection
before this additional fixture exclusion, so it cannot mask a broken control.
Missing dependencies, malformed setup, network or permission errors cannot
count as successful security controls. Unavailable capabilities block Stage 9.
