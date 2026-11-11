# Receipt adoption is blocked pending repair approval

Stage: none. Stage 11 remains complete. Stage 12 is not authorized.
This is authorized integration-readiness security work, not a stage transition.

## Confirmed finding: unauthenticated receipt adoption

At PR #30 head `561d2dda904daf18f17a0fede93f28b502d72884`,
[gate/obligations.py:344–350](https://github.com/mack-dot/forge/blob/561d2dda904daf18f17a0fede93f28b502d72884/gate/obligations.py#L344-L350)
accepts a disk record if its key matches and its result is `established`.
It does not authenticate the record or recheck the associated evidence files.
[The store at lines 368–373](https://github.com/mack-dot/forge/blob/561d2dda904daf18f17a0fede93f28b502d72884/gate/obligations.py#L368-L373)
also supplies no independent integrity anchor.

Actual local reproduction used a fresh, real booking proof. We then changed
`evidence_sha256` to 64 zeroes and `artifact_sha256` to 64 ones in that genuine
receipt. We kept the key and `established` state. The second full incremental
gate exited **0**, reported VERIFIED and `reused=true`, and created no new
booking proof log. The security regression itself exited **1**. This is a
failed security test, not a passing verification result.

The attack requires control of the cache file. This test does not establish
that an untrusted GitHub PR can currently obtain that control. It does establish
that the receipt is not an authenticated source of verification evidence. Treat
cross-process and cross-run adoption through this reader as unsafe. Historical
warm-run results do not establish resistance to receipt tampering.

## Prepared repair, not published

`repair.patch` changes only `gate/obligations.py`, `gate/incremental.py`, and
their two entries in `gate/provenance/implementation.lock`. It leaves PR #30
and the recorded evidence untouched.

1. The actual trusted dispatcher retains the complete canonical receipt and
   an inventory of all generated proof artifacts and logs in process memory.
   It uses the existing `gate/provenance/common.py::files` implementation,
   including exact file-set and symlink checks.
2. These entries remain pending until the full gate checks source integrity,
   complete coverage, and every affected obligation. Only then can they
   authorize reuse. No disk file can create a trusted entry.
3. Adoption requires the same live producer process, full receipt byte equality,
   complete artifact and log integrity, a matching obligation/input/context
   key, and trusted input bindings. The key also binds the current host and
   Python executable digest. Hashes held beside an untrusted receipt are never
   used as authority.
4. A new CLI invocation uses its own fresh work-directory cache. The existing
   PR checker therefore performs a fresh dependent proof on replay. It does
   not silently import old cache files. An explicit in-process caller can share
   a cache; attempting to import that cache into another process is rejected.

This deliberately removes the prior persistent-cache optimization. Historical
Stage 11 EXIT scripts read frozen records; rerunning those scripts would not
validate this repair. Their recorded results and reports remain unchanged.

This is local execution provenance. The trusted producer is the current gate
process that actually ran the pinned verifier. It is not a signature, GitHub
run authentication, or cross-run evidence admission. It assumes the approved
gate, verifier, OS, and process memory remain trusted. Code executing inside
that process can compromise it, as it can compromise fresh verification.
No candidate-authored Python runs in the process.

The existing signed release path authenticates a fixed Stage 9 ELF/Rocq proof,
release request, signer workflow, and artifact set. Reusing that policy for
booking evidence would falsely expand its scope. This repair does not do so.
Cross-run reuse remains disabled until a separate reviewed adapter can bind
an authorized producer and the complete obligation evidence package. No new
signing service or signing-policy change is proposed.

## PR #30 and the remaining readiness gates

Fresh GitHub reads still show the recorded head, zero reviews, and no merge.
No tracked file in its local checkout changed. The cache reader predates #30,
but #30 is not bootstrap-only: it enables dependent gates on Linux. Its profile
changes can be reviewed separately. Do not enable a hosted reuse experiment
between its merge and the approved repair.

The unsupported-host import error remains a low-severity reporting defect:
[obligations.py:25](https://github.com/mack-dot/forge/blob/561d2dda904daf18f17a0fede93f28b502d72884/gate/obligations.py#L25),
[incremental.py:30](https://github.com/mack-dot/forge/blob/561d2dda904daf18f17a0fede93f28b502d72884/gate/incremental.py#L30), and
[refund.py:51](https://github.com/mack-dot/forge/blob/561d2dda904daf18f17a0fede93f28b502d72884/gate/refund.py#L51).
An unsupported host can exit 1 during import instead of the documented 2.
It still refuses verification. Recommend explicit owner acceptance for the
Linux/x86_64 scope and a separate correction; no acceptance is recorded yet.

The raw and sanitized archives still validate: 10,160 members each, zero
mismatches. No remote copy or independent storage identity is confirmed.
Follow the previously reviewed [backup procedure](../linux-ci-readiness/BACKUP-REVIEW.md):
identify an independent private host, verify its SSH key independently, run
the copy script, retain remote validation and filesystem identity, then read
both archive hashes back a second time. Hashes alone cannot establish storage
independence. Do not delete local evidence or call the curated archives a
complete system backup.

The classic protection endpoint still returns HTTP 403. The connector also
rejects the effective branch-rules endpoint as an unsupported URL (400).
The previously read active ruleset requires exact-head human review; no
required status-check rule was observed. Complete effective policy is not
confirmed. An administrator must run these read-only commands in their own
authorized session and provide JSON plus HTTP status, without sharing tokens:

```sh
gh api repos/mack-dot/forge --jq '.permissions'
gh api --include repos/mack-dot/forge/branches/main/protection
gh api repos/mack-dot/forge/rules/branches/main
gh api 'repos/mack-dot/forge/rulesets?includes_parents=true'
gh api repos/mack-dot/forge/rulesets/26065125
```

## Exact authorization boundaries

- Owner `mack-dot`: review PR #30 at its exact head. Approval does not itself
  authorize the agent to merge. Give separate merge authorization if wanted.
- Review the separate repair diff and its exact lock digest. Authorize its PR
  publication, then complete required human approval and a separate merge
  authorization. Local tests and a proposed lock digest are not owner approval.
- Only after both approved changes are merged: review and authorize publication
  of the booking-only workflow and harness. Then approve the workflow PR and
  authorize its merge and a specific dispatch against an exact booking PR head.
- Confirm the independent backup and effective protection state. No protection
  changes, approval bypass, Node integration, signing, deployment, Stage 12,
  or SPM work is authorized by these preparations.

Hosted evidence, Linux acceptance, billed runner-minutes, and performance
improvements remain unestablished. Local repair tests are separate evidence.
