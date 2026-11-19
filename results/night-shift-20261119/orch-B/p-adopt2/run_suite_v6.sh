#!/bin/bash
# p-adopt2 (night shift 2026-11-19, Orchestrator B). PREPARED, NOT RUN by the worker.
# Copy of p-adopt/run_suite.sh, adapted to the v6 packet. It runs the Slice 1 refund-finality suite exactly as
# scripts/exit_slice1.py (sink_controls) runs it: cwd = tree root;
#   node --import tsx tests/refund-finality/suite.ts <fresh out dir> <compiled issuer module>
# Runs (in this order):
#   (1) pristine : orch-B/p-adopt/pristine (export of 985f5eaf, READ-ONLY reuse) with p-adopt/build/pristine-core/model.cjs
#                  (sha256 e6d5f5e5..., equal to the Slice 1 record) = the baseline;
#   (2) export   : p-adopt2/export (adoption-v6.diff applied) with p-adopt2/build/issuer/model.cjs (IssueBytes2, a60786ae...);
#   (3) x3probe  : the same export, but with suite_x3probe.ts (p-adopt2/suite-variant/; a MEASUREMENT VARIANT, NOT in the
#                  diff): only the x3 audit row catches a refusal at sink start, with an UNCHANGED pass condition. The file
#                  is copied into export/tests/refund-finality/ for this run and removed afterwards. Skip it with NO_PROBE=1.
# PREDICTION (made before any run): (1) exit 0, 115 rows, 0 failed. (2) exit 2, NO report.json: suite.ts:517 `w.sink()` on
# the x3 store (attacker-signed row + state update) throws "v6 sink refuses to serve: start-up audit ... is false"
# (reproduced in logs/tamper-v6-1.log). (3) exit 1, 115 rows, exactly 1 failed: "dispatcher | the public-key audit of that
# changed database" (observed "MEASUREMENT VARIANT: the sink refused to start ..."). Any other FAIL row is NOT predicted.
# This script runs NO Dafny. It refuses while hol.lock exists or a HOL process runs. It does NOT take heavy.lock: the
# orchestrator holds the heavy window. Scrubbed environment; pinned Node 24.3.0; wall-clock timeout per run.
# Usage: run_suite_v6.sh [N]   (N = attempt number; default: the next free one).
# Exit: 0 the three runs ended as PREDICTED (see summary.txt line "PREDICTION"); 1 a run differs from the prediction;
#       64 refused (HOL lock or process); 65 setup problem.
set -u
O=<REPO>/results/night-shift-20261119/orch-B
P=$O/p-adopt2; BASE=$O/p-adopt/pristine
LOCKS=<REPO>/results/night-shift-20261119/locks
TMO=${SUITE_TIMEOUT_S:-1200}
if [ -e "$LOCKS/hol.lock" ] || pgrep -f 'bin/hol' >/dev/null; then echo "refused: hol.lock exists or a HOL process runs"; exit 64; fi
N=${1:-$(( $(ls -d $P/suite/attempt-* 2>/dev/null | sed 's/.*attempt-//' | sort -n | tail -1) + 1 ))}
A=$P/suite/attempt-$N; mkdir -p $A || exit 65
[ -e $A/done ] && { echo "attempt $N exists; give a new N"; exit 65; }
ENV=(env -i PATH=/opt/homebrew/bin:/usr/bin:/bin HOME=$P/home LANG=C)
[ "$("${ENV[@]}" node --version)" = "v24.3.0" ] || { echo "pinned Node v24.3.0 not first in PATH"; exit 65; }
MP=$O/p-adopt/build/pristine-core/model.cjs; ME=$P/build/issuer/model.cjs
shasum -a 256 $MP $ME $P/adoption-v6.diff $P/suite-variant/suite_x3probe.ts > $A/inputs-sha256.txt
(cd $P/export && shasum -a 256 $(cut -c67- $P/new-files-sha256.txt)) | diff - $P/new-files-sha256.txt > $A/export-drift.txt \
  || { echo "the changed export differs from new-files-sha256.txt"; exit 65; }
