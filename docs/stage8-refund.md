# Stage 8 refund boundary: source proof checked; integration gate blocked

Stage 8 is CURRENT. The approved contracts, policy and gate remain unchanged.
All three required EXIT commands ran. Their latest actual codes are:

| Command | Exit | Result |
| --- | --- | --- |
| `python3 scripts/exit_stage_8.py --case wrapper-proof` | 0 | Six required proof obligations and all three source rejection controls passed. |
| `python3 scripts/exit_stage_8.py --case hostile-outputs` | 1 | Approved T2 test snapshot changed a null prototype; strict mutation assertion failed. |
| `python3 scripts/exit_stage_8.py --case evidence-separation` | 1 | Source evidence reproduced; the same T2 assertion blocked integration evidence. |

The [status record](../results/stage8/status.json) lists every attempt and record
digest. The first wrapper EXIT returned 1 because its reporting harness omitted
Dafny's `.expect` audit sidecar. That unprotected reporting code was corrected;
the full EXIT then returned 0. Both attempts remain archived. No proof, policy
or approved gate was changed to obtain that result.

## What the source proof establishes

The [contract](../spec/refund/RefundSpec.dfy) covers every typed context and
modeled response, without a validity precondition. The
[implementation](../impl/Refund.dfy) terminates and returns only decision/plan
data, with an empty modifies set:

- Every authorized amount is nonnegative, within the remaining refundable
  amount, and within the original charge. Valid charges use integer minor
  units through 2^63-1; source arithmetic uses mathematical integers.
- Every authorized reason is one of the three exact approved labels.
- Every ineligible context or response returns Rejected with an empty plan.
- Every eligible proposal is accepted with its exact amount and reason,
  including valid zero proposals. It returns one intent with caller-bound IDs.
- An intent exists exactly for an authorization. A concrete valid witness and
  an arbitrary-input binding prevent reject-all or narrowed-domain acceptance.

The exact source evidence is in
[the passing source run](../results/stage8/wrapper-proof/attempt-0002/source-positive/evidence.json).
Dafny verification returned 0. Both empty-baseline audits returned 0. The full
source closure and all six required obligations were checked. Three separate
fresh gate invocations produced byte-identical source evidence. This is Dafny
source proof, not a separate proof-certificate kernel check.

The over-limit mutant failed actual verification with exit 4 at R1. The
reject-all mutant failed verification with exit 4 at R4. The assumption escape
failed the actual auditor with exit 2 and a finding for Refund.Assess. Each
negative gate process returned 1. These are deliberate rejection controls,
separate from the EXIT harness code. Exact mutated files and complete output
are retained in the wrapper attempt records.

## What was tested, and what remains blocked

The approved hostile suite passed 68 concrete fixtures and 3,000 generated T1
cases in each failed run. T2 seed 8001 failed after two cases and six shrinks.
The raw failure shows an unchanged null-prototype input compared against a
clone with an ordinary prototype. The failure is in the protected test's
snapshot, not an observed refund-policy violation. It remains a real gate
failure and cannot be counted as a pass.

The unprotected adapter uses JSON.parse for grammar and TypeScript's JSON parser
for duplicate-member inspection. It caps accumulated response bytes, binds
contexts by charge/request IDs, and records the terminal outcome before
dispatch. Late completion, an identical retry and an executor exception cannot
reopen that in-memory attempt. No payment provider exists in this adapter.

Supplemental tests actually passed 23 concrete fixtures and 500 generated cases
with seeds 8004 and 8005, 250 cases each. These exercise numeric representation,
exact byte boundaries, malformed/truncated bytes, stale responses, concurrent
terminal calls, caller/result mutation, executor reentry/failure and invalid
contexts. The [full supplemental record](../results/stage8/development/supplemental-0001/report.json)
includes exact inputs, command, report and process exit 0. These observations
do not complete the failed EXIT or establish a universal runtime theorem.

A minimal [unapplied snapshot repair](../proposals/refund-hostile-snapshot.md)
has a direct development run of 9,000 cases and 68 fixtures, exit 0. That run
used the proposal path and is explicitly outside the approved gate. It does
not replace either failed EXIT. The final scope freeze prevents application.

Effect-bypass and duplicate-dispatch rejection controls have not been reached
by the EXIT harness. Fabricated-count, mislabeled-method, mismatched-artifact
and spec-tamper controls have also not been reached. Integration evidence
reproduction remains unfinished. Stage 8 cannot be marked DONE.

## Assumptions and reproduction

Dafny 4.11.0, bundled Boogie/.NET and Z3 4.12.1 remain trusted. So do the checked
Python/Node/package installations, this gate, the host OS and hardware. The
recorded package provenance limits still apply. The source proof assumes
neither accurate model advice nor a returning model or network.

Parsing, Unicode/BigNumber conversion, JavaScript compilation, the generated
runtime and effect dispatch are tested or trusted integration links. The
external monotonic clock and scheduler must deliver timeout events. Logical
clock tests do not prove physical deadline delivery. The host must supply
truthful context, reserve remaining funds atomically and provide durable
payment idempotency. Cumulative refunds, crash recovery, multi-process
concurrency, actual payment success and deployment identity remain unproved.

Model recommendation quality is **unmeasured**. No real model evaluation or
passing eval_measured record exists. Controlled hostile suppliers are test
fixtures. Stage 7's C binary proof does not cover this JavaScript integration.
`end_to_end=false`.

On the existing pinned host, run the three commands in the table from the repo
root. Each creates a new attempt directory and preserves earlier failures.
The unchanged approved gate is expected to reproduce the documented blocker.
Do not apply the diagnostic repair without a separate exact decision. No
Stage 9 work has started.
