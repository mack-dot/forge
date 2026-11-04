# Fixed ELF correspondence — local review supplement

Current stage: none. Stage12 remains unauthorized. `end_to_end=false`.
Status: PARTIALLY_ESTABLISHED. No new claim or profile is active.

The fixed-input GCD result and modeled exit event passed a fresh full recursive
Rocq replay:597 modules,86 permitted closure assumptions. The actual QEMU run
matches the checked projection and exits0. Complete QEMU/Linux refinement and
new authenticated release admission remain unestablished.

Read REPORT.md, CORRESPONDENCE.md and APPROVAL-PACKET.md. The latter states the
exact conditional claim, six trust conditions and independent review boundaries.
The source files are review copies. `contract.patch` is unapplied; its validation
only checked that it applies. `profile.json.proposed` is inactive.

## Reproduce and inspect

Authenticate these archive digests against the separately reviewed commit before
extracting or running anything. In-archive manifests do not authenticate themselves.
Use the existing pinned checker image and resource limits. No installation or
new persistent infrastructure is required. The original runtime/checker trust
conditions remain; these packets do not replace independent source review.

- `replay-packet.tar.gz` contains all host proof inputs and the existing checker.
  Its README describes a fresh two-object rebuild followed by full kernel replay.
  `--rebuild-only` explicitly omits kernel replay.
- `execution-records.tar.gz` contains the actual records under `records/`.
  Report-relative evidence paths refer to that directory after extraction.
  `records-manifest.json` preserves every archived file's digest and size.
- The70MB runtime packet remains in the owner evidence workspace. Its digest is
  below and in portable-archives.json. The runtime-packet directory here contains
  review copies of its entry point/manifest only; it is not the complete runtime.
  Obtain the complete archive and authenticate its digest before running it.
  Local packet relocation passed. Independent physical-host replay is NOT RUN.

Complete runtime archive in the owner workspace:
`/Users/mackianni/forge/results/executable-correspondence-2026-11-03/attempt-0001/runtime-packet.tar.gz`.

- `replay-packet.tar.gz`: SHA256 `3ae40b4c538928cc4b8c3bb2d4a01f6d771c0c464f2d139e93046cf7291bd4ac`; 1306062 bytes.
- `execution-records.tar.gz`: SHA256 `37098fde2aa3240606f9c4170c04b16c83c6300cb7618f1e068548a2b497b436`; 656544 bytes.
- `runtime-packet.tar.gz`: SHA256 `55eec1b9063b6982c23acf6d8d6624dbbc85fabe9e1fed191c070e57ffc37912`; 70158672 bytes.

PR37 stays at fc85ecc2c7f12caa6c8991fa002410bdf78dd51d, draft and unapproved.
This supplement is separate from that head. PR36's upload repair is separate.
Publication, claim/profile adoption, protected integration changes, merge,
dispatch, signing, admission and deployment retain their approval boundaries.
The owner reports an independent backup; its exact hashes/restore remain unverified.
See BACKUP-HANDOFF.md. Local archive validation and restore both passed.
