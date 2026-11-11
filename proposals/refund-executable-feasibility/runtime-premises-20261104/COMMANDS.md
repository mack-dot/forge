# Exact local commands — U296

Working directory: `/Users/mackianni/forge`.
Expected negative outcomes remain distinct from positive proof results.
Every command below actually ran. JSON records include full child arguments.

## precise-0001

Actual exit: **1**. Local elapsed seconds: `69.77989979201811`.

```sh
/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/HOL/bin/hol run --holstate=/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/misc/cakeml-heap /Users/mackianni/forge/results/refund-runtime-premises-2026-11-04/attempt-0002/precise-0001/proof.sml
```

Child working directory: `/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/compiler/dafny/forge_refundArm8Proof_experiment`.

## precise-0002

Actual exit: **1**. Local elapsed seconds: `75.94697450002423`.

```sh
/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/HOL/bin/hol run --holstate=/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/misc/cakeml-heap /Users/mackianni/forge/results/refund-runtime-premises-2026-11-04/attempt-0002/precise-0002/proof.sml
```

Child working directory: `/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/compiler/dafny/forge_refundArm8Proof_experiment`.

## precise-0003

Actual exit: **0**. Local elapsed seconds: `73.93576958301128`.

```sh
/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/HOL/bin/hol run --holstate=/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/misc/cakeml-heap /Users/mackianni/forge/results/refund-runtime-premises-2026-11-04/attempt-0002/precise-0003/proof.sml
```

Child working directory: `/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/compiler/dafny/forge_refundArm8Proof_experiment`.

## precise-repeat

Actual exit: **0**. Local elapsed seconds: `83.92350924998755`.

```sh
/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/HOL/bin/hol run --holstate=/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/misc/cakeml-heap /Users/mackianni/forge/results/refund-runtime-premises-2026-11-04/attempt-0002/precise-repeat/proof.sml
```

Child working directory: `/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/compiler/dafny/forge_refundArm8Proof_experiment`.

## exact-import

Actual exit: **0**. Local elapsed seconds: `75.09015316699515`.

```sh
/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/HOL/bin/hol run --holstate=/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/misc/cakeml-heap /Users/mackianni/forge/results/refund-runtime-premises-2026-11-04/attempt-0002/exact-import/preload.sml /Users/mackianni/forge/results/refund-runtime-premises-2026-11-04/attempt-0002/exact-import/imported/forge_refundPreciseBehaviorTheory.sig /Users/mackianni/forge/results/refund-runtime-premises-2026-11-04/attempt-0002/exact-import/imported/forge_refundPreciseBehaviorTheory.sml /Users/mackianni/forge/results/refund-runtime-premises-2026-11-04/attempt-0002/exact-import/audit.sml
```

Child working directory: `/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/compiler/dafny/forge_refundArm8Proof_experiment`.

## missing-space

Actual exit: **1**. Local elapsed seconds: `80.85842025000602`.

```sh
/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/HOL/bin/hol run --holstate=/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/misc/cakeml-heap /Users/mackianni/forge/results/refund-runtime-premises-2026-11-04/attempt-0002/missing-space/preload.sml /Users/mackianni/forge/results/refund-runtime-premises-2026-11-04/attempt-0002/missing-space/imported/forge_refundPreciseBehaviorTheory.sig /Users/mackianni/forge/results/refund-runtime-premises-2026-11-04/attempt-0002/missing-space/imported/forge_refundPreciseBehaviorTheory.sml /Users/mackianni/forge/results/refund-runtime-premises-2026-11-04/attempt-0002/missing-space/audit.sml
```

Child working directory: `/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/compiler/dafny/forge_refundArm8Proof_experiment`.

## changed-limits

Actual exit: **1**. Local elapsed seconds: `77.68999408298987`.

```sh
/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/HOL/bin/hol run --holstate=/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/misc/cakeml-heap /Users/mackianni/forge/results/refund-runtime-premises-2026-11-04/attempt-0002/changed-limits/preload.sml /Users/mackianni/forge/results/refund-runtime-premises-2026-11-04/attempt-0002/changed-limits/imported/forge_refundPreciseBehaviorTheory.sig /Users/mackianni/forge/results/refund-runtime-premises-2026-11-04/attempt-0002/changed-limits/imported/forge_refundPreciseBehaviorTheory.sml /Users/mackianni/forge/results/refund-runtime-premises-2026-11-04/attempt-0002/changed-limits/audit.sml
```

Child working directory: `/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/compiler/dafny/forge_refundArm8Proof_experiment`.

## Identity and preservation checks

`python3 -B results/refund-runtime-premises-2026-11-04/attempt-0002/runtime_readback.py`: actual exit 0.
`python3 -B results/refund-runtime-premises-2026-11-04/attempt-0002/readback.py`: actual exit 0.

The earlier exact input readback was an inline Python command; its result is retained as `records/input-readback.json`.
The initial read-only HOL specialization is retained in `records/initial-inspection/command.json` (actual exit 0).
No native, hosted, independent-device restore, signing or admission command ran here.

These local runs used cached parent theories. Timing differences are not evidence of a cache speedup.
