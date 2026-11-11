"""Exercise actual gates and cache adoption. No mocked proof results.

Run on the prepared checkout with the existing pinned local toolchain. This
records local executions only. The same-process authority is deliberately not
restored by the cross-process test. All original and hostile records are kept.
"""
import argparse
import contextlib
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys
import time


def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + '\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', required=True, type=Path)
    parser.add_argument('--out', required=True, type=Path)
    parser.add_argument('--cross-process', action='store_true')
    args = parser.parse_args()
    root, out = args.root.resolve(), args.out.resolve()
    sys.path.insert(0, str(root / 'gate'))
    sys.dont_write_bytecode = True
    import incremental
    import obligations
    import coverage
    from common import Rejected, canonical, digest
    assert incremental.ROOT == root
    cache = root / 'build/security-cache'
    rows = []

    def run(label, candidate, expected, reason=None, hit=None):
        work = root / 'build' / ('regression-' + label)
        evidence = root / 'build' / (label + '.json')
        work.mkdir(parents=True, exist_ok=False)
        operation = {'commands': [], 'end_to_end': False, 'stage_exit': False}
        start = time.perf_counter_ns()
        with (out / (label + '.log')).open('w') as log, contextlib.redirect_stdout(log), contextlib.redirect_stderr(log):
            try:
                incremental.check(candidate, evidence, work, operation, incremental.host_profile(), cache=cache)
                code = 0
            except Rejected as error:
                code = 1
                operation.update(outcome='REJECTED', error=str(error))
            except coverage.Unsupported as error:
                code = 3
                operation.update(outcome='UNSUPPORTED', error=str(error))
            except Exception as error:
                code = 2
                operation.update(outcome='NOT_ESTABLISHED', error=type(error).__name__ + ': ' + str(error))
        operation['exit_code'] = code
        write(work / 'operation.json', operation)
        row = {'scenario': label, 'expected_exit': expected, 'actual_exit': code,
               'wall_seconds': (time.perf_counter_ns() - start) / 1e9,
               'candidate_commit': None, 'candidate_kind': 'local uncommitted fixture',
               'candidate_source_identity': digest(canonical(coverage.inventory(candidate, ('.git',), True)[1])),
               'candidate_booking_sha256': digest((candidate / 'impl/Booking.dfy').read_bytes()),
               'cache_hit': operation.get('obligations', {}).get('booking', {}).get('reused'),
               'fresh_booking_gate_log': (work / 'obligations/booking-0.log').is_file(),
               'expensive_booking_verification_executed': (work / 'verify/build/obligations/booking-work/verify.log').is_file(),
               'summed_github_runner_minutes': None, 'billed_runner_minutes': None,
               'hosted_execution': False, 'operation': operation,
               'evidence_sha256': digest(evidence.read_bytes()) if evidence.exists() else None}
        assertions = [code == expected, (code == 0) == evidence.exists()]
        if reason:
            assertions.append(reason in operation.get('error', ''))
        if hit is not None:
            assertions.extend([row['cache_hit'] is hit,
                               row['expensive_booking_verification_executed'] is (not hit)])
        if code == 0:
            assertions.extend([operation['coverage']['covered'] is True,
                               operation['coverage']['findings'] == [],
                               operation['affected_obligations'] == ['ledger-proof', 'booking']])
        row['acceptance_passed'] = all(assertions)
        rows.append(row)
        write(out / (label + '.json'), row)
        write(out / 'results.json', rows)
        print(label + ': actual=' + str(code) + ' expected=' + str(expected) + ' assertions=' + str(row['acceptance_passed']), flush=True)
        if not row['acceptance_passed']:
            raise RuntimeError('Acceptance failed: ' + label)
        return row

    if args.cross_process:
        out.mkdir(parents=True, exist_ok=False)
        run('cross-process', root.parent / 'forge-receipt-auth-fixtures-20261102/A', 1, 'CACHE_UNAUTHENTICATED')
        return 0

    out.mkdir(parents=True, exist_ok=False)
    fixtures = root.parent / 'forge-receipt-auth-fixtures-20261102'
    fixtures.mkdir(exist_ok=False)
    candidate = fixtures / 'A'
    shutil.copytree(root, candidate, ignore=shutil.ignore_patterns('build', '.toolchain', 'node_modules'))
    path = candidate / 'impl/Booking.dfy'
    assert path.read_text().count('other < value') == 1
    path.write_text(path.read_text().replace('other < value', 'other <= value'))
    (root / '.toolchain').symlink_to('/Users/mackianni/forge/.toolchain', target_is_directory=True)
    write(out / 'environment.json', {
        'source_commit': '561d2dda904daf18f17a0fede93f28b502d72884',
        'patch_sha256': hashlib.sha256(Path(__file__).with_name('repair.patch').read_bytes()).hexdigest(),
        'implementation_lock_sha256': digest((root / 'gate/provenance/implementation.lock').read_bytes()),
        'host': platform.platform(), 'python_version': platform.python_version(),
        'python_sha256': digest(Path(sys.executable).read_bytes()),
        'hosted_execution': False})

    a = run('A-cold', candidate, 0, hit=False)
    receipt = a['operation']['obligations']['booking']
    cached = cache / (receipt['cache_key'] + '.json')
    original = cached.read_bytes()
    (out / 'original-receipt.json').write_bytes(original)
    b = run('B-warm', candidate, 0, hit=True)
    assert b['evidence_sha256'] == a['evidence_sha256']
    assert b['operation']['obligations']['booking']['evidence_sha256'] == receipt['evidence_sha256']

    # Exactly the original attack: keep key and established; corrupt substantive digests.
    forged = json.loads(original)
    forged['evidence_sha256'], forged['artifact_sha256'] = '0' * 64, '1' * 64
    assert forged['cache_key'] == receipt['cache_key'] and forged['result'] == 'established'
    (out / 'corrupted-receipt.json').write_bytes(canonical(forged))
    cached.write_bytes(canonical(forged))
    try:
        run('D-receipt', candidate, 1, 'CACHE_RECEIPT_INTEGRITY')
    finally:
        cached.write_bytes(original)

    artifact = root / 'build/regression-A-cold/verify/build/obligations/booking.json'
    good_artifact = artifact.read_bytes()
    changed_artifact = json.loads(good_artifact)
    changed_artifact['artifact']['sha256'] = '2' * 64
    (out / 'substituted-artifact.json').write_bytes(canonical(changed_artifact))
    artifact.write_bytes(canonical(changed_artifact))
    try:
        run('D-artifact', candidate, 1, 'CACHE_ARTIFACT_INTEGRITY')
        forged = json.loads(original)
        forged['evidence_sha256'] = digest(canonical(changed_artifact))
        forged['artifact_sha256'] = changed_artifact['artifact']['sha256']
        cached.write_bytes(canonical(forged))
        (out / 'coherent-forged-receipt.json').write_bytes(canonical(forged))
        run('D-coherent-rewrite', candidate, 1, 'CACHE_RECEIPT_INTEGRITY')
    finally:
        artifact.write_bytes(good_artifact)
        cached.write_bytes(original)

    # A changed input computes a different obligation identity and runs real Dafny.
    changed = fixtures / 'C'
    shutil.copytree(candidate, changed)
    changed_path = changed / 'impl/Booking.dfy'
    changed_path.write_text(changed_path.read_text().replace('other <= value', '!(other > value)'))
    c = run('C-invalidation', changed, 0, hit=False)
    changed_receipt = c['operation']['obligations']['booking']
    assert changed_receipt['cache_key'] != receipt['cache_key']
    stale_path = cache / (changed_receipt['cache_key'] + '.json')
    original_c = stale_path.read_bytes()
    forged = json.loads(original)
    forged['cache_key'] = changed_receipt['cache_key']
    (out / 'stale-identity-receipt.json').write_bytes(canonical(forged))
    stale_path.write_bytes(canonical(forged))
    try:
        run('D-stale-identity', changed, 1, 'CACHE_RECEIPT_INTEGRITY')
    finally:
        stale_path.write_bytes(original_c)

    uncovered = fixtures / 'uncovered'
    shutil.copytree(candidate, uncovered)
    (uncovered / 'impl/Extra.dfy').write_text('// Deliberately outside the approved obligation registry.\n')
    run('D-uncovered', uncovered, 3, 'UNSUPPORTED')
    harness = fixtures / 'harness'
    shutil.copytree(candidate, harness)
    p = harness / 'gate/booking.py'
    p.write_text(p.read_text() + '\n# Deliberately changed protected harness.\n')
    run('D-harness', harness, 1, 'UNAPPROVED_PROTECTED_CHANGE')

    argv = [sys.executable, '-B', str(Path(__file__).resolve()), '--root', str(root),
            '--out', str(out / 'cross-process'), '--cross-process']
    with (out / 'cross-process.log').open('wb') as log:
        child = subprocess.run(argv, stdout=log, stderr=subprocess.STDOUT)
    write(out / 'cross-process-command.json', {'argv': argv, 'exit_code': child.returncode})
    assert child.returncode == 0
    run('B-restored-valid', candidate, 0, hit=True)
    write(out / 'summary.json', {'local_security_acceptance': True, 'main_process_cases': len(rows),
          'cross_process_rejection': True, 'cross_run_reuse_enabled': False,
          'hosted_execution': False, 'performance_improvement_claimed': False})
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
