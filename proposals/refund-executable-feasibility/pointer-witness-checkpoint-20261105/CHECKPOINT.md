# Refund pointer-witness checkpoint — U308

CURRENT stage: **none**. Active milestone: **M1 — executable behavioral correctness**.
Stage 12 remains unauthorized. `end_to_end=false`. M1/integration EXIT: **NOT_ESTABLISHED**.

Use the [current execution checklist](../../../FORGE_MISSION_STATUS.md#current-execution-checklist)
to resume. The [owner's mission](../../../FORGE_MISSION.md) remains unchanged.
M1 concerns the full approved refund R1–R5 integer/Unicode behavior for the exact
executable. The fixed RISC-V GCD result remains supporting evidence. M2 admission,
M3 incremental reuse and M4 usability remain subsequent priorities.

## Result and exact limit

The previously launched `pointer-0003` completed with HOL exit `0` and four
exports. Its composed theorem reports seven antecedents. However, both fresh
full-contract imports exited `1`: the complete premise-equivalence proof leaves
the resource condition unresolved. This is **not a completed validation packet**.
[U307](../stack-initialization-validation-20261105/REPORT.md) remains the latest
completed local validation packet. This documentation step ran byte/history
checks; it ran no new HOL proof, native program or hosted job.

| Exported theorem | Claim built by the recorded HOL run |
| --- | --- |
| `refund_initializer_oracle_independence` | Changing the syntax oracle changes the modeled initializer only through its compiler oracle |
| `refund_pointer_fixed_point` | The published pointer fixed-point relation under the explicit causal syntax-prefix condition |
| `refund_fixed_syntax_pointer_witness` | The relation for a fixed but arbitrary syntax oracle, using the constructed pointer witness |
| `refund_witnessed_single_epoch` | Conditional one-epoch word trace after composition with that witness |

See the [exact source](records/pointer-0003/proof.sml),
[printed statements](records/pointer-0003/stdout.log) and
[command record](records/pointer-0003/command.json). Fresh imports match the three
helper statements and the main conclusion. They do not establish equivalence of
the complete expected and exported premise sets. The residual mismatch must be
diagnosed; it must not be presumed to be notation or silently accepted.

The seven reported conditions concern `STD_streams`, `wfFS`, `wfcl`, canonical
stdin, nonempty stack, endian agreement and `data_lang_safe_for_space`. The last
condition refers to the **constructed pointer witness**. An arbitrary replacement
pointer oracle is not justified. The generic helper retains its causal prefix
condition; the fixed-syntax instance proves it for `Syn = (lambda po. syn)`.
The syntax oracle `syn` remains arbitrary. No approved input domain is narrowed.

The model initializer can return a synthetic fallback. These results do not
establish successful initialization, actual memory/register correspondence,
resource adequacy, all target installer transitions or full executable behavior.
One word-language epoch is not the complete target-prefix condition from U298.
The positive run checks for no explicit hypotheses or new tagged axioms in its
four exports. Its new full dependency/assumption-closure audit has **not completed**.
Do not reuse U307's closure counts as a measured count for this theory.

## Actual recorded commands and exits

The linked command records retain exact HOL argv, working directory, source,
heap and parent hashes, CPU limits and measured local duration. These are
recovered execution records, not proof runs performed by this tracking update.

| Case / exact command record | Actual exit | Observed result |
| --- | --- | --- |
| [pointer-0001](records/pointer-0001/command.json) | 1 | Composition guard: `Pointer premise shape mismatch` |
| [pointer-0002](records/pointer-0002/command.json) | 1 | Same composition guard; preserved |
| [normalization-diagnostic](records/normalization-diagnostic/command.json) | 0 | Diagnostic only; second normalization still does not match |
| [pointer-0003](records/pointer-0003/command.json) | 0 | Four claims exported; seven antecedents reported |
| [exact-import-0001](records/exact-import-0001/command.json) | 1 | Complete premise-equivalence proof has unsolved resource goal |
| [exact-import-0002](records/exact-import-0002/command.json) | 1 | Contextual normalization still leaves resource goal |
| [premise-diagnostic](records/premise-diagnostic/command.json) | 1 | Script error: `map_index` is undeclared; argument comparison did not run |
| [checkpoint.py](records/checkpoint.py) byte capture | 0 | Exact raw, imported, prior-packet and protected bytes match |
| Repeat / export comparison / new rejection controls | NOT RUN | Pending successful complete-contract audit |
| New full closure audit / independent full-chain replay | NOT RUN | Import stops before closure reporting |
| Native/hosted execution, admission, other-device restore | NOT RUN | No new result from this tracking step |

Composition passes on its third proof attempt. The complete premise-equivalence
proof has two failed attempts. The diagnostic script error is not a mathematical
rejection or a successful negative test. Keep the five-attempt limit per failing
proof; U290/U297 remain stopped. All failed sources and logs are preserved.
The two recorded cross-thread coordination calls failed at local MCP transport;
delivery was not confirmed. They are not verification results.

The byte capture checked 539 raw files, 264 imported-file copies, four new
exports, six pinned sources, 50 protected paths and 684 U307 manifest members
in each local copy. Mission and native hashes match. See
[checkpoint-readback.json](records/checkpoint-readback.json).
Hashes establish byte identity, not producer authentication or applicability.
`pointer-0003` recorded `118.15264391701203` local wall seconds. Hosted runner
cost and comparable performance measurements are **NOT RUN**.

## Next executable task

- [ ] Repair only the undeclared indexing helper in a new diagnostic source.
  Compare all typed arguments of the expected and exported resource predicate.
  Preserve the existing failed diagnostic and both failed imports unchanged.
- [ ] Resolve the actual premise mismatch with checked normalization or an
  explicit correctness argument. Retain the resource and endian conditions.
  Do not change the claim or expected contract merely to obtain a pass.
- [ ] Complete a fresh four-claim import with complete premise equivalence and
  a measured dependency/assumption closure. Then repeat the successful proof
  source in a fresh case and require four identical exports.
- [ ] Run the prepared pointer-substitution, missing-prefix and missing-space
  controls only after the positive audit passes. Check the intended reason;
  script or infrastructure failures do not satisfy a rejection requirement.
- [ ] Continue to successful initialization and the existing lower-pass event
  relation to [U298](../target-install-bridge-20261105/REPORT.md). Preserve the
  exact source, memory, FFI/OS, resource and runtime applicability requirements.

The preserved `records/readback.py` is an **unexecuted draft**. It still expects
the first import to pass and refers to repeat/control cases that do not exist.
Do not run it as an acceptance record. Prepare a corrected version from actual
results after the required checks run. The separate checkpoint script records
the current failures without altering those draft bytes.

## Identity and authorization

| Item | Exact identity |
| --- | --- |
| Local baseline commit | `c752467773dd396ec1dbbfef5782b94b16030333` |
| Local branch | `docs/integration-readiness-20261103` |
| Proof source SHA-256 | `99e35d5937ac492740bd9a5c674c6fba7adf5ba2e0773db2d5a50978dac9b71f` |
| Theory data SHA-256 | `2ee72b9c06e787835dd0ecde5b7a2fb17e1adf70323ad2f2a6b2e318b463d320` |
| Native artifact SHA-256 | `b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8` |
| U307 manifest SHA-256 | `30ab0534f56edc26ee60d6dfae2c658f07c0a76b85f188cca1178f5b96464037` |

Source review, complete independent replay, physical/FFI/OS correspondence,
resource adequacy and new authenticated provenance/admission remain open.
The owner reports a backup on another device. Exact archive hashes and restore
from that copy remain unverified. Saved U268 protection exports expose review
controls; this step did not refresh them or GitHub PR/main state. The old HTTP403
summary is not a current protection observation.

Local preparation, verification and unsigned commits retain existing authority.
Protected adoption, push/publication, merge, workflow dispatch, signing, admission
and deployment require the applicable exact authorization and independent review.
No new stage, acceptance policy, Node integration, SPM work or infrastructure
is introduced. Missing correspondence remains explicit. `end_to_end=false`.

## Tracking validation

The documentation/history/link check exited `0`. Each uncertainty log retains
its exact old prefix. Distinct workspace and worktree histories remain distinct.
All 539 raw files still match. See
[documentation-check.json](records/documentation-check.json).
The full staged whitespace check exited `2` on preserved raw/generated/upstream
bytes; the authored-file check exited `0`. See
[whitespace-check.json](records/whitespace-check.json).
These checks validate this tracking update. They do not resolve the failed
premise-equivalence audit or replace the pending proof validation.

The first precommit identity assertion exited `1` due to a truncated commit
ID in new prose and the assertion literal. The original baseline record and
Git HEAD agree. The tracker is corrected; append-only U309 corrects U308.
See [precommit-identity-error.json](records/precommit-identity-error.json).
The proof artifacts and recorded exits are unchanged.
