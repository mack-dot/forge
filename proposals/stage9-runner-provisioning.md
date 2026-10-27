# Stage 9 dedicated-runner provisioning plan

Status: review only. Nothing here authorizes provisioning or execution.
Stage 9 remains CURRENT. `end_to_end=false`.

The file-only approval at `06b40caa6bf5fb6963756b39646413559f84c61d` excludes
runner registration, workflow dispatch, public Sigstore signing and deployment.
The [receipt audit](../docs/stage9-signing-preparation-audit.md) found unresolved
checks. Resolve those findings through separate exact approval before signing.
The following is a concrete proposed operating plan, not a claim that its
controls are already installed or tested.

## Admission prerequisite

Read-only GitHub metadata confirms that `mack-dot/forge` is public and its
owner type is `User`. The observation is in
[repository-metadata.json](../results/stage9/implementation-adoption/repository-metadata.json).
Do not assume organization runner groups are available on this repository.
GitHub documents runner groups for organizations and enterprises and warns
about public-repository workloads on self-hosted runners.
[GitHub runner access documentation](https://docs.github.com/en/actions/how-tos/manage-runners/self-hosted-runners/manage-access).

The required admission rule is: only the reviewed `main` revisions of
`.github/workflows/provenance.yml` and
`.github/workflows/provenance-negative.yml` can use the runner. Review all
executable inputs against the approved lock before dispatch. No fork, pull
request, unrelated workflow or arbitrary candidate command may use this host.
The `forge-stage9` label routes jobs; it is not an authorization boundary.
Manual queue inspection and an obscure label do not establish this rule.

**Registration is blocked until an enforceable admission mechanism is
selected and demonstrated.** An organization/enterprise runner group can
restrict selected repositories and workflows where that feature is available.
The workflow allowlist would contain the two full workflow paths at
`refs/heads/main`; write access and branch changes must also be controlled.
[GitHub workflow access controls](https://docs.github.com/en/enterprise-cloud@latest/actions/how-tos/manage-runners/self-hosted-runners/manage-access).

That group is not established here. Moving this personal repository to an
organization would change the approved owner/repository identity and require
new exact contract, policy and workflow approval. Do not transfer it, change
visibility, or widen the signer policy under the present approval. Keeping the
current identity requires a separately reviewed, demonstrably effective
admission mechanism. This plan does not invent one or treat labels as one.

## Host and isolation layout

Use a dedicated Apple Silicon machine. Do not use the user's working Mac.
Give it no personal home directories, iCloud account, developer keychain, SSH
keys, production credentials or production network access. Use a dedicated
non-admin account, `forge-runner`, without passwordless sudo. An operator uses
a separate administrator account only for explicitly approved provisioning.
Docker access is powerful; the whole dedicated host is the isolation boundary.

Use one job per disposable runner instance. A proof job and a signing job must
not share mutable host state. Restore a trusted host baseline between them;
transfer proof outputs only through the workflow's same-run artifact download.
Use a separate restored instance for the wrong-signer job. A single physical
host can serve these jobs sequentially after restoration. Preserve external
logs before teardown. GitHub's `--ephemeral` unregisters a runner after one
job; it does not wipe the host. `--disableupdate` preserves the approved runner
binary, subject to GitHub's update enforcement.
[GitHub ephemeral-runner behavior](https://docs.github.com/en/actions/reference/runners/self-hosted-runners).

| Location | Proposed access and purpose |
| --- | --- |
| `/Users/forge-runner/actions-runner` | Fresh runner installation per job; no cross-job credentials. |
| `/Users/forge-runner/actions-runner/_work` | Disposable exact-commit checkout; never the original developer workspace. |
| `/opt/forge-stage7-seed` | Operator-owned trusted seed, readable by the runner; exact Git objects and 45 locked Python dependency files. Set `FORGE_STAGE7_ROOT` here. |
| Docker volume `forge-stage7-upstream-bf6a65114ed2` | A job-local clone of the trusted Linux-native seed, on this host's isolated Docker daemon; writable by container UID/GID 1000:1000. |
| Separate controller host | Approved checkout, expected lock/commit and request database outside candidate data; database mode 0600. No runner write access. |
| External evidence archive | Complete raw logs, failed attempts, digests and actual codes; no ephemeral keys or credentials. |

Provision the Linux volume from the verified upstream commit and preserve all
case-colliding paths. Verify its exact tree and dependencies before use. Do not
reuse a volume from an untrusted workload. A seed accelerates construction;
it never substitutes for a fresh independent kernel check. Keep the original
Stage 7 environment and its failure records intact. Do not repair permissions
by changing the personal workspace or global Docker configuration.

## Pins and resource allocation

The installed [runtime pins](../gate/provenance/runtime.json),
[Stage 7 pins](../toolchain/stage7-pins.json), and
[provenance policy](../policy/provenance.json) remain authoritative.

| Component | Required identity |
| --- | --- |
| Actions runner | 2.338.2, osx-arm64; official archive SHA-256 `25a065af409ffa317ab4d5a3b614dd15fc9c40f2172bc1b35a1b1258e919a388`. |
| Python | 3.10.11; pinned dependency file identities must match. |
| Docker Desktop | 4.48.0 (207573); client/server 28.5.1, API 1.51; exact commits and components in runtime.json. |
| Build tools | Buildx 0.29.1-desktop.1; Docker driver `desktop-linux`; BuildKit 0.25.1. |
| Linux runtime | `6.10.14-linuxkit`; proof workload uses the pinned platform and image. |
| Proof checker image | `ghcr.io/theorem-labs/oss-fuzz-theorems-checker@sha256:cc9ae43a9f4b0dd59d7c8d30727d36e039bfe72a2a9f9c4a99c68e413037e902`. |
| Proof tools | Rocq 9.2.0, OCaml 4.14.3 and the exact existing upstream/source pins; full dependency closure remains required. |
| Cosign | 3.1.4; darwin-arm64 SHA-256 `9f9b8cd557cf2e5b3df3373a00baa005a86b02391e3e06dd0ce37b3a1533d3a4`. |

The exact macOS host build and dedicated hardware have not been selected.
Record and review both before registration; the existing gate pins only
Darwin/ARM64, not a full macOS build. Authenticate the runner archive against
the approved digest. A printed version alone does not authenticate its bytes.
Retain installer identities and the restored host baseline identity.

Proposed allocation: 32 GiB host RAM and at least 200 GiB free local SSD, with
at least two Docker VM CPUs and 8 GiB VM RAM. These are planning allocations,
not measured sufficiency or speed claims. Configure only the dedicated host
after authorization. Record actual peak memory and storage use when checks run.

The approved proof command pins CPU 0, memory and memory-plus-swap to 4 GiB,
512 PIDs, a 256 MiB temporary filesystem and unlimited stack. It uses a
read-only root filesystem, no network and UID/GID 1000:1000. The observer uses
CPU 0, 256 MiB, 64 PIDs, no network, a read-only root, all capabilities dropped
and no new privileges. Packaging has no explicit per-build CPU/memory limit;
the dedicated Docker VM supplies its outer resource allocation. The approved
read-only binds expose only the dedicated seed and checked project inputs.
No privileged container or mount of personal host directories is proposed.
An external service timeout,
OOM or tool mismatch is a blocked attempt, never proof rejection or success.

GitHub may stop scheduling an outdated pinned runner. Its documentation requires
updates within 30 days of a new release and can enforce critical updates sooner.
If 2.338.2 cannot register or receive a job, retain the actual error and seek
an exact pin revision. Do not silently update or bypass the pin.
[GitHub runner update requirements](https://docs.github.com/en/actions/reference/runners/self-hosted-runners).

## Credentials, permissions and network

The administrator creates the short-lived runner registration token on the
separate control machine. Do not give the runner a personal access token or
repository administrator credential. GitHub repository registration tokens
expire after one hour; creating one requires repository administration access
(fine-grained `Administration: write`). No such token was requested here.
[GitHub registration-token API](https://docs.github.com/en/rest/actions/self-hosted-runners).

Only after admission and registration authorization, configure the authenticated
runner with `--ephemeral --disableupdate` and label `forge-stage9`. Keep token
material out of shell traces, command records and public logs. Keep private
runner configuration readable only by its account. Do not start a persistent
system service or place long-lived bootstrap credentials on the machine.

| Actor/job | Permissions and secrets |
| --- | --- |
| Independent controller | Expected lock, commit and artifact identities; nonce database; dispatch capability only after separate authorization. No candidate-supplied trust roots. |
| Proof job | `contents: read`; no OIDC signing permission, payment or deployment credential. Checkout does not persist Git credentials. |
| Sign job | `contents: read`, `actions: read`, `id-token: write`; no repository write permission or production secret. |
| Negative signer | Same limited permissions, distinct approved negative-workflow identity; never admitted as the release signer. |
| Local release verifier | Pinned Cosign and authenticated public TUF state; separate controller state; no signing key. |

The positive certificate identity must remain exactly
`https://github.com/mack-dot/forge/.github/workflows/provenance.yml@refs/heads/main`,
with issuer `https://token.actions.githubusercontent.com`, the expected workflow
commit and the approved numeric repository/owner IDs. Do not use a local key,
alternate issuer, wildcard or candidate-selected identity. Never archive OIDC
tokens, private signing keys or runner credential files. Retain public bundles,
validated TUF metadata and actual signature-verification output.

Deny access to production networks, unrelated LAN hosts and cloud metadata
services. Permit outbound HTTPS only for required GitHub job/artifact APIs,
pinned image/download sources and Sigstore services named by authenticated
configuration. Determine the exact allowlist from GitHub's documented runner
endpoints and validated Sigstore configuration before bringing the host online.
Do not claim that an untested firewall list works. The proof and observation
containers remain network-disabled. No public inbound service is required.

## Reviewable operation sequence — not executed

1. Resolve receipt-binding findings with exact protected-file approval. Select
   an enforceable workflow-admission mechanism and review its configuration.
2. Approve the dedicated hardware, OS build, resource allocation, installer
   identities and isolation settings. Provision that host only; verify pins,
   case-sensitive upstream identity and fresh writable volume ownership.
3. Authorize registration separately. Authenticate the archive, create the
   short-lived token off-host, and register one ephemeral instance. Record
   runner identity and admission controls without recording secret tokens.
4. Authorize the two named manual workflows, public signing and local research
   container execution separately. Fix the exact dispatched commit and lock
   in the independent controller. Public transparency entries are permanent
   external records; file approval alone does not authorize them.
5. Run the proof job, archive its complete output, restore the host, then let
   a clean sign job validate the same run's artifact. Use another clean instance
   for the distinct wrong-signer workflow. Run all six real EXIT commands with
   their required controls; record checker and harness codes separately.
6. Before teardown, verify external copies of all records, including failures.
   Unregister any remaining instance and destroy only the disposable host's
   runner credentials, workspaces and mutable volumes. Retain original evidence
   and trusted seed identities. Registration teardown does not revoke an issued
   public certificate or erase a transparency entry.

No step above has run. No cost, duration, availability or successful pin
compatibility is claimed. This plan does not authorize Stage 10 work.
