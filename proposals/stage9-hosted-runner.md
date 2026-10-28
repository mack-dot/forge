# Stage 9 on GitHub-hosted Linux runners (design, unapplied)

Status: design only. No protected file is changed. It does not authorize
signing, deployment or a provenance dispatch. Stage 9 remains CURRENT.
`end_to_end=false`. See U086. It supersedes the self-hosted path in
[stage9-runner-provisioning.md](stage9-runner-provisioning.md) and the
admission amendment in [stage9-runner-admission.md](stage9-runner-admission.md).

## Decision (user, 2026-10-28)

- Public repository, so anyone can verify a release without a token.
- Producer jobs on GitHub-hosted `ubuntu-24.04` runners instead of a dedicated
  self-hosted Mac.
- Owner/organization: open. The signer identity contains the owner. Decide it
  before the first signature.

## Why

- Each hosted job runs on a fresh VM. No other workload shares it, so the
  self-hosted admission problem (U077) and the dedicated-hardware problem go away.
- The checker image is `linux/amd64`. It runs natively, not under emulation.
- The approved proof container is limited to 4 GiB memory and one CPU. A
  standard public-repository runner has 16 GiB and 4 CPUs.
- `policy/provenance.json` already pins the `linux-amd64` Cosign hash.
- Standard hosted runners are free for public repositories.

## What does not change

The contract, the policy, the signer identity
(`mack-dot/forge/.github/workflows/provenance.yml@refs/heads/main`), the
receipt and package checks in `release.py`, and the independent verifier on a
separate controller host. The verifier needs no token for a public repository.

## What must change (a later exact proposal)

| File | Change |
| --- | --- |
| `.github/workflows/provenance.yml`, `provenance-negative.yml` | `runs-on: ubuntu-24.04`; steps that build the Stage 7 prerequisites from pinned sources. |
| `gate/provenance/runtime.json` | Linux pins instead of Docker Desktop and the macOS runner. |
| `gate/provenance/producer.py` | `runtime()` checks for Linux; builder `default` instead of `desktop-linux`; image-store check. |
| `gate/provenance/preflight.py` | Linux/x86_64 instead of Darwin/arm64; `linux-amd64` Cosign; hosted runner version is recorded, not pinned. |
| `gate/provenance/implementation.lock` | New hashes. |

## Open questions (measure before the exact proposal)

1. Hosted images update weekly. Exact Docker pins need a pinned Docker install
   in the job, or a recorded-not-pinned exception. The hard rules require pins.
2. Free disk after the 5.2 GB checker pull, plus the seed volume.
3. Time to rebuild the upstream clone, the 45 Python dependency files and the
   seed volume per run. Time of the fresh proof run (6-hour job limit).
4. The package config digest built on Linux is new. It is bound per request,
   not fixed in `artifact-identities.json`.

## First step: measurement probe

[probe.yml](stage9-hosted-runner/probe.yml) records the host, Docker version,
image store and free disk, and times one pull of the pinned checker image.
It has only `contents: read`. It signs nothing and runs no proof. To run it,
copy it to `.github/workflows/`, push it to `main` and dispatch it. Do this
only after the repository is public again.
