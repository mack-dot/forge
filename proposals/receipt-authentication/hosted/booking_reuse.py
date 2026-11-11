"""Exercise actual gates and cache adoption. No mocked proof results.

Run only from the approved main workflow on GitHub-hosted Linux. The same-process authority is deliberately not
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



def git(directory, *args):
    return subprocess.check_output(['git', '-c', 'core.hooksPath=/dev/null', '-c', 'core.fsmonitor=false',
                                    '-C', str(directory), *args])


def copy_fixture(candidate, destination):
    # Candidate checkout is input data. Never carry its .git or cached toolchain.
    shutil.copytree(candidate, destination, ignore=shutil.ignore_patterns('.git', 'build', '.toolchain', 'node_modules'))


def commit_fixture(directory):
    git(directory, 'init', '-q')
    git(directory, 'add', '--force', '--all')
    env = dict(os.environ, GIT_AUTHOR_NAME='Forge experiment fixture', GIT_AUTHOR_EMAIL='fixture@invalid',
               GIT_COMMITTER_NAME='Forge experiment fixture', GIT_COMMITTER_EMAIL='fixture@invalid',
               GIT_AUTHOR_DATE='2000-01-01T00:00:00Z', GIT_COMMITTER_DATE='2000-01-01T00:00:00Z')
    subprocess.run(['git', '-c', 'core.hooksPath=/dev/null', '-C', str(directory), 'commit',
                    '--no-gpg-sign', '-qm', 'Unpublished booking acceptance fixture'], env=env, check=True)


def preflight():
    import re
    import urllib.request
    if (os.environ.get('GITHUB_REPOSITORY') != 'mack-dot/forge'
            or os.environ.get('GITHUB_REF') != 'refs/heads/main'
            or os.environ.get('GITHUB_EVENT_NAME') != 'workflow_dispatch'):
        raise RuntimeError('Wrong repository, ref, or trigger')
    number, head = os.environ['BOOKING_PR'], os.environ['BOOKING_HEAD']
    if not re.fullmatch('[1-9][0-9]*', number) or not re.fullmatch('[0-9a-f]{40}', head):
        raise RuntimeError('Exact PR number and head required')
    def get(suffix):
        request = urllib.request.Request('https://api.github.com/repos/mack-dot/forge' + suffix,
            headers={'Accept': 'application/vnd.github+json', 'Authorization': 'Bearer ' + os.environ['GH_TOKEN'],
                     'User-Agent': 'forge-booking-experiment'})
        with urllib.request.urlopen(request) as response:
            if response.status != 200:
                raise RuntimeError('GitHub read failed')
            return json.load(response)
    pr = get('/pulls/' + number)
    if not (pr['state'] == 'open' and pr['head']['sha'] == head
            and pr['base']['sha'] == os.environ['GITHUB_SHA'] and pr['base']['ref'] == 'main'
            and pr['base']['repo']['id'] == 1434789853 and pr['head']['repo']['id'] == 1434789853
            and pr['changed_files'] == 1):
        raise RuntimeError('PR identity or approved experiment scope differs')
    changes = get('/pulls/' + number + '/files?per_page=100')
    if len(changes) != 1 or changes[0]['filename'] != 'impl/Booking.dfy' or changes[0]['status'] != 'modified':
        raise RuntimeError('Only the real booking implementation change is in scope')
    # Metadata is an observation, not an approval token or a reusable proof receipt.
    Path('build').mkdir(exist_ok=True)
    write(Path('build/booking-preflight.json'), {'pr': pr['number'], 'head': head,
          'base': pr['base']['sha'], 'changed_files': changes, 'run_id': os.environ['GITHUB_RUN_ID']})


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', required=True, type=Path)
    parser.add_argument('--out', required=True, type=Path)
    parser.add_argument('--cross-process', action='store_true')
    parser.add_argument('--candidate', type=Path, required=True)
    parser.add_argument('--preflight', action='store_true')
    args = parser.parse_args()
    root, out = args.root.resolve(), args.out.resolve()
    candidate = args.candidate.resolve()
    if args.preflight:
        preflight()
        return 0
    if not (os.environ.get('GITHUB_ACTIONS') == 'true' and os.environ.get('RUNNER_ENVIRONMENT') == 'github-hosted' and platform.system() == 'Linux'
            and platform.machine() == 'x86_64' and os.environ.get('GITHUB_REF') == 'refs/heads/main'):
        raise RuntimeError('Requires an authorized GitHub-hosted Linux/main dispatch')
    if os.environ.get('GITHUB_EVENT_NAME') != 'workflow_dispatch':
        raise RuntimeError('Unexpected trigger')
    for directory, expected in ((root, os.environ['GITHUB_SHA']), (candidate, os.environ['BOOKING_HEAD'])):
        if git(directory, 'rev-parse', 'HEAD').strip().decode() != expected:
            raise RuntimeError('Exact checkout identity differs')
        if git(directory, 'diff', '--name-only', 'HEAD', '--'):
            raise RuntimeError('Tracked checkout differs')
    if not args.cross_process:
        # The only cold-case change is the real PR implementation alternative.
        original = (root / 'impl/Booking.dfy').read_text()
        if original.count('other < value') != 1 or (candidate / 'impl/Booking.dfy').read_text() != original.replace('other < value', 'other <= value'):
            raise RuntimeError('Booking PR differs from the approved experiment fixture')
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
               'candidate_commit': git(candidate, 'rev-parse', 'HEAD').decode().strip(),
               'candidate_kind': 'GitHub PR head' if candidate == args.candidate.resolve() else 'unpublished hosted fixture commit',
               'candidate_source_identity': digest(canonical(coverage.inventory(candidate, ('.git',), True)[1])),
               'candidate_booking_sha256': digest((candidate / 'impl/Booking.dfy').read_bytes()),
               'cache_hit': operation.get('obligations', {}).get('booking', {}).get('reused'),
               'fresh_booking_gate_log': (work / 'obligations/booking-0.log').is_file(),
               'expensive_booking_verification_executed': (work / 'verify/build/obligations/booking-work/verify.log').is_file(),
               'summed_github_runner_minutes': None, 'billed_runner_minutes': None,
               'hosted_execution': True, 'operation': operation,
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
        run('cross-process', candidate, 1, 'CACHE_UNAUTHENTICATED')
        return 0

    out.mkdir(parents=True, exist_ok=False)
    fixtures = root / 'build/booking-fixtures'
    fixtures.mkdir(exist_ok=False)
    write(out / 'environment.json', {
        'trusted_commit': os.environ['GITHUB_SHA'], 'pr_head': os.environ['BOOKING_HEAD'],
        'run_id': os.environ['GITHUB_RUN_ID'], 'run_attempt': os.environ['GITHUB_RUN_ATTEMPT'],
        'workflow_ref': os.environ['GITHUB_WORKFLOW_REF'],
        'implementation_lock_sha256': digest((root / 'gate/provenance/implementation.lock').read_bytes()),
        'harness_sha256': digest(Path(__file__).read_bytes()),
        'host': platform.platform(), 'python_version': platform.python_version(),
        'python_sha256': digest(Path(sys.executable).read_bytes()),
        'image_version': os.environ.get('ImageVersion'),
        'runner_environment': os.environ['RUNNER_ENVIRONMENT'],
        'runner_os': os.environ.get('RUNNER_OS'), 'runner_arch': os.environ.get('RUNNER_ARCH'),
        'hosted_execution': True})

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
    copy_fixture(candidate, changed)
    changed_path = changed / 'impl/Booking.dfy'
    changed_path.write_text(changed_path.read_text().replace('other <= value', '!(other > value)'))
    commit_fixture(changed)
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
    copy_fixture(candidate, uncovered)
    (uncovered / 'impl/Extra.dfy').write_text('// Deliberately outside the approved obligation registry.\n')
    commit_fixture(uncovered)
    run('D-uncovered', uncovered, 3, 'UNSUPPORTED')
    harness = fixtures / 'harness'
    copy_fixture(candidate, harness)
    p = harness / 'gate/booking.py'
    p.write_text(p.read_text() + '\n# Deliberately changed protected harness.\n')
    commit_fixture(harness)
    run('D-harness', harness, 1, 'UNAPPROVED_PROTECTED_CHANGE')

    argv = [sys.executable, '-B', str(Path(__file__).resolve()), '--root', str(root),
            '--out', str(out / 'cross-process'), '--candidate', str(candidate), '--cross-process']
    with (out / 'cross-process.log').open('wb') as log:
        child = subprocess.run(argv, stdout=log, stderr=subprocess.STDOUT)
    write(out / 'cross-process-command.json', {'argv': argv, 'exit_code': child.returncode})
    assert child.returncode == 0
    run('B-restored-valid', candidate, 0, hit=True)
    write(out / 'summary.json', {'hosted_security_acceptance': True, 'main_process_cases': len(rows),
          'cross_process_rejection': True, 'cross_run_reuse_enabled': False,
          'hosted_execution': True, 'performance_improvement_claimed': False})
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
