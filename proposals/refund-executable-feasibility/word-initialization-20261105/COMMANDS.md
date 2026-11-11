# Exact executed commands — U303

All exits are actual child results. Copied U300/U302 parents are historical.
No new native/hosted execution, signing or admission occurred.

These are the executed child commands. The dispatchers in `records/run_hol.py`,
`records/run_composed.py` and `records/run_import.py` set the recorded pinned heap,
`HOLDIR`, `CAKEMLDIR`, Poly/ML `PATH`, output directory and CPU/core limits.
The commands require that environment. Existing output directories are preserved;
use a fresh case name through the dispatcher for a new local replay. Absolute
paths record this host. Relocation and clean independent full-chain replay are
not established by this packet.

## code-0002

Actual exit: `1`. Local wall seconds: `75.2133590830199`.

Working directory: `/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/compiler/dafny/forge_refundArm8Proof_experiment`.

```sh
/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/HOL/bin/hol run --holstate=/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/misc/cakeml-heap /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/code-0002/proof.sml
```

Source SHA256: `efc7f9b20268f1a46fc32ad71953974d9bb7aec50fae8c301aec083fcd130e4d`.

[Full record](records/code-0002/command.json).

## code-0003

Actual exit: `0`. Local wall seconds: `82.08604533300968`.

Working directory: `/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/compiler/dafny/forge_refundArm8Proof_experiment`.

```sh
/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/HOL/bin/hol run --holstate=/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/misc/cakeml-heap /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/code-0003/proof.sml
```

Source SHA256: `420252c0db7a0c3ca7a24e8f64fdc6586749aa33c15dabb3050168058d11a43f`.

[Full record](records/code-0003/command.json).

## code-repeat

Actual exit: `0`. Local wall seconds: `86.47124958297354`.

Working directory: `/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/compiler/dafny/forge_refundArm8Proof_experiment`.

```sh
/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/HOL/bin/hol run --holstate=/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/misc/cakeml-heap /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/code-repeat/proof.sml
```

Source SHA256: `420252c0db7a0c3ca7a24e8f64fdc6586749aa33c15dabb3050168058d11a43f`.

[Full record](records/code-repeat/command.json).

## empty-stack

Actual exit: `1`. Local wall seconds: `120.48440483401646`.

Working directory: `/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/compiler/dafny/forge_refundArm8Proof_experiment`.

```sh
/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/HOL/bin/hol run --holstate=/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/misc/cakeml-heap /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/empty-stack/proof.sml
```

Source SHA256: `0c40a120c2f0c4ecec92309e25f350f27258b86b71fb73842a15dac9f72584f6`.

[Full record](records/empty-stack/command.json).

## epoch-0001

Actual exit: `1`. Local wall seconds: `95.21514637500513`.

Working directory: `/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/compiler/dafny/forge_refundArm8Proof_experiment`.

```sh
/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/HOL/bin/hol run --holstate=/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/misc/cakeml-heap /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/epoch-0001/preload.sml /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/epoch-0001/space-parent/forge_installSpaceBarrierTheory.sig /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/epoch-0001/space-parent/forge_installSpaceBarrierTheory.sml /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/epoch-0001/trace-parent/forge_spaceInstallTraceTheory.sig /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/epoch-0001/trace-parent/forge_spaceInstallTraceTheory.sml /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/epoch-0001/word-parent/forge_compilerWordTraceTheory.sig /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/epoch-0001/word-parent/forge_compilerWordTraceTheory.sml /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/epoch-0001/data-parent/forge_refundDataBehaviorTheory.sig /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/epoch-0001/data-parent/forge_refundDataBehaviorTheory.sml /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/epoch-0001/refund-parent/forge_refundWordPremisesTheory.sig /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/epoch-0001/refund-parent/forge_refundWordPremisesTheory.sml /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/epoch-0001/code-0003/forge_refundWordInitializationTheory.sig /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/epoch-0001/code-0003/forge_refundWordInitializationTheory.sml /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/epoch-0001/proof.sml
```

Source SHA256: `95a6d7d3e0356dc264064449ba5a643edd7a0bfe5aedd1fc072957d7039e701e`.

[Full record](records/epoch-0001/command.json).

## epoch-0002

Actual exit: `0`. Local wall seconds: `84.1709705000103`.

Working directory: `/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/compiler/dafny/forge_refundArm8Proof_experiment`.

