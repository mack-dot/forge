#!/bin/bash
# p-adopt2: builds adoption-v6.diff (pristine export of 985f5eaf -> changed export), then checks it. Applies nothing.
# Baseline: orch-B/p-adopt/pristine (read-only reuse). Changed export: p-adopt2/export.
set -u
O=/Users/mackianni/forge/results/night-shift-20261119/orch-B; P=$O/p-adopt2; B=$O/p-adopt/pristine; cd $P
FILES=(impl/finality-core/IssueBytes2.dfy impl/finality-core/SerModel.dfy impl/finality-core/ShellCoreV3.dfy
 impl/finality-core/ShellCoreV4.dfy impl/finality-core/ShellCoreV5.dfy impl/finality-core/ShellCoreV6.dfy
 impl/finality-core/SinkCoreV3.dfy scripts/exit_slice1.py tests/demo-gauntlet/sink_tool.ts tests/refund-finality/suite.ts
 ts/refund-finality/core/sinkcore-v6.cjs ts/refund-finality/dispatcher.ts ts/refund-finality/minter.ts ts/refund-finality/sink.ts)
# Cross-check: the list equals every file that differs between the two trees (symlinks excluded).
diff -rqN -x node_modules -x .toolchain $B $P/export | sed -e "s#^Files $B/\([^ ]*\) and .*#\1#" | sort > changed-files.txt
printf '%s\n' "${FILES[@]}" | sort | diff - changed-files.txt && echo "file list = tree difference" || echo "FILE LIST DIFFERS FROM TREE DIFFERENCE"
: > adoption-v6.diff
for f in "${FILES[@]}"; do
  if [ -e $B/$f ]; then A=a/$f; else A=/dev/null; fi
  diff -uN --label $A --label b/$f $B/$f export/$f >> adoption-v6.diff
done
echo "lines $(wc -l < adoption-v6.diff)"
grep -E '^\+\+\+ ' adoption-v6.diff
echo "protected-or-clearing hits: $(grep -E '^(\+\+\+|---) ' adoption-v6.diff | grep -cE ' [ab]/(gate|policy|spec|toolchain|schemas|\.github|governance|clearing)/|/clearing/|spec\.lock|AGENTS\.md|javascript_env\.py|build_model\.py|interop/export\.cjs|interop/model\.ts|ledger\.property|tsconfig\.json|package(-lock)?\.json')"
git -C /Users/mackianni/forge apply --check $P/adoption-v6.diff; echo "git apply --check exit $?"
shasum -a 256 adoption-v6.diff
(cd export && shasum -a 256 "${FILES[@]}") > new-files-sha256.txt
