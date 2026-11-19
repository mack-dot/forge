#!/bin/bash
# h-sink: builds h-sink.diff (pristine branch export -> changed tree) for the owned paths and the two test edits; checks it.
set -u
H=<REPO>/results/night-shift-20261119/orch-B/h-sink; B=$H/pristine; T=$H/tree; W=<SCRATCH>/B-trust
FILES=(impl/finality-core/IssueBytes2.dfy impl/finality-core/SerModel.dfy impl/finality-core/ShellCoreV3.dfy impl/finality-core/ShellCoreV4.dfy
 impl/finality-core/ShellCoreV5.dfy impl/finality-core/ShellCoreV6.dfy impl/finality-core/SinkCoreV3.dfy scripts/exit_slice1.py
 tests/demo-gauntlet/sink_tool.ts tests/refund-finality/suite.ts ts/refund-finality/core/sinkcore-v6.cjs ts/refund-finality/core/store.ts
 ts/refund-finality/dispatcher.ts ts/refund-finality/sink.ts)
cd $H
diff -rqN -x node_modules -x .toolchain $B $T | sed -e "s#^Files $B/\([^ ]*\) and .*#\1#" | sort > changed-files.txt
printf '%s\n' "${FILES[@]}" | sort | diff - changed-files.txt && echo "file list = tree difference" || echo "FILE LIST DIFFERS FROM TREE DIFFERENCE"
: > h-sink.diff
for f in "${FILES[@]}"; do if [ -e $B/$f ]; then A=a/$f; else A=/dev/null; fi; diff -uN --label $A --label b/$f $B/$f $T/$f >> h-sink.diff; done
echo "lines $(wc -l < h-sink.diff)"
echo "protected-or-clearing hits: $(grep -E '^(\+\+\+|---) ' h-sink.diff | grep -cE ' [ab]/(gate|policy|spec|toolchain|schemas|\.github|governance|clearing)/|/clearing/|spec\.lock|AGENTS\.md|javascript_env\.py|build_model\.py|interop/export\.cjs|interop/model\.ts|ledger\.property|tsconfig\.json|package(-lock)?\.json')"
echo "branch head $(git -C $W rev-parse HEAD)"; git -C $W apply --check $H/h-sink.diff; echo "git apply --check exit $?"
shasum -a 256 h-sink.diff | tee h-sink.diff.sha256
(cd $T && shasum -a 256 "${FILES[@]}") > new-files-sha256.txt
