#!/bin/bash
# h-sink (night shift 2026-11-19, Orchestrator B). PREPARED, NOT RUN by the worker. HEAVY (the full Slice 1 suite).
# Runs tests/refund-finality/suite.ts as scripts/exit_slice1.py runs it (cwd = tree root;
#   node --import tsx tests/refund-finality/suite.ts <fresh out dir> <compiled issuer module>), on:
#   (1) pristine: h-sink/pristine (git archive of nightshift/B-trust: sink/dispatcher/minter unchanged) = the baseline;
#   (2) hardened: h-sink/tree (= pristine + h-sink.diff). The minter is UNCHANGED in both trees, so both runs use the
#       pristine issuer module p-adopt/build/pristine-core/model.cjs (sha256 e6d5f5e5...).
# PREDICTION (made before any run, not observed):
#   (1) exit 0, 115 rows, 0 failed.
#   (2) exit 2, NO report.json. The first raw tamper row x1 (suite.ts:506: raw INSERT INTO outbox from a second connection)
#       ABORTS in SQL with "h-sink S1/S2/S4: an outbox row is written only by its settled row" (trigger h_outbox_bi); the
#       exception is not caught by the suite; main() rejects. The rows x2-x7 would ABORT the same way (S5 / S2 triggers).
#       BY DESIGN: the hardened schema makes those hostile writes impossible through SQL; the suite's x-rows need a new
#       expectation ("the write aborts"), or a trigger-dropping writer (owner and h-regress decision). Rows before x1
#       (controls a-d incl. zero amounts, races b and c through commit_cli/dispatch_cli) are predicted to pass; a race row
#       is at risk from start-up cost (START_DELAY_MS 5000; each process runs integrity_check and the full audit).
#   Any other failure is NOT predicted: analyse; do not re-record.
# Refuses (64) while hol.lock exists or a HOL process runs. Does NOT take heavy.lock. Scrubbed env; pinned Node 24.3.0.
# Usage: run_suite_h.sh [N]
set -u
O=<REPO>/results/night-shift-20261119/orch-B; H=$O/h-sink
LOCKS=<REPO>/results/night-shift-20261119/locks; TMO=${SUITE_TIMEOUT_S:-1200}
if [ -e "$LOCKS/hol.lock" ] || pgrep -f 'bin/hol' >/dev/null; then echo "refused: hol.lock exists or a HOL process runs"; exit 64; fi
pmset -g batt | head -1 | grep -q "Power" || { echo "refused: not on AC power"; exit 64; }
N=${1:-$(( $(ls -d $H/suite/attempt-* 2>/dev/null | sed 's/.*attempt-//' | sort -n | tail -1) + 1 ))}
A=$H/suite/attempt-$N; mkdir -p $A || exit 65; [ -e $A/done ] && { echo "attempt $N exists"; exit 65; }
ENV=(env -i PATH=/opt/homebrew/bin:/usr/bin:/bin HOME=$H/home LANG=C)
[ "$("${ENV[@]}" node --version)" = "v24.3.0" ] || { echo "pinned Node v24.3.0 not first in PATH"; exit 65; }
M=$O/p-adopt/build/pristine-core/model.cjs
shasum -a 256 $M $H/h-sink.diff $H/tree/ts/refund-finality/sink.ts $H/tree/ts/refund-finality/core/store.ts $H/tree/ts/refund-finality/dispatcher.ts > $A/inputs-sha256.txt
for T in pristine hardened; do
  case $T in pristine) D=$H/pristine;; hardened) D=$H/tree;; esac
  echo "# $T start=$(date -u +%FT%TZ) tree=$D timeout=${TMO}s" | tee $A/$T.meta
  ( cd $D && /usr/bin/time -p "${ENV[@]}" timeout $TMO node --import tsx tests/refund-finality/suite.ts $A/$T-out $M > $A/$T.stdout 2> $A/$T.stderr ); code=$?
  echo "# $T end=$(date -u +%FT%TZ) exit $code" | tee -a $A/$T.meta; echo $code > $A/$T.exit
done
python3 -I - $A > $A/summary.txt <<'PY'
import json, sys, pathlib
a = pathlib.Path(sys.argv[1])
def load(t):
    f = a / (t + '-out') / 'report.json'
    return json.loads(f.read_text()) if f.exists() else None
code = lambda t: int((a / (t + '.exit')).read_text())
rp, rh = load('pristine'), load('hardened')
for t, r in (('pristine', rp), ('hardened', rh)):
    print(t, 'exit', code(t), 'counts', json.dumps(r['counts']) if r else 'NO REPORT')
    if r:
        for x in r['rows']:
            if not x['pass']: print('  FAIL', x['control'], '|', x['name'], '|', str(x.get('observed', ''))[:200])
    else:
        print('  stderr:', ' / '.join((a / (t + '.stderr')).read_text(errors='replace').strip().splitlines()[:4])[:500])
err = (a / 'hardened.stderr').read_text(errors='replace')
ok = code('pristine') == 0 and rp is not None and rp['counts']['failed'] == 0 and code('hardened') == 2 and rh is None and 'h-sink S1/S2/S4' in err
print('PREDICTION', 'MET' if ok else 'NOT MET (analyse; do not re-record)')
sys.exit(0 if ok else 1)
PY
rc=$?; cat $A/summary.txt; touch $A/done; echo "exit $rc"; exit $rc
