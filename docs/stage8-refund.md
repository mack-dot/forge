# Stage 8: verified boundary around untrusted AI

Stage 8 is DONE. All three real EXIT commands passed. Stage 9 is CURRENT;
its implementation has not started. `end_to_end=false`.

| Command | Latest actual exit | Required result |
| --- | --- | --- |
| `python3 scripts/exit_stage_8.py --case wrapper-proof` | 0 | Full source proof, universal binding, success witness and source rejection controls. |
| `python3 scripts/exit_stage_8.py --case hostile-outputs` | 0 | Hostile corpus, supplemental checks, real mutation detection, effect-bypass and duplicate-dispatch rejection. |
| `python3 scripts/exit_stage_8.py --case evidence-separation` | 0 | Fresh canonical replay; rejection of mislabeled methods, fabricated counts, wrong artifacts and altered spec identity. |

The [completion record](../results/stage8/completed/completion.json) binds the
current EXIT reports, commands, codes, digests and archived operations. Every
prior attempt remains intact, including the original
[blocked status](../results/stage8/status.json).

## Universal source guarantees

The [approved contract](../spec/refund/RefundSpec.dfy) covers every typed context
and modeled response without a validity precondition. The
[implementation](../impl/Refund.dfy) terminates and has an empty modifies set:

- Every authorization has a valid context and an amount between zero and the
  remaining refundable amount, inclusive, within the original charge.
- Valid monetary values are integer minor units through 2^63-1. Source
  arithmetic uses mathematical integers; it does not wrap or clamp.
- Every accepted reason is one of the three exact approved labels.
- Every ineligible context or response returns Rejected and an empty plan.
- Every eligible proposal is accepted with its exact amount and reason,
  including zero. It returns exactly one intent with caller-bound IDs.
- An intent exists exactly for an authorization. The arbitrary-input binding
  and a concrete eligible successful witness rule out reject-all acceptance.

Dafny 4.11.0 and bundled Z3 4.12.1 checked all six required source, contract,
universal-binding and witness obligations with the pinned resource limit,
one worker, disabled proof timeout, and full include verification. Both audits
matched the approved empty baseline. This is `source_proof`; no separate
proof-certificate kernel check is claimed for Stage 8.

[Canonical source evidence](../results/stage8/completed/source-evidence.json):
`be32ef9e27fee402aefd9fab6de9cc66ceb03d1d68101d6b238364756ebd8c86`.
The exact source artifact remains
`de34f8f9deb55c5978b9ccf4656b91b1361d6c0600348bcae4e5abd5f127f3e5`.

## Finite integration testing

The real Dafny compiler produced the [JavaScript module](../results/stage8/completed/model.cjs).
Its SHA-256 is
`d462e12309766d5b055715500daab5c238e9c9d06236b47577d43941c22b4dda`.
The full compiler output, fixed export footer identity and commands are archived.
Source-to-JavaScript semantic preservation is not proved.

The adapter uses JSON.parse for grammar and TypeScript's JSON parser to inspect
duplicate members, including escaped key spellings. It enforces the byte cap,
keeps model strings inert, binds trusted contexts by charge/request IDs, and
records terminal state before dispatch. Test executors only record calls;
there is no payment-provider client.

Each accepted hostile-suite run executed 9,000 generated cases and 68 concrete
fixtures. T1, T2 and T3 each used seeds 8001, 8002 and 8003, with 1,000 cases per
seed. Supplemental testing passed 500 generated cases with seeds 8004 and 8005
and 23 fixtures. It covered stale completion, caller/result mutation, concurrent
terminal calls, executor reentry/failure, invalid contexts, numeric and byte
boundaries, and malformed/truncated responses. Repeated runs of these seeds are
reproduction, not additional distinct coverage.

The repaired input assertion also passed direct controls. The test extracts the
exact approved T2 callback, oracle and model bridge with TypeScript's parser,
then runs them in Node with the real compiled wrapper. Four combinations of
ordinary and null-prototype inputs passed unchanged. Sixteen actual field or
prototype mutations were rejected by the snapshot assertion. These are finite
`unit_tested` controls; they do not replace the universal source proof.

