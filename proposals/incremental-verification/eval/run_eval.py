"""Run the frozen Stage 11 evaluation cases against the incremental PR gate, cold then warm.

  python3 -I run_eval.py CASES_JSON APPROVED_SHA256 PLAIN TOOLCHAIN NODE_MODULES OUTPUT WORK

PLAIN is a clean tree of the Stage 11 candidate (no .git, .toolchain, node_modules, build).
Per case: root = clone of PLAIN with the toolchain and node_modules linked; candidate =
clone of PLAIN with the case's edits. The gate runs twice in the same root: pass "cold"
with an empty obligation cache and pass "warm" immediately after, so reuse can be measured.
The runner only prepares inputs and records results.
"""
import hashlib
import json
import os
from pathlib import Path
import resource
import shutil
import subprocess
import sys
import time

CASES, APPROVED, PLAIN, TOOLCHAIN, NODE_MODULES, OUT, WORK = sys.argv[1:8]
CASES, PLAIN, OUT, WORK = Path(CASES), Path(PLAIN), Path(OUT).resolve(), Path(WORK).expanduser().resolve()
raw = CASES.read_bytes()
assert hashlib.sha256(raw).hexdigest() == APPROVED, 'CASES_NOT_FROZEN'
spec = json.loads(raw)
OUT.mkdir(parents=True, exist_ok=False)
WORK.mkdir(parents=True, exist_ok=False)
NODE_DIR = os.environ.get('FORGE_EVAL_NODE_DIR', '/opt/homebrew/bin')
SANDBOX = ['/usr/bin/sandbox-exec', '-p', '(version 1)(allow default)(deny network-outbound (remote ip "*:*"))(deny network-inbound (local ip "*:*"))']


def clone(src, dst):
    subprocess.run(['/bin/cp', '-cRp', str(src), str(dst)], check=True)


def link_tools(tree, copy_toolchain=False):
    # The root's toolchain is a private copy (APFS clone), so a root_changes 'delete' under
    # .toolchain never reaches the real pinned toolchain. Candidates only need links.
    if copy_toolchain:
        clone(TOOLCHAIN, tree / '.toolchain')
    else:
        os.symlink(TOOLCHAIN, tree / '.toolchain')
    os.symlink(NODE_MODULES, tree / 'node_modules')


def apply(change, tree):
    op = change['op']
    path = tree / change.get('path', '')
    if op == 'append':
        path.write_text(path.read_text() + change['text'])
    elif op == 'write':
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(change['text'])
    elif op == 'replace':
        s = path.read_text(); assert s.count(change['find']) == 1, ('anchor', change['path']); path.write_text(s.replace(change['find'], change['replace']))
    elif op == 'replace_all':
        s = path.read_text(); assert change['find'] in s; path.write_text(s.replace(change['find'], change['replace']))
    elif op in ('delete', 'unlink'):
        if op == 'delete' and (path.is_symlink() or any(parent.is_symlink() for parent in path.parents
                                                        if parent != tree and parent.is_relative_to(tree))):
            raise ValueError('refusing to delete through a symlink: ' + change['path'])
        path.unlink()
    elif op == 'relock_spec':
        lock = json.loads((tree / 'spec.lock').read_text())
        lock['spec_sha256'] = hashlib.sha256((tree / 'spec/LedgerSpec.dfy').read_bytes()).hexdigest()
        (tree / 'spec.lock').write_text(json.dumps(lock, sort_keys=True) + '\n')
    elif op == 'regen_evidence':
        link_tools(tree)
        child = subprocess.run([sys.executable, 'gate/gate.py', '--impl', 'impl/Ledger.dfy', '--evidence', 'evidence.json'],
                               cwd=tree, capture_output=True, text=True, env=dict(os.environ, PYTHONDONTWRITEBYTECODE='1'))
        assert child.returncode == 0, child.stdout + child.stderr
        (tree / '.toolchain').unlink(); (tree / 'node_modules').unlink(); shutil.rmtree(tree / 'build', ignore_errors=True)
        for cache in list(tree.rglob('__pycache__')):
            shutil.rmtree(cache)
    else:
        raise ValueError(op)


def gate(root, candidate, label, work):
    # The pinned node lives in NODE_DIR (checked by bytes by scripts/javascript_env.py).
    env = {'PATH': str(Path(sys.executable).parent) + ':' + NODE_DIR + ':/usr/bin:/bin', 'HOME': os.environ['HOME'], 'TMPDIR': str(work)}
    argv = [sys.executable, 'gate/incremental.py', '--candidate', str(candidate), '--evidence', 'build/%s.json' % label, '--work', 'build/%s' % label]
    before = resource.getrusage(resource.RUSAGE_CHILDREN); start = time.perf_counter_ns()
    child = subprocess.run(SANDBOX + argv, cwd=root, env=env, capture_output=True, timeout=1800)
    wall = (time.perf_counter_ns() - start) / 1e9; after = resource.getrusage(resource.RUSAGE_CHILDREN)
    op = {}
    if (root / 'build' / label / 'operation.json').is_file():
        op = json.loads((root / 'build' / label / 'operation.json').read_text())
    return child, op, wall, after.ru_utime - before.ru_utime + after.ru_stime - before.ru_stime


