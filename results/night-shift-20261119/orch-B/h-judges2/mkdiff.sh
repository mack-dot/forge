#!/bin/bash
# mkdiff.sh (h-judges2): ONE diff of the owned files against the pristine export of 74fb70eb, then git apply --check
# on a fresh export (and on the read-only branch worktree).
D=<REPO>/results/night-shift-20261119/orch-B/h-judges2; cd $D
FILES="tests/refund-finality/regress/run.ts tests/refund-finality/regress/harness.ts tests/refund-finality/regress/worker.ts tests/refund-finality/regress/remote.ts tests/refund-finality/regress/controls.ts tests/refund-finality/regress/k_judge_blindspots.ts tests/refund-finality/regress/README.md"
for x in x1_reqid_mismatch_duplicate x2_cross_charge_duplicate x3_upgrade_legacy_gap_duplicate x4_signed_unauthorized_commits x5_hostile_writer_store x6_zero_row_and_prefix_rollback; do FILES="$FILES tests/refund-finality/regress/$x.ts"; done
for f in README.md SPEC_ORACLE.md heavy_spec.sh oracle.ts run.ts selftest.ts; do FILES="$FILES tests/refund-finality/spec-conformance/$f"; done
: > h-judges2.diff
for f in $FILES; do (cd $D && git diff --no-index --no-prefix -- pristine/$f tree/$f | sed -e "s#^--- pristine/#--- a/#" -e "s#^+++ tree/#+++ b/#" -e "s#^diff --git pristine/\([^ ]*\) tree/#diff --git a/\1 b/#") >> h-judges2.diff; done
shasum -a 256 h-judges2.diff | tee h-judges2.diff.sha256
rm -rf $D/applycheck; mkdir -p $D/applycheck; git -C <REPO> archive 74fb70eb tests/refund-finality | tar -x -C $D/applycheck
cd $D/applycheck && git init -q . && git apply --check $D/h-judges2.diff; echo "apply --check (fresh export): exit $?"
git -C <SCRATCH>/B-trust apply --check $D/h-judges2.diff; echo "apply --check (branch worktree, read only): exit $?"
rm -rf $D/applycheck
