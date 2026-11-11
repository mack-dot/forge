# Actual local commands — U299

All commands below ran. Child and wrapper exits agree for these completed
checks. Negative controls require the recorded refusal, not exit zero.
Times are local elapsed observations. Hosted execution and runner-minutes: NOT RUN.
Existing case directories are append-only; use a fresh label for a new replay.

## closure-0001

Working directory: `/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/compiler/dafny/forge_refundArm8Proof_experiment`.
Actual exit: `1`.
Local wall seconds: `59.14230895799119`.
Source SHA256: `92816cdeb3831f9685d3bc1be0b3b88e6625937550ade386b9fbc84d335b852b`.

```sh
/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/HOL/bin/hol run --holstate=/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/misc/cakeml-heap /Users/mackianni/forge/results/refund-closure-install-2026-11-05/attempt-0001/closure-0001/proof.sml
```

## closure-0002

Working directory: `/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/compiler/dafny/forge_refundArm8Proof_experiment`.
Actual exit: `0`.
Local wall seconds: `61.621146500023315`.
Source SHA256: `5353adb2d3069820578a740c25bcb03834b6843bd73f030be1ef4ac51ce2f845`.

```sh
/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/HOL/bin/hol run --holstate=/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/misc/cakeml-heap /Users/mackianni/forge/results/refund-closure-install-2026-11-05/attempt-0001/closure-0002/proof.sml
```

## closure-repeat

Working directory: `/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/compiler/dafny/forge_refundArm8Proof_experiment`.
Actual exit: `0`.
Local wall seconds: `61.552646041993285`.
Source SHA256: `5353adb2d3069820578a740c25bcb03834b6843bd73f030be1ef4ac51ce2f845`.

```sh
/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/HOL/bin/hol run --holstate=/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/misc/cakeml-heap /Users/mackianni/forge/results/refund-closure-install-2026-11-05/attempt-0001/closure-repeat/proof.sml
```

## exact-import

Working directory: `/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/compiler/dafny/forge_refundArm8Proof_experiment`.
Actual exit: `0`.
Local wall seconds: `66.2584357910091`.
Source SHA256: `c32b2b68937a314c7b2956272845603af2c3e54e56d980f31b7644886c49ab78`.

```sh
/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/HOL/bin/hol run --holstate=/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/misc/cakeml-heap /Users/mackianni/forge/results/refund-closure-install-2026-11-05/attempt-0001/exact-import/preload.sml /Users/mackianni/forge/results/refund-closure-install-2026-11-05/attempt-0001/exact-import/closure-0002/forge_refundClosureInstallTheory.sig /Users/mackianni/forge/results/refund-closure-install-2026-11-05/attempt-0001/exact-import/closure-0002/forge_refundClosureInstallTheory.sml /Users/mackianni/forge/results/refund-closure-install-2026-11-05/attempt-0001/exact-import/audit.sml
```

## injected-install

Working directory: `/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/compiler/dafny/forge_refundArm8Proof_experiment`.
Actual exit: `1`.
Local wall seconds: `67.09831562501495`.
Source SHA256: `45a52655a2998e7f9bb9e786cfe3c00273fb0285bc48a38f9ad75632ffbb69cb`.

```sh
/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/HOL/bin/hol run --holstate=/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/misc/cakeml-heap /Users/mackianni/forge/results/refund-closure-install-2026-11-05/attempt-0001/injected-install/proof.sml
```

## wrong-program

Working directory: `/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/compiler/dafny/forge_refundArm8Proof_experiment`.
Actual exit: `1`.
Local wall seconds: `65.53574741599732`.
Source SHA256: `48a6fe3a8e6b48b08cbd50f608bf27c68bb19e183a1046094a00064b006441da`.

```sh
/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/HOL/bin/hol run --holstate=/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/misc/cakeml-heap /Users/mackianni/forge/results/refund-closure-install-2026-11-05/attempt-0001/wrong-program/preload.sml /Users/mackianni/forge/results/refund-closure-install-2026-11-05/attempt-0001/wrong-program/closure-0002/forge_refundClosureInstallTheory.sig /Users/mackianni/forge/results/refund-closure-install-2026-11-05/attempt-0001/wrong-program/closure-0002/forge_refundClosureInstallTheory.sml /Users/mackianni/forge/results/refund-closure-install-2026-11-05/attempt-0001/wrong-program/audit.sml
```

## readback-0001

Working directory: `/Users/mackianni/forge`.
Actual exit: `1`.
Local wall seconds: `NOT RECORDED`.
Source SHA256: `b059ecd60aac13d5979875b586c72b88d484dbf6a62ec517eb3fc4a0073563db`.

```sh
python3 -B results/refund-closure-install-2026-11-05/attempt-0001/readback.py
```

## readback-0002

Working directory: `/Users/mackianni/forge`.
Actual exit: `0`.
Local wall seconds: `1.2232457920035813`.
Source SHA256: `9043e5b6a7b53a58976fb7dfc1a5491e6d877b80d579d482a30c2d73a267517f`.

```sh
python3 -B /Users/mackianni/forge/results/refund-closure-install-2026-11-05/attempt-0001/readback.py
```

The first readback failure was recorded from the tool result. Its original source
and exact failed assertion are retained. The second readback has captured stdout
and stderr. Source and import invocations, limits and result records remain in
`records/`. A zero import exit does not establish independent full-chain replay.
