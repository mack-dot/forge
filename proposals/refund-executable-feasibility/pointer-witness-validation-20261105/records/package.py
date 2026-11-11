"""Package completed local checks without changing earlier evidence."""
from pathlib import Path
import hashlib
import json
import shlex
import shutil
import subprocess

ROOT = Path('/Users/mackianni/forge')
WT = Path('/private/tmp/forge-readiness-docs-20261103')
HERE = Path(__file__).resolve().parent
RAW = ROOT / 'results/refund-pointer-witness-2026-11-05/attempt-0001'
REL = Path('proposals/refund-executable-feasibility/pointer-witness-validation-20261105')
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
read = lambda p: json.loads(p.read_text())
result = read(RAW / 'readback-validation.json')
assert result['actual_exit'] == 0
assert read(RAW / 'controls-readback.json')['actual_exit'] == 0
base = result['continuation_baseline']['base_commit']
assert subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=WT, text=True).strip() == base
assert not subprocess.check_output(['git', 'status', '--porcelain'], cwd=WT)
first = read(RAW / 'pointer-0003/command.json')
repeat = read(RAW / 'pointer-repeat/command.json')
imported = read(RAW / 'exact-import-0003/command.json')
values = {
    'BASE': base, 'SOURCE': first['source_sha256'],
    'DAT': next(h for f, h in first['objects'].items() if f.endswith('Theory.dat')),
    'NATIVE': result['native_sha256'], 'NODES': result['closure_node_count'],
    'DEPENDENCIES': result['dependency_file_count'], 'IMPORT_WALL': imported['wall_seconds'],
    'REPEAT_WALL': repeat['wall_seconds'],
    'PRIOR_MEMBERS': sum(x['members'] for x in result['prior_packets'].values()),
}
report = (HERE / 'REPORT.template.md').read_text()
for key, value in values.items():
    assert '@' + key + '@' in report
    report = report.replace('@' + key + '@', str(value))
assert '@' not in report
cases = result['recorded_child_exits']
commands = '# Exact recorded HOL commands\n\n'
commands += ('These are actual child commands. The original wrappers preserve the pinned\n'
             'heap, parent identities, environment setup and CPU limits. Runs are local,\n'
             'not hosted or independent clean full-chain replay. Existing case names must\n'
             'not be overwritten. Reproduction requires the pinned toolchain and parents.\n\n')
for name, actual in cases.items():
    d = read(RAW / name / 'command.json')
    assert d['actual_exit'] == actual
    commands += ('## ' + name + '\n\nActual exit: `' + str(actual) + '`. Local wall seconds: `' + str(d['wall_seconds']) + '`.\n\n'
                 'Working directory: `' + d['cwd'] + '`.\n\n```sh\n' + shlex.join(d['argv']) + '\n```\n\n')
commands += '## Evidence readback\n\n```sh\npython3 -B results/refund-pointer-witness-2026-11-05/attempt-0001/readback-validation.py\n```\n\nActual exit: `0`. This binds bytes and records; HOL performs proof checking.\n'
captured = {str(p.relative_to(RAW)): sha(p) for p in sorted(RAW.rglob('*')) if p.is_file()}
before = {}
for label, root in [('workspace', ROOT), ('worktree', WT)]:
    assert not (root / REL).exists()
    assert '## U311 ' not in (root / 'unsure.md').read_text()
    before[label] = {}
    for file in ['ROADMAP.md', 'FORGE_MISSION_STATUS.md', 'unsure.md']:
        current = root / file
        saved = HERE / 'before-current' / label / file
        saved.parent.mkdir(parents=True, exist_ok=True)
        assert not saved.exists()
        shutil.copyfile(current, saved)
        before[label][file] = sha(saved)
        original = HERE / 'before' / label / file
        if file == 'unsure.md':
            assert current.read_bytes().startswith(original.read_bytes())
    records = root / REL / 'records'
    shutil.copytree(RAW, records)
    for f, h in captured.items():
        assert sha(records / f) == h
    (root / REL / 'REPORT.md').write_text(report)
    (root / REL / 'COMMANDS.md').write_text(commands)
metadata = {'actual_exit': 0, 'base_commit': base, 'captured_files': captured,
            'before_current': before, 'prior_turn_snapshots_preserved': True,
            'distinct_histories_preserved': True, 'end_to_end': False}
(HERE / 'package-readback.json').write_text(json.dumps(metadata, indent=2) + '\n')
for root in (ROOT, WT):
    shutil.copyfile(HERE / 'package-readback.json', root / REL / 'records/package-readback.json')
    shutil.copyfile(Path(__file__), root / REL / 'records/package.py')
print(json.dumps({'actual_exit': 0, 'captured_files': len(captured), **values}))
