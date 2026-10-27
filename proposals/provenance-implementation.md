# Stage 9 implementation and workflow proposal — awaiting exact approval

Base revision: `097431cf458e5c62332575b09e953224471fa64d`.
The three contract additions at that revision are now approved and applied
exactly. Their [adoption record](provenance-decision.md) and raw commands are
preserved. No existing protected file changed. Stage 9 remains CURRENT.

## Exact decision

This proposal contains **11 additions**: eight protected files, two GitHub
workflows and the EXIT harness. The [manifest](provenance-implementation/approval-manifest.json)
lists every target, candidate, byte count and SHA-256. The complete
[patch](provenance-implementation/proposed.diff) is unapplied.

- Manifest SHA-256: `5ea08fb8e32d875adc1ab3bb690599602cd622a7c61223f8cc56d4c5bbe972fa`.
- Patch SHA-256: `25410a1397fb5d8ea8a616359924afadabc0da64b4bc800ca3aab1f3244642b7`.
- Implementation lock SHA-256: `6b43c19370742b02eb05c66b9a9091a6c47431998ef045a09018fa6671459daa`.

| Target | Purpose |
| --- | --- |
| `gate/provenance/common.py` | Exact input identities, command records, HTTPS source retrieval, real Cosign dispatch. |
| `gate/provenance/release.py` | Authenticated statement/policy/receipt binding and atomic request consumption. |
| `gate/provenance/producer.py` | Independent packaging, controller requests, fresh Rocq replay, constrained fixture construction and Cosign signing. |
| `gate/provenance/observe.py` | Actual container namespace readback and substitution rejection. |
| `gate/provenance/preflight.py` | Check the runner; install only checksum-pinned Cosign; authenticate the negative fixture's producer run. |
| `gate/provenance/Dockerfile` | Package the unchanged ELF with an idle supervisor. |
| `gate/provenance/runtime.json` | Exact runtime/tool pins and the explicitly unprovisioned runner prerequisite. |
| `gate/provenance/implementation.lock` | Bind 60 source/input files and 45 installed upstream Python dependency files. |
| `.github/workflows/provenance.yml` | Manual proof job, followed by a separate signing job with OIDC permission. |
| `.github/workflows/provenance-negative.yml` | Manual authentic wrong-signer fixture from a different workload identity. |
| `scripts/exit_stage_9.py` | Six real EXIT cases, conservative rejection classification, separate tool and harness codes. |

Approval must name this published proposal revision and its exact manifest and
digests. It must distinguish applying these files from permission to dispatch
the defined research workflows, publish public Sigstore attestations, and run
the isolated local container controls. None of those operations is authorized
by the preceding three-file contract approval. This proposal does not authorize
production deployment, payment execution, additional protected changes, or
automatic runner registration/provisioning.

## Acceptance path

The independent controller first packages the exact accepted ELF and generates
a 256-bit request challenge. It stores the expected source commit, image config
digest, policy identifiers/hashes and independently approved implementation-lock
digest in a SQLite database outside the candidate directory. Candidate data
cannot choose the expected policy, signer, implementation or request.

The proof workflow checks out the exact dispatched main commit. It uses the
unchanged `scripts/stage7_own_job.py` in a new attempt directory in the existing
Linux-native Stage 7 volume. It freshly compiles the target proofs and both
binding wrappers. It runs the unchanged upstream independent Rocq checker over
the complete dependency closure and performs the assumption audits. No old log
can stand in for this execution. Existing dependency builds may be reused; all
579 dependency modules are still independently checked. The complete raw logs,
source identities and hashes of every actual `.vo` input are retained.

The separate signing job has `id-token: write`; the proof job does not. It can
only sign the exact release statement and the explicitly constructed security
fixtures. It consumes this run's proof-job artifact through a pinned action.
The negative workflow uses a different certificate identity and checks the
primary run's repository, path, commit, event, branch and successful conclusion.
Workflow re-runs require a new request. Tokens and ephemeral keys are not logged.

The release verifier runs pinned Cosign with exact issuer, SAN, repository,
workflow ref, event and commit constraints. It refreshes TUF, preserves validated
metadata, and uses Cosign's CT, Rekor, certificate and signing-time checks.
It then decodes the authenticated standard DSSE JSON payload and checks exact
artifact/evidence/policy/receipt identities. JSON/base64 handling is not custom
signature verification. No crypto, ELF decoder, RISC-V semantics or proof kernel
is implemented here. The approved acceptance scripts and workflows are also
retrieved at the authenticated commit and compared against the independent lock.

Canonical evidence is separate from signatures, timestamps, TUF records,
execution receipts and controller challenges. Its exact expected bytes retain
the accepted Stage 7 theorem and assumptions and Stage 8 method separation.
R1–R5 remain `source_proof`; T1–T3 remain `property_tested`; model quality remains
unmeasured. A source proof or passing test cannot authorize the C binary claim.

## Package and deployment claim

The package identity is explicitly a **Docker image config SHA-256**, with all
rootfs layer diff IDs, the base index/platform identities and recipe recorded.
It is not labelled as an OCI distribution-manifest digest. No registry push is
needed for the local research experiment. The controller and producer must
independently obtain the same package descriptor; disagreement blocks signing.

