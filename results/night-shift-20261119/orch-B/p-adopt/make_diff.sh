#!/bin/bash
# p-adopt: builds adoption.diff (pristine export of 985f5eaf -> changed export), then checks it. Applies nothing.
set -u
P=/Users/mackianni/forge/results/night-shift-20261119/orch-B/p-adopt; cd $P
FILES=(impl/finality-core/IssueBytes2.dfy impl/finality-core/SerModel.dfy impl/finality-core/ShellCoreV3.dfy
 impl/finality-core/ShellCoreV4.dfy impl/finality-core/SinkCoreV3.dfy scripts/exit_slice1.py
 ts/refund-finality/core/sinkcore-v4.cjs ts/refund-finality/dispatcher.ts ts/refund-finality/minter.ts ts/refund-finality/sink.ts)
: > adoption.diff
for f in "${FILES[@]}"; do
  if [ -e pristine/$f ]; then A=a/$f; else A=/dev/null; fi
  diff -uN --label $A --label b/$f pristine/$f export/$f >> adoption.diff
done
echo "lines $(wc -l < adoption.diff)"
grep -E '^\+\+\+ ' adoption.diff
echo "protected-or-clearing hits: $(grep -E '^(\+\+\+|---) ' adoption.diff | grep -cE ' [ab]/(gate|policy|spec|toolchain|schemas|\.github|governance|clearing)/|spec\.lock|AGENTS\.md|javascript_env\.py|build_model\.py|interop/|ledger\.property|tsconfig\.json|package(-lock)?\.json')"
git -C /Users/mackianni/forge apply --check $P/adoption.diff; echo "git apply --check exit $?"
shasum -a 256 adoption.diff
(cd export && shasum -a 256 "${FILES[@]}") > new-files-sha256.txt