```sh
/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/HOL/bin/hol run --holstate=/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/misc/cakeml-heap /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/epoch-0002/preload.sml /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/epoch-0002/space-parent/forge_installSpaceBarrierTheory.sig /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/epoch-0002/space-parent/forge_installSpaceBarrierTheory.sml /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/epoch-0002/trace-parent/forge_spaceInstallTraceTheory.sig /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/epoch-0002/trace-parent/forge_spaceInstallTraceTheory.sml /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/epoch-0002/word-parent/forge_compilerWordTraceTheory.sig /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/epoch-0002/word-parent/forge_compilerWordTraceTheory.sml /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/epoch-0002/data-parent/forge_refundDataBehaviorTheory.sig /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/epoch-0002/data-parent/forge_refundDataBehaviorTheory.sml /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/epoch-0002/refund-parent/forge_refundWordPremisesTheory.sig /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/epoch-0002/refund-parent/forge_refundWordPremisesTheory.sml /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/epoch-0002/code-0003/forge_refundWordInitializationTheory.sig /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/epoch-0002/code-0003/forge_refundWordInitializationTheory.sml /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/epoch-0002/proof.sml
```

Source SHA256: `cf0b3ef7d15dffb81700c7026a5e9dd46bb79fadb9e0d9b52db8b5247993bc0c`.

[Full record](records/epoch-0002/command.json).

## epoch-repeat

Actual exit: `0`. Local wall seconds: `79.24619800000801`.

Working directory: `/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/compiler/dafny/forge_refundArm8Proof_experiment`.

```sh
/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/HOL/bin/hol run --holstate=/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/misc/cakeml-heap /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/epoch-repeat/preload.sml /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/epoch-repeat/space-parent/forge_installSpaceBarrierTheory.sig /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/epoch-repeat/space-parent/forge_installSpaceBarrierTheory.sml /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/epoch-repeat/trace-parent/forge_spaceInstallTraceTheory.sig /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/epoch-repeat/trace-parent/forge_spaceInstallTraceTheory.sml /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/epoch-repeat/word-parent/forge_compilerWordTraceTheory.sig /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/epoch-repeat/word-parent/forge_compilerWordTraceTheory.sml /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/epoch-repeat/data-parent/forge_refundDataBehaviorTheory.sig /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/epoch-repeat/data-parent/forge_refundDataBehaviorTheory.sml /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/epoch-repeat/refund-parent/forge_refundWordPremisesTheory.sig /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/epoch-repeat/refund-parent/forge_refundWordPremisesTheory.sml /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/epoch-repeat/code-0003/forge_refundWordInitializationTheory.sig /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/epoch-repeat/code-0003/forge_refundWordInitializationTheory.sml /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/epoch-repeat/proof.sml
```

Source SHA256: `cf0b3ef7d15dffb81700c7026a5e9dd46bb79fadb9e0d9b52db8b5247993bc0c`.

[Full record](records/epoch-repeat/command.json).

## exact-import

Actual exit: `1`. Local wall seconds: `120.71845279200352`.

Working directory: `/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/compiler/dafny/forge_refundArm8Proof_experiment`.

```sh
/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/HOL/bin/hol run --holstate=/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/misc/cakeml-heap /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/exact-import/preload.sml /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/exact-import/space-parent/forge_installSpaceBarrierTheory.sig /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/exact-import/space-parent/forge_installSpaceBarrierTheory.sml /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/exact-import/trace-parent/forge_spaceInstallTraceTheory.sig /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/exact-import/trace-parent/forge_spaceInstallTraceTheory.sml /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/exact-import/word-parent/forge_compilerWordTraceTheory.sig /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/exact-import/word-parent/forge_compilerWordTraceTheory.sml /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/exact-import/data-parent/forge_refundDataBehaviorTheory.sig /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/exact-import/data-parent/forge_refundDataBehaviorTheory.sml /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/exact-import/refund-parent/forge_refundWordPremisesTheory.sig /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/exact-import/refund-parent/forge_refundWordPremisesTheory.sml /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/exact-import/code-0003/forge_refundWordInitializationTheory.sig /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/exact-import/code-0003/forge_refundWordInitializationTheory.sml /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/exact-import/epoch-0002/forge_refundInitializedEpochTheory.sig /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/exact-import/epoch-0002/forge_refundInitializedEpochTheory.sml /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/exact-import/audit.sml
```

Source SHA256: `c4cf829d1b2efd1f896adc285cc8074c0a6e177f774a554717ccff2e0c907c50`.

[Full record](records/exact-import/command.json).

## exact-import-0002

