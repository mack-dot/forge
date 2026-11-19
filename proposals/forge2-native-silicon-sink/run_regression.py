"""Goal 19 regression in a scratch clone: Stage EXIT cases, the frozen-gate check, link checks, the EXIT scripts of
Slices 1 to 3 and of the M1 conformance, and the EXIT script of the native silicon sink.

Dispatch only: it starts the existing scripts and records their real exit codes. It decides nothing.

The clone is a THROWAWAY clone of the present commit of this repository. The working tree must have no change
in a tracked file, so the clone holds exactly the commit under test. The two tool folders are linked, not copied.
Nothing is committed or pushed anywhere.

Usage: python3 proposals/forge2-native-silicon-sink/run_regression.py <new-clone-folder> <record.json>
Environment: the pinned Node must be first in PATH, and rustc 1.92.0 must be in PATH. Stage 4 reads GitHub with
the token of `gh auth token` (read only; the token is not written anywhere).
"""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

FORGE = Path(__file__).resolve().parents[2]
clone, record_path = Path(sys.argv[1]).resolve(), Path(sys.argv[2]).resolve()
STAGE11 = ['--eval', 'results/stage11/eval-0007', '--baseline', 'results/stage11/eval-pr27-0003']
CASES = [(1, c, []) for c in ('reproducibility', 'planted-bugs', 'spec-lock', 'contract-binding', 'audit-controls')]
CASES += [(2, c, []) for c in ('schema', 'artifact-mismatch', 'method-policy', 'round-trip', 'policy-controls')]
CASES += [(3, c, []) for c in ('correct-typescript', 'self-transfer', 'evidence-labels', 'reproducibility', 'loader-demo', 'cli-demo')]
CASES += [(5, c, []) for c in ('vacuity', 'mutations')]
CASES += [(6, 'report', [])]
CASES += [(8, c, []) for c in ('wrapper-proof', 'hostile-outputs', 'evidence-separation')]
CASES += [(4, c, []) for c in ('affected-claims', 'unapproved-spec', 'approved-spec')]
CASES += [(11, c, STAGE11) for c in ('legitimate-change', 'stale-dependency', 'report')]
# EXIT script, its build folder, the tracked record of its bundle.
BUNDLES = [
    ('slice 1 evidence', 'scripts/exit_slice1.py', 'build/slice1/evidence', 'proposals/forge2-slice1-refund-finality/records/evidence.json'),
    ('slice 2 evidence', 'scripts/exit_slice2.py', 'build/slice2/evidence', 'proposals/forge2-slice2-spec-clearing/records/evidence.json'),
    ('slice 3 evidence', 'scripts/exit_slice3.py', 'build/slice3/evidence', 'proposals/forge2-slice3-runtime-certificates/records/evidence.json'),
    ('M1 conformance evidence', 'scripts/exit_m1_conformance.py', 'build/m1-conformance/evidence', 'proposals/forge2-m1-conformance/records/evidence.json'),
    ('native silicon sink evidence', 'scripts/exit_silicon_sink.py', 'build/silicon/evidence', 'proposals/forge2-native-silicon-sink/records/evidence.json'),
]
PROTECTED = ('spec/', 'spec.lock', 'policy/', 'governance/gate-ratifications/', 'package.json', 'package-lock.json', 'tsconfig.json', 'gate/')


def git(folder, *arguments):
    return subprocess.run(['git', '-C', str(folder), *arguments], capture_output=True, text=True, check=True).stdout


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


if clone.exists():
    raise SystemExit('the clone folder exists already')
if git(FORGE, 'status', '--porcelain', '--untracked-files=no').strip():
    raise SystemExit('a tracked file has an uncommitted change: commit first, so that the clone is the commit under test')
head = git(FORGE, 'rev-parse', 'HEAD').strip()
base = git(FORGE, 'merge-base', 'HEAD', 'origin/main').strip()
changed = sorted(git(FORGE, 'diff', '--name-only', base, 'HEAD').splitlines())
subprocess.run(['git', 'clone', '--quiet', '--no-hardlinks', str(FORGE), str(clone)], check=True)
git(clone, 'checkout', '--quiet', '--detach', head)
for link in ('.toolchain', 'node_modules'):
    (clone / link).symlink_to(FORGE / link)

