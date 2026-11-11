from pathlib import Path
import hashlib
import json
import re
import subprocess

R = Path('/Users/mackianni/forge')
W = Path('/private/tmp/forge-readiness-docs-20261103')
H = Path(__file__).resolve().parent
P = Path('proposals/refund-executable-feasibility/initial-stack-code-checkpoint-20261105')
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
baseline = json.loads((H / 'checkpoint.json').read_text())
checks = []
for group, root in [('workspace', R), ('worktree', W)]:
    old = (H / 'before' / group / 'unsure.md').read_bytes()
    new = (root / 'unsure.md').read_bytes()
    assert new.startswith(old)
    assert new[len(old):].count(b'## U314 ') == 1
    assert (root / 'ROADMAP.md').read_text().splitlines()[2].startswith('**CURRENT: none')
    for name, digest in baseline['raw_files'].items():
        assert sha(root / P / 'records' / name) == digest
    for name in ['CHECKPOINT.md', 'COMMANDS.md']:
        source = root / P / name
        for target in re.findall(r'\]\(([^)]+)\)', source.read_text()):
            assert (source.parent / target.split('#')[0]).exists(), (name, target)
    for name in ['ROADMAP.md', 'FORGE_MISSION_STATUS.md']:
        text = (root / name).read_text()
        section = text[text.index('## '):].split('\n## ', 1)[0]
        for target in re.findall(r'\]\(([^)]+)\)', section):
            assert (root / target.split('#')[0]).exists(), (name, target)
    checks.append(dict(copy=group, prior_uncertainty_sha256=hashlib.sha256(old).hexdigest(),
                       prior_uncertainty_bytes=len(old), prefix_preserved=True,
                       checked_raw_files=baseline['raw_file_count']))
assert (R / P / 'CHECKPOINT.md').read_bytes() == (W / P / 'CHECKPOINT.md').read_bytes()
record = dict(actual_exit=0, check='Append-only histories, stage, new links and raw-byte copies',
              copies=checks, end_to_end=False)
(H / 'documentation-check.json').write_text(json.dumps(record, indent=2) + '\n')
for root in [R, W]:
    for name in ['documentation-check.json', 'finalize.py']:
        (root / P / 'records' / name).write_bytes((H / name).read_bytes())

def command(argv, log):
    run = subprocess.run(argv, cwd=W, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    (H / log).write_bytes(run.stdout)
    return dict(argv=argv, cwd=str(W), actual_exit=run.returncode, log=log)

paths = ['ROADMAP.md', 'FORGE_MISSION_STATUS.md', 'unsure.md', str(P)]
stage = command(['git', 'add', '--', *paths], 'git-add.log')
assert stage['actual_exit'] == 0
full = command(['git', 'diff', '--cached', '--check'], 'full-whitespace.log')
authored = command(['git', 'diff', '--cached', '--check', '--',
                    *paths[:3], str(P / 'CHECKPOINT.md'), str(P / 'COMMANDS.md'),
                    str(P / 'records/checkpoint.py'), str(P / 'records/checkpoint-complete.py'),
                    str(P / 'records/update-tracking.py'), str(P / 'records/finalize.py')],
                   'authored-whitespace.log')
assert full['actual_exit'] in (0, 2)
assert authored['actual_exit'] == 0
whitespace = dict(full=full, authored=authored,
                  scope='Raw proof/source bytes remain unchanged; authored files must pass.',
                  end_to_end=False)
(H / 'whitespace-check.json').write_text(json.dumps(whitespace, indent=2) + '\n')
for root in [R, W]:
    for name in ['whitespace-check.json', 'full-whitespace.log', 'authored-whitespace.log']:
        (root / P / 'records' / name).write_bytes((H / name).read_bytes())
    with (root / P / 'CHECKPOINT.md').open('a') as f:
        f.write('\n## Tracking checks\n\n')
        f.write('Documentation/history/link checks exited `0`. Each uncertainty log retains\n')
        f.write('its exact original prefix, including the separate workspace U310 history.\n')
        f.write(f'Full staged whitespace check: `{full["actual_exit"]}`. Authored-file check: `{authored["actual_exit"]}`.\n')
        f.write('Preserved raw source/log formatting is not rewritten. See the\n')
        f.write('[documentation](records/documentation-check.json) and\n')
        f.write('[whitespace](records/whitespace-check.json) records.\n')
    manifest = {str(f.relative_to(root / P)): sha(f)
                for f in sorted((root / P).rglob('*')) if f.is_file() and f.name != 'MANIFEST.json'}
    (root / P / 'MANIFEST.json').write_text(json.dumps(manifest, indent=2) + '\n')
assert (R / P / 'MANIFEST.json').read_bytes() == (W / P / 'MANIFEST.json').read_bytes()
stage = command(['git', 'add', '--', *paths], 'git-add-final.log')
assert stage['actual_exit'] == 0
changed = subprocess.check_output(['git', 'diff', '--cached', '--name-only'], cwd=W).decode().splitlines()
assert all(name in paths[:3] or name.startswith(str(P) + '/') for name in changed)
assert not subprocess.check_output(['git', 'diff', '--name-only'], cwd=W)
packet = dict(actual_exit=0, packet_members=len(manifest),
              manifest_sha256=sha(W / P / 'MANIFEST.json'), staged_paths=len(changed),
              documentation_exit=0, full_whitespace_exit=full['actual_exit'],
              authored_whitespace_exit=authored['actual_exit'], end_to_end=False)
(H / 'precommit.json').write_text(json.dumps(packet, indent=2) + '\n')
print(json.dumps(packet))