PROBE=$P/export/tests/refund-finality/suite_x3probe.ts
RUNS="pristine export"; [ "${NO_PROBE:-0}" = 1 ] || RUNS="$RUNS x3probe"
for T in $RUNS; do
  case $T in
    pristine) D=$BASE; M=$MP; S=tests/refund-finality/suite.ts;;
    export)   D=$P/export; M=$ME; S=tests/refund-finality/suite.ts;;
    x3probe)  D=$P/export; M=$ME; S=tests/refund-finality/suite_x3probe.ts; cp $P/suite-variant/suite_x3probe.ts $PROBE || exit 65;;
  esac
  echo "# $T start=$(date -u +%FT%TZ) tree=$D suite=$S module=$M timeout=${TMO}s" | tee $A/$T.meta
  ( cd $D && /usr/bin/time -p "${ENV[@]}" timeout $TMO node --import tsx $S $A/$T-out $M > $A/$T.stdout 2> $A/$T.stderr ); code=$?
  [ $T = x3probe ] && rm -f $PROBE
  echo "# $T end=$(date -u +%FT%TZ) exit $code" | tee -a $A/$T.meta
  echo $code > $A/$T.exit
done
# Row-by-row comparison (control | name -> pass); every failing or missing row side by side; the prediction check.
python3 -I - $A > $A/summary.txt <<'EOF'
import json, sys, pathlib
a = pathlib.Path(sys.argv[1])
def load(t):
    f = a / (t + '-out') / 'report.json'
    return json.loads(f.read_text()) if f.exists() else None
def code(t):
    f = a / (t + '.exit')
    return int(f.read_text()) if f.exists() else None
runs = [t for t in ('pristine', 'export', 'x3probe') if (a / (t + '.meta')).exists()]
rep = {t: load(t) for t in runs}
for t in runs:
    r = rep[t]
    print(t, 'exit', code(t), 'counts', json.dumps(r['counts']) if r else 'NO REPORT', 'ids', json.dumps(r['ids']) if r else '')
    if r is None:
        err = (a / (t + '.stderr')).read_text(errors='replace').strip().splitlines()
        print('  ' + t + ' stderr (first 3 lines):', ' / '.join(err[:3])[:400])
key = lambda r: r['control'] + ' | ' + r['name']
rows = {t: ({key(x): x for x in rep[t]['rows']} if rep[t] else {}) for t in runs}
allk = sorted(set().union(*[set(v) for v in rows.values()]))
for k in allk:
    ps = {t: rows[t].get(k, {}).get('pass') for t in runs}
    if any(ps[t] is not True for t in runs if rep[t] is not None):
        print('ROW', k, '|', ' | '.join(t + ' ' + str(ps[t]) for t in runs))
        for t in runs:
            if rows[t].get(k) and ps[t] is not True:
                print('   observed', t + ':', str(rows[t][k].get('observed', '-'))[:240])
X3 = 'dispatcher | the public-key audit of that changed database'
ok = True
if 'pristine' in runs:
    r = rep['pristine']; ok &= code('pristine') == 0 and r is not None and r['counts']['rows'] == 115 and r['counts']['failed'] == 0
if 'export' in runs:
    err = (a / 'export.stderr').read_text(errors='replace')
    ok &= code('export') == 2 and rep['export'] is None and 'v6 sink refuses to serve: start-up audit' in err
if 'x3probe' in runs:
    r = rep['x3probe']
    ok &= code('x3probe') == 1 and r is not None and r['counts']['rows'] == 115 and [key(x) for x in r['rows'] if not x['pass']] == [X3] \
        and 'MEASUREMENT VARIANT: the sink refused to start: v6 sink refuses' in rows['x3probe'][X3]['observed']
print('PREDICTION', 'MET' if ok else 'NOT MET (a difference that was not predicted: analyse; do not re-record)')
sys.exit(0 if ok else 1)
EOF
rc=$?
cat $A/summary.txt; touch $A/done; echo "exit $rc"; exit $rc
