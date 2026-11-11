# Actual command records

All exits below are observed results. Plans and unmet prerequisites are not exits.
Working root: `/Users/mackianni/forge`. Raw records:
`results/refund-native-audit-2026-11-04/attempt-0010/`.

## HOL runs

Each uses the pinned HOL executable and CakeML heap. The runner validates2659
U310 parent files before and after each process. CPU limit3600 seconds per process.
The per-case invocation and command JSON files retain complete argv, cwd, source
hash and output hashes.

| Case | Actual child exit | Exact source |
| --- | ---: | --- |
| model-0001 | 1 | `records/model-0001/proof.sml` |
| model-0002 | 1 | `records/model-0002/proof.sml` |
| model-0003 | 1 | `records/model-0003/proof.sml` |
| model-0004 | 1 | `records/model-0004/proof.sml` |
| model-0005 | 1 | `records/model-0005/proof.sml` |
| model-0006 | 1 | `records/model-0006/proof.sml` |
| model-0007 | 0 | `records/model-0007/proof.sml` |
| status-diagnostic | 0 | `records/status-diagnostic/proof.sml` |
| repeat | 0 | `records/repeat/proof.sml` |
| import-0001 | 0 | `records/import-0001/proof.sml` |
| wrong-ready-status | 1 | `records/wrong-ready-status/proof.sml` |
| changed-error-frame | 1 | `records/changed-error-frame/proof.sml` |

Each recorded child command follows. These are retained executions, not proposed commands.

```text
/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/HOL/bin/hol run --holstate=/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/misc/cakeml-heap /Users/mackianni/forge/results/refund-native-audit-2026-11-04/attempt-0010/model-0007/preload.sml /Users/mackianni/forge/results/refund-native-audit-2026-11-04/attempt-0010/model-0007/proof.sml
```

```text
/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/HOL/bin/hol run --holstate=/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/misc/cakeml-heap /Users/mackianni/forge/results/refund-native-audit-2026-11-04/attempt-0010/repeat/preload.sml /Users/mackianni/forge/results/refund-native-audit-2026-11-04/attempt-0010/repeat/proof.sml
```

```text
/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/HOL/bin/hol run --holstate=/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/misc/cakeml-heap /Users/mackianni/forge/results/refund-native-audit-2026-11-04/attempt-0010/import-0001/preload.sml /Users/mackianni/forge/results/refund-native-audit-2026-11-04/attempt-0010/model-0007/forge_refundReadBoundaryTheory.sig /Users/mackianni/forge/results/refund-native-audit-2026-11-04/attempt-0010/model-0007/forge_refundReadBoundaryTheory.sml /Users/mackianni/forge/results/refund-native-audit-2026-11-04/attempt-0010/import-0001/proof.sml
```

```text
/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/HOL/bin/hol run --holstate=/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/misc/cakeml-heap /Users/mackianni/forge/results/refund-native-audit-2026-11-04/attempt-0010/wrong-ready-status/preload.sml /Users/mackianni/forge/results/refund-native-audit-2026-11-04/attempt-0010/model-0007/forge_refundReadBoundaryTheory.sig /Users/mackianni/forge/results/refund-native-audit-2026-11-04/attempt-0010/model-0007/forge_refundReadBoundaryTheory.sml /Users/mackianni/forge/results/refund-native-audit-2026-11-04/attempt-0010/wrong-ready-status/proof.sml
```

```text
/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/HOL/bin/hol run --holstate=/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/misc/cakeml-heap /Users/mackianni/forge/results/refund-native-audit-2026-11-04/attempt-0010/changed-error-frame/preload.sml /Users/mackianni/forge/results/refund-native-audit-2026-11-04/attempt-0010/model-0007/forge_refundReadBoundaryTheory.sig /Users/mackianni/forge/results/refund-native-audit-2026-11-04/attempt-0010/model-0007/forge_refundReadBoundaryTheory.sml /Users/mackianni/forge/results/refund-native-audit-2026-11-04/attempt-0010/changed-error-frame/proof.sml
```

## Native and observer runs

| Command / record | Actual exit |
| --- | ---: |
| `python3 results/refund-native-audit-2026-11-04/attempt-0010/native_controls.py native-0001` | 0 |
| `python3 results/refund-native-audit-2026-11-04/attempt-0010/native_controls.py native-repeat` | 0 |
| `python3 results/refund-native-audit-2026-11-04/attempt-0010/observe_directory.py directory-observation-0001` | 1 |
| `python3 results/refund-native-audit-2026-11-04/attempt-0010/observe_positive.py positive-observer-check` | 1 |
| LLDB static disassembly/Python command record | 1 |

The16 native child records appear in `records/native-0001/observations.json`
and `records/native-repeat/observations.json`. Each contains the complete argv,
environment, descriptor setup, stream hashes and actual process status. The
seven normal exits per run are0. The no-stdout-reader case is signal status-13.
Debugger exits1 are debugger failures, not established native child exits.

```text
/Users/mackianni/forge/.toolchain/experiments/refund-entry-lldb-23.1.5/observer/LLVM-23.1.5-macOS-ARM64/bin/lldb --no-lldbinit --batch --source /Users/mackianni/forge/results/refund-native-audit-2026-11-04/attempt-0010/observer-static/commands.lldb
```

```text
/Users/mackianni/forge/.toolchain/experiments/refund-entry-lldb-23.1.5/observer/LLVM-23.1.5-macOS-ARM64/bin/lldb --no-lldbinit --batch --source /Users/mackianni/forge/results/refund-native-audit-2026-11-04/attempt-0010/directory-observation-0001/commands.lldb
```

```text
/Users/mackianni/forge/.toolchain/experiments/refund-entry-lldb-23.1.5/observer/LLVM-23.1.5-macOS-ARM64/bin/lldb --no-lldbinit --batch --source /Users/mackianni/forge/results/refund-native-audit-2026-11-04/attempt-0010/positive-observer-check/commands.lldb
```

## Read-only artifact and replay checks

| Command / record | Actual exit |
| --- | ---: |
| `/usr/bin/shasum -a 256 -c /Users/mackianni/forge/results/refund-native-audit-2026-11-04/attempt-0004/identity-0001/chain.sha256` | 0 |
| `/usr/bin/codesign --verify --strict --verbose=2 /Users/mackianni/forge/results/refund-native-audit-2026-11-04/attempt-0004/native-build-0001/refund` | 0 |
| `/usr/bin/codesign --verify --strict --verbose=2 /Users/mackianni/forge/results/refund-native-audit-2026-11-04/attempt-0004/native-repeat-0001/refund` | 0 |
| `python3 results/refund-native-audit-2026-11-04/attempt-0010/native_readback.py` | 0 |
| `python3 results/refund-native-audit-2026-11-04/attempt-0010/replay_preflight.py` | 0 |
| `python3 results/refund-native-audit-2026-11-04/attempt-0010/readback.py` | 0 |

The six git pin/source-diff commands in `records/replay-preflight-commands.json`
each exit0. The preflight runner completes0 while its replay gate remains NO_GO.
Independent replay is NOT RUN. No Docker query, cold rebuild or new native
build/signature ran. All six failed model bundles and all three observer failures
remain preserved; none counts as a passing negative control.

## Preservation checks

`git diff --cached --check` exits2 on exact preserved evidence bytes. The command
restricted to authored Markdown exits0. Exact argv and outputs are in
`records/whitespace-checks.json` and `records/whitespace-full.stdout`.
The tracking and package-copy wrappers each exit0. The new uncertainty entry is
U315; prefix hashes prove append-only preservation in both distinct histories.
