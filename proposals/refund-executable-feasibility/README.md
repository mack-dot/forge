# Refund executable feasibility — source representation experiment

Verdict: **BLOCKED_BY_CORRESPONDENCE**. CURRENT stage: none. Stage12 remains
unauthorized. `end_to_end=false`. This is an unadopted local feasibility proposal.

## Target and exact contract

The target is the approved refund decision component, not the old GCD self-test.
Refund is stateless. Ledger and booking require additional map and retry-state
relations. Selecting refund reduces those representation obligations without
restricting its existing input domain or weakening its behavioral requirements.

Approved inputs and source identities:

| File | SHA256 |
| --- | --- |
| `spec/refund/RefundSpec.dfy` | `90a21c71ae3a7e1cdb7c74d393ae8ed6f312548710bdf0ae71c62255c7ccfe57` |
| `impl/Refund.dfy` | `0416882492de095b59f3547a8df788193ec41952cf2d30a65df80b8ecd52a700` |
| `gate/refund/Bindings.dfy` | `d689b18a64aa2cdc7c705e8d6b953c401e3f866f8311d624238b563e1d7a621d` |
| `spec/refund/protocol.md` | `5ef4e8fa6c23a4a455b3cbdc3f5b14ae313762446fea8444ca5e6c570e86ecd4` |
| `spec/refund/spec.lock` | `993dade887f6141e9a9e27ae78e17b6cc2545923f334d83c17aad40bc3b28b57` |

`Assess` has no precondition and modifies no state. The domain includes arbitrary
mathematical integers, finite strings and all response constructors. Money is
valid from0 through9223372036854775807. Valid context requires nonempty charge
and request IDs, enabled/open flags, valid original value and remaining value
between0 and original. A candidate must have amount between0 and remaining and
one exact reason: `duplicate_charge`, `service_not_delivered`, `returned_item`.

- R1: authorization respects valid context and amount bounds.
- R2: authorization preserves an allowed reason.
- R3: every ineligible input is rejected with no intent.
- R4: every eligible input succeeds with its exact amount, reason and caller IDs.
- R5: authorization is equivalent to eligibility; exactly one matching intent
  accompanies authorization and no intent accompanies rejection.

Zero is an eligible amount. Error response constructors remain rejected.
The source implementation is terminating and has no loops or recursive calls.
Physical progress, memory exhaustion and operating-system termination are not
established by that source fact.

The protocol's strict JSON parsing, byte limits, timeouts and actual payment
executor remain separate boundaries. Context truth, atomic reservation and
durable idempotency are host responsibilities. No cumulative-refund, concurrent
payment or exactly-once execution theorem is claimed.

## New checked source relation

`flat-bridge/attempt-0001/FlatCore.dfy` uses primitive integer, boolean and string
fields. It does not use a bounded replacement for mathematical integers or IDs.
`Bridge.dfy` maps every original response constructor to those fields and maps
the result back to the original decision and intent. It proves exact equality
with the original `Refund.Assess` result, plus the complete R1–R5 conditions.

The flattened interface has no precondition. Both original approved source
files are included byte for byte. Included-file verification checks their
bodies, the new implementation and the relation. Non-vacuity checks cover40,
zero and the maximum amount; over-remaining and larger-than-money inputs reject.
These witness checks supplement the universal relation; they do not replace it.

New source hashes:

- `FlatCore.dfy`: `a89484e354914ca293286abfdb97376805d4e417a270342db15df4b784a51f4d`.
- `Bridge.dfy`: `ee11d3ca9299f748deb8485dc20a2219bef93d883b4f4f6d9952f6f839d4e299`.

Checked source closure: those two files, original `impl/Refund.dfy`, original
`spec/refund/RefundSpec.dfy`, and Dafny's built-in semantics. Dafny4.11.0,
Boogie, Z3 4.12.1 and their execution platform remain trusted. This experiment
does not produce a small-kernel proof certificate or validate compiler output.

