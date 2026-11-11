# Acceptance and hosted measurement plan

The repair's actual local results are in
`results/ops-readiness/receipt-auth-2026-11-02/`. They are not hosted results.
The Linux matrix below is executable through the prepared `booking-ci.patch`.
That patch adds only `.github/workflows/booking-reuse.yml` and its trusted
`.github/experiments/booking_reuse.py` harness. Neither file is published.

Prerequisites: independently reviewed and approved #30 and receipt repair;
authorized merges; confirmed effective protection; independent backup; a
separately approved workflow PR and authorized merge; explicit dispatch
authorization for an exact booking PR head. Create or rebase that booking PR
on the approved workflow revision. Its only source change is the existing
`booking-a.patch`: `other < value` becomes `other <= value`.

The workflow checks out exact main and candidate commits. It accepts only the
named open PR in `mack-dot/forge`, with the named head, the current main base,
and one modified file, `impl/Booking.dfy`. It validates the pinned bootstrap
and repair lock before toolchain setup. The candidate is data, not executable
gate code. The harness comes from the separately approved main revision.
The bootstrap covers locked producer inputs; it does not by itself authorize
the new workflow or its harness. GitHub must execute that approved workflow.

## Executable matrix

| Case | Input or attack | Required gate result | Booking execution / adoption |
| --- | --- | --- | --- |
| A | Real booking PR, fresh process and cache | 0; VERIFIED; complete coverage | Real pinned Dafny executes; no hit |
| B | Identical trusted inputs, same live producer | 0; same evidence bytes and key | Authenticated process-local hit; no booking proof execution |
| C | Fixture commit changes `other <= value` to `!(other > value)` | 0; VERIFIED; different input/key | Real pinned Dafny executes again |
| D receipt | Change both evidence/artifact digests; preserve key and `established` | 1; CACHE_RECEIPT_INTEGRITY; no accepted evidence | No unsafe adoption |
| D artifact | Substitute original booking bundle bytes; leave receipt intact | 1; CACHE_ARTIFACT_INTEGRITY | No unsafe adoption |
| D coherent rewrite | Substitute bundle and update the receipt's corresponding hashes | 1; CACHE_RECEIPT_INTEGRITY | On-disk self-consistency gives no authority |
| D stale identity | Put A's receipt under C's key and change its key field | 1; CACHE_RECEIPT_INTEGRITY | No evidence transfer to another input |
| D uncovered | Add a file outside every declared obligation | 3; UNSUPPORTED; no accepted evidence | Coverage cannot pass |
| D harness | Change the protected booking harness | 1; UNAPPROVED_PROTECTED_CHANGE | No unapproved harness execution |
| D prior process | New interpreter reads the intact prior process's cache | 1; CACHE_UNAUTHENTICATED | An intact unsigned record still lacks authority |
| B restored | Restore the exact preserved fixtures; use original live process | 0; VERIFIED | Legitimate reuse still works |

The raw full-gate codes are recorded separately from harness assertions.
The negative cases are successful security tests only when the stated refusal
occurs. An infrastructure error cannot satisfy a negative test. A failed
assertion keeps the workflow red and its logs are retained. No test manufactures
a passing proof or bypasses the real gate.

Case A/B uses the actual GitHub PR commit. C and the changed-file negative
cases create deterministic local fixture commits **on the hosted runner**.
They are labeled unpublished fixtures, not GitHub PR commits. Each record
includes the exact commit, full source identity, expected and actual outcome,
hit state, actual booking-verifier log presence, wall duration, and evidence
identity. Tests with receipt-only mutations keep the candidate commit unchanged.

The ledger baseline/snapshot checks still run for every full gate call. A warm
booking hit does not mean zero verifier computation. The experiment establishes
only same-process reuse on one trusted runner. It cannot establish cross-run
artifact admission or whole-application correctness.

## Commands, after approval only

The workflow's exact invocation is:

```sh
.toolchain/ci-python/bin/python -I -B .github/experiments/booking_reuse.py --root . --out build/booking-observations --candidate ../candidate
```

Authorize an exact workflow source and booking head before dispatch:

```sh
gh workflow run booking-reuse.yml --repo mack-dot/forge --ref main -f booking_pr=NUMBER -f booking_head=EXACT_HEAD
```

This dispatch is **NOT RUN**. Check that main still equals the approved source
immediately before dispatch. Retain the returned run ID and fetch its metadata
to confirm the actual `head_sha`, workflow, event, ref, attempt, and repository.
If main moved, stop and review the new source before another dispatch.

## Measurements and evidence collection

Use the prepared `collect_hosted_measurements.py` after the job finishes. It
reads GitHub metadata and the real artifact ZIP. It compares the ZIP SHA-256
against GitHub's independent artifact digest before reading any observations.
This collector is for measurement, not release admission or cache authority.

- Correctness: compare each real gate code, refusal reason, coverage, obligation
  set, key, evidence digest, and verifier execution observation to the matrix.
  An absent observation is NOT ESTABLISHED.
- Wall time: use `perf_counter_ns` around each complete gate call. Separate
  case time from setup, artifact upload, and job start overhead. Keep raw data.
- Runner use: collect every job page for every attempt. Sum job
  `completed_at - started_at` once per job. This is observed job elapsed
  runner-minutes. Do not repeat the shared job total for each scenario.
- Each sequential case occupies one runner for its measured interval; report
  its wall time / 60 as an interval within that shared job. Attribute setup and
  other overhead separately. This is not a separate billed allocation.
- Billing: preserve the Actions timing endpoint response if available, including
  errors. GitHub marks this endpoint as closing down. Its reported billable
  milliseconds are not the same as job elapsed
  time. Actual billed minutes stay unknown unless the owner's billing record
  identifies them. Do not infer free, zero usage, or billed minutes from a
  public repository or a failed API call. Shared-job billing cannot be assigned
  exactly to each case.
- Cache adoption: count `reused=true` only after the gate's complete adoption
  checks. Distinguish misses, integrity rejections, incompatible identities,
  and actual proof execution. Old commands retained in a reused record are
  not fresh execution or fresh cost.
- Compare A and B only with equal trusted inputs, runner image, pins, policy,
  and harness. Report C separately because its inputs differ. One observation
  is not a stable speedup estimate. No saving is claimed by this preparation.

Primary API references: [job intervals and pagination](https://docs.github.com/en/rest/actions/workflow-jobs),
[run usage and its limits](https://docs.github.com/en/rest/actions/workflow-runs#get-workflow-run-usage),
and [current owner billing APIs](https://docs.github.com/en/rest/billing/usage).
The workflow requires and records the documented
[GitHub-hosted runner environment](https://docs.github.com/en/actions/reference/workflows-and-actions/variables).

## Remaining limits

Linux ledger-change verification and Node integration remain outside this
booking experiment. The committed macOS ledger evidence still cannot establish
Linux ledger-change acceptance. Stage 12 is not justified by local repair
tests alone. First establish the approved hosted matrix without weakening any
failure result, then assess whether a separate cross-run provenance proposal
is needed. No extra infrastructure or signing service is proposed.
