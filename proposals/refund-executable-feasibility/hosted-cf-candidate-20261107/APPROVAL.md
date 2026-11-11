# Proposed next action: one hosted generic FFI proof job

Approval is pending. Nothing in this packet has been published or run remotely.
The owner's current goal requires explicit approval for additional hosted runs
and external resource use. The U326 one-run grant has already been used.

Approve these two bounded external actions together:

1. Publish the exact [input manifest](payload/INPUTS.json) and its three parts
   to public `mack-dot/forge`, under `proposals/m1-hosted-cf-inputs`, on a new
   `proposal/m1-cf-inputs-20261107` branch. Total new input bytes:10,815,103.
   Reuse the previously published base inputs at commit
   `ac05eaf972b8c98784466ae063fca505aaaf25f4`. No new external host is proposed.
2. Replace only `.github/workflows/m1-macos-preflight.yml` on existing proposal
   branch `proposal/m1-macos-preflight-20261106` with the exact prepared
   [workflow](records/proposed-workflow.yml). Substitute only its
   `ADDON_COMMIT_SHA` placeholder with the new input commit after byte readback.
   This one update triggers one job. No rerun,automatic retry or merge is included.

The new manifest is932,639 bytes, SHA256
`6822e8da53f477f991bfa4a7cab02ffc59906a58460048a49af190fb42b2c105`.
The new archive is9,882,464 bytes, SHA256
`1f7a009b866b18c8299aac5d36b6ad59e54bfb73d4bba568da98ebde3c2146e1`.
It contains1,475 files: pinned CakeML/HOL library files, unchanged cached proof
parents, the unchanged candidate, licenses and four prepared statement checks.
The reused base adds18 files. This is a cached-parent experiment, not independent
full-chain replay. The manifests disclose local source paths and file hashes.

The workflow template SHA256 is
`6db12f716e14a227b5de1b6d7f58da6ba3c020dc07bb87b413a225cedfea2b42`.
The embedded driver SHA256 is
`b859fe575016c8b88f77a9d105e6e54f4535d7b82fffe8173dfdb28223b94eaf`.
The sole permitted substitution changes the final workflow hash; record and
read back that exact final hash before triggering execution. Recheck the branch
head and input bytes. Stop if either baseline has changed unexpectedly.

The job uses standard GitHub-hosted `macos-15` ARM64 and accepts only image
`20261104.0514.1`. It stops if that image is unavailable or any environment check
fails. Maximum job duration15 minutes; each HOL child CPU120 seconds, wall150
seconds, maximum heap1536 MiB and output-file cap4 MiB. At most five serial HOL
children: candidate, identical repeat, fresh import, wrong-exception control,
omitted-event control. Stop at the first unexpected result. A candidate failure
is evidence, not permission to change the theorem or run another job.

The driver checks architecture, OS, resources, actual `/var/tmp` mkstemp,
read/write, process, memory and a denied-read control. It creates private0700
paths, checks every input before and after execution, and uses the public
loadHierarchy/path-registration APIs. Pinned runtime, saved states, library
files, theorem statement and tactics remain byte-identical. It records actual
child exit codes, exception locations where provided, complete streams, runtime
library paths and generated theory files. Compressed log transport includes
raw sizes and hashes; missing or truncated output is a failed evidence check.

Job token permissions are `{}`. No checkout action, secret, install, sudo,
security-setting change, signing, native refund execution or 21-snapshot replay
is included. GitHub's fresh VM and OS isolation remain provider trust; mode bits
and hash checks do not prove isolation against the provider or same-UID code.
The original MiniSat binding remains unchanged. Its historical absolute path
must be unavailable; the unchanged HOL fallback is permitted, as in U326.

Purpose: allow the unchanged `cfLib` load and `read_error_generic` candidate
to run and reveal a genuine proof result or exact residual. Even a checked
candidate would still require native C/memory/frame correspondence and
refund-level composition. No error event or original premise may be dropped.
Stage12 remains unauthorized. `end_to_end=false` throughout this experiment.
