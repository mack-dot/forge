# Proposed single hosted macOS preflight

Status: prepared locally; publication and execution NOT RUN.
CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.

The candidate is one standard GitHub-hosted `macos-15` ARM64 VM for the existing
public `mack-dot/forge` repository. GitHub documents this standard public-repository
class as free and each job as a fresh VM. It has3 M1 CPUs,7GB RAM and14GB storage.
This is a candidate profile, not a validated proof environment.
[Provider specification and public-repository pricing](https://docs.github.com/en/actions/reference/runners/github-hosted-runners).

Prepared file: `m1-macos-preflight.yml`. Requested external action:

1. Create `proposal/m1-macos-preflight-20261106` in `mack-dot/forge`, based on
   existing main commit `f9eb1cbc252b28c80e5dfe2774da71bc35a31bd3`.
2. Publish only this prepared file as `.github/workflows/m1-macos-preflight.yml`.
   That push starts one environment-only job on the exact dedicated branch.
3. Read its logs and retain real exits,errors,paths,image and workflow identities.

The workflow has no repository checkout, action dependencies, package installs,
secrets, signing, proof inputs or toolchain uploads. Its token permissions are
empty. A job-level public-repository guard and standard runner label restrict
it to the documented free class. It changes permissions only on its own new
temporary file for a negative control, then removes that file. No sudo or
security-policy change is included.

The job observes OS/architecture,image identity,resources,/var/tmp mkstemp,
read/write,a denied read of its own mode000 file,process execution and64MiB memory.
It pins the candidate image version to20261104.0514.1. An image mismatch fails
and requires review; it will not silently accept a new image.
[Published macOS15 ARM64 image release](https://github.com/actions/runner-images/releases/tag/macos-15-arm64%2F20261104.0514).

The remote main identity and public visibility were read through the connected
GitHub app. The12 workflows at that exact base contain no push trigger for this
proposal branch, so this file introduces the only matching workflow trigger.
No PR or main-branch mutation is proposed.

This job does not validate the pinned HOL/PolyML production chain or prove that
the provider's administrators cannot interfere. Its VM is disposed after the
job; a future SAT job must repeat its environment controls in that same future
job before execution. Peer-job separation relies on GitHub's fresh-VM claim.
Full proof-input/output exclusivity and provider trust remain explicit review
items.7GB RAM is not asserted sufficient for the complete M1 chain.

After a successful preflight, prepare the exact immutable HOL/SAT transfer
manifest. That external transfer and SAT run need their own explicit approval.
No refund specification,event trace,resource premise or trusted runtime changes.

Why approval is required: the user's previous goal says, "Do not install
infrastructure, incur cloud charges, change security settings, or transfer
source/evidence to a new external host without explicit authorization."
This proposal publishes a new generic workflow and runs it on an external VM.
Approval is requested for these exact three steps only. Existing M1 authorizations
and all protected-file,Stage12,swarm,signing and deployment restrictions remain.
