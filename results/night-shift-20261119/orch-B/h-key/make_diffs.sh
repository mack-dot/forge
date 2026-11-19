#!/bin/bash
# make_diffs.sh: h-key.diff, h-key-judges.diff, h-key-scripts-UNAPPLIED.diff (paths relative to the repository root).
H=<REPO>/results/night-shift-20261119/orch-B/h-key; cd $H
mk() { out=$1; shift; : > $out
  for f in "$@"; do
    if [ -e pristine/$f ]; then git diff --no-index pristine/$f tree/$f; else git diff --no-index /dev/null tree/$f; fi \
      | sed -e "s#a/pristine/#a/#g; s#b/tree/#b/#g; s#b/pristine/#b/#g; s#a/tree/#a/#g" >> $out
  done; }
R=tests/refund-finality/regress
MAIN="ts/refund-finality/keyfile.ts ts/refund-finality/encoding.ts ts/refund-finality/minter.ts ts/refund-finality/sink.ts ts/refund-finality/dispatcher.ts ts/refund-finality/core/store.ts ts/refund-finality/proposer.ts ts/refund-finality/launch/minter-launch.sh tests/refund-finality/suite.ts $(cd tree && ls $R/kf_*.ts) $R/m_lib.ts $R/d_lib.ts $R/s_lib.ts $R/p_lib.ts $R/m2_closed_launch.ts $R/m2_completed_and_retry_after_commit.ts $R/m2_refused_pair_stays_closed.ts $R/m2_squat_invented_prestate_does_not_block.ts $R/m2_stale_retry_store_mode.ts $R/m_same_request_different_candidate_refused.ts $R/s3_kill_commits.ts $R/s_repair_prefix.ts"
JUDGES="$R/harness.ts $R/worker.ts $R/k_judge_blindspots.ts tests/refund-finality/spec-conformance/oracle.ts tests/refund-finality/spec-conformance/run.ts tests/refund-finality/spec-conformance/selftest.ts"
SCRIPTS="scripts/exit_m1_conformance.py scripts/demo_gauntlet.py scripts/exit_slice1.py"
mk h-key.diff $MAIN; mk h-key-judges.diff $JUDGES; mk h-key-scripts-UNAPPLIED.diff $SCRIPTS
# completeness: every changed file is in exactly one diff
(cd $H && diff -rq pristine tree | grep -v node_modules | sed -E 's#^Files pristine/([^ ]+) and .*#\1#; s#^Only in tree/?(.*): (.*)#\1/\2#' | sed 's#^/##' | sort) > changed.txt
echo $MAIN $JUDGES $SCRIPTS | tr ' ' '\n' | sort > listed.txt
diff changed.txt listed.txt && echo "COMPLETE: every changed file is in one diff"
shasum -a 256 h-key.diff h-key-judges.diff h-key-scripts-UNAPPLIED.diff
