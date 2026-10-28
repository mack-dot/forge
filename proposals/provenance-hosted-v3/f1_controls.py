"""F1 and verifier-guard controls for the v3 candidate (U104).

Run from a scratch copy with v3 applied and committed as a Git repository.
Each attack is a real commit; the candidate's own source_tree() and
repository_identity() decide. No network: the guards under test reject before
any request. Exit 0 only if every expectation holds.
"""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'gate/provenance'))

from common import Records, Rejected, context, repository_identity, source_tree, write  # noqa: E402


def git(*args):
    return subprocess.run(['git', '-C', str(ROOT)] + list(args), check=True, capture_output=True,
                          text=True).stdout.strip()


def commit_variant(base, label, change, force=()):
    git('checkout', '-q', '--detach', base)
    change()
    git('add', '-A', '.')
    for path in force:
        git('add', '-f', path)
    git('-c', 'user.name=control', '-c', 'user.email=control@invalid', 'commit', '-q', '-m', label)
    return git('rev-parse', 'HEAD')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--implementation-sha256', required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=False)
    policy, _, implementation = context(args.implementation_sha256)
    records = Records(args.output / 'commands')
    git_dir = ROOT / '.git'
    base = git('rev-parse', 'HEAD')
    results = []

    def expect(name, expected, action):
        try:
            action()
            observed = 'ACCEPTED'
        except Rejected as error:
            observed = error.reason
        results.append({'control': name, 'expected': expected, 'observed': observed,
                        'pass': observed == expected})
        print(json.dumps(results[-1]), flush=True)

    expect('clean candidate commit', 'ACCEPTED', lambda: source_tree(git_dir, base, implementation, records))
    attacks = [
        ('shadow module beside the gate', 'UNLOCKED_EXECUTABLE:gate/provenance/argparse.py',
         lambda: (ROOT / 'gate/provenance/argparse.py').write_text('raise SystemExit(1)\n')),
        ('shadow module in the proof container scripts', 'UNLOCKED_EXECUTABLE:scripts/json.py',
         lambda: (ROOT / 'scripts/json.py').write_text('raise SystemExit(1)\n')),
        ('compiled cache file', 'UNLOCKED_EXECUTABLE:scripts/__pycache__/stage7_own_job.cpython-310.pyc',
         lambda: ((ROOT / 'scripts/__pycache__').mkdir(exist_ok=True),
                  (ROOT / 'scripts/__pycache__/stage7_own_job.cpython-310.pyc').write_bytes(b'\0' * 16))),
        ('unlocked data file inside gate/provenance', 'UNLOCKED_EXECUTABLE:gate/provenance/extra.json',
         lambda: (ROOT / 'gate/provenance/extra.json').write_text('{}\n')),
        ('changed locked byte', 'AUTHENTICATED_WORKFLOW_INPUT:gate/provenance/release.py',
         lambda: (ROOT / 'gate/provenance/release.py').write_text(
             (ROOT / 'gate/provenance/release.py').read_text() + '# changed\n')),
        ('symlink in scripts', 'SOURCE_ENTRY_TYPE:scripts/link.py',
         lambda: os.symlink('stage7_job.py', ROOT / 'scripts/link.py')),
    ]
    for name, expected, change in attacks:
        force = [expected.split(':', 1)[1]] if '__pycache__' in expected else []
        commit = commit_variant(base, name, change, force)
        expect(name, expected, lambda: source_tree(git_dir, commit, implementation, records))
    git('checkout', '-q', '--detach', base)

    # Guards that must reject before any network request.
    saved = dict(os.environ)
    try:
        os.environ['GITHUB_ACTIONS'] = 'true'
        expect('verifier inside a workflow job', 'VERIFIER_NOT_INDEPENDENT',
               lambda: repository_identity(policy, implementation, base, records))
        os.environ.pop('GITHUB_ACTIONS')
        os.environ.pop('FORGE_VERIFIER_GITHUB_TOKEN', None)
        os.environ['FORGE_PRODUCER_GITHUB_TOKEN'] = 'x' * 40
        expect('producer token offered to the verifier', 'GITHUB_TOKEN_REQUIRED:FORGE_VERIFIER_GITHUB_TOKEN',
               lambda: repository_identity(policy, implementation, base, records))
    finally:
        os.environ.clear()
        os.environ.update(saved)
    write(args.output / 'results.json', {'controls': results, 'end_to_end': False,
                                          'not_run': ['authenticated fetch from the private repository (decision B)']})
    return 0 if all(r['pass'] for r in results) else 1


if __name__ == '__main__':
    sys.exit(main())
