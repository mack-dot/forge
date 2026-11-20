"""Goal 21 regression in a scratch clone: Stage EXIT cases, the frozen-gate check, link checks, the EXIT scripts of
Slices 1 to 3, of the M1 conformance, of the native silicon sink (Goal 19), of the forge-airlock SDK (Goal 20) and of
intent clearing (Goal 21). Copied from proposals/forge2-goal20-sdk/run_regression.py with one more bundle, more link
checks, a count of dangling links, and for each of the six prior bundles the SHA-256 of its tracked record at
origin/main.

Dispatch only: it starts the existing scripts and records their real exit codes. It decides nothing.

The clone is a THROWAWAY clone of the present commit of this repository. The working tree must have no change
in a tracked file, so the clone holds exactly the commit under test. The two tool folders are linked, not copied.
Nothing is committed or pushed anywhere.

Usage: python3 proposals/forge2-goal21-intent/run_regression.py <new-clone-folder> <record.json>
Environment: the pinned Node must be first in PATH, and rustc 1.92.0 must be in PATH. Stage 4 reads GitHub with
the token of `gh auth token` (read only; the token is not written anywhere). Hold the machine lock: this run is long
and starts Dafny many times (one Dafny process at a time; FORGE_DAFNY_LOCK is passed through to every child).
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
    ('forge-airlock SDK evidence', 'scripts/exit_goal20_sdk.py', 'build/goal20/evidence', 'proposals/forge2-goal20-sdk/records/evidence.json'),
    ('intent clearing evidence', 'scripts/exit_goal21_intent.py', 'build/goal21/evidence', 'proposals/forge2-goal21-intent/records/evidence.json'),
]
PRIOR_BUNDLES = [row[0] for row in BUNDLES[:6]]  # these six records must not change in this pull request
PROTECTED = ('spec/', 'spec.lock', 'policy/', 'governance/gate-ratifications/', 'package.json', 'package-lock.json', 'tsconfig.json', 'gate/', 'clearing/')
LINK_FILES = ['FORGE_MASTER_IDEA.md', 'ROADMAP.md', 'unsure.md', 'proposals/forge2-native-silicon-sink/REPORT.md', 'proposals/forge2-goal20-sdk/REPORT.md',
              'proposals/forge2-goal20-sdk/REVIEW.md', 'proposals/forge2-goal20-sdk/DESIGN.md', 'docs/quickstart-5min.md', 'src/airlock/PROTOCOL.md',
              'proposals/forge2-goal21-intent/DESIGN.md', 'proposals/forge2-goal21-intent/REPORT.md', 'proposals/forge2-goal21-intent/REVIEW.md',
              'proposals/forge2-finish-line/DIRECTIVE.md', 'proposals/forge2-finish-line/QUEUE.md', 'proposals/forge2-finish-line/ACCEPTED_ASSUMPTIONS.md',
              'proposals/forge2-finish-line/APEX3_STEP3A_BRIEF.md', 'docs/STATUS.md']


def git(folder, *arguments):
    return subprocess.run(['git', '-C', str(folder), *arguments], capture_output=True, text=True, check=True).stdout


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def sha256_at_origin_main(path):
    """The SHA-256 of the file at origin/main of this repository, or None if it is not there (real git exit code)."""
    child = subprocess.run(['git', '-C', str(FORGE), 'show', 'origin/main:' + path], capture_output=True)
    return hashlib.sha256(child.stdout).hexdigest() if child.returncode == 0 else None


if clone.exists():
    raise SystemExit('the clone folder exists already')
if git(FORGE, 'status', '--porcelain', '--untracked-files=no').strip():
    raise SystemExit('a tracked file has an uncommitted change: commit first, so that the clone is the commit under test')
head = git(FORGE, 'rev-parse', 'HEAD').strip()
origin_main = git(FORGE, 'rev-parse', 'origin/main').strip()
base = git(FORGE, 'merge-base', 'HEAD', 'origin/main').strip()
changed = sorted(git(FORGE, 'diff', '--name-only', base, 'HEAD').splitlines())
subprocess.run(['git', 'clone', '--quiet', '--no-hardlinks', str(FORGE), str(clone)], check=True)
git(clone, 'checkout', '--quiet', '--detach', head)
for link in ('.toolchain', 'node_modules'):
    (clone / link).symlink_to(FORGE / link)

environment = dict(os.environ)  # FORGE_DAFNY_LOCK, when set, reaches every child unchanged
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
dangling = {}
for name in LINK_FILES:
    child = run('links ' + name, ['python3', '-I', '-B', links, 'HEAD', name], 'links')
    try:
        found = json.loads(child.stdout)['files'][name]
    except (ValueError, KeyError, TypeError):
        found = None
    if isinstance(found, dict):
        dangling[name] = {'exit_code': child.returncode, 'relative_links': found.get('relative_links'), 'missing': found.get('missing')}
    else:  # FILE NOT IN REVISION (exit 2) or an unreadable report: no count is invented
        dangling[name] = {'exit_code': child.returncode, 'relative_links': None, 'missing': None,
                          'note': found if isinstance(found, str) else 'the link checker printed no readable report'}
bundles = {}
for label, script, folder, tracked in BUNDLES:
    child = run(label, ['python3', script, '--case', 'evidence'], 'evidence')
    made = sorted((clone / folder).glob('attempt-*/evidence.json'))
    bundles[label] = {'exit_code': child.returncode, 'clone_bundle_sha256': sha256(made[-1]) if made and child.returncode == 0 else None,
                      'tracked_record': tracked, 'tracked_record_sha256': sha256(clone / tracked) if (clone / tracked).exists() else None}
    bundles[label]['byte_identical'] = bundles[label]['clone_bundle_sha256'] is not None and bundles[label]['clone_bundle_sha256'] == bundles[label]['tracked_record_sha256']
    if label in PRIOR_BUNDLES:
        at_main = sha256_at_origin_main(tracked)
        bundles[label]['origin_main_record_sha256'] = at_main
        bundles[label]['equal_to_origin_main'] = at_main is not None and at_main == bundles[label]['tracked_record_sha256']
stage_rows = [row for row in rows if row['group'] == 'stage-exit']
record = {
    'what': 'Goal 21 regression: scratch clone of the commit under test',
    'commit_under_test': head, 'origin_main': origin_main, 'merge_base_with_origin_main': base,
    'files_changed_against_the_merge_base': changed,
    'protected_paths_changed': [name for name in changed if name.startswith(PROTECTED)],
    'rows': rows,
    'stage_exit_cases': len(stage_rows), 'stage_exit_cases_exit_0': sum(row['exit_code'] == 0 for row in stage_rows),
    'files_changed_by_the_stage_runs': changed_by_stage_runs,
    'links': dangling,
    'dangling_links': sum(len(v['missing']) for v in dangling.values() if isinstance(v['missing'], list)),
    'link_files_without_a_count': sorted(name for name, v in dangling.items() if not isinstance(v['missing'], list)),
    'bundles': bundles,
    'prior_bundles_equal_to_origin_main': all(bundles[label].get('equal_to_origin_main') for label in PRIOR_BUNDLES),
    'not_run': ['Stage 7 (Docker, about 3.3 hours)', 'Stage 9 (deferred; hosted signing)', 'Stage 10 (its EXIT script is not on main)', 'any HOL or Holmake process'],
    'end_to_end': False,
}
record_path.write_text(json.dumps(record, indent=1, sort_keys=True) + '\n')
print(json.dumps({'stage_exit_cases': record['stage_exit_cases'], 'stage_exit_cases_exit_0': record['stage_exit_cases_exit_0'],
                  'protected_paths_changed': record['protected_paths_changed'], 'dangling_links': record['dangling_links'],
                  'link_files_without_a_count': record['link_files_without_a_count'],
                  'prior_bundles_equal_to_origin_main': record['prior_bundles_equal_to_origin_main'],
                  'bundles': {label: (value['exit_code'], value['byte_identical']) for label, value in bundles.items()}}))
