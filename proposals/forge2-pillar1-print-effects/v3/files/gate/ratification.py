"""Non-weakening controls for a Tier-0 gate ratification.

The RATIFIED gate bytes must still reject every planted bug of the trusted base and every ratified control, and must
still accept the trusted approved implementation. The tree that runs is the trusted checkout plus exactly the
ratified bytes; no other candidate file is used.
"""

from pathlib import Path
import shutil
import subprocess
import sys

from common import Rejected, digest

COPIED = ('gate', 'spec', 'impl', 'toolchain', 'schemas', 'policy')
BASELINE = 'impl/Ledger.dfy'


def _candidate_bytes(candidate, name, expected):
    source = candidate / name
    if source.is_symlink() or not source.is_file() or not source.resolve().is_relative_to(candidate.resolve()):
        raise Rejected('RATIFICATION_CONTROL: ratified file is missing, a link, or outside the candidate: ' + name)
    data = source.read_bytes()
    if digest(data) != expected:
        raise Rejected('RATIFICATION_CONTROL: candidate bytes differ from the ratified digest: ' + name)
    return data


def materialize(root, candidate, ratification, tree):
    for folder in COPIED:
        shutil.copytree(root / folder, tree / folder, ignore=shutil.ignore_patterns('__pycache__', '*.pyc'))
    shutil.copyfile(root / 'spec.lock', tree / 'spec.lock')
    (tree / '.toolchain').symlink_to(root / '.toolchain', target_is_directory=True)
    for name, entry in sorted(ratification['files'].items()):
        target = tree / name
        if entry['new_sha256'] is None:
            target.unlink(missing_ok=True)
            continue
        data = _candidate_bytes(candidate, name, entry['new_sha256'])
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
    (tree / 'bugs').mkdir()
    controls = []
    for path in sorted((root / 'bugs').glob('*.dfy')):
        if path.is_symlink() or not path.is_file():
            raise Rejected('RATIFICATION_CONTROL: trusted planted bug is not a plain file: ' + path.name)
        shutil.copyfile(path, tree / 'bugs' / path.name)
        controls.append(('bugs/' + path.name, 1, 'trusted planted bug'))
    for control in ratification['controls']:
        (tree / control['path']).write_bytes(_candidate_bytes(candidate, control['path'], control['sha256']))
        if control['path'] not in [c[0] for c in controls]:
            controls.append((control['path'], 1, 'ratified control'))
    if not any(kind == 'trusted planted bug' for _, _, kind in controls):
        raise Rejected('RATIFICATION_CONTROL: the trusted base has no planted bug to test the ratified gate')
    controls.append((BASELINE, 0, 'trusted approved implementation'))
    return controls


def run_controls(root, candidate, ratification, work, environment=None):
    tree = Path(work) / 'ratified-tree'
    controls = materialize(root, candidate, ratification, tree)
    results = []
    for index, (path, expected, kind) in enumerate(controls):
        child = subprocess.run([sys.executable, 'gate/gate.py', '--impl', path,
                                '--evidence', 'build/control-%02d.evidence.json' % index],
                               cwd=tree, capture_output=True, text=True, env=environment)
        (Path(work) / ('ratification-control-%02d.log' % index)).write_text(child.stdout + child.stderr)
        results.append({'path': path, 'kind': kind, 'expected_exit': expected, 'exit_code': child.returncode,
                        'sha256': digest((tree / path).read_bytes())})
        if child.returncode not in (0, 1):
            raise RuntimeError('RATIFICATION_CONTROL_ERROR: the ratified gate returned %d for %s; no decision'
                               % (child.returncode, path))
        if child.returncode != expected:
            raise Rejected('RATIFICATION_CONTROL: the ratified gate %s %s (%s)'
                           % ('accepted' if child.returncode == 0 else 'rejected', path, kind))
    return results
