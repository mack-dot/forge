#!/bin/bash
# p-adopt (night shift 2026-11-19, Orchestrator B). PREPARED, NOT RUN by the worker.
# Runs the Slice 1 refund-finality suite exactly as scripts/exit_slice1.py (sink_controls) runs it:
#   cwd = tree root; node --import tsx tests/refund-finality/suite.ts <fresh out dir> <compiled issuer module>
# twice: (1) PRISTINE export of 985f5eaf with its own module (impl/RefundFinality.dfy + old footer; sha256 e6d5f5e5...,
#            equal to the Slice 1 record) = the baseline of this scratch environment;
#        (2) CHANGED export (adoption.diff applied) with the IssueBytes2 module (sha256 a60786ae...).
# The modules were built before, through dafny_locked.sh (logs/b2-issuer-build.log, logs/b3-pristine-core-build.log).
# This script runs NO Dafny. It refuses while hol.lock exists or a HOL process runs. It does NOT take heavy.lock:
# the orchestrator holds the heavy window. Scrubbed environment; pinned Node 24.3.0; wall-clock timeout per run.
# Usage: run_suite.sh [N]   (N = attempt number; default: the next free one). Exit: 0 both suites exit 0;
#        1 a suite failed (see summary); 64 refused (HOL lock or process); 65 setup problem.
set -u
P=/Users/mackianni/forge/results/night-shift-20261119/orch-B/p-adopt
LOCKS=/Users/mackianni/forge/results/night-shift-20261119/locks
TMO=${SUITE_TIMEOUT_S:-1200}
if [ -e "$LOCKS/hol.lock" ] || pgrep -f 'bin/hol' >/dev/null; then echo "refused: hol.lock exists or a HOL process runs"; exit 64; fi
N=${1:-$(( $(ls -d $P/suite/attempt-* 2>/dev/null | sed 's/.*attempt-//' | sort -n | tail -1) + 1 ))}
A=$P/suite/attempt-$N; mkdir -p $A || exit 65
[ -e $A/done ] && { echo "attempt $N exists; give a new N"; exit 65; }
ENV=(env -i PATH=/opt/homebrew/bin:/usr/bin:/bin HOME=$P/home LANG=C)
[ "$("${ENV[@]}" node --version)" = "v24.3.0" ] || { echo "pinned Node v24.3.0 not first in PATH"; exit 65; }
shasum -a 256 $P/build/pristine-core/model.cjs $P/build/issuer/model.cjs $P/adoption.diff > $A/inputs-sha256.txt
(cd $P/export && shasum -a 256 $(cut -c67- $P/new-files-sha256.txt)) | diff - $P/new-files-sha256.txt > $A/export-drift.txt \
  || { echo "the changed export differs from new-files-sha256.txt"; exit 65; }
rc=0
for T in pristine export; do
  if [ $T = pristine ]; then M=$P/build/pristine-core/model.cjs; else M=$P/build/issuer/model.cjs; fi
  echo "# $T start=$(date -u +%FT%TZ) module=$M timeout=${TMO}s" | tee $A/$T.meta
  ( cd $P/$T && /usr/bin/time -p "${ENV[@]}" timeout $TMO node --import tsx tests/refund-finality/suite.ts $A/$T-out $M \
      > $A/$T.stdout 2> $A/$T.stderr ); code=$?
  echo "# $T end=$(date -u +%FT%TZ) exit $code" | tee -a $A/$T.meta
  [ $code -eq 0 ] || rc=1
done
# Row-by-row comparison (control | name -> pass) of the two reports; rows only in one report are listed too.
python3 -I - $A > $A/summary.txt <<'EOF'
import json, sys, pathlib
a = pathlib.Path(sys.argv[1])
def load(t):
    f = a / (t + '-out') / 'report.json'
    return json.loads(f.read_text()) if f.exists() else None
base, new = load('pristine'), load('export')
for t, r in (('pristine', base), ('export', new)):
    print(t, 'counts', json.dumps(r['counts']) if r else 'NO REPORT', 'ids', json.dumps(r['ids']) if r else '')
if base and new:
    key = lambda r: r['control'] + ' | ' + r['name']
    b, n = {key(r): r for r in base['rows']}, {key(r): r for r in new['rows']}
    for k in sorted(set(b) | set(n)):
        pb, pn = b.get(k, {}).get('pass'), n.get(k, {}).get('pass')
        if pb is not True or pn is not True:
            print('ROW', k, '| pristine', pb, '| export', pn, '| observed export:', n.get(k, {}).get('observed', '-')[:200])
EOF
cat $A/summary.txt; touch $A/done; echo "exit $rc"; exit $rc