Actual exit: `1`. Local wall seconds: `79.27940291698906`.

Working directory: `/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/compiler/dafny/forge_refundArm8Proof_experiment`.

```sh
/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/HOL/bin/hol run --holstate=/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/misc/cakeml-heap /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/exact-import-0002/preload.sml /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/exact-import-0002/space-parent/forge_installSpaceBarrierTheory.sig /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/exact-import-0002/space-parent/forge_installSpaceBarrierTheory.sml /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/exact-import-0002/trace-parent/forge_spaceInstallTraceTheory.sig /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/exact-import-0002/trace-parent/forge_spaceInstallTraceTheory.sml /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/exact-import-0002/word-parent/forge_compilerWordTraceTheory.sig /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/exact-import-0002/word-parent/forge_compilerWordTraceTheory.sml /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/exact-import-0002/data-parent/forge_refundDataBehaviorTheory.sig /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/exact-import-0002/data-parent/forge_refundDataBehaviorTheory.sml /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/exact-import-0002/refund-parent/forge_refundWordPremisesTheory.sig /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/exact-import-0002/refund-parent/forge_refundWordPremisesTheory.sml /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/exact-import-0002/code-0003/forge_refundWordInitializationTheory.sig /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/exact-import-0002/code-0003/forge_refundWordInitializationTheory.sml /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/exact-import-0002/epoch-0002/forge_refundInitializedEpochTheory.sig /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/exact-import-0002/epoch-0002/forge_refundInitializedEpochTheory.sml /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/exact-import-0002/audit.sml
```

Source SHA256: `655cf063914fd8d008c83315b942484902933ba66ec39ccf9617b67b36327de8`.

[Full record](records/exact-import-0002/command.json).

## exact-import-0003

Actual exit: `1`. Local wall seconds: `27.190357000014046`.

Working directory: `/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/compiler/dafny/forge_refundArm8Proof_experiment`.

```sh
/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/HOL/bin/hol run --holstate=/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/misc/cakeml-heap /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/exact-import-0003/preload.sml /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/exact-import-0003/space-parent/forge_installSpaceBarrierTheory.sig /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/exact-import-0003/space-parent/forge_installSpaceBarrierTheory.sml /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/exact-import-0003/trace-parent/forge_spaceInstallTraceTheory.sig /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/exact-import-0003/trace-parent/forge_spaceInstallTraceTheory.sml /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/exact-import-0003/word-parent/forge_compilerWordTraceTheory.sig /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/exact-import-0003/word-parent/forge_compilerWordTraceTheory.sml /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/exact-import-0003/data-parent/forge_refundDataBehaviorTheory.sig /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/exact-import-0003/data-parent/forge_refundDataBehaviorTheory.sml /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/exact-import-0003/refund-parent/forge_refundWordPremisesTheory.sig /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/exact-import-0003/refund-parent/forge_refundWordPremisesTheory.sml /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/exact-import-0003/code-0003/forge_refundWordInitializationTheory.sig /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/exact-import-0003/code-0003/forge_refundWordInitializationTheory.sml /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/exact-import-0003/epoch-0002/forge_refundInitializedEpochTheory.sig /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/exact-import-0003/epoch-0002/forge_refundInitializedEpochTheory.sml /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/exact-import-0003/audit.sml
```

Source SHA256: `cc14409bc4f3102e96b55ddb75958c8b0426012986b37516c80a6c18b0d57183`.

[Full record](records/exact-import-0003/command.json).

## exact-import-0004

Actual exit: `1`. Local wall seconds: `73.11389537499053`.

Working directory: `/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/compiler/dafny/forge_refundArm8Proof_experiment`.

```sh
/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/HOL/bin/hol run --holstate=/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/misc/cakeml-heap /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/exact-import-0004/preload.sml /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/exact-import-0004/space-parent/forge_installSpaceBarrierTheory.sig /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/exact-import-0004/space-parent/forge_installSpaceBarrierTheory.sml /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/exact-import-0004/trace-parent/forge_spaceInstallTraceTheory.sig /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/exact-import-0004/trace-parent/forge_spaceInstallTraceTheory.sml /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/exact-import-0004/word-parent/forge_compilerWordTraceTheory.sig /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/exact-import-0004/word-parent/forge_compilerWordTraceTheory.sml /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/exact-import-0004/data-parent/forge_refundDataBehaviorTheory.sig /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/exact-import-0004/data-parent/forge_refundDataBehaviorTheory.sml /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/exact-import-0004/refund-parent/forge_refundWordPremisesTheory.sig /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/exact-import-0004/refund-parent/forge_refundWordPremisesTheory.sml /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/exact-import-0004/code-0003/forge_refundWordInitializationTheory.sig /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/exact-import-0004/code-0003/forge_refundWordInitializationTheory.sml /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/exact-import-0004/epoch-0002/forge_refundInitializedEpochTheory.sig /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/exact-import-0004/epoch-0002/forge_refundInitializedEpochTheory.sml /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/exact-import-0004/audit.sml
```

