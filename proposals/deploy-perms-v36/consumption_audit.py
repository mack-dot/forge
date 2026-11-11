"""Request-consumption audit on copies of real controller databases (no live request changes).

  python3 -I -B consumption_audit.py CODE_ROOT LOCK OUTPUT CONSUMED_DB CONSUMED_CHALLENGE
      PENDING_DB PENDING_CHALLENGE CANDIDATE

Runs the checkout's real release.py and observe.py through the bootstrap against
copies, plus two SQLite interruption checks that use the same statements as the
admission code. Exit 0 when every case leaves the state named in the table.
"""
import json
import os
from pathlib import Path
import shutil
import sqlite3
import subprocess
import sys
import time

code, lock, OUT = Path(sys.argv[1]), sys.argv[2], Path(sys.argv[3]).resolve()
CONSUMED_DB, CONSUMED_CH, PENDING_DB, PENDING_CH, CANDIDATE = sys.argv[4:9]
OUT.mkdir(parents=True, exist_ok=False)
results = []


def state(db, challenge):
    connection = sqlite3.connect('file:' + str(db) + '?mode=ro', uri=True)
    row = connection.execute('SELECT state FROM requests WHERE challenge=?', (challenge,)).fetchone()
    connection.close()
    return row and row[0]


def copy(src, name):
    target = OUT / (name + '.sqlite')
    shutil.copyfile(src, target)
    return target


def launch(script, db, challenge, name, extra):
    records = OUT / name
    argv = ['python3', '-I', '-S', '-B', str(code / 'gate/provenance/bootstrap.py'), '--implementation-sha256', lock,
            '--', str(code / 'gate/provenance' / script), '--candidate', CANDIDATE, '--controller', str(db),
            '--challenge', challenge, '--implementation-sha256', lock, '--records', str(records)] + extra
    child = subprocess.run(argv, capture_output=True, text=True, cwd='/tmp')
    result = json.loads((records / 'result.json').read_text())
    return child.returncode, result.get('reason') or result.get('result')


def record(name, before, after, exit_code, reason, expected_after, expected_reason):
    ok = after == expected_after and (expected_reason is None or (reason or '').startswith(expected_reason))
    results.append({'case': name, 'state_before': before, 'state_after': after, 'exit': exit_code,
                    'reason': reason, 'expected_state_after': expected_after,
                    'expected_reason': expected_reason, 'pass': ok})
    print('PASS' if ok else 'FAIL', '|', name, '| state', before, '->', after, '| exit', exit_code, '|', reason, flush=True)


# 1-2. A consumed request can never be admitted again (release.py --admit, observe.py accepted).
for script, extra, name in [('release.py', ['--admit'], 'release-admit-on-consumed'),
                            ('observe.py', ['--case', 'accepted'], 'observe-accepted-on-consumed')]:
    db = copy(CONSUMED_DB, name)
    before = state(db, CONSUMED_CH)
    code_, reason = launch(script, db, CONSUMED_CH, name, extra)
    record(name, before, state(db, CONSUMED_CH), code_, reason, 'consumed', 'STALE_OR_CONSUMED_REQUEST')

# 3. Verification fails on a pending request: the transaction rolls back, the request stays pending.
db = copy(PENDING_DB, 'verify-fails-on-pending')
before = state(db, PENDING_CH)
code_, reason = launch('release.py', db, PENDING_CH, 'verify-fails-on-pending', ['--admit'])
record('verification fails before consumption (release.py --admit)', before, state(db, PENDING_CH), code_, reason,
       'pending', None)

# 4. Interrupted after the UPDATE but before COMMIT (same statements as the admission code).
db = copy(PENDING_DB, 'killed-before-commit')
before = state(db, PENDING_CH)
child = subprocess.run([sys.executable, '-I', '-c', (
    'import os, sqlite3, sys\n'
    'c = sqlite3.connect("file:" + sys.argv[1] + "?mode=rw", uri=True)\n'
    'c.execute("BEGIN IMMEDIATE")\n'
    'c.execute("UPDATE requests SET state=\'consumed\' WHERE challenge=? AND state=\'pending\'", (sys.argv[2],))\n'
    'os._exit(9)\n'), str(db), PENDING_CH])
record('process killed after UPDATE, before COMMIT', before, state(db, PENDING_CH), child.returncode, 'killed', 'pending', None)

# 5. Two admissions at once: BEGIN IMMEDIATE lets only one writer in.
db = copy(PENDING_DB, 'concurrent-admission')
before = state(db, PENDING_CH)
holder = subprocess.Popen([sys.executable, '-I', '-c', (
    'import sqlite3, sys, time\n'
    'c = sqlite3.connect("file:" + sys.argv[1] + "?mode=rw", uri=True)\n'
    'c.execute("BEGIN IMMEDIATE")\n'
    'print("held", flush=True)\n'
    'time.sleep(4)\n'
    'c.rollback()\n'), str(db)], stdout=subprocess.PIPE, text=True)
holder.stdout.readline()
try:
    second = sqlite3.connect('file:' + str(db) + '?mode=rw', uri=True, timeout=0.5)
    second.execute('BEGIN IMMEDIATE')
    outcome = 'second writer admitted'
except sqlite3.OperationalError as error:
    outcome = 'second writer refused: ' + str(error)
holder.wait()
record('second admission while the first holds the transaction', before, state(db, PENDING_CH), 0, outcome,
       'pending', 'second writer refused')

(OUT / 'results.json').write_text(json.dumps({'results': results, 'end_to_end': False}, indent=2) + '\n')
bad = [r for r in results if not r['pass']]
print('cases', len(results), 'not passing', len(bad))
sys.exit(1 if bad else 0)
