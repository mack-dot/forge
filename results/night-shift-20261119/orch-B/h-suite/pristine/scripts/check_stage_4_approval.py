#!/usr/bin/env python3
"""Exercise exact approval against a v1 trusted baseline using real Dafny runs.

Every tree is a complete copy of this checkout (minus untracked trees). Under the
incremental gate, the approved fee-spec change is UNSUPPORTED (exit 3): every affected
obligation is re-established (the candidate carries the matching evidence.json and
booking lock), but the negative fixtures in bugs/ and the proposal copy in proposals/ include
the spec and no obligation depends on them (UNKNOWN_DEPENDENCY). The approval path is still exercised: the
operation record must name the bound approval and the snapshot proof must have run. Results go
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
        # The baseline is the trusted base for the gate: it needs the pinned toolchain and the
        # pinned JavaScript packages that dependent obligations (ledger-model) read.
        for name in ('.toolchain', 'node_modules'):
            if (ROOT / name).exists():
                (destination / name).symlink_to((ROOT / name).resolve(), target_is_directory=True)


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
            if name in ('approved', 'approved-repeat'):
                assert operation['outcome'] == 'UNSUPPORTED'
                assert operation['spec_approval']['record'] == 'gate/approvals/fees-v2.json'
                assert 'Ledger.Apply (correctness)' in operation['snapshots'][1]['checked']
                assert all(r['result'] == 'established' for r in operation['obligations'].values())
                findings = operation['coverage']['findings']
                assert findings and all(f['reason'] == 'UNKNOWN_DEPENDENCY' and f['path'] == 'spec/LedgerSpec.dfy'
                                        and ('bugs/' in f['detail'] or 'proposals/' in f['detail']) for f in findings)
            else:
                assert operation['outcome'] == 'REJECTED'
                assert operation['error'].startswith('UNAPPROVED_PROTECTED_CHANGE:')
        first, second = (report['cases'][i]['operation'] for i in (0, 1))
        assert (first['outcome'], first['error'][:40], first['affected_obligations']) == \
            (second['outcome'], second['error'][:40], second['affected_obligations'])
        report.update(result='passed', exit_code=0, identical_decisions=True)
    except (AssertionError, OSError, ValueError, KeyError) as error:
        report.update(result='failed', exit_code=1, error=str(error))
        print(str(error), file=sys.stderr)
    REPORT.parent.mkdir(parents=True, exist_ok=True)
    REPORT.write_bytes(canonical(report))
    return report['exit_code']


if __name__ == '__main__':
    sys.exit(main())
