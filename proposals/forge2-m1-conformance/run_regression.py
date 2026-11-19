"""Wave Gate 1 regression: Stage EXIT cases, frozen-gate check, link checks, the EXIT scripts of Slices 1, 2 and 3 and the M1 conformance EXIT script in a scratch clone.

Dispatch only: it starts the existing scripts and records their real exit codes. It decides nothing.

The clone is a THROWAWAY repository made from the present commit of this repository. The uncommitted
Wave Gate 1 files of the working tree (everything that git lists as modified or untracked, except
results/, .hol/, goal18.md and ignored files) are copied in and committed THERE, so that the revision-based
checks (links, frozen gate modules) see them. That commit exists only in the clone. Nothing is
committed or pushed in the owner's repository.

Usage: python3 proposals/forge2-m1-conformance/run_regression.py <new-clone-folder> <record.json>
Environment: the pinned Node must be first in PATH, and rustc must be in PATH (it builds the untrusted optimizer v2). Stage 4 reads GitHub with the token of `gh auth token`
(read only; the token is not written anywhere).
"""
import hashlib, json, os, shutil, subprocess, sys
from pathlib import Path

FORGE = Path(__file__).resolve().parents[2]
clone, record_path = Path(sys.argv[1]).resolve(), Path(sys.argv[2]).resolve()
EXCLUDED = ('results/', '.hol/', 'goal18.md')
STAGE11 = ['--eval', 'results/stage11/eval-0007', '--baseline', 'results/stage11/eval-pr27-0003']
CASES = [(1, c, []) for c in ('reproducibility', 'planted-bugs', 'spec-lock', 'contract-binding', 'audit-controls')]
CASES += [(2, c, []) for c in ('schema', 'artifact-mismatch', 'method-policy', 'round-trip', 'policy-controls')]
CASES += [(3, c, []) for c in ('correct-typescript', 'self-transfer', 'evidence-labels', 'reproducibility', 'loader-demo', 'cli-demo')]
CASES += [(5, c, []) for c in ('vacuity', 'mutations')]
CASES += [(6, 'report', [])]
CASES += [(8, c, []) for c in ('wrapper-proof', 'hostile-outputs', 'evidence-separation')]
CASES += [(4, c, []) for c in ('affected-claims', 'unapproved-spec', 'approved-spec')]
CASES += [(11, c, STAGE11) for c in ('legitimate-change', 'stale-dependency', 'report')]


def git(folder, *arguments):
    return subprocess.run(['git', '-C', str(folder), *arguments], capture_output=True, text=True, check=True).stdout


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


if clone.exists():
    raise SystemExit('the clone folder exists already')
head = git(FORGE, 'rev-parse', 'HEAD').strip()
changed = sorted(name for name in git(FORGE, 'ls-files', '--modified', '--others', '--exclude-standard').splitlines()
                 if name and not name.startswith(EXCLUDED) and (FORGE / name).is_file())
subprocess.run(['git', 'clone', '--quiet', '--no-hardlinks', str(FORGE), str(clone)], check=True)
git(clone, 'checkout', '--quiet', '--detach', head)
for link in ('.toolchain', 'node_modules'):
    (clone / link).symlink_to(FORGE / link)
for name in changed:
    (clone / name).parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(FORGE / name, clone / name)
copied = {name: sha256(clone / name) for name in changed}
if changed:
    git(clone, 'add', '--', *changed)
git(clone, '-c', 'user.name=forge scratch clone', '-c', 'user.email=scratch@invalid', 'commit', '--quiet', '--allow-empty', '-m',
    'Wave Gate 1 candidate files (scratch clone only; not in the owner\'s repository)')
candidate = git(clone, 'rev-parse', 'HEAD').strip()

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
    rows.append({'check': label, 'group': group, 'argv': argv, 'exit_code': child.returncode,
                 'last_line': (lines[-1] if lines else '')[:300]})
    print('%s: exit %d' % (label, child.returncode), flush=True)
    return child


