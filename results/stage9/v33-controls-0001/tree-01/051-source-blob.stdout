#!/usr/bin/env python3
"""Exercise exact approval against a v1 trusted baseline using real Dafny runs."""

import json
from pathlib import Path
import shlex
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'gate'))
from common import canonical, digest

WORK = ROOT / 'build/stage4-approval'


def checkout(destination):
    destination.mkdir(parents=True)
    for name in ('gate', 'policy', 'spec', 'toolchain', 'schemas', '.github', 'impl', 'proposals'):
        shutil.copytree(ROOT / name, destination / name,
                        ignore=shutil.ignore_patterns('__pycache__', '*.pyc'))
    for name in ('spec.lock', 'AGENTS.md'):
        shutil.copyfile(ROOT / name, destination / name)
    (destination / '.toolchain').symlink_to(ROOT / '.toolchain', target_is_directory=True)


def main():
    if WORK.exists():
        raise RuntimeError('Preserve build/stage4-approval before rerunning')
    baseline = WORK / 'baseline'
    checkout(baseline)
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
        for name, expected in [('approved', 0), ('approved-repeat', 0), ('changed-after-approval', 1),
                               ('weaken-c2', 1), ('candidate-approval-edit', 1), ('policy-edit', 1)]:
            candidate = WORK / name
            checkout(candidate)
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
            if expected:
                assert not evidence.exists() and operation['error'].startswith('UNAPPROVED_PROTECTED_CHANGE:')
            else:
                bundle = json.loads(evidence.read_text())
                assert {c['spec_sha'] for c in bundle['claims']} == {
                    '2ad0742dcbf81bf24f9235ed88f9728c7b078dfa6ed55632a90b6aa847b35940'}
                assert bundle['backend_details']['spec_approval']['record'] == 'gate/approvals/fees-v2.json'
                assert 'Ledger.Apply (correctness)' in operation['snapshots'][1]['checked']
        first = (baseline / 'build/approved.json').read_bytes()
        assert first == (baseline / 'build/approved-repeat.json').read_bytes()
        command = json.loads(first)['evidence'][0]['reproduce_cmd']
        replay = run(shlex.split(command), baseline, 'literal-replay')
        assert replay.returncode == 0 and (baseline / 'build/change-evidence.json').read_bytes() == first
        report.update(result='passed', exit_code=0, byte_identical=True,
                      evidence_sha256=digest(first))
        shutil.copyfile(baseline / 'build/approved.json', ROOT / 'results/stage4/approved-local-evidence.json')
    except (AssertionError, OSError, ValueError, KeyError) as error:
        report.update(result='failed', exit_code=1, error=str(error))
        print(str(error), file=sys.stderr)
    (ROOT / 'results/stage4/approval-local.json').write_bytes(canonical(report))
    return report['exit_code']


if __name__ == '__main__':
    sys.exit(main())
