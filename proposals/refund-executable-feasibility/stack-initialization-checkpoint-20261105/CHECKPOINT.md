# Refund stack-initialization checkpoint — U306

CURRENT stage: **none**. Active milestone: **M1 — executable behavioral correctness**.
Stage 12 remains unauthorized. `end_to_end=false`. Integration EXIT: **NOT_ESTABLISHED**.

Track the active work in [FORGE_MISSION_STATUS.md](../../../FORGE_MISSION_STATUS.md#current-execution-checklist).
The goal remains the full approved refund R1–R5 integer/Unicode behavior for the
exact executable. The fixed RISC-V GCD result remains supporting evidence.

## Current result and its limit

The previously launched `init-0007` completed with HOL exit `0`. Its combined
word-trace theorem retains eight conditions. Three checked model-constructor
lemmas discharge U305's GC, store and compiler-function conditions. This tracking
step recovered that result and checked byte identity. It ran no new HOL proof.

| Exported theorem | Meaning |
| --- | --- |
| `refund_stack_gc` | Exact modeled initializer supplies the required GC function |
| `refund_stack_store` | Exact modeled initializer satisfies `init_store_ok` |
| `refund_stack_compiler` | Exact lower-pass compiler function matches the required composition |
| `refund_stack_initialized_single_epoch` | Conditional word trace has one epoch for every clock |

The full [proof source](records/init-0007/proof.sml), [printed statements](records/init-0007/stdout.log)
and [child command record](records/init-0007/command.json) are preserved.
Repeat, fresh exact-statement import, full premise/closure audit and new negative
controls are **NOT RUN**. This is a partial checkpoint, not a fully validated
assurance packet. U305 remains the latest completed local validation packet.

The eight retained conditions are: canonical nine-field stdin; `STD_streams fs`;
`wfFS fs`; `wfcl cl`; nonempty stack; endian agreement; data safe-for-space; and
the all-clock pointer-oracle evaluation relation. The printed theorem is the
authoritative statement. The prepared expected-statement audit is unexecuted.

**Model initialization is not physical initialization.** The published
`full_make_init` contains a `make_init_any` fallback when optional initialization
fails. That fallback includes an empty memory domain and a synthetic stack.
The new lemmas do not prove `IS_SOME (SND initial)`, loaded-memory correctness,
resource adequacy or an actual runtime-state relation. See the preserved
[upstream definition](records/upstream/compiler/backend/proofs/stack_removeProofScript.sml).
Matching model fields cannot replace those missing applicability obligations.

## Actual execution record

| Check | Actual exit / status | Result |
| --- | --- | --- |
| HOL bundles `init-0001` / `init-0002` | 1/1 | Type errors before new proofs; preserved |
| `init-0003` / `init-0004` | 1/1 | Compiler bitmap-conversion obligation remains |
| `bitmap-diagnostic` | 0 | Found that broad simplification erased the useful equality to `T` |
| `init-0005` / `init-0006` | 1/1 | Helpers pass; composition guards refuse nine premises / unmatched conjunct |
| `init-0007` | 0 | Four claims exported; exact helper discharges compiler conjunct; eight remain |
| Tracking byte audit, initial / corrected | 1/0 | Corrected the audit's imported-file path; no proof/evidence changed |
| Repeat / fresh exact import / new rejection controls | NOT RUN | Next local validation work |
| Independent full-chain replay, native/hosted run, admission, restore | NOT RUN | Existing trust and operational gaps remain |

The compiler proof passed on its third actual proof attempt. Composition passed
on its third attempt. The first two bundles failed before proof execution.
No failing proof exceeded five attempts. U290/U297 remain stopped. An incidental
text-diff inspection error is also preserved. No failed attempt was deleted.

The corrected byte audit checked 534 U305 manifest members in each copy, four
new exports, 224 imported-file copies, ten pinned sources, 50 protected paths,
mission bytes and the unchanged native artifact. It captured all 456 raw files.
See [checkpoint-readback.json](records/checkpoint-readback.json).
Hashes establish byte identity, not producer authentication or theorem applicability.
Local elapsed time for `init-0007` was `128.15955466599553` seconds. Hosted cost
and performance comparisons are **NOT RUN**.

## Next executable task and acceptance criteria

- [ ] Run the prepared [expected-statement audit](records/expected.sml) in a fresh
  HOL process. Check all four exact claims, all eight premises, and the complete
  dependency/assumption closure. Correct audit syntax only when a real diagnostic
  identifies it. Do not change the theorem to fit the expected statement.
- [ ] Repeat the successful source in a new case. Require four byte-identical
  exports. Keep the existing case directories and failed sources unchanged.
- [ ] Reject compiler substitution, a claim of successful physical initialization
  without its premises, and removal of the resource condition. Record the actual
  reason. An infrastructure error does not count as a successful negative test.
- [ ] Then connect the word trace through existing lower-pass semantics to the
  [U298 target-prefix condition](../target-install-bridge-20261105/REPORT.md).
  Preserve successful-initialization, pointer, resource and physical-state premises.

Exact prior launch, from `/Users/mackianni/forge`:

```sh
python3 -B results/refund-stack-initialization-2026-11-05/attempt-0001/run_composed.py \
  init-0007 results/refund-stack-initialization-2026-11-05/attempt-0001/stack-init-conj.sml \
  space-parent:forge_installSpaceBarrier trace-parent:forge_spaceInstallTrace \
  word-parent:forge_compilerWordTrace data-parent:forge_refundDataBehavior \
  refund-parent:forge_refundWordPremises init-parent:forge_refundWordInitialization \
  epoch-parent:forge_refundInitializedEpoch oracle-parent:forge_refundWordOracle
```

Do not rerun that case name. Use a fresh case for each repeat or audit. The raw
dispatcher retains exact argv, CPU limits, heap digest and parent identities.
This packet preserves local evidence, not a standalone clean toolchain or an
independent full-chain replay environment.

## Identity and approval boundary

| Item | Exact identity |
| --- | --- |
| Baseline local commit | `5beaf94efee3aaff2be358a212e214424d689da7` |
| Proof source SHA-256 | `9fc5478364027e06ca8b35185f4ec08f6735c5133876815325b3bd2b2b75fcb6` |
| Theory data SHA-256 | `3d4b6a2e096f81ea8762a4d8ece4f4bea12621cc10a841124597dc8e4b7f1cc6` |
| Native artifact SHA-256 | `b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8` |
| U305 manifest SHA-256 | `3d95cdc96f7bc5c2c7f1dfd161eb80bf5463a47a34d9fb141b4876426e521656` |

Independent source review, complete replay, physical memory/FFI/OS correspondence,
resource adequacy and new authenticated provenance/admission remain open.
The owner reports another-device backup. Exact archive hashes and a restore test
on that copy remain unverified. Effective GitHub protections were not refreshed.

Local preparation, verification and unsigned commits remain authorized. Protected
adoption, publication, push, merge, dispatch, signing, admission and deployment
retain their existing approval boundaries. No new stage, Node, SPM, acceptance
policy or general infrastructure work is introduced. M2–M4 remain later priorities.

## Tracking validation

The documentation history/link check exited `0`. It preserves each uncertainty
log's exact old prefix and the distinct workspace/worktree histories. All 456
captured raw files still match. See [documentation-check.json](records/documentation-check.json).
The full staged whitespace check exited `2` on preserved raw/generated/upstream
bytes; the authored-file check exited `0`. See [whitespace-check.json](records/whitespace-check.json).
These are tracking checks. They do not replace the pending proof validation.
