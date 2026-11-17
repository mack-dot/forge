"""Floor controls for a Tier-0 gate ratification. They are a FLOOR, not a proof that the gate did not get weaker.

The tree that runs is the trusted checkout plus exactly the ratified bytes; no other candidate file is used. In it:
1. the ratified gate must reject every planted bug of the trusted base and every control that the record names, each
   for a proof or audit reason, and must accept the trusted approved implementation;
2. the ratified protected_manifest must return what the trusted one returns for the same tree, and the ratified
   authorize must still refuse a changed, an added and a removed protected file and pass an unchanged manifest.
The main safeguard stays the owner's review of the exact bytes. Two independent reviews showed that bytes written on
purpose pass these controls (a gate.py that only prints the expected words; functions that behave well only inside
the probe). The controls catch accidents, not intent. The booking, refund, provenance and TypeScript gates are not
exercised here, and the changed PR gate itself never runs: its modules are outside Tier-0 for that reason.
"""

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

from common import Rejected, digest

COPIED = ('gate', 'spec', 'impl', 'toolchain', 'schemas', 'policy')
BASELINE = 'impl/Ledger.dfy'
PROOF_REASONS = ('VERIFICATION_REJECTED:', 'AUDIT_REJECTED:')
ALLOWED_ENVIRONMENT = ('PATH', 'HOME', 'TMPDIR', 'LANG', 'LC_ALL', 'LD_LIBRARY_PATH', 'DOTNET_ROOT')
TIMEOUT_SECONDS = 1800
PROBE = r"""
import json, sys
sys.path.insert(0, 'gate')
from pathlib import Path
import incremental, approval
from common import Rejected
root = Path('.').resolve()
manifest = incremental.protected_manifest(root)
out = {'manifest': manifest, 'authorize': {}}
def probe(name, proposed):
    try:
        out['authorize'][name] = 'returned None' if approval.authorize(root, manifest, proposed) is None else 'returned a value'
    except Rejected as error:
        out['authorize'][name] = 'Rejected: ' + str(error).split(':')[0]
    except Exception as error:
        out['authorize'][name] = 'error: ' + type(error).__name__
names = sorted(manifest)
if names:      # an empty manifest is reported as it is; the caller compares it with the trusted one
    changed = dict(manifest); changed[names[0]] = '0' * 64
    added = dict(manifest); added['gate/zz-probe-added.py'] = '0' * 64
    removed = dict(manifest); del removed[names[-1]]
    probe('unchanged', dict(manifest)); probe('changed', changed); probe('added', added); probe('removed', removed)
print('PROBE ' + json.dumps(out, sort_keys=True))
"""
EXPECTED_PROBE = {'unchanged': 'returned None', 'changed': 'Rejected: UNAPPROVED_PROTECTED_CHANGE',
                  'added': 'Rejected: UNAPPROVED_PROTECTED_CHANGE', 'removed': 'Rejected: UNAPPROVED_PROTECTED_CHANGE'}


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
        if (tree / control['path']).exists() or (tree / control['path']).is_symlink():
            raise Rejected('RATIFICATION_CONTROL: a control may not replace a planted bug of the trusted base: ' + control['path'])
        (tree / control['path']).write_bytes(_candidate_bytes(candidate, control['path'], control['sha256']))
        controls.append((control['path'], 1, 'ratified control'))
    if not any(kind == 'trusted planted bug' for _, _, kind in controls):
        raise Rejected('RATIFICATION_CONTROL: the trusted base has no planted bug to test the ratified gate')
    controls.append((BASELINE, 0, 'trusted approved implementation'))
    return controls


def run_controls(root, candidate, ratification, work, trusted_manifest, environment=None):
    if environment is None:      # the ratified bytes never see the caller's full environment
        environment = {name: os.environ[name] for name in ALLOWED_ENVIRONMENT if name in os.environ}
        environment['PYTHONNOUSERSITE'] = '1'
    tree = Path(work) / 'ratified-tree'
    controls = materialize(root, candidate, ratification, tree)
    results = []
    for index, (path, expected, kind) in enumerate(controls):
        child = subprocess.run([sys.executable, 'gate/gate.py', '--impl', path,
                                '--evidence', 'build/control-%02d.evidence.json' % index],
                               cwd=tree, capture_output=True, text=True, env=environment, timeout=TIMEOUT_SECONDS)
        (Path(work) / ('ratification-control-%02d.log' % index)).write_text(child.stdout + child.stderr)
        lines = [line for line in (child.stdout + child.stderr).splitlines() if line.strip()]
        last = lines[-1] if lines else ''
        results.append({'path': path, 'kind': kind, 'expected_exit': expected, 'exit_code': child.returncode,
                        'reason': last.split(':')[0][:40], 'sha256': digest((tree / path).read_bytes())})
        if child.returncode not in (0, 1):
            raise RuntimeError('RATIFICATION_CONTROL_ERROR: the ratified gate returned %d for %s; no decision'
                               % (child.returncode, path))
        if child.returncode != expected:
            raise Rejected('RATIFICATION_CONTROL: the ratified gate %s %s (%s)'
                           % ('accepted' if child.returncode == 0 else 'rejected', path, kind))
        if expected == 1 and not last.startswith(PROOF_REASONS):
            raise Rejected('RATIFICATION_CONTROL: the ratified gate rejected %s (%s) for a reason that is not a proof '
                           'or audit result: %s' % (path, kind, last[:80]))
        if expected == 0 and not last.startswith('ACCEPTED:'):
            raise Rejected('RATIFICATION_CONTROL: unexpected acceptance text for ' + path)
    # The ratified protected-change functions, run in their own process inside the ratified tree.
    shutil.rmtree(tree / 'build', ignore_errors=True)
    expected_manifest = trusted_manifest(tree)
    child = subprocess.run([sys.executable, '-B', '-c', PROBE], cwd=tree, capture_output=True, text=True, env=environment,
                           timeout=TIMEOUT_SECONDS)
    (Path(work) / 'ratification-probe.log').write_text(child.stdout + child.stderr)
    marked = [line for line in child.stdout.splitlines() if line.startswith('PROBE ')]
    if child.returncode != 0 or len(marked) != 1:
        raise RuntimeError('RATIFICATION_CONTROL_ERROR: the probe of the ratified gate functions did not finish')
    probe = json.loads(marked[0][len('PROBE '):])
    if not isinstance(probe, dict):
        raise RuntimeError('RATIFICATION_CONTROL_ERROR: the probe of the ratified gate functions returned no object')
    if probe.get('manifest') != expected_manifest:
        raise Rejected('RATIFICATION_CONTROL: the ratified protected_manifest differs from the trusted one on the same tree')
    if probe.get('authorize') != EXPECTED_PROBE:
        raise Rejected('RATIFICATION_CONTROL: the ratified authorize no longer refuses protected changes: '
                       + json.dumps(probe.get('authorize'), sort_keys=True))
    results.append({'path': 'gate/incremental.py:protected_manifest, gate/approval.py:authorize', 'kind': 'function probe',
                    'expected_exit': 0, 'exit_code': 0, 'reason': 'equal manifest; four authorize probes as expected'})
    return results
