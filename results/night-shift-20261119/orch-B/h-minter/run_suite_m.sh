#!/bin/bash
# h-minter (night shift 2026-11-19, Orchestrator B). PREPARED, NOT RUN by the worker. Adapted from p-adopt2/run_suite_v6.sh.
# It runs the Slice 1 refund-finality suite as scripts/exit_slice1.py runs it: cwd = tree root;
#   node --import tsx tests/refund-finality/suite.ts <fresh out dir> <compiled issuer module>
# Runs, in this order:
#   (1) pristine : h-minter/pristine (export of branch de71cf4d with proposer.ts of 7413cb2f; merged minter) with p-adopt/build/pristine-core/model.cjs;
#   (2) head-m   : h-minter/tree (branch head + h-minter.diff) with h-minter/build/issueonce.cjs (IssueOnce, 4cf78df8...);
#   (3) v6-m     : h-minter/tree-v6 (adoption-v6.diff + the h-minter minter.ts and IssueOnce.dfy) with issueonce.cjs;
#   (4) v6-m-x3  : the same tree with p-adopt2/suite-variant/suite_x3probe.ts (measurement variant; copied in, removed after).
# PREDICTION (made before any run):
#   (1) exit 0, 0 failed rows.
#   (2) exit 1, exactly 1 failed row: "option | single-use on: another transition for a pre-state that has a signed token"
#       (suite.ts:586-589: request opt_b on the pre-state of opt_a is now SIGNED by design: a new request id on a signed
#       pre-state is allowed; the row expects the OLD rule). The row "single-use on: the same transition again" passes.
#   (3) exit 2, NO report.json: inherited from the v6 packet (suite.ts:517 x3 store: "v6 sink refuses to serve").
#   (4) exit 1, exactly 2 failed rows: the X3 row of the v6 packet and the single-use row of (2).
# Refuses while hol.lock exists or a HOL process runs. Does NOT take heavy.lock. Scrubbed environment; pinned Node.
# Usage: run_suite_m.sh [N]. Exit: 0 PREDICTION MET; 1 not met; 64 refused; 65 setup problem.
set -u
O=/Users/mackianni/forge/results/night-shift-20261119/orch-B
H=$O/h-minter; P=$O/p-adopt2
LOCKS=/Users/mackianni/forge/results/night-shift-20261119/locks
TMO=${SUITE_TIMEOUT_S:-1200}
if [ -e "$LOCKS/hol.lock" ] || pgrep -f 'bin/hol' >/dev/null; then echo "refused: hol.lock exists or a HOL process runs"; exit 64; fi
pmset -g batt | head -1 | grep -q "AC Power" || { echo "refused: not on AC power"; exit 64; }
N=${1:-$(( $(ls -d $H/suite/attempt-* 2>/dev/null | sed 's/.*attempt-//' | sort -n | tail -1) + 1 ))}
A=$H/suite/attempt-$N; mkdir -p $A || exit 65
[ -e $A/done ] && { echo "attempt $N exists; give a new N"; exit 65; }
ENV=(env -i PATH=/opt/homebrew/bin:/usr/bin:/bin HOME=$H/home LANG=C)
[ "$("${ENV[@]}" node --version)" = "v24.3.0" ] || { echo "pinned Node v24.3.0 not first in PATH"; exit 65; }
MP=$O/p-adopt/build/pristine-core/model.cjs; MM=$H/build/issueonce.cjs
shasum -a 256 $MP $MM $H/h-minter.diff $P/suite-variant/suite_x3probe.ts $H/tree/ts/refund-finality/minter.ts \
  $H/tree-v6/ts/refund-finality/minter.ts > $A/inputs-sha256.txt