## Actual commands and results

From the Forge records workspace:

```sh
python3 -B scripts/exit_stage_8.py --case wrapper-proof
```

Actual exit0;9.892985208018217 local seconds. Original source proof0. Existing
over-limit and always-reject controls each returned gate1 with verifier4.
The assumption-escape control returned gate1 with auditor2. Protected inputs
were unchanged. Full report: `refund-wrapper-proof-report.json`, originating
from `results/stage8/wrapper-proof/attempt-0005/report.json`.

From `flat-bridge/attempt-0001`, using the existing pinned installation:

```sh
/Users/mackianni/forge/.toolchain/dafny-4.11.0/dafny/dafny verify Bridge.dfy \
  --solver-path /Users/mackianni/forge/.toolchain/dafny-4.11.0/dafny/z3/bin/z3-4.12.1 \
  --resource-limit 1000000 --verification-time-limit 0 --cores 1 \
  --verify-included-files
```

Actual exit0;7 verified,0 errors;1.2701178749848623 local seconds. Run records
preserve absolute command paths so the original invocation is unambiguous.
For another machine, use its identical approved Dafny and Z3 installations.

`flat-bridge/run_controls.py` dispatches the same established checker. It is
not a new verifier. It preserves all prior outputs and refuses to overwrite a
case directory. Actual exit0. Its recorded child commands returned:

| Case | Actual exit | Required reason/result |
| --- | --- | --- |
| Fresh-directory repeat | 0 | Same source hashes and byte-identical positive output |
| Amount upper bound removed from body only | 4 | Postcondition could not be proved; contract unchanged |
| Body always rejects | 4 | Postcondition could not be proved; non-vacuity unchanged |

An initial `dafny audit ... --compare-report` returned2 because its expected
report file did not exist. This was a harness error, not a successful negative
control. Its output remains in `audit.stdout` and `audit-command.json`. The
second invocation used a copy of the existing `gate/expected-audit.md` baseline
and returned0 with zero findings. See `audit-retry-command.json`. No source or
audit expectation was changed to suppress a finding.

These are local source checks. No new hosted run or compiled refund proof ran.

## Smallest remaining link and method order

The new source relation removes an ADT/interface obstacle. It does not connect
Dafny source to executable bytes. The next experiment must inspect and reproduce
an established backend's exact supported path for this full component.

The primary publication [Verified VCG and Verified Compiler for Dafny](https://arxiv.org/html/2512.05262v1)
describes a verified subset compiler to CakeML and a verified VCG. It includes
integer, boolean, string and array values. This makes it a candidate to inspect,
not evidence that the full refund component is supported or already compiled.
The new flat representation has not been accepted by that backend. Its exact
source artifact, parser/input representation, Unicode semantics, returned tuple
support, checked proof closure and full native-code build remain unverified here.

Follow the mission's order: verified compilation first; then established checked
binary semantics; then established translation validation; then an explicitly
conditional compositional argument. The existing LPS/GCD proof has no refund
executable, refund input relation or refund theorem. It cannot be transferred by
renaming its claim or matching a digest. No claim of impossibility is made.

Required correspondence includes numeric and string representations, input and
output encoding, calling convention, memory, runtime dependencies, compiler
transformations, entry conditions, resource/progress assumptions and exact
artifact identity. Source hashes establish identity, not this correspondence.

## Approval and continuation

Read-only backend inspection and safe local experiments remain authorized.
No protected source, policy, lock or workflow was modified. No replacement of
the approved implementation has been proposed for adoption by this experiment.
An exact claim/profile/checker change requires a separately reviewable proposal
and applicable approval. Publication, merge, dispatch, signing and admission
retain their separate boundaries. Do not restart Stage12 or move to M3/M4.

The full mission and completion ledger remain in `FORGE_MISSION.md` and
`FORGE_MISSION_STATUS.md`. Neither this source step nor saving those documents
completes M1 or the overall mission.