The observer freshly authenticates the candidate, atomically consumes the
request for admission, starts an isolated container and reads the actual ELF
through its running filesystem namespace. It compares container state and
mounts before and after. It records the observed bytes even for a substitution
control. The wrong-file control uses a real read-only bind mount over the ELF;
the observer must reject `DEPLOYED_ARTIFACT_MISMATCH`. The extra container is
explicitly labelled as a security fixture, not another admitted release.
Created containers are stopped and retained for inspection; unrelated containers
and all existing proof attempts remain untouched.

The observation establishes file materialization at that time only. The idle
supervisor does not execute the RISC-V ELF. There is no proof of loader behavior,
live instruction identity, persistence, model-to-hardware fidelity or whole
application correctness. `end_to_end=false` is mandatory throughout.

## Six controls and required reasons

All commands below are **NOT RUN**. These are requirements, not results.

| Case | Required real behavior |
| --- | --- |
| `valid-bundle` | Two fresh Cosign/release checks; byte-identical canonical reproduction; reject altered evidence, fabricated receipt and validly signed wrong method. |
| `unsigned` | First verify a positive bundle; remove signatures from an otherwise complete explicit control; require actual Cosign signature-count rejection. |
| `wrong-signer` | First authenticate the fixture under its own fixed identity; then require the exact SAN mismatch under the unchanged release identity. |
| `wrong-digest` | First verify the authorized signature against its actual different blob; then require the established checker's artifact-digest mismatch. |
| `wrong-policy` | Actual signature success followed by policy rejection; also reject signed stale requests, wrong specs and unsupported methods. |
| `deployed-identity` | Actual accepted-file observation; actual substituted-file rejection; repeated admission of the consumed request fails. |

The harness retains native Cosign codes separately from gate and harness codes.
Expected diagnostic strings come from the pinned sigstore-go source. If the
actual tool returns a different error, including an unexpected validation order,
the harness fails. It must not reinterpret that failure as a successful control.
Missing dependencies, expired/unavailable TUF metadata, permissions, failed
containers and network errors never satisfy a negative control.

## Required environment and operations still pending

The workflow uses a **dedicated self-hosted macOS ARM64 runner** with label
`forge-stage9`. This keeps the already measured Docker Desktop and prepared
Linux-native proof environment available. No usable runner has been established
or registered in this preparation. Registration, credentials and host isolation
are a separate operational prerequisite, not something these files silently set
up. Do not attach an unisolated personal host with unrelated credentials. A
different execution profile needs a concrete reviewed pin change, not removal
of the runtime checks.

The proposed runner version is 2.338.2, with its official archive SHA-256 pinned.
The runner installation must be authenticated against that archive during
provisioning; the proposed preflight checks its executed version. Do not claim
that a version string independently authenticates the runner binary.

The approved operator must supply `FORGE_STAGE7_ROOT` pointing to the preserved
Stage 7 checkout, outside the disposable runner checkout. The Linux volume,
exact upstream Git objects and pinned Python dependencies must already exist.
The proposal neither changes global Docker configuration nor repairs host
permissions. The runner must be restricted to the reviewed trusted-main jobs;
no untrusted PR/fork workload is in this authorization. The runner host, GitHub
OIDC/API/artifact service, public Sigstore TUF/Fulcio/CT/Rekor services, trusted
clock and controller state remain explicit trust boundaries.

After exact file and research-operation approval, the operator records the
approved implementation-lock digest independently. `producer.py --action request`
creates the research request and controller database. Workflow dispatch inputs
carry that request and digest. Signed output is downloaded and its authenticity
is determined by the local release gate, not by the download alone. The negative
workflow supplies the authentic wrong-signer bundle. The operator then writes
`.toolchain/stage9/controller.json` with `candidate`, `controller`, `request`,
`challenge`, and `implementation_sha256`, using its independently created state.
No secret, token or private key belongs in that configuration.

Run the six exact ROADMAP commands in their listed order. The deployment case
consumes the admission request; repeating admission requires a new controller
request and fresh signed receipts. Preserve all original attempts.

## Preparation checks and sources

Preparation records are in `results/stage9/implementation-preparation/`.
Only syntax, structural integrity, source-pin research and read-only tool
inventory checks have run. They do not establish that the proposed gate works,
that a signature is valid, or that Stage 9 passes. No Cosign binary was installed,
no new proof was executed, and no container was built or started in preparation.

The first Buildx inventory call used an unsupported `--format` option and
returned 125. The supported read-only `docker buildx inspect` retry returned 0.
Both complete outputs remain archived. The actual observed builder is
`desktop-linux`, Docker driver, BuildKit 0.25.1. The candidate uses that builder
explicitly. This is an integration finding, not a negative security control.

Primary sources:

- [Pinned Cosign verification options](https://github.com/sigstore/cosign/blob/0e48502cf5ef34e2e60bbd3617aa19945712f705/pkg/cosign/verify.go)
  bind certificate constraints and delegate to sigstore-go.
- [sigstore-go 1.3.0 signature checks](https://github.com/sigstore/sigstore-go/blob/v1.3.0/pkg/verify/signature.go)
  and [certificate identity checks](https://github.com/sigstore/sigstore-go/blob/v1.3.0/pkg/verify/certificate_identity.go)
  supply the intended rejection diagnostics.
- [Docker reproducible builds](https://docs.docker.com/build/ci/github-actions/reproducible-builds/)
  documents `SOURCE_DATE_EPOCH`; actual equality remains a required experiment.
- [GitHub runner 2.338.2 release](https://github.com/actions/runner/releases/tag/v2.338.2)
  supplies the proposed runner archive digest. No runner has been provisioned.
