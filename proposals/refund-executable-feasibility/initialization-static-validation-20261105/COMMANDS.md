# Executed commands — U313

These are actual child executions, not expected outcomes. `init-parent` is a
copied historical input from U312. `parent-repeat` is its new execution. Every
HOL process used the existing pinned heap, a 3600 CPU-second process limit and
core limit0. No wall-clock acceptance timeout was added. Local durations are
observations; they are not hosted cost measurements.

The preserved wrappers set HOLDIR, CAKEMLDIR and the pinned Poly/ML PATH. Use a
new case directory when reproducing; the wrappers refuse to overwrite prior cases.
They preserve the original workspace paths. Clean independent replay is NOT RUN.

## init-parent

Actual exit: `0`. Observed wall seconds: `89.81102383302641`.

Working directory: `/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/compiler/dafny/forge_refundArm8Proof_experiment`.

```sh
/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/HOL/bin/hol run --holstate=/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/misc/cakeml-heap /Users/mackianni/forge/results/refund-initialization-success-2026-11-05/attempt-0001/success-0002/proof.sml
```

[Invocation](records/init-parent/invocation.json), [terminal record](records/init-parent/command.json),
[stdout](records/init-parent/stdout.log), [stderr](records/init-parent/stderr.log).

## static-0001

Actual exit: `1`. Observed wall seconds: `93.63393187499605`.

Working directory: `/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/compiler/dafny/forge_refundArm8Proof_experiment`.

```sh
/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/HOL/bin/hol run --holstate=/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/misc/cakeml-heap /Users/mackianni/forge/results/refund-initialization-static-2026-11-05/attempt-0001/static-0001/preload.sml /Users/mackianni/forge/results/refund-initialization-static-2026-11-05/attempt-0001/static-0001/init-parent/forge_refundSuccessfulInitializationTheory.sig /Users/mackianni/forge/results/refund-initialization-static-2026-11-05/attempt-0001/static-0001/init-parent/forge_refundSuccessfulInitializationTheory.sml /Users/mackianni/forge/results/refund-initialization-static-2026-11-05/attempt-0001/static-0001/proof.sml
```

[Invocation](records/static-0001/invocation.json), [terminal record](records/static-0001/command.json),
[stdout](records/static-0001/stdout.log), [stderr](records/static-0001/stderr.log).

## static-0002

Actual exit: `0`. Observed wall seconds: `96.82446858400363`.

Working directory: `/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/compiler/dafny/forge_refundArm8Proof_experiment`.

```sh
/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/HOL/bin/hol run --holstate=/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/misc/cakeml-heap /Users/mackianni/forge/results/refund-initialization-static-2026-11-05/attempt-0001/static-0002/preload.sml /Users/mackianni/forge/results/refund-initialization-static-2026-11-05/attempt-0001/static-0002/init-parent/forge_refundSuccessfulInitializationTheory.sig /Users/mackianni/forge/results/refund-initialization-static-2026-11-05/attempt-0001/static-0002/init-parent/forge_refundSuccessfulInitializationTheory.sml /Users/mackianni/forge/results/refund-initialization-static-2026-11-05/attempt-0001/static-0002/proof.sml
```

[Invocation](records/static-0002/invocation.json), [terminal record](records/static-0002/command.json),
[stdout](records/static-0002/stdout.log), [stderr](records/static-0002/stderr.log).

## static-0003

Actual exit: `0`. Observed wall seconds: `73.43925004199264`.

Working directory: `/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/compiler/dafny/forge_refundArm8Proof_experiment`.

```sh
/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/HOL/bin/hol run --holstate=/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/misc/cakeml-heap /Users/mackianni/forge/results/refund-initialization-static-2026-11-05/attempt-0001/static-0003/preload.sml /Users/mackianni/forge/results/refund-initialization-static-2026-11-05/attempt-0001/static-0003/init-parent/forge_refundSuccessfulInitializationTheory.sig /Users/mackianni/forge/results/refund-initialization-static-2026-11-05/attempt-0001/static-0003/init-parent/forge_refundSuccessfulInitializationTheory.sml /Users/mackianni/forge/results/refund-initialization-static-2026-11-05/attempt-0001/static-0003/proof.sml
```

