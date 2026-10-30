#!/usr/bin/env python3
"""Exercise exact approval against a v1 trusted baseline using real Dafny runs.

Every tree is a complete copy of this checkout (minus untracked trees). Under the
coverage-sound gate, an approved spec change is UNSUPPORTED (exit 3) rather than
accepted: the booking lock pins the ledger spec and impl/Booking.dfy includes
impl/Ledger.dfy, so their claims are not re-established by the ledger gate. The
approval path itself is still exercised: the operation record must name the bound
approval and list spec/LedgerSpec.dfy and spec.lock as established paths. Results go
to results/stage4/approval-coverage-v2.json; historical results are never rewritten.
"""

import json
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'gate'))
from common import canonical, digest

WORK = ROOT / 'build/stage4-approval'
REPORT = ROOT / 'results/stage4/approval-coverage-v2.json'
UNTRACKED = ('.git', '.toolchain', 'build', 'node_modules', 'TestResults')


def checkout(destination, toolchain):
    destination.mkdir(parents=True)
    for entry in sorted(ROOT.iterdir()):
        if entry.name in UNTRACKED or entry.name == '__pycache__':
            continue
        if sys.platform == 'darwin':
            subprocess.run(['/bin/cp', '-cRp', str(entry), str(destination / entry.name)], check=True)
        elif entry.is_dir() and not entry.is_symlink():
            shutil.copytree(entry, destination / entry.name, symlinks=True,
                            ignore=shutil.ignore_patterns('__pycache__', '*.pyc'))
        else:
            shutil.copy2(entry, destination / entry.name, follow_symlinks=False)
    for pycache in destination.rglob('__pycache__'):
        shutil.rmtree(pycache)
    if toolchain:
        (destination / '.toolchain').symlink_to(ROOT / '.toolchain', target_is_directory=True)


def main():
    if WORK.exists():
        raise RuntimeError('Preserve build/stage4-approval before rerunning')
    if REPORT.exists():
        raise RuntimeError('Preserve ' + str(REPORT.relative_to(ROOT)) + ' before rerunning')
    baseline = WORK / 'baseline'
    checkout(baseline, toolchain=True)
    for name in ('spec/LedgerSpec.dfy', 'spec.lock', 'impl/Ledger.dfy'):
        shutil.copyfile(ROOT / 'results/stage4/fee-baseline' / name, baseline / name)
    report = {'stage': 4, 'stage_exit': False, 'end_to_end': False, 'commands': [], 'cases': []}

    def run(command, cwd, name):
        child = subprocess.run(command, cwd=cwd, capture_output=True, text=True)
        log = WORK / (name + '.log')
        log.write_text(child.stdout + child.stderr)
        report['commands'].append({'command': command, 'cwd': str(cwd.relative_to(ROOT)),
                                   'exit_code': child.returncode, 'log': str(log.relative_to(ROOT))})
        print(name + ': exit ' + str(child.returncode), flush=True)
        return child

    try:
        for name, expected in [('approved', 3), ('approved-repeat', 3), ('changed-after-approval', 1),
                               ('weaken-c2', 1), ('candidate-approval-edit', 1), ('policy-edit', 1)]:
            candidate = WORK / name
            checkout(candidate, toolchain=False)
            if name in ('changed-after-approval', 'weaken-c2'):
                spec = candidate / 'spec/LedgerSpec.dfy'
                text = spec.read_text()
                text = (text + '\n// Not covered by the approved fee text.\n' if name == 'changed-after-approval'
                        else text.replace('    forall account | account in balances :: 0 <= balances[account]', '    true', 1))
                spec.write_text(text)
                lock = json.loads((candidate / 'spec.lock').read_text())
                lock['spec_sha256'] = digest(spec.read_bytes())
                (candidate / 'spec.lock').write_bytes(canonical(lock))
            if name == 'candidate-approval-edit':
                path = candidate / 'gate/approvals/fees-v2.json'
                path.write_text(path.read_text() + '\n')
            if name == 'policy-edit':
                path = candidate / 'policy/tiers.yaml'
                path.write_text(path.read_text() + '\n')
            command = ['python3', 'gate/incremental.py', '--candidate', str(candidate),
                       '--evidence', 'build/' + name + '.json', '--work', 'build/' + name]
            child = run(command, baseline, name)
            operation = json.loads((baseline / 'build' / name / 'operation.json').read_text())
            report['cases'].append({'name': name, 'operation': operation})
            assert child.returncode == expected, child.stdout + child.stderr
            evidence = baseline / 'build' / (name + '.json')
            assert not evidence.exists()
            if expected == 1:
                assert operation['outcome'] == 'REJECTED'
                assert operation['error'].startswith('UNAPPROVED_PROTECTED_CHANGE:')
            else:
                assert operation['outcome'] == 'UNSUPPORTED'
                assert operation['spec_approval']['record'] == 'gate/approvals/fees-v2.json'
                assert 'Ledger.Apply (correctness)' in operation['snapshots'][1]['checked']
                coverage = operation['coverage']
                assert sorted(coverage['established_paths']) == ['impl/Ledger.dfy', 'spec.lock', 'spec/LedgerSpec.dfy']
                assert [c['path'] for c in coverage['changed']] == ['impl/Ledger.dfy', 'spec.lock', 'spec/LedgerSpec.dfy']
                assert coverage['findings'] and all(f['reason'] == 'DEPENDENT_NOT_REESTABLISHED' for f in coverage['findings'])
                assert any('spec/booking/spec.lock' in f['detail'] for f in coverage['findings'])
        first = report['cases'][0]['operation']['coverage']
        assert first == report['cases'][1]['operation']['coverage']
        report.update(result='passed', exit_code=0, identical_coverage_records=True)
    except (AssertionError, OSError, ValueError, KeyError) as error:
        report.update(result='failed', exit_code=1, error=str(error))
        print(str(error), file=sys.stderr)
    REPORT.parent.mkdir(parents=True, exist_ok=True)
    REPORT.write_bytes(canonical(report))
    return report['exit_code']


if __name__ == '__main__':
    sys.exit(main())
