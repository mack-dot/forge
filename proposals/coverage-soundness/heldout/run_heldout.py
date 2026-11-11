"""Run the frozen held-out coverage cases against a candidate PR gate.

  python3 -I run_heldout.py CASES_JSON APPROVED_SHA256 PATCHED_PLAIN TOOLCHAIN OUTPUT WORK PASSES

PATCHED_PLAIN is a clean tree of the base commit with the candidate gate files applied
(no .git, no .toolchain, no build). Each case gets fresh APFS clones: a root (trusted
base; gets the toolchain) and a candidate (gets the case's edits). The runner only
prepares inputs and calls gate/incremental.py; it never interprets Dafny output.
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

CASES, APPROVED, PLAIN, TOOLCHAIN, OUT, WORK, PASSES = sys.argv[1:8]
CASES, PLAIN, TOOLCHAIN, OUT, WORK = Path(CASES), Path(PLAIN), Path(TOOLCHAIN), Path(OUT).resolve(), Path(WORK).expanduser().resolve()
raw = CASES.read_bytes()
assert hashlib.sha256(raw).hexdigest() == APPROVED, 'CASES_NOT_FROZEN'
spec = json.loads(raw)
OUT.mkdir(parents=True, exist_ok=False)
WORK.mkdir(parents=True, exist_ok=False)
SANDBOX = ['/usr/bin/sandbox-exec', '-p', '(version 1)(allow default)(deny network-outbound (remote ip "*:*"))(deny network-inbound (local ip "*:*"))']


def clone(src, dst):
    subprocess.run(['/bin/cp', '-cRp', str(src), str(dst)], check=True)


def apply(change, tree):
    path = tree / change.get('path', '')
    op = change['op']
    if op == 'append':
        path.write_text(path.read_text() + change['text'])
    elif op == 'write':
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(change['text'])
    elif op == 'replace':
        s = path.read_text()
        assert s.count(change['find']) == 1, ('anchor', change['path'])
        path.write_text(s.replace(change['find'], change['replace']))
    elif op == 'delete':
        path.unlink()
    elif op == 'chmod':
        path.chmod(int(change['mode'], 8))
    elif op == 'symlink':
        os.symlink(change['target'], path)
    elif op == 'relock_spec':
        lock = json.loads((tree / 'spec.lock').read_text())
        lock['spec_sha256'] = hashlib.sha256((tree / 'spec/LedgerSpec.dfy').read_bytes()).hexdigest()
        (tree / 'spec.lock').write_text(json.dumps(lock, sort_keys=True) + '\n')
    else:
        raise ValueError(op)


records = []
for number in range(1, int(PASSES) + 1):
    for case in spec['cases']:
        work = WORK / ('pass-%d' % number) / case['id'].replace('\n', '_')
        work.mkdir(parents=True)
        root, candidate = work / 'root', work / 'candidate'
        clone(PLAIN, root)
        clone(PLAIN, candidate)
        clone(TOOLCHAIN, root / '.toolchain')
        for change in case.get('root_changes', []):
            apply(change, root)
        for change in case['changes']:
            apply(change, candidate)
        (root / 'build').mkdir()
        argv = [sys.executable, 'gate/incremental.py', '--candidate', str(candidate),
                '--evidence', 'build/evidence.json', '--work', 'build/work']
        env = {'PATH': str(Path(sys.executable).parent) + ':/usr/bin:/bin', 'HOME': os.environ['HOME'], 'TMPDIR': str(work)}
        before = resource.getrusage(resource.RUSAGE_CHILDREN)
        start = time.perf_counter_ns()
        child = subprocess.run(SANDBOX + argv, cwd=root, env=env, capture_output=True, timeout=1800)
        wall = (time.perf_counter_ns() - start) / 1e9
        after = resource.getrusage(resource.RUSAGE_CHILDREN)
        operation = {}
        if (root / 'build/work/operation.json').is_file():
            operation = json.loads((root / 'build/work/operation.json').read_text())
        coverage = operation.get('coverage') or {}
        findings = sorted(f['reason'] + ' ' + f['path'] for f in coverage.get('findings', []))
        expected_findings = sorted(case.get('expected_findings', []))
        stderr = child.stderr.decode(errors='replace')
        reason = next((l.split(':')[0] for l in stderr.splitlines() if l[:1].isupper() and ':' in l), None)
        ok = (child.returncode == case['expected_exit'] and operation.get('outcome') == case['expected_outcome']
              and (root / 'build/evidence.json').is_file() == (case['expected_exit'] == 0)
              and ('expected_findings' not in case or set(expected_findings) <= set(findings))
              and ('expected_reason_prefix' not in case or reason == case['expected_reason_prefix']))
        if case['id'] == 'h15-valid-alternative-ledger-only':
            ok = ok and 'Ledger.Apply (correctness)' in operation.get('snapshots', [{}, {}])[1].get('checked', [])
        record = {'pass': number, 'id': case['id'], 'expected_exit': case['expected_exit'], 'exit': child.returncode,
                  'expected_outcome': case['expected_outcome'], 'outcome': operation.get('outcome'),
                  'reason_prefix': reason, 'expected_findings': expected_findings, 'findings': findings,
                  'changed': [c['path'] for c in coverage.get('changed', [])], 'inventory': coverage.get('inventory'),
                  'evidence_written': (root / 'build/evidence.json').is_file(), 'pass_ok': ok,
                  'wall_seconds': round(wall, 3),
                  'cpu_seconds': round(after.ru_utime - before.ru_utime + after.ru_stime - before.ru_stime, 3),
                  'stderr_first_line': (stderr.strip().splitlines() or [''])[0][:300]}
        records.append(record)
        out = OUT / ('pass-%d' % number) / case['id'].replace('\n', '_')
        out.mkdir(parents=True)
        (out / 'record.json').write_text(json.dumps(record, indent=1, sort_keys=True) + '\n')
        (out / 'stderr.txt').write_bytes(child.stderr)
        (out / 'stdout.txt').write_bytes(child.stdout)
        if operation:
            (out / 'operation.json').write_text(json.dumps(operation, indent=1, sort_keys=True) + '\n')
        print('PASS' if ok else 'FAIL', number, case['id'].replace('\n', '\\n'), 'exit', child.returncode,
              operation.get('outcome'), reason, findings[:3], round(wall, 1), flush=True)
        shutil.rmtree(work, ignore_errors=True)
(OUT / 'records.json').write_text(json.dumps({'cases_sha256': APPROVED, 'records': records, 'end_to_end': False}, indent=1) + '\n')
bad = [r for r in records if not r['pass_ok']]
print('records', len(records), 'not passing', len(bad))
sys.exit(1 if bad else 0)