[Invocation](records/static-0003/invocation.json), [terminal record](records/static-0003/command.json),
[stdout](records/static-0003/stdout.log), [stderr](records/static-0003/stderr.log).

## exact-import-0001

Actual exit: `1`. Observed wall seconds: `74.39440104100504`.

Working directory: `/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/compiler/dafny/forge_refundArm8Proof_experiment`.

```sh
/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/HOL/bin/hol run --holstate=/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/misc/cakeml-heap /Users/mackianni/forge/results/refund-initialization-static-2026-11-05/attempt-0001/exact-import-0001/preload.sml /Users/mackianni/forge/results/refund-initialization-static-2026-11-05/attempt-0001/exact-import-0001/init-parent/forge_refundSuccessfulInitializationTheory.sig /Users/mackianni/forge/results/refund-initialization-static-2026-11-05/attempt-0001/exact-import-0001/init-parent/forge_refundSuccessfulInitializationTheory.sml /Users/mackianni/forge/results/refund-initialization-static-2026-11-05/attempt-0001/exact-import-0001/static-0002/forge_refundInitializationStaticTheory.sig /Users/mackianni/forge/results/refund-initialization-static-2026-11-05/attempt-0001/exact-import-0001/static-0002/forge_refundInitializationStaticTheory.sml /Users/mackianni/forge/results/refund-initialization-static-2026-11-05/attempt-0001/exact-import-0001/audit.sml
```

[Invocation](records/exact-import-0001/invocation.json), [terminal record](records/exact-import-0001/command.json),
[stdout](records/exact-import-0001/stdout.log), [stderr](records/exact-import-0001/stderr.log).

## exact-import-0002

Actual exit: `0`. Observed wall seconds: `74.49953612498939`.

Working directory: `/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/compiler/dafny/forge_refundArm8Proof_experiment`.

```sh
/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/HOL/bin/hol run --holstate=/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/misc/cakeml-heap /Users/mackianni/forge/results/refund-initialization-static-2026-11-05/attempt-0001/exact-import-0002/preload.sml /Users/mackianni/forge/results/refund-initialization-static-2026-11-05/attempt-0001/exact-import-0002/init-parent/forge_refundSuccessfulInitializationTheory.sig /Users/mackianni/forge/results/refund-initialization-static-2026-11-05/attempt-0001/exact-import-0002/init-parent/forge_refundSuccessfulInitializationTheory.sml /Users/mackianni/forge/results/refund-initialization-static-2026-11-05/attempt-0001/exact-import-0002/static-0003/forge_refundInitializationStaticTheory.sig /Users/mackianni/forge/results/refund-initialization-static-2026-11-05/attempt-0001/exact-import-0002/static-0003/forge_refundInitializationStaticTheory.sml /Users/mackianni/forge/results/refund-initialization-static-2026-11-05/attempt-0001/exact-import-0002/audit.sml
```

[Invocation](records/exact-import-0002/invocation.json), [terminal record](records/exact-import-0002/command.json),
[stdout](records/exact-import-0002/stdout.log), [stderr](records/exact-import-0002/stderr.log).

## parent-repeat

Actual exit: `0`. Observed wall seconds: `96.35147487500217`.

Working directory: `/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/compiler/dafny/forge_refundArm8Proof_experiment`.

```sh
/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/HOL/bin/hol run --holstate=/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/misc/cakeml-heap /Users/mackianni/forge/results/refund-initialization-static-2026-11-05/attempt-0001/parent-repeat/proof.sml
```

[Invocation](records/parent-repeat/invocation.json), [terminal record](records/parent-repeat/command.json),
[stdout](records/parent-repeat/stdout.log), [stderr](records/parent-repeat/stderr.log).

## static-repeat

Actual exit: `0`. Observed wall seconds: `83.72585545800393`.