Source SHA256: `cc14409bc4f3102e96b55ddb75958c8b0426012986b37516c80a6c18b0d57183`.

[Full record](records/exact-import-0004/command.json).

## exact-import-0005

Actual exit: `0`. Local wall seconds: `68.94899841598817`.

Working directory: `/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/compiler/dafny/forge_refundArm8Proof_experiment`.

```sh
/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/HOL/bin/hol run --holstate=/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/misc/cakeml-heap /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/exact-import-0005/preload.sml /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/exact-import-0005/space-parent/forge_installSpaceBarrierTheory.sig /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/exact-import-0005/space-parent/forge_installSpaceBarrierTheory.sml /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/exact-import-0005/trace-parent/forge_spaceInstallTraceTheory.sig /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/exact-import-0005/trace-parent/forge_spaceInstallTraceTheory.sml /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/exact-import-0005/word-parent/forge_compilerWordTraceTheory.sig /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/exact-import-0005/word-parent/forge_compilerWordTraceTheory.sml /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/exact-import-0005/data-parent/forge_refundDataBehaviorTheory.sig /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/exact-import-0005/data-parent/forge_refundDataBehaviorTheory.sml /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/exact-import-0005/refund-parent/forge_refundWordPremisesTheory.sig /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/exact-import-0005/refund-parent/forge_refundWordPremisesTheory.sml /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/exact-import-0005/code-0003/forge_refundWordInitializationTheory.sig /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/exact-import-0005/code-0003/forge_refundWordInitializationTheory.sml /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/exact-import-0005/epoch-0002/forge_refundInitializedEpochTheory.sig /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/exact-import-0005/epoch-0002/forge_refundInitializedEpochTheory.sml /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/exact-import-0005/audit.sml
```

Source SHA256: `f86abfd9f3df5f42d8068e621369174778bec03f677882c98130c66e252351a0`.

[Full record](records/exact-import-0005/command.json).

## initial-0001

Actual exit: `1`. Local wall seconds: `86.8600142080104`.

Working directory: `/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/compiler/dafny/forge_refundArm8Proof_experiment`.

```sh
/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/HOL/bin/hol run --holstate=/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/misc/cakeml-heap /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/initial-0001/proof.sml
```

Source SHA256: `921673efdb5223feb488c8d8d041549c393158fa82ff10ca4c94a5faa9cbdd23`.

[Full record](records/initial-0001/command.json).

## missing-space

Actual exit: `1`. Local wall seconds: `75.15250754202134`.

Working directory: `/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/compiler/dafny/forge_refundArm8Proof_experiment`.

```sh
/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/HOL/bin/hol run --holstate=/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/misc/cakeml-heap /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/missing-space/preload.sml /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/missing-space/space-parent/forge_installSpaceBarrierTheory.sig /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/missing-space/space-parent/forge_installSpaceBarrierTheory.sml /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/missing-space/trace-parent/forge_spaceInstallTraceTheory.sig /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/missing-space/trace-parent/forge_spaceInstallTraceTheory.sml /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/missing-space/word-parent/forge_compilerWordTraceTheory.sig /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/missing-space/word-parent/forge_compilerWordTraceTheory.sml /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/missing-space/data-parent/forge_refundDataBehaviorTheory.sig /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/missing-space/data-parent/forge_refundDataBehaviorTheory.sml /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/missing-space/refund-parent/forge_refundWordPremisesTheory.sig /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/missing-space/refund-parent/forge_refundWordPremisesTheory.sml /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/missing-space/code-0003/forge_refundWordInitializationTheory.sig /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/missing-space/code-0003/forge_refundWordInitializationTheory.sml /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/missing-space/epoch-0002/forge_refundInitializedEpochTheory.sig /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/missing-space/epoch-0002/forge_refundInitializedEpochTheory.sml /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/missing-space/audit.sml
```

Source SHA256: `0735431ef8f3328735b7302033373ca447351ad7d5654b7afe7d037228239603`.

