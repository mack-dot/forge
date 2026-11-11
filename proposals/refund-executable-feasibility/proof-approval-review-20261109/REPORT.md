# U337: frozen proof-run approval reviewed; execution remains unauthorized

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
No blocking static mismatch was found in the reviewed proposal. This is a
recommendation for a separate approval decision, not permission to run it.
The owner's latest response explicitly authorizes no additional execution.

## Exact artifact and input scope

Reviewed [PROOF-RUN-APPROVAL.md](../hosted-integrity-run-20261109/PROOF-RUN-APPROVAL.md)
and its complete workflow, driver, manifests, candidate, import and two controls.
Workflow16385 bytes, SHA256
`1af894a0f8f13b279c3c4752f77366c02c32075959041d08174c996c01b560a1`.
Driver SHA256
`2667f6d8f81e4286c04a80bf3e856b66c74ce15141d5e80c18e1fb4662d45fd8`.
These frozen files are unchanged. Embedded shell/driver identities match.

| Input | Immutable commit | Manifest SHA256 | Members |
| --- | --- | --- | ---: |
| Addon | `21c4bdf958627e6a24e8dee9a45d90568b3e3c20` | `6822e8da53f477f991bfa4a7cab02ffc59906a58460048a49af190fb42b2c105` |1475|
| Base | `ac05eaf972b8c98784466ae063fca505aaaf25f4` | `6822d1ae4ef5ca78ae14e352c5b1e222ed113bba1f3760d9b0141b70386c51a7` |18|

[REVIEW.json](REVIEW.json) records every archive part identity and the candidate/
import/control hashes. The candidate and import retain the exact quotation SHA256
`289b8be8c848dc3debddbac5184e613e2c1e127c56dddd574e5b43087cc8c29a`.
Its explicit FFI transition, buffer, final state and complete event append remain.
The proof inputs retain cached ancestry. This job is not independent full-chain
replay. U335/U336 provide the existing complete transferred-byte evidence; this
review does not claim another remote download or integrity execution.

## Proposed commands, permissions and budget — NOT RUN

The proposed write replaces only `.github/workflows/m1-macos-preflight.yml` on
`proposal/m1-macos-preflight-20261106`, expected head
`8ad9de1e538edd48a2084796510e784913eaef8b`. A push triggers one job.
Before any authorized publication, recheck that head and all inherited triggers.
This review did not publish, dispatch, or recheck live branch state.

Shell: `bash --noprofile --norc -euo pipefail {0}`.
Entry command: `/usr/bin/python3 -I -B -`, with the exact embedded driver.
One `macos-15` job;15-minute limit; ARM64 and image `20261104.0514.1` required.
Image availability and resource adequacy are untested for this proposed run.
The driver rejects an image mismatch; no substitution is proposed.
Token permissions `{}`; no secrets, checkout action, package install, sudo,
release signing, deployment, or repository security-setting changes.

Environment commands are `/usr/bin/sw_vers`, `/usr/sbin/sysctl -n hw.memsize`,
`/usr/bin/true`, and `/usr/bin/otool -L` on the three private runtime files.
The driver creates its own `/var/tmp` mkstemp file for read/write and denied-read
controls, changes only that file's mode, and removes it. It touches64MiB for a
memory probe. It requires at least4GiB memory and2GiB free temporary disk.
Payload extraction uses a private0700 directory under `RUNNER_TEMP`.
It reads ten immutable public package files,26196042 bytes, from
`raw.githubusercontent.com`; each request has a30-second timeout and no retry.
It refuses redirects, checks manifest/part/archive/member hashes, and checks
input identities before and after each HOL child.

Let `R` be that private root and `T=R/.toolchain/experiments/refund-cakeml-20261104`.
Each HOL invocation is exactly:

```text
T/HOL/bin/hol --maxheap 1536 run --poly R/outputs/<case>/bootstrap.sml
```

Working directory: `T/cakeml/basis`. Cases are `proof`, `repeat`, `import`,
`wrong-exception`, `omitted-event`, in that order. Every next case requires the
previous case's acceptance checks. Each child has CPU120s, wall150s, maxheap1536MiB,
4MiB per-file limit and zero core dumps. These are per-child limits, not a measured
aggregate memory bound. Five child timeouts total750s; download/setup/logging also
consume the900s job budget. Completion within that budget is not established.

The generated bootstrap uses the existing four saved states and public
loadHierarchy/path APIs. The frozen solver binding and fallback stay unchanged.
The driver records argv, environment, streams, actual exits and generated objects.
It checks the exact private dynamic-library paths and input hashes after each case.
Proof/repeat require exit0, completion marker, four exports and identical repeat
hashes. Import requires exit0 and its completion marker. Negative proof controls
require exit1, the exact statement-mismatch reason and no success marker/exports.
These are expected outcomes only. Any unexpected result stops the sequence.
Full logs and complete artifacts must be read back before any theorem claim.

## Actual review results

| Executed command/check | Actual exit |
| --- | ---: |
| `python3 -I -B proposals/refund-executable-feasibility/proof-approval-review-20261109/review.py` |0|
| `/bin/bash --noprofile --norc -n proposals/refund-executable-feasibility/hosted-integrity-run-20261109/records/proposed-proof-shell.sh` |0|

The script parses Python syntax without importing or executing the driver.
It verifies manifests, reviewed source hashes, quotation identity, prior evidence,
50 protected paths and mission bytes. These checks are not proof execution.
Hosted proof, repeat, import and negative proof controls: NOT RUN.

## Control distinction and next boundaries

The three previous hosted integrity controls produced expected in-process
ValueError rejections. They have no separate process exit codes. The surrounding
integrity checker exited0. The two proposed HOL negative controls are separate
children with expected exit1; neither has an observed result yet.

Proceed only after separate explicit authorization of this exact proposal.
If its theorem passes and full evidence is checked, the next mathematical work
is native memory/frame correspondence and whole-program composition. Independent
replay of the entire correctness chain remains a later distinct obligation.
This response grants none of that execution authority. A successful generic
TextIO.read theorem alone would not close M1 or establish physical FFI refinement.