Working directory: `/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/compiler/dafny/forge_refundArm8Proof_experiment`.

```sh
/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/HOL/bin/hol run --holstate=/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/misc/cakeml-heap /Users/mackianni/forge/results/refund-initialization-static-2026-11-05/attempt-0001/static-repeat/preload.sml /Users/mackianni/forge/results/refund-initialization-static-2026-11-05/attempt-0001/static-repeat/init-parent/forge_refundSuccessfulInitializationTheory.sig /Users/mackianni/forge/results/refund-initialization-static-2026-11-05/attempt-0001/static-repeat/init-parent/forge_refundSuccessfulInitializationTheory.sml /Users/mackianni/forge/results/refund-initialization-static-2026-11-05/attempt-0001/static-repeat/proof.sml
```

[Invocation](records/static-repeat/invocation.json), [terminal record](records/static-repeat/command.json),
[stdout](records/static-repeat/stdout.log), [stderr](records/static-repeat/stderr.log).

## wrong-code

Actual exit: `1`. Observed wall seconds: `88.43712304200744`.

Working directory: `/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/compiler/dafny/forge_refundArm8Proof_experiment`.

```sh
/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/HOL/bin/hol run --holstate=/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/misc/cakeml-heap /Users/mackianni/forge/results/refund-initialization-static-2026-11-05/attempt-0001/wrong-code/preload.sml /Users/mackianni/forge/results/refund-initialization-static-2026-11-05/attempt-0001/wrong-code/init-parent/forge_refundSuccessfulInitializationTheory.sig /Users/mackianni/forge/results/refund-initialization-static-2026-11-05/attempt-0001/wrong-code/init-parent/forge_refundSuccessfulInitializationTheory.sml /Users/mackianni/forge/results/refund-initialization-static-2026-11-05/attempt-0001/wrong-code/static-0003/forge_refundInitializationStaticTheory.sig /Users/mackianni/forge/results/refund-initialization-static-2026-11-05/attempt-0001/wrong-code/static-0003/forge_refundInitializationStaticTheory.sml /Users/mackianni/forge/results/refund-initialization-static-2026-11-05/attempt-0001/wrong-code/audit.sml
```

[Invocation](records/wrong-code/invocation.json), [terminal record](records/wrong-code/command.json),
[stdout](records/wrong-code/stdout.log), [stderr](records/wrong-code/stderr.log).

## wrong-oracle

Actual exit: `1`. Observed wall seconds: `92.0457927910029`.

Working directory: `/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/compiler/dafny/forge_refundArm8Proof_experiment`.

```sh
/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/HOL/bin/hol run --holstate=/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/misc/cakeml-heap /Users/mackianni/forge/results/refund-initialization-static-2026-11-05/attempt-0001/wrong-oracle/preload.sml /Users/mackianni/forge/results/refund-initialization-static-2026-11-05/attempt-0001/wrong-oracle/init-parent/forge_refundSuccessfulInitializationTheory.sig /Users/mackianni/forge/results/refund-initialization-static-2026-11-05/attempt-0001/wrong-oracle/init-parent/forge_refundSuccessfulInitializationTheory.sml /Users/mackianni/forge/results/refund-initialization-static-2026-11-05/attempt-0001/wrong-oracle/static-0003/forge_refundInitializationStaticTheory.sig /Users/mackianni/forge/results/refund-initialization-static-2026-11-05/attempt-0001/wrong-oracle/static-0003/forge_refundInitializationStaticTheory.sml /Users/mackianni/forge/results/refund-initialization-static-2026-11-05/attempt-0001/wrong-oracle/audit.sml
```

[Invocation](records/wrong-oracle/invocation.json), [terminal record](records/wrong-oracle/command.json),
[stdout](records/wrong-oracle/stdout.log), [stderr](records/wrong-oracle/stderr.log).

## missing-memory

Actual exit: `1`. Observed wall seconds: `84.97921049999422`.

Working directory: `/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/compiler/dafny/forge_refundArm8Proof_experiment`.