[Full record](records/missing-space/command.json).

## premise-diagnostic

Actual exit: `0`. Local wall seconds: `86.68858429102693`.

Working directory: `/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/compiler/dafny/forge_refundArm8Proof_experiment`.

```sh
/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/HOL/bin/hol run --holstate=/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/misc/cakeml-heap /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/premise-diagnostic/preload.sml /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/premise-diagnostic/space-parent/forge_installSpaceBarrierTheory.sig /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/premise-diagnostic/space-parent/forge_installSpaceBarrierTheory.sml /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/premise-diagnostic/trace-parent/forge_spaceInstallTraceTheory.sig /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/premise-diagnostic/trace-parent/forge_spaceInstallTraceTheory.sml /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/premise-diagnostic/word-parent/forge_compilerWordTraceTheory.sig /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/premise-diagnostic/word-parent/forge_compilerWordTraceTheory.sml /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/premise-diagnostic/data-parent/forge_refundDataBehaviorTheory.sig /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/premise-diagnostic/data-parent/forge_refundDataBehaviorTheory.sml /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/premise-diagnostic/refund-parent/forge_refundWordPremisesTheory.sig /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/premise-diagnostic/refund-parent/forge_refundWordPremisesTheory.sml /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/premise-diagnostic/code-0003/forge_refundWordInitializationTheory.sig /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/premise-diagnostic/code-0003/forge_refundWordInitializationTheory.sml /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/premise-diagnostic/epoch-0002/forge_refundInitializedEpochTheory.sig /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/premise-diagnostic/epoch-0002/forge_refundInitializedEpochTheory.sml /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/premise-diagnostic/audit.sml
```

Source SHA256: `8d23f6ece54182ffa547935765b23ce67c91414da7bb0d48841771032a2afc95`.

[Full record](records/premise-diagnostic/command.json).

## wrong-return

Actual exit: `1`. Local wall seconds: `75.0817581670126`.

Working directory: `/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/compiler/dafny/forge_refundArm8Proof_experiment`.

```sh
/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/HOL/bin/hol run --holstate=/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/misc/cakeml-heap /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/wrong-return/proof.sml
```

Source SHA256: `d78baf87204926cf24635e6ebb82ffc187ec864e922e559bc306103afa7db4d2`.

[Full record](records/wrong-return/command.json).

## wrong-word-code

Actual exit: `1`. Local wall seconds: `73.72495829200489`.

Working directory: `/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/compiler/dafny/forge_refundArm8Proof_experiment`.

```sh
/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/HOL/bin/hol run --holstate=/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/misc/cakeml-heap /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/wrong-word-code/preload.sml /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/wrong-word-code/space-parent/forge_installSpaceBarrierTheory.sig /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/wrong-word-code/space-parent/forge_installSpaceBarrierTheory.sml /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/wrong-word-code/trace-parent/forge_spaceInstallTraceTheory.sig /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/wrong-word-code/trace-parent/forge_spaceInstallTraceTheory.sml /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/wrong-word-code/word-parent/forge_compilerWordTraceTheory.sig /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/wrong-word-code/word-parent/forge_compilerWordTraceTheory.sml /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/wrong-word-code/data-parent/forge_refundDataBehaviorTheory.sig /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/wrong-word-code/data-parent/forge_refundDataBehaviorTheory.sml /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/wrong-word-code/refund-parent/forge_refundWordPremisesTheory.sig /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/wrong-word-code/refund-parent/forge_refundWordPremisesTheory.sml /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/wrong-word-code/code-0003/forge_refundWordInitializationTheory.sig /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/wrong-word-code/code-0003/forge_refundWordInitializationTheory.sml /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/wrong-word-code/epoch-0002/forge_refundInitializedEpochTheory.sig /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/wrong-word-code/epoch-0002/forge_refundInitializedEpochTheory.sml /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/wrong-word-code/audit.sml
```

Source SHA256: `ea43f38529290de51e1e9fa3af81fbd4dc5931916a81496ce91787814062ab9f`.

[Full record](records/wrong-word-code/command.json).

## readback-0001

Actual exit: `0`. Local wall seconds: `2.12288445798913`.

Working directory: `/Users/mackianni/forge`.

```sh
python3 -B /Users/mackianni/forge/results/refund-word-initialization-2026-11-05/attempt-0001/readback.py
```

Source SHA256: `23929ac3576c71e3207b37209880e26724a4bd5a1371f4c20afc6e624d4651ec`.

[Full record](records/readback-0001/command.json).
