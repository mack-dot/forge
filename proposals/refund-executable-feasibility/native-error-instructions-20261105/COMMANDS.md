# Actual commands

Raw root: `/Users/mackianni/forge/results/refund-native-audit-2026-11-04/attempt-0011`.
Commands below ran. Their failures are not passing negative controls.

## static-native: actual exit 0

```text
/Users/mackianni/forge/.toolchain/experiments/refund-entry-lldb-23.1.5/observer/LLVM-23.1.5-macOS-ARM64/bin/lldb --no-lldbinit --batch --source /Users/mackianni/forge/results/refund-native-audit-2026-11-04/attempt-0011/static-native/commands.lldb
```

Record: `records/static-native/command.json`.

## inspect-steps: actual exit 1

```text
/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/HOL/bin/hol run --holstate=/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/misc/cakeml-heap /Users/mackianni/forge/results/refund-native-audit-2026-11-04/attempt-0011/inspect-steps/preload.sml /Users/mackianni/forge/results/refund-native-audit-2026-11-04/attempt-0011/inspect-steps/proof.sml
```

Record: `records/inspect-steps/command.json`.

## inspect-steps-0002: actual exit 1

```text
/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/HOL/bin/hol run --holstate=/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/misc/cakeml-heap /Users/mackianni/forge/results/refund-native-audit-2026-11-04/attempt-0011/inspect-steps-0002/preload.sml /Users/mackianni/forge/results/refund-native-audit-2026-11-04/attempt-0011/inspect-steps-0002/proof.sml
```

Record: `records/inspect-steps-0002/command.json`.

## inspect-arm8-steps: actual exit 1

```text
/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/HOL/bin/hol run --holstate=/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/HOL/examples/l3-machine-code/arm8/step/arm8-heap /Users/mackianni/forge/results/refund-native-audit-2026-11-04/attempt-0011/inspect-arm8-steps/preload.sml /Users/mackianni/forge/results/refund-native-audit-2026-11-04/attempt-0011/inspect-arm8-steps/proof.sml
```

Record: `records/inspect-arm8-steps/command.json`.

## dependency-diagnostic: actual exit 1

```text
/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/HOL/bin/hol run --holstate=/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/HOL/examples/l3-machine-code/arm8/step/arm8-heap /Users/mackianni/forge/results/refund-native-audit-2026-11-04/attempt-0011/dependency-diagnostic/preload.sml /Users/mackianni/forge/results/refund-native-audit-2026-11-04/attempt-0011/dependency-diagnostic/proof.sml
```

Record: `records/dependency-diagnostic/command.json`.

## Artifact and preservation checks

| Executed check | Actual exit |
| --- | ---: |
| Original native-word/file binding |0|
| `python3 results/refund-native-audit-2026-11-04/attempt-0011/readback.py` |1|
| `python3 results/refund-native-audit-2026-11-04/attempt-0011/readback_0002.py` |0|
| HOL git source revision / tracked diff / final tracked diff |0/0/0|

The first reader inspected stdout only; the retained loader failure is in stderr.
The corrected reader checks both streams. No proof or failure output changed.

New instruction proof/export, repeat, exact theorem import, proof negative controls,
native execution, signing and independent clean replay are NOT RUN. U315 proof,
closure, controls and signature results are prior results with checked unchanged
identities. No current success is inferred from an old command exit.

## Preservation checks

`git diff --cached --check` exits2 on exact preserved evidence bytes. The command
restricted to authored Markdown exits0. Exact argv and outputs are in
`records/whitespace-checks.json` and `records/whitespace-full.stdout`.
The tracking and package-copy wrappers each exit0. The new uncertainty entry is
U316; prefix hashes prove append-only preservation in both distinct histories.
