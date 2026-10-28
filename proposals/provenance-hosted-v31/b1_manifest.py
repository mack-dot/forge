"""Compute the exact B1 publication set without committing or pushing anything.

Uses a temporary index in the given Git directory: reads the current main tree,
adds the listed paths from the working tree, and writes tree objects only.
The test-branch tree is the main tree plus the v3.1 candidate files.
"""
import fnmatch
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import yaml

ROOT = Path(__file__).resolve().parents[2]
V31 = ROOT / 'proposals/provenance-hosted-v31'
PATHS = [
    '.github/workflows/stage9-private-dry-run-v31.yml', 'ROADMAP.md', 'unsure.md',
    'proposals/provenance-hosted-v2/negative_controls.py', 'proposals/provenance-hosted-v3',
    'proposals/provenance-hosted-v31', 'results/stage9/github-settings-0001', 'results/stage9/hosted-probe-0006',
    'results/stage9/v2-negative-controls-0001', 'results/stage9/v2-negative-controls-0001.console',
    'results/stage9/v2-approval-readiness-0001', 'results/stage9/v3-local-checks-0001',
    'results/stage9/v3-local-checks-0001.console', 'results/stage9/v3-pre-verification-0001',
    'results/stage9/v31-controls-0001', 'results/stage9/b-prep-0001',
]
EXCLUDE = ['results/stage9/b-prep-0001/b1-publication-manifest.json']


def git(git_dir, env, *args):
    return subprocess.run(['git', '--git-dir', git_dir, '--work-tree', str(ROOT), '-c', 'core.fileMode=false'] + list(args),
                          env=env, capture_output=True, text=True, check=True).stdout


def purpose(path):
    if path.startswith('.github/workflows/'):
        return 'workflow', 'adds one manual-dispatch workflow: contents: read, no OIDC token, no secrets'
    if path.startswith('proposals/'):
        return 'proposal or test tool', 'none: data and local tools; only the dry run applies the candidate, to a copy'
    return 'record', 'none'


def main():
    git_dir, base = sys.argv[1], sys.argv[2]
    index = Path(tempfile.mkdtemp()) / 'index'
    env = dict(os.environ, GIT_INDEX_FILE=str(index))
    git(git_dir, env, 'read-tree', base)
    git(git_dir, env, 'add', '--', *PATHS)
    for path in EXCLUDE:
        git(git_dir, env, 'rm', '-q', '--cached', '--ignore-unmatch', '--', path)
    main_tree = git(git_dir, env, 'write-tree').strip()
    changed = git(git_dir, env, 'diff', '--cached', '--name-status', base).split('\n')
    files = []
    for line in filter(None, changed):
        status, path = line.split('\t', 1)
        data = (ROOT / path).read_bytes()
        kind, authority = purpose(path)
        files.append({'path': path, 'status': status, 'sha256': hashlib.sha256(data).hexdigest(),
                      'bytes': len(data), 'purpose': kind, 'authority': authority})
    # Push-triggered workflows on main and the paths that would trigger them.
    triggers = {}
    for wf in sorted((ROOT / '.github/workflows').glob('*.yml')):
        on = yaml.safe_load(wf.read_text()).get('on') or yaml.safe_load(wf.read_text()).get(True)
        if isinstance(on, dict) and 'push' in on:
            pats = on['push'].get('paths', ['**'])
            hits = [f['path'] for f in files if any(fnmatch.fnmatch(f['path'], p) for p in pats)]
            triggers[wf.name] = {'paths': pats, 'matching_b1_files': hits}
    manifest = json.loads((V31 / 'approval-manifest.json').read_text())
    for path, item in manifest['files'].items():
        blob = subprocess.run(['git', '--git-dir', git_dir, 'hash-object', '-w', str(V31 / 'candidate' / path)],
                              capture_output=True, text=True, check=True).stdout.strip()
        mode = '100644'
        git(git_dir, env, 'update-index', '--add', '--cacheinfo', f'{mode},{blob},{path}')
    branch_tree = git(git_dir, env, 'write-tree').strip()
    out = {'base_main_commit': base, 'b1_main_tree': main_tree, 'test_branch_tree': branch_tree,
           'test_branch_adds_v31_files': sorted(manifest['files']), 'push_triggers': triggers,
           'files': files, 'end_to_end': False}
    target = ROOT / EXCLUDE[0]
    target.write_text(json.dumps(out, indent=2, sort_keys=True) + '\n')
    counts = {}
    for f in files:
        top = '/'.join(f['path'].split('/')[:3]) if f['path'].startswith('results/') else '/'.join(f['path'].split('/')[:2])
        counts[top] = counts.get(top, 0) + 1
    print(json.dumps({'b1_main_tree': main_tree, 'test_branch_tree': branch_tree, 'files': len(files),
                      'by_area': counts, 'push_triggers': triggers}, indent=1))
    return 0


if __name__ == '__main__':
    sys.exit(main())