environment = dict(os.environ)
token = subprocess.run(['gh', 'auth', 'token'], capture_output=True, text=True)
if token.returncode == 0 and token.stdout.strip():
    environment['GH_TOKEN'] = token.stdout.strip()
rows = []


def run(label, argv, group):
    child = subprocess.run(argv, cwd=clone, env=environment, capture_output=True, text=True)
    # Path-free record: the clone folder, the repository folder and the home folder are replaced.
    text = (child.stdout + child.stderr).replace(str(clone), '<clone>').replace(str(FORGE), '<forge>').replace(str(Path.home()), '<home>')
    lines = text.strip().splitlines()
    rows.append({'check': label, 'group': group, 'argv': argv, 'exit_code': child.returncode, 'last_line': (lines[-1] if lines else '')[:300]})
    print('%s: exit %d' % (label, child.returncode), flush=True)
    return child


for stage, case, extra in CASES:
    run('stage %d %s' % (stage, case), ['python3', 'scripts/exit_stage_%d.py' % stage, '--case', case, *extra], 'stage-exit')
changed_by_stage_runs = sorted(line[3:] for line in git(clone, 'status', '--porcelain').splitlines() if line[3:] not in ('.toolchain', 'node_modules'))
run('frozen PR-gate modules', ['python3', '-I', '-B', 'proposals/round4-20261117/check_frozen_pr_gate.py', 'HEAD'], 'frozen-gate')
links = 'proposals/round4-20261117/check_links.py'
for name in ('FORGE_MASTER_IDEA.md', 'ROADMAP.md', 'unsure.md', 'proposals/forge2-native-silicon-sink/REPORT.md'):
    run('links ' + name, ['python3', '-I', '-B', links, 'HEAD', name], 'links')
bundles = {}
for label, script, folder, tracked in BUNDLES:
    child = run(label, ['python3', script, '--case', 'evidence'], 'evidence')
    made = sorted((clone / folder).glob('attempt-*/evidence.json'))
    bundles[label] = {'exit_code': child.returncode, 'clone_bundle_sha256': sha256(made[-1]) if made and child.returncode == 0 else None,
                      'tracked_record': tracked, 'tracked_record_sha256': sha256(clone / tracked) if (clone / tracked).exists() else None}
    bundles[label]['byte_identical'] = bundles[label]['clone_bundle_sha256'] is not None and bundles[label]['clone_bundle_sha256'] == bundles[label]['tracked_record_sha256']
stage_rows = [row for row in rows if row['group'] == 'stage-exit']
record = {
    'what': 'Goal 19 regression: scratch clone of the commit under test',
    'commit_under_test': head, 'merge_base_with_origin_main': base,
    'files_changed_against_the_merge_base': changed,
    'protected_paths_changed': [name for name in changed if name.startswith(PROTECTED)],
    'rows': rows,
    'stage_exit_cases': len(stage_rows), 'stage_exit_cases_exit_0': sum(row['exit_code'] == 0 for row in stage_rows),
    'files_changed_by_the_stage_runs': changed_by_stage_runs,
    'bundles': bundles,
    'not_run': ['Stage 7 (Docker, about 3.3 hours)', 'Stage 9 (deferred; hosted signing)', 'Stage 10 (its EXIT script is not on main)', 'any HOL or Holmake process'],
    'end_to_end': False,
}
record_path.write_text(json.dumps(record, indent=1, sort_keys=True) + '\n')
print(json.dumps({'stage_exit_cases': record['stage_exit_cases'], 'stage_exit_cases_exit_0': record['stage_exit_cases_exit_0'],
                  'protected_paths_changed': record['protected_paths_changed'],
                  'bundles': {label: (value['exit_code'], value['byte_identical']) for label, value in bundles.items()}}))