cmp -s $H/tree/ts/refund-finality/minter.ts $H/tree-v6/ts/refund-finality/minter.ts || { echo "the two minter.ts copies differ"; exit 65; }
PROBE=$H/tree-v6/tests/refund-finality/suite_x3probe.ts
for T in pristine head-m v6-m v6-m-x3; do
  case $T in
    pristine) D=$H/pristine; M=$MP; S=tests/refund-finality/suite.ts;;
    head-m)   D=$H/tree; M=$MM; S=tests/refund-finality/suite.ts;;
    v6-m)     D=$H/tree-v6; M=$MM; S=tests/refund-finality/suite.ts;;
    v6-m-x3)  D=$H/tree-v6; M=$MM; S=tests/refund-finality/suite_x3probe.ts; cp $P/suite-variant/suite_x3probe.ts $PROBE || exit 65;;
  esac
  echo "# $T start=$(date -u +%FT%TZ) tree=$D suite=$S module=$M timeout=${TMO}s" | tee $A/$T.meta
  ( cd $D && /usr/bin/time -p "${ENV[@]}" timeout $TMO node --import tsx $S $A/$T-out $M > $A/$T.stdout 2> $A/$T.stderr ); code=$?
  [ $T = v6-m-x3 ] && rm -f $PROBE
  echo "# $T end=$(date -u +%FT%TZ) exit $code" | tee -a $A/$T.meta
  echo $code > $A/$T.exit
done
python3 -I - $A > $A/summary.txt <<'PYEOF'
import json, sys, pathlib
a = pathlib.Path(sys.argv[1])
def load(t):
    f = a / (t + '-out') / 'report.json'
    return json.loads(f.read_text()) if f.exists() else None
def code(t):
    f = a / (t + '.exit')
    return int(f.read_text()) if f.exists() else None
runs = [t for t in ('pristine', 'head-m', 'v6-m', 'v6-m-x3') if (a / (t + '.meta')).exists()]
rep = {t: load(t) for t in runs}
key = lambda r: r['control'] + ' | ' + r['name']
for t in runs:
    r = rep[t]
    print(t, 'exit', code(t), 'counts', json.dumps(r['counts']) if r else 'NO REPORT')
    if r is None:
        err = (a / (t + '.stderr')).read_text(errors='replace').strip().splitlines()
        print('  stderr (first 3 lines):', ' / '.join(err[:3])[:400])
rows = {t: ({key(x): x for x in rep[t]['rows']} if rep[t] else {}) for t in runs}
for k in sorted(set().union(*[set(v) for v in rows.values()])):
    ps = {t: rows[t].get(k, {}).get('pass') for t in runs}
    if any(ps[t] is not True for t in runs if rep[t] is not None):
        print('ROW', k, '|', ' | '.join(t + ' ' + str(ps[t]) for t in runs))
        for t in runs:
            if rows[t].get(k) and ps[t] is not True:
                print('   observed', t + ':', str(rows[t][k].get('observed', '-'))[:240])
SINGLE = 'option | single-use on: another transition for a pre-state that has a signed token'
X3 = 'dispatcher | the public-key audit of that changed database'
failed = lambda t: sorted(key(x) for x in rep[t]['rows'] if not x['pass'])
ok = True
ok &= code('pristine') == 0 and rep['pristine'] is not None and rep['pristine']['counts']['failed'] == 0
ok &= code('head-m') == 1 and rep['head-m'] is not None and failed('head-m') == [SINGLE]
ok &= code('v6-m') == 2 and rep['v6-m'] is None and 'v6 sink refuses to serve: start-up audit' in (a / 'v6-m.stderr').read_text(errors='replace')
ok &= code('v6-m-x3') == 1 and rep['v6-m-x3'] is not None and failed('v6-m-x3') == sorted([SINGLE, X3])
print('PREDICTION', 'MET' if ok else 'NOT MET (a difference that was not predicted: analyse; do not re-record)')
sys.exit(0 if ok else 1)
PYEOF
rc=$?
cat $A/summary.txt; touch $A/done; echo "exit $rc"; exit $rc