[Canonical property-test evidence](../results/stage8/completed/property-evidence.json):
`77d94ab0c41ea5c887924515f0921f6c0362c32d427b3f11d7afc79f21cbe0dd`.
The [hostile](../results/stage8/completed/hostile.json),
[supplemental](../results/stage8/completed/supplemental.json), and
[mutation-control](../results/stage8/completed/snapshot-controls.json) reports
retain the executed counts and results. `property_tested` never satisfies R1-R5.

## Rejection controls and reproduction

| Control | Gate exit | Actual checker or test result |
| --- | --- | --- |
| Over-limit authorization | 1 | Dafny verification 4; diagnostic bound to R1. |
| Reject every proposal | 1 | Dafny verification 4; diagnostic bound to R4. |
| Assumption escape | 1 | Dafny audit 2; explicit Refund.Assess finding. |
| Effect bypass | 1 | Hostile test process 1; an unchecked executor call was rejected. |
| Duplicate intent dispatch | 1 | Hostile test process 1; the extra recorded effect failed T3. |
| property_tested presented as source proof | 1 | METHOD_POLICY rejection. |
| eval_measured presented as source proof | 1 | METHOD_POLICY rejection. |
| Wrong artifact digest | 1 | ARTIFACT_MISMATCH rejection. |
| Invented passing case count | 1 | REPRODUCTION_MISMATCH after fresh real checks. |
| Changed spec identity | 1 | APPROVED_CONTRACT rejection in a disposable copy. |

The source and property-test bundles each match three separately executed fresh
accepted gate runs byte for byte. The property bundle names the same source
artifact as the source-proof bundle. Source, gate, policy, tool and dependency
identities matched before and after checking. Evidence contains no timestamps.
Operational logs are retained separately. Canonical comparison never substitutes
for a newly executed checker.

On the existing pinned host, run the three commands in the first table from the
repo root. Each creates a new attempt directory. For a single bundle replay,
use the reproduce_cmd recorded in that bundle; use --check-evidence to require
fresh checks to reproduce a supplied bundle exactly. No cross-platform install
or general CLI product claim is made by this stage.

## Historical failures and exact repair

The original approved test took its input snapshot with structuredClone, which
normalized a generated null prototype. Its strict mutation assertion then
rejected unchanged input. The user approved only the
[exact prototype-preserving repair](../proposals/refund-hostile-snapshot-decision.md).
That patch was applied unchanged. No other protected file changed in this run.
The contract, oracle, seeds, counts and negative controls remain unchanged.

All earlier failures remain archived. Wrapper attempt 1 omitted the auditor's
.expect sidecar in its unprotected report reader. Hostile attempt 1 and evidence
attempt 1 hit the original snapshot defect. The added mutation-control test had
a type-check error, then a missing extracted helper; both failures and their
source snapshots remain. Hostile attempt 2 records that helper failure. The
final passing attempts are wrapper 4, hostile 3 and evidence separation 2.

## Trust boundaries

Dafny, Boogie, Z3, their runtimes, the gate, pinned Python/Node/packages, the host
OS and hardware remain trusted. Recorded package-provenance limits still apply.
The source proof assumes neither accurate model advice nor a returning model or
network. Reason-set membership does not establish the reason's factual truth.

Parsing, Unicode/BigNumber conversion, JavaScript compilation, generated runtime
behavior and effect dispatch are tested or trusted integration links. External
monotonic clocks and schedulers must deliver timeout events. Logical-clock tests
do not establish physical deadline delivery. The host must supply truthful
context, reserve remaining funds atomically and provide durable payment
idempotency. Cumulative refunds, crash recovery, multi-process concurrency,
actual payment success and deployment identity remain unproved.

Model recommendation quality is **unmeasured**, with no score and no passing
eval_measured record. Controlled hostile suppliers are test fixtures. Stage 7's
C binary proof does not cover this JavaScript integration. `end_to_end=false`.
