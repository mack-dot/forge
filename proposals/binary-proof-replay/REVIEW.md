# Exact proof-only hosted replay — ready for workflow review

Proposal only. NOT installed, published, merged or dispatched. Stage 12 remains
unauthorized. This does not change the binary theorem or its preconditions.

The existing local Stage 7 runner returned 1. Its proof container returned 137;
then the named container, source volume and checker image were absent. No OOM or
cleanup actor was established. All host failure records remain preserved. Do not
repeat a long proof until its execution environment is stable.

The existing production provenance workflow can sign when a repository variable
is enabled. Its old dry-run workflows use superseded locks and proposal patches.
Neither is a suitable substitute for a current proof-only execution request.

[fix.patch](fix.patch) adds one manual, main-only workflow. The first five setup
steps match the current approved provenance workflow. They retain the immutable
checkout action, hash-checked Python 3.10.11 archive, implementation bootstrap,
pinned Docker packages and case-sensitive Stage 7 restoration. Disk reclamation
runs only on the new disposable GitHub runner. It touches no local Docker or SPM
resource.

The only proof call is the unchanged `producer.replay`, with current lock
`76b983ac279a80ab42bf15c7446ee997a2bcd9b25a003db829f7e8fb2d4b8cd9`.
It compiles the exact existing proof and witness, runs the published independent
Rocq audit, collects the full dependency bytes and applies `validate_receipt`.
Existing image, source, ELF, assumption, fixed-artifact and kernel-command checks
remain unchanged. A proof nonce binds the new receipt; it is not a release request.
There is no controller access, package build, sign job, OIDC permission, secret
input, release admission, deployment or cross-run adoption.

The workflow grants only contents:read. It has no PR or workflow-run trigger.
It checks the exact dispatched source and refuses reruns. The 300-minute job limit
matches the existing workflow. It does not change proof resource limits; timeout,
crash, exhausted budget or missing artifacts cannot pass proof validation.
Output and failure logs are uploaded by the existing immutable artifact action.

## Actual preparation checks

`python3 -B proposals/binary-proof-replay/validate.py` returned **0**.
Six shell bodies passed `bash -n`; the inline Python passed `ast.parse`.
`git apply --check` returned **0** against main
`f9eb1cbc252b28c80e5dfe2774da71bc35a31bd3`.
The check compares setup steps, permissions, pins and calls. It checks proposal
structure only. It does not establish a working hosted setup or passing proof.
Exact workflow SHA-256:
`907f537572c5babe444295be007f67f689a9291c3d7618567120d99dd2f19abc`.
Patch and dependency hashes are in [validation.json](validation.json).

## Exact authorization boundary

The campaign's authority rules require separate permission for publication,
merging and workflow dispatch. Approving this proposal for publication would
permit a standalone review PR containing this exact workflow. It would not permit
self-approval, merge, dispatch, signing, policy changes or Stage 12.
After independent exact-head review and authorized merge, a separate execution
request must name the resulting main commit and this workflow. Confirm the lock
and unchanged proof inputs before dispatch. Record actual job time and cost.

Expected acceptance, NOT RUN: unchanged real Rocq compile and independent audit
return 0; all fixed receipt identities match; all files and logs are retained.
If anything fails, preserve it and report NOT_ESTABLISHED. Do not revise a pin to
make it pass. Even a passing proof replay would not repair the observed QEMU
stack-precondition mismatch or establish execution-model refinement.