for stage, case, extra in CASES:
    run('stage %d %s' % (stage, case), ['python3', 'scripts/exit_stage_%d.py' % stage, '--case', case, *extra], 'stage-exit')
# What the stage runs changed in the clone (the two tool links are not counted).
changed_by_stage_runs = sorted(line[3:] for line in git(clone, 'status', '--porcelain').splitlines()
                               if line[3:] not in ('.toolchain', 'node_modules'))
run('frozen PR-gate modules', ['python3', '-I', '-B', 'proposals/round4-20261117/check_frozen_pr_gate.py', 'HEAD'], 'frozen-gate')
links = 'proposals/round4-20261117/check_links.py'
for name in ('FORGE_MASTER_IDEA.md', 'ROADMAP.md', 'unsure.md', 'proposals/forge2-m1-conformance/REPORT.md'):
    run('links ' + name, ['python3', '-I', '-B', links, 'HEAD', name], 'links')
markdown = [name for name in git(clone, 'ls-files', '*.md').splitlines() if not name.startswith('results/')]
everything = run('links, all %d Markdown files outside results/' % len(markdown), ['python3', '-I', '-B', links, 'HEAD', *markdown], 'links-all')
missing = {name: value['missing'] for name, value in json.loads(everything.stdout)['files'].items()
           if isinstance(value, dict) and value['missing']}
slice1 = run('slice 1 evidence', ['python3', 'scripts/exit_slice1.py', '--case', 'evidence'], 'slice1')
bundles = sorted((clone / 'build/slice1/evidence').glob('attempt-*/evidence.json'))
slice2 = run('slice 2 evidence', ['python3', 'scripts/exit_slice2.py', '--case', 'evidence'], 'slice2')
bundles2 = sorted((clone / 'build/slice2/evidence').glob('attempt-*/evidence.json'))
slice3 = run('slice 3 evidence', ['python3', 'scripts/exit_slice3.py', '--case', 'evidence'], 'slice3')
bundles3 = sorted((clone / 'build/slice3/evidence').glob('attempt-*/evidence.json'))
slice4 = run('M1 conformance evidence', ['python3', 'scripts/exit_m1_conformance.py', '--case', 'evidence'], 'm1-conformance')
bundles4 = sorted((clone / 'build/m1-conformance/evidence').glob('attempt-*/evidence.json'))
stage_rows = [row for row in rows if row['group'] == 'stage-exit']
record = {
    'what': 'Wave Gate 1 regression: scratch clone of the present commit plus the uncommitted Wave Gate 1 files',
    'base_commit': head, 'scratch_clone_commit': candidate,
    'scratch_clone_commit_note': 'exists only in the throwaway clone; not in the owner\'s repository; not pushed',
    'copied_files_sha256': copied,
    'rows': rows,
    'stage_exit_cases': len(stage_rows), 'stage_exit_cases_exit_0': sum(row['exit_code'] == 0 for row in stage_rows),
    'files_changed_by_the_stage_runs': changed_by_stage_runs,
    'markdown_files_checked': len(markdown), 'links_without_target': missing,
    'slice1_bundle_sha256': sha256(bundles[-1]) if bundles and slice1.returncode == 0 else None,
    'slice2_bundle_sha256': sha256(bundles2[-1]) if bundles2 and slice2.returncode == 0 else None,
    'slice3_bundle_sha256': sha256(bundles3[-1]) if bundles3 and slice3.returncode == 0 else None,
    'm1_conformance_bundle_sha256': sha256(bundles4[-1]) if bundles4 and slice4.returncode == 0 else None,
    'not_run': ['Stage 7 (Docker, about 3.3 hours)', 'Stage 9 (deferred; hosted signing)', 'Stage 10 (its EXIT script is not on main)'],
    'end_to_end': False,
}
record_path.write_text(json.dumps(record, indent=1, sort_keys=True) + '\n')
print(json.dumps({key: record[key] for key in ('stage_exit_cases', 'stage_exit_cases_exit_0', 'slice1_bundle_sha256', 'slice2_bundle_sha256', 'slice3_bundle_sha256', 'm1_conformance_bundle_sha256')}))
