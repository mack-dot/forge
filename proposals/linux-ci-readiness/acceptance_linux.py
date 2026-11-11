"""Acceptance harness for real, trusted Linux gates; not an alternative verifier.

Run only in a fresh, owner-authorized Linux checkout with the approved toolchain.
Fixtures are local test inputs, not GitHub PRs or authoritative release receipts.
No network, merge, signing, cache injection, deletion, or policy change is done.
"""
import argparse
import hashlib
import io
import json
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import sys
import tarfile
import time


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write(path, value):
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + '\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--trusted', type=Path, required=True)
    parser.add_argument('--expected-commit', required=True)
    parser.add_argument('--suite', choices=['node', 'ledger-source', 'booking-abc'], required=True)
    parser.add_argument('--out', type=Path, required=True, help='Fresh directory under trusted/build')
    args = parser.parse_args()
    require(platform.system() == 'Linux' and platform.machine() == 'x86_64', 'Requires actual Linux/x86_64')
    require(re.fullmatch('[0-9a-f]{40}', args.expected_commit), 'Exact trusted commit required')
    root = args.trusted.resolve()
    out = args.out.resolve()
    require(out.is_relative_to(root / 'build') and out != root / 'build', 'Output must be below trusted/build')
    require(not out.exists(), 'Output exists; preserve it and use a fresh checkout/output')

    def git(*argv):
        return subprocess.check_output(['git', '-c', 'core.hooksPath=/dev/null', '-C', str(root), *argv])

    require(git('rev-parse', 'HEAD').decode().strip() == args.expected_commit, 'Trusted commit differs')
    require(not git('diff', 'HEAD', '--'), 'Trusted tracked files differ')
    pins = json.loads((root / 'toolchain/linux-pins.json').read_text())
    require(platform.python_version() == pins['python']['version'], 'Use pinned Python')
    require(sha(Path(sys.executable)) == pins['python']['executable_sha256'], 'Python executable differs')
    out.mkdir(parents=True)
    commands = []
    environment = {k: v for k, v in os.environ.items() if k in
                   ('PATH', 'HOME', 'TMPDIR', 'LANG', 'LC_ALL', 'LD_LIBRARY_PATH', 'DOTNET_ROOT')}
    environment.update(PYTHONDONTWRITEBYTECODE='1', PYTHONNOUSERSITE='1')
    environment['PATH'] = str(Path(sys.executable).parent) + os.pathsep + environment.get('PATH', os.defpath)
    identity = {'commit': args.expected_commit, 'tree': git('rev-parse', 'HEAD^{tree}').decode().strip(),
                'system': platform.platform(), 'python_version': platform.python_version(),
                'python_sha256': sha(Path(sys.executable)), 'linux_pins_sha256': sha(root / 'toolchain/linux-pins.json'),
                'validator_pins_sha256': sha(root / 'toolchain/validator-linux-pins.json'),
                'javascript_pins_sha256': sha(root / 'toolchain/javascript-linux-pins.json'),
                'implementation_lock_sha256': sha(root / 'gate/provenance/implementation.lock'),
                'harness_sha256': sha(Path(__file__)), 'suite': args.suite,
                'github_run_id': os.environ.get('GITHUB_RUN_ID'),
                'runner_image_version': os.environ.get('ImageVersion'),
                'os_release': Path('/etc/os-release').read_text()}
    for name, path in [('dafny', root / '.toolchain/dafny-4.11.0/dafny/dafny'),
                       ('z3', root / pins['z3']['path'])]:
        identity[name + '_sha256'] = sha(path)
    write(out / 'environment.json', identity)

    def run(label, argv, expected):
        start = time.perf_counter_ns()
        with (out / (label + '.log')).open('wb') as log:
            child = subprocess.run(argv, cwd=root, env=environment, stdout=log, stderr=subprocess.STDOUT)
        row = {'label': label, 'argv': argv, 'cwd': str(root), 'exit_code': child.returncode,
               'wall_seconds': (time.perf_counter_ns() - start) / 1e9,
               'log_sha256': sha(out / (label + '.log'))}
        commands.append(row)
        write(out / 'commands.json', commands)
        require(child.returncode == expected, label + ': unexpected exit ' + str(child.returncode))
        return row

    prefix = [sys.executable]
    relative = out.relative_to(root).as_posix()
    try:
        if args.suite in ('node', 'booking-abc'):
            run('node-pins', prefix + ['scripts/javascript_env.py'], 0)
        if args.suite == 'node':
            # A tampered copy must be rejected by the existing hash check before execution.
            real_node = shutil.which('node', path=environment['PATH'])
            require(real_node is not None, 'Node missing after successful pin check')
            bad_directory = out / 'tampered-node'
            bad_directory.mkdir()
            bad_node = bad_directory / 'node'
            bad_node.write_bytes(Path(real_node).read_bytes() + b'\x00')
            bad_node.chmod(0o700)
            previous_path = environment['PATH']
            environment['PATH'] = str(bad_directory) + os.pathsep + previous_path
            try:
                run('node-tampered', prefix + ['scripts/javascript_env.py'], 1)
            finally:
                environment['PATH'] = previous_path
            require('Node executable differs from pin' in (out / 'node-tampered.log').read_text(),
                    'Wrong Node tampering refusal')
        elif args.suite == 'ledger-source':
            for n in ('1', '2'):
                run('ledger-' + n, prefix + ['gate/gate.py', '--backend', 'dafny', '--impl',
                    'impl/Ledger.dfy', '--tier', 'critical', '--evidence', relative + '/ledger-' + n + '.json'], 0)
            require((out / 'ledger-1.json').read_bytes() == (out / 'ledger-2.json').read_bytes(), 'Evidence differs')
            bundle = json.loads((out / 'ledger-1.json').read_text())
            require(bundle['end_to_end'] is False, 'Overclaim')
            require({x['claim_id'] for x in bundle['evidence']} == {'C1','C2','C3','C4','C5'}, 'Claim set differs')
            require(all(x['result'] == 'passed' and x['method'] == 'source_proof' for x in bundle['evidence']), 'Methods differ')
            require('toolchain/linux-pins.json' in bundle['trusted_input_sha256'] and
                    'toolchain/pins.json' not in bundle['trusted_input_sha256'], 'Wrong evidence profile')
            run('ledger-defect', prefix + ['gate/gate.py', '--backend', 'dafny', '--impl',
                'bugs/off_by_one.dfy', '--tier', 'critical', '--evidence', relative + '/defect.json'], 1)
            require(not (out / 'defect.json').exists(), 'Rejected fixture emitted evidence')
            require('VERIFICATION_REJECTED' in (out / 'ledger-defect.log').read_text(), 'Wrong rejection cause')
        else:
            cache = root / 'build/obligation-cache'
            require(not cache.exists(), 'Cold suite requires fresh checkout; do not delete existing evidence/cache')
            archive = git('archive', '--format=tar', 'HEAD')

            def candidate(name, mutate):
                target = out / name
                target.mkdir()
                with tarfile.open(fileobj=io.BytesIO(archive)) as stream:
                    for member in stream.getmembers():
                        parts = Path(member.name)
                        require(not parts.is_absolute() and '..' not in parts.parts and
                                (member.isfile() or member.isdir()), 'Unexpected archive entry')
                    stream.extractall(target)
                booking = target / 'impl/Booking.dfy'
                old = '      if other < value {\n        value := other;\n      }'
                require(booking.read_text().count(old) == 1, 'Booking fixture anchor drift')
                booking.write_text(booking.read_text().replace(old, old.replace('other < value', 'other <= value')))
                if mutate:
                    ledger = target / 'impl/Ledger.dfy'
                    source = ledger.read_text()
                    require(source.count('debit') == 6, 'Ledger fixture anchor drift')
                    ledger.write_text(source.replace('debit', 'remaining'))
                manifest = {p.relative_to(target).as_posix(): sha(p) for p in sorted(target.rglob('*')) if p.is_file()}
                write(out / (name + '-inputs.json'), manifest)
                return target

            a = candidate('candidate-a', False)
            b = candidate('candidate-b', True)

            def check(label, target, expected):
                row = run(label, prefix + ['gate/incremental.py', '--profile', 'linux', '--candidate',
                    str(target), '--evidence', relative + '/' + label + '.json', '--work',
                    relative + '/' + label + '-work'], expected)
                op = json.loads((out / (label + '-work/operation.json')).read_text())
                require(op['exit_code'] == row['exit_code'], 'Gate/receipt exit mismatch')
                if expected == 0:
                    require(op['outcome'] == 'VERIFIED' and op['coverage']['covered'] is True and
                            op['coverage']['findings'] == [], 'Missing coverage')
                    require(op['affected_obligations'] == ['ledger-proof', 'booking'], 'Affected set differs')
                else:
                    require(not (out / (label + '.json')).exists(), 'Failed gate emitted evidence')
                return op

            cold = check('A-cold', a, 0)
            ac = cold['obligations']['booking']
            require(ac['result'] == 'established' and ac['reused'] is False and ac['commands'], 'A did not run booking')
            require(all(x['exit_code'] == 0 for x in ac['commands']), 'A checker failed')
            cache_path = cache / (ac['cache_key'] + '.json')
            before_cache = sha(cache_path)
            warm = check('C-warm', a, 0)
            wc = warm['obligations']['booking']
            require(wc['result'] == 'established' and wc['reused'] is True and
                    wc['cache_key'] == ac['cache_key'] and wc['evidence_sha256'] == ac['evidence_sha256'], 'C reuse differs')
            require(sha(cache_path) == before_cache, 'C replaced the trusted receipt')
            require(not (out / 'C-warm-work/obligations/booking-0.log').exists(), 'C executed booking')
            require((out / 'A-cold.json').read_bytes() == (out / 'C-warm.json').read_bytes(), 'Warm evidence differs')
            # At PR #30, changed ledger + macOS committed evidence must refuse overall.
            invalidated = check('B-invalidated', b, 2)
            bc = invalidated['obligations']['booking']
            require(bc['reused'] is False and bc['cache_key'] != ac['cache_key'] and bc['commands'], 'B reused stale booking')
            require(bc['result'] == 'established' and all(x['exit_code'] == 0 for x in bc['commands']), 'B booking proof failed')
            require('EVIDENCE_PROFILE' in invalidated['obligations']['ledger-evidence']['reason'], 'Wrong B refusal')
            require(sha(cache_path) == before_cache, 'B overwrote old receipt')
            write(out / 'reuse-observations.json', {'cold_key': ac['cache_key'], 'warm_key': wc['cache_key'],
                'changed_key': bc['cache_key'], 'prior_receipt_sha256': before_cache,
                'booking_executions': {'A': 1, 'C': 0, 'B': 1}, 'booking_reuses': {'A': 0, 'C': 1, 'B': 0},
                'invalidated_receipts_not_reused': 1, 'cross_run_reuse_established': False,
                'full_ledger_incremental_acceptance': False})
            uncovered = candidate('candidate-uncovered', False)
            (uncovered / 'impl/Extra.dfy').write_text('module Extra {}\n')
            write(out / 'candidate-uncovered-inputs.json', {
                p.relative_to(uncovered).as_posix(): sha(p)
                for p in sorted(uncovered.rglob('*')) if p.is_file()})
            refused = check('uncovered', uncovered, 3)
            require(refused['outcome'] == 'UNSUPPORTED' and refused['coverage']['covered'] is False,
                    'Uncovered code was not refused')
            require(any(x['reason'] == 'UNCOVERED_CHANGE' and x['path'] == 'impl/Extra.dfy'
                        for x in refused['coverage']['findings']), 'Wrong coverage refusal')
        require(not git('diff', 'HEAD', '--'), 'Trusted files changed')
        write(out / 'result.json', {'test_expectations_met': True, 'end_to_end': False,
            'genuine_github_pr_demonstration': False, 'suite': args.suite,
            'note': 'B intentionally expects safe refusal until per-profile committed evidence is approved.'})
    except Exception as error:
        write(out / 'result.json', {'test_expectations_met': False, 'error': str(error), 'end_to_end': False})
        raise


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        print(type(error).__name__ + ': ' + str(error), file=sys.stderr)
        sys.exit(1)
