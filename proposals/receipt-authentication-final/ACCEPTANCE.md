# Booking integration acceptance

Stage remains none. Stage 12 is unauthorized. Integration EXIT requires all
local and hosted requirements. Local verification cannot fill a hosted result.

The standalone repair PR contains the three production files plus permanent
original and repaired regression tests. Its base is #30's unchanged exact head.
The booking workflow remains a separate two-file PR. Node integration remains
outside both changes. No changes are published.

Run the committed repair test from a clean local checkout, with the already
approved pinned toolchain available at the recorded local path:

```sh
python3 -B tests/integration/receipt_authentication.py --root /private/tmp/forge-auth-final-reviewed-20261102 --out /private/tmp/forge-auth-final-reviewed-results-20261102
```

| Case | Required actual gate exit | Additional observation |
| --- | --- | --- |
| A cold | 0 | Complete coverage; one real booking gate process; successful Dafny proof output |
| B warm | 0 | Same evidence identity; zero observed booking process launches; no new booking proof log |
| C changed Booking input | 0 | New cache key; one real booking gate process and fresh proof |
| Receipt changed, key and established retained | 1 | CACHE_RECEIPT_INTEGRITY |
| Artifact substitution | 1 | CACHE_ARTIFACT_INTEGRITY |
| Coordinated receipt/artifact rewrite | 1 | CACHE_RECEIPT_INTEGRITY |
| Stale source identity | 1 | CACHE_RECEIPT_INTEGRITY |
| Changed protected harness | 1 | UNAPPROVED_PROTECTED_CHANGE |
| Prior interpreter's receipt | 1 | CACHE_UNAUTHENTICATED |
| Missing memory anchor | 1 | CACHE_UNAUTHENTICATED |
| Invalid memory anchor | 1 | CACHE_RECEIPT_INTEGRITY |
| Uncovered file | 3 | UNSUPPORTED; no accepted evidence |
| Restored valid inputs and authority | 0 | Valid same-process reuse still works |

The test uses Python's subprocess audit event to record actual parent-process
launches. It does not replace a gate, subprocess function, or verifier. On cold
and invalidated cases, it observes the booking process and retains the nested
Dafny command records and proof artifacts. On warm cases, the actual launch
count is zero. Ledger snapshot verification still runs on every full-gate call.

The anchor-loss fixtures deliberately remove or corrupt trusted process state.
They never install a fabricated passing result. Original receipt-corruption
steps remain byte-identical to the permanently preserved counterexample.

The separately prepared hosted harness runs this matrix on GitHub-hosted
Linux under the approved main workflow. It checks exact main and booking PR
heads, the one-file Booking change, pinned bootstrap/lock, and a GitHub-hosted
runner. Candidate code remains data. C and changed-file negatives use explicitly
labeled unpublished fixture commits. The prior-process case uses the current
candidate path. All failures retain their raw observations.

Publication, merge and dispatch remain unauthorized. After the corresponding
human actions, the workflow invokes the prepared harness with:

```sh
.toolchain/ci-python/bin/python -I -B .github/experiments/booking_reuse.py --root . --out build/booking-observations --candidate ../candidate
```

The workflow grants only contents/pull-requests read permission, uses immutable
action commits and the existing Linux runner/toolchain, and preserves failed
observations as an experiment artifact. It performs no signing or release
admission. Cross-run reuse stays disabled.

Measure each gate interval with perf_counter_ns. Keep A, B and C separate.
Record exact source, receipt and evidence identities, refusal reasons, actual
launch counts, and retained verifier logs. After completion, collect GitHub's
run, all job pages/attempts and artifact metadata. Verify the downloaded ZIP
against the independent digest from GitHub before reading results. Sum each
job interval once. Per-case wall/60 is an interval on the shared runner; it is
not an independently billed allocation. Keep setup/upload and other job
overhead separate. Actual billed cost requires the owner's billing records;
the optional timing endpoint response cannot establish it. No savings claim
is supported by this preparation.

The executable integration status check is integration_exit.py. It requires
all matrix observations plus independent review/merge authorization, repair
approval/merge, verified protections, confirmed off-machine backup, successful
hosted A/B/C/D, reproducibility/provenance, and hosted runtime/job minutes.
Missing observations fail. This status check grants no cache or release authority.
