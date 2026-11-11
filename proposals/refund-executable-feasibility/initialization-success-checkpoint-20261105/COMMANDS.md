# Executed initialization-checkpoint commands

These are recorded process executions. The documentation step recovered their
terminal records and checked file identities. It did not rerun HOL. All runs
used the pinned existing heap, a 3600 CPU-second process limit and core limit0.
Wall durations are observations; they are not acceptance limits or hosted costs.

## inspect-0001

Actual exit: `0`. Observed wall seconds: `74.79371783297393`.

Working directory: `/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/compiler/dafny/forge_refundArm8Proof_experiment`.

```sh
/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/HOL/bin/hol run --holstate=/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/misc/cakeml-heap /Users/mackianni/forge/results/refund-initialization-success-2026-11-05/attempt-0001/inspect-0001/proof.sml
```

[Invocation](records/inspect-0001/invocation.json), [terminal record](records/inspect-0001/command.json),
[stdout](records/inspect-0001/stdout.log), [stderr](records/inspect-0001/stderr.log).

## success-0001

Actual exit: `1`. Observed wall seconds: `97.60717079101596`.

Working directory: `/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/compiler/dafny/forge_refundArm8Proof_experiment`.

```sh
/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/HOL/bin/hol run --holstate=/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/misc/cakeml-heap /Users/mackianni/forge/results/refund-initialization-success-2026-11-05/attempt-0001/success-0001/proof.sml
```

[Invocation](records/success-0001/invocation.json), [terminal record](records/success-0001/command.json),
[stdout](records/success-0001/stdout.log), [stderr](records/success-0001/stderr.log).

## success-0002

Actual exit: `0`. Observed wall seconds: `89.81102383302641`.

Working directory: `/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/compiler/dafny/forge_refundArm8Proof_experiment`.

```sh
/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/HOL/bin/hol run --holstate=/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/misc/cakeml-heap /Users/mackianni/forge/results/refund-initialization-success-2026-11-05/attempt-0001/success-0002/proof.sml
```

[Invocation](records/success-0002/invocation.json), [terminal record](records/success-0002/command.json),
[stdout](records/success-0002/stdout.log), [stderr](records/success-0002/stderr.log).

## Tracking readbacks

```sh
python3 -B results/refund-initialization-success-2026-11-05/attempt-0001/checkpoint-readback.py
```

Actual exit: `1`. It searched stdout alone for the recorded type error. The
error is in stderr. This is an audit-script failure, not a failed theorem or
successful negative control. [Failure record](records/checkpoint-readback-0001.json).

```sh
python3 -B results/refund-initialization-success-2026-11-05/attempt-0001/checkpoint-readback-complete.py
```

Actual exit: `0`. This copy reads both streams. It checks process records,
exact bytes, 11 source pins, 50 protected paths and 843 prior packet members
in each of the workspace and Git worktree. It does not check proof validity.
[Readback result](records/checkpoint-readback.json).

Fresh complete-contract import, dependency-closure audit, proof repeat, new
negative controls, native/hosted execution, release admission and off-machine
restore: **NOT RUN** for this checkpoint. These are required work, not passes.
