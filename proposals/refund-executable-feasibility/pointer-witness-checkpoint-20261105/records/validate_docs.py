"""Validate tracking edits and captured bytes; no proof judgment is made here."""
from pathlib import Path
import hashlib
import json
import re
import shutil

ROOT = Path('/Users/mackianni/forge')
WT = Path('/private/tmp/forge-readiness-docs-20261103')
HERE = Path(__file__).resolve().parent
REL = Path('proposals/refund-executable-feasibility/pointer-witness-checkpoint-20261105')
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
readback = json.loads((HERE / 'checkpoint-readback.json').read_text())

def block(text, title):
    start = text.index(title)
    end = text.find('\n## ', start + len(title))
    return start, len(text) if end == -1 else end

checks = {}
for name, root in [('workspace', ROOT), ('worktree', WT)]:
    for file, detail in readback['before_docs'][name].items():
        p = HERE / 'before' / name / file
        assert sha(p) == detail['sha256'] and p.stat().st_size == detail['bytes']
    old = {f: (HERE / 'before' / name / f).read_text() for f in readback['before_docs'][name]}
    new = {f: (root / f).read_text() for f in old}
    a,b = block(new['ROADMAP.md'], '## Pointer-witness proof captured; complete premise audit open — U308\n')
    assert new['ROADMAP.md'][:a] + new['ROADMAP.md'][b+1:] == old['ROADMAP.md']
    a,b = block(new['FORGE_MISSION_STATUS.md'], '## Resume here — pointer-witness audit incomplete (U308)\n')
    status_remainder = new['FORGE_MISSION_STATUS.md'][:a] + new['FORGE_MISSION_STATUS.md'][b+1:]
    a,b = block(status_remainder, '## Current execution checklist\n')
    c,d = block(old['FORGE_MISSION_STATUS.md'], '## Current execution checklist\n')
    assert status_remainder[:a] + old['FORGE_MISSION_STATUS.md'][c:d] + status_remainder[b:] == old['FORGE_MISSION_STATUS.md']
    assert (root / 'unsure.md').read_bytes().startswith((HERE / 'before' / name / 'unsure.md').read_bytes())
    assert new['unsure.md'].count('## U308 ') == 1
    ids = re.findall(r'^## (U\d+)\b', new['unsure.md'], re.M)
    assert len(ids) == len(set(ids))
    sections = [(root / REL / 'CHECKPOINT.md', (root / REL / 'CHECKPOINT.md').read_text())]
    for file, title in [('ROADMAP.md', '## Pointer-witness proof captured; complete premise audit open — U308\n'),
                        ('FORGE_MISSION_STATUS.md', '## Resume here — pointer-witness audit incomplete (U308)\n'),
                        ('FORGE_MISSION_STATUS.md', '## Current execution checklist\n')]:
        a,b = block(new[file], title)
        sections.append((root / file, new[file][a:b]))
    links = 0
    for p, text in sections:
        for target in re.findall(r'\[[^\]]+\]\(([^)]+)\)', text):
            filename = target.split('#', 1)[0]
            if filename:
                assert (p.parent / filename).is_file(), (p, target)
                links += 1
    for path, expected in readback['captured_files'].items():
        assert sha(root / REL / 'records' / path) == expected
    checks[name] = {'old_history_preserved': True, 'uncertainty_append_only': True,
                    'unique_uncertainty_ids': len(ids), 'linked_files': links,
                    'captured_files_unchanged': len(readback['captured_files'])}
assert (ROOT / 'unsure.md').read_bytes() != (WT / 'unsure.md').read_bytes()
result = {'actual_exit': 0, 'scope': 'documentation/history/link and byte validation',
          'checks': checks, 'new_proof_execution': False, 'end_to_end': False}
(HERE / 'documentation-check.json').write_text(json.dumps(result, indent=2) + '\n')
for root in (ROOT, WT):
    shutil.copyfile(HERE / 'documentation-check.json', root / REL / 'records/documentation-check.json')
    shutil.copyfile(Path(__file__), root / REL / 'records/validate_docs.py')
print(json.dumps(result))