records = []
for case in spec['cases']:
    work = WORK / case['id']; work.mkdir(parents=True)
    root, candidate = work / 'root', work / 'candidate'
    clone(PLAIN, root); clone(PLAIN, candidate); link_tools(root, copy_toolchain=True); (root / 'build').mkdir()
    out = OUT / case['id']; out.mkdir(parents=True)
    try:
        for change in case.get('root_changes', []):
            apply(change, root)
        for change in case['changes']:
            apply(change, candidate)
    except (AssertionError, OSError, ValueError) as error:
        # The frozen case cannot be built as written (for example a missing edit anchor).
        # It is recorded as a harness error, never as a gate outcome.
        record = {'id': case['id'], 'expected_exit': case['expected_exit'], 'expected_outcome': case['expected_outcome'],
                  'status': 'harness_error', 'error': str(error)[:300], 'pass_ok': False, 'warm_same_decision': True,
                  'warm_reused': [], 'cold': {'exit': None, 'outcome': None, 'reason_prefix': None, 'affected': None,
                  'obligations': {}, 'findings': [], 'evidence_written': False, 'wall_seconds': 0.0, 'cpu_seconds': 0.0},
                  'warm': {'exit': None, 'outcome': None, 'reason_prefix': None, 'affected': None, 'obligations': {},
                  'findings': [], 'evidence_written': False, 'wall_seconds': 0.0, 'cpu_seconds': 0.0}}
        records.append(record)
        (out / 'record.json').write_text(json.dumps(record, indent=1, sort_keys=True) + '\n')
        print('HARNESS_ERROR', case['id'], str(error)[:120], flush=True)
        shutil.rmtree(work, ignore_errors=True)
        continue
    runs = {}
    for label in ('cold', 'warm'):
        child, op, wall, cpu = gate(root, candidate, label, work)
        cv = op.get('coverage') or {}
        stderr = child.stderr.decode(errors='replace')
        reason = next((l.split(':')[0] for l in stderr.splitlines() if l[:1].isupper() and ':' in l), None)
        obligations = {n: {'result': r.get('result'), 'reused': r.get('reused'), 'wall_seconds': r.get('wall_seconds'), 'reason': (r.get('reason') or '')[:120]}
                       for n, r in (op.get('obligations') or {}).items()}
        runs[label] = {'exit': child.returncode, 'outcome': op.get('outcome'), 'reason_prefix': reason,
                       'affected': op.get('affected_obligations'), 'obligations': obligations,
                       'findings': sorted(f['reason'] + ' ' + f['path'] for f in cv.get('findings', [])),
                       'evidence_written': (root / 'build' / (label + '.json')).is_file(),
                       'wall_seconds': round(wall, 3), 'cpu_seconds': round(cpu, 3),
                       'stderr_first_line': (stderr.strip().splitlines() or [''])[0][:300]}
        (out / (label + '-stderr.txt')).write_bytes(child.stderr)
        if op:
            (out / (label + '-operation.json')).write_text(json.dumps(op, indent=1, sort_keys=True) + '\n')
    cold = runs['cold']
    ok = (cold['exit'] == case['expected_exit'] and cold['outcome'] == case['expected_outcome']
          and cold['evidence_written'] == (case['expected_exit'] == 0)
          and ('expected_findings' not in case or set(case['expected_findings']) <= set(cold['findings']))
          and ('expected_reason_prefix' not in case or cold['reason_prefix'] == case['expected_reason_prefix'])
          and ('expected_affected' not in case or sorted(case['expected_affected']) == sorted(cold['affected'] or [])))
    same = all(runs['warm'][k] == cold[k] for k in ('exit', 'outcome', 'reason_prefix', 'findings', 'affected'))
    record = {'id': case['id'], 'expected_exit': case['expected_exit'], 'expected_outcome': case['expected_outcome'],
              'cold': cold, 'warm': runs['warm'], 'pass_ok': ok, 'warm_same_decision': same,
              'warm_reused': sorted(n for n, r in runs['warm']['obligations'].items() if r.get('reused'))}
    records.append(record)
    (out / 'record.json').write_text(json.dumps(record, indent=1, sort_keys=True) + '\n')
    print('PASS' if ok else 'FAIL', case['id'], 'cold', cold['exit'], cold['outcome'], cold['reason_prefix'], cold['affected'],
          round(cold['wall_seconds'], 1), '| warm', runs['warm']['exit'], runs['warm']['outcome'], round(runs['warm']['wall_seconds'], 1),
          'reused', record['warm_reused'], '| same' if same else '| DIFFERS', flush=True)
    shutil.rmtree(work, ignore_errors=True)
(OUT / 'records.json').write_text(json.dumps({'cases_sha256': APPROVED, 'records': records, 'end_to_end': False}, indent=1) + '\n')
bad = [r for r in records if not r['pass_ok']]
print('records', len(records), 'not passing', len(bad), 'warm differs', sum(not r['warm_same_decision'] for r in records))
sys.exit(1 if bad else 0)