```sh
/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/HOL/bin/hol run --holstate=/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/misc/cakeml-heap /Users/mackianni/forge/results/refund-initialization-static-2026-11-05/attempt-0001/missing-memory/preload.sml /Users/mackianni/forge/results/refund-initialization-static-2026-11-05/attempt-0001/missing-memory/init-parent/forge_refundSuccessfulInitializationTheory.sig /Users/mackianni/forge/results/refund-initialization-static-2026-11-05/attempt-0001/missing-memory/init-parent/forge_refundSuccessfulInitializationTheory.sml /Users/mackianni/forge/results/refund-initialization-static-2026-11-05/attempt-0001/missing-memory/static-0003/forge_refundInitializationStaticTheory.sig /Users/mackianni/forge/results/refund-initialization-static-2026-11-05/attempt-0001/missing-memory/static-0003/forge_refundInitializationStaticTheory.sml /Users/mackianni/forge/results/refund-initialization-static-2026-11-05/attempt-0001/missing-memory/audit.sml
```

[Invocation](records/missing-memory/invocation.json), [terminal record](records/missing-memory/command.json),
[stdout](records/missing-memory/stdout.log), [stderr](records/missing-memory/stderr.log).

## missing-memory-0002

Actual exit: `1`. Observed wall seconds: `89.95736079101334`.

Working directory: `/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/compiler/dafny/forge_refundArm8Proof_experiment`.

```sh
/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/HOL/bin/hol run --holstate=/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/misc/cakeml-heap /Users/mackianni/forge/results/refund-initialization-static-2026-11-05/attempt-0001/missing-memory-0002/preload.sml /Users/mackianni/forge/results/refund-initialization-static-2026-11-05/attempt-0001/missing-memory-0002/init-parent/forge_refundSuccessfulInitializationTheory.sig /Users/mackianni/forge/results/refund-initialization-static-2026-11-05/attempt-0001/missing-memory-0002/init-parent/forge_refundSuccessfulInitializationTheory.sml /Users/mackianni/forge/results/refund-initialization-static-2026-11-05/attempt-0001/missing-memory-0002/static-0003/forge_refundInitializationStaticTheory.sig /Users/mackianni/forge/results/refund-initialization-static-2026-11-05/attempt-0001/missing-memory-0002/static-0003/forge_refundInitializationStaticTheory.sml /Users/mackianni/forge/results/refund-initialization-static-2026-11-05/attempt-0001/missing-memory-0002/audit.sml
```

[Invocation](records/missing-memory-0002/invocation.json), [terminal record](records/missing-memory-0002/command.json),
[stdout](records/missing-memory-0002/stdout.log), [stderr](records/missing-memory-0002/stderr.log).

## Sequence and readback commands

```sh
python3 -B results/refund-initialization-static-2026-11-05/attempt-0001/validate-sequence.py
```

Actual exit: `1`. The guard refused the first missing-memory case because its
`MATCH_MP_TAC: No match` error was not the required missing-premise refusal.
All preceding successful cases remain valid; no repeated runs were required.
[Failure record](records/validation-sequence-failure.json).

The corrected missing-memory execution is recorded above as `missing-memory-0002`.
It first passes all seven positive checks, then leaves `memory_assumption` unproved.

```sh
python3 -B results/refund-initialization-static-2026-11-05/attempt-0001/validate-completion.py
python3 -B results/refund-initialization-static-2026-11-05/attempt-0001/readback.py
```

Actual exits: `0 / 0`. The first checks actual control outcomes. The second binds
actual records to exact artifacts, sources and dependency closure. Neither replaces
HOL or proves physical applicability. [Completion](records/validation-completion.json),
[readback](records/readback.json).

Original/static byte comparisons each exited `0`:
[original](records/parent-repeat-comparison.json), [static](records/static-repeat-comparison.json).

Independent full-chain replay, new native/hosted execution, admission and independent
off-machine restore: **NOT RUN**. No performance savings are claimed.
