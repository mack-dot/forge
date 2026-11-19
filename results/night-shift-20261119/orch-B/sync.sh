#!/bin/bash
# Orchestrator B only. Copy B's night-shift evidence into the nightshift/B-trust worktree; replace absolute paths in
# text copies. Usage: sync.sh [EXCLUDED_TASK_DIR ...]  (task directories that are not re-checked yet stay out).
set -e
SRC=<REPO>/results/night-shift-20261119
WT=<SCRATCH>/B-trust
DST=$WT/results/night-shift-20261119
EX=(); for t in "$@"; do EX+=(--exclude "orch-B/$t/"); done
mkdir -p $DST
rsync -a --exclude '.git/' --exclude '/orch-B/h-*/tree*/' --exclude '/orch-B/h-*/pristine/' --exclude '/orch-B/h-*/home/' --exclude '/orch-B/h-*/b/base/' --exclude '/orch-B/h-*/b/tree*/' --exclude 'locks/' --exclude 'orch-A/' --exclude 'MORNING_REPORT.md' \
  --exclude 'f-records/checkout/' --exclude 'f-records/work/' --exclude 'translate-*-output/' --exclude 'translate-out/' \
  --exclude 'build-probe/' --exclude 'run-*.out' --exclude 'node_modules/' --exclude '__pycache__/' --exclude '*.pyc' \
  --exclude 'build/' --exclude '*.db' --exclude '*.sqlite*' --exclude '*.pem' --exclude '*.key' --exclude '.DS_Store' \
  --exclude 'f-records/records/**/*.log' --exclude 'wt/' --exclude 'flood10mb*' --exclude 'recheck-f/rerun/' \
  --exclude 'bin-*/' --exclude 'p-adopt/export/' --exclude 'p-adopt2/export/' --exclude 'p-adopt2/build/' --exclude 'p-adopt2/home/' --exclude 'p-adopt2/suite-variant/export*/' --exclude 'p-adopt/pristine/' --exclude 'p-adopt/applytest/' --exclude 'p-adopt/home/' --exclude 'p-adopt/build/' --exclude 'x-issuer-bridge/bin/' --exclude 'recheck-xb/copy/' --exclude 'x-issuer-bridge/run/work/' --exclude 'js-out*/' --exclude 'conformance/scratch/' --exclude '*.dylib' "${EX[@]}" $SRC/ $DST/ || [ $? -eq 24 ]   # 24 = some source files vanished during the copy (workers write while I sync): not an error; the sanitising step below MUST still run
grep -rIl -e '<HOME>' -e '<TMP>' -e 'Users-<USER>' $DST 2>/dev/null | while read f; do
  chmod u+w "$f" "$(dirname "$f")" 2>/dev/null; perl -pi -e 's#<REPO>#<REPO>#g; s#<TMP>/[A-Za-z0-9._/-]*scratchpad#<SCRATCH>#g; s#<HOME>#<HOME>#g; s#<TMP>#<TMP>#g; s#<PROJECT>#<PROJECT>#g' "$f"
done
cd $WT; git add -A results/night-shift-20261119; echo "staged: $(git status --short | wc -l)"; find results/night-shift-20261119 -size +1M | head
