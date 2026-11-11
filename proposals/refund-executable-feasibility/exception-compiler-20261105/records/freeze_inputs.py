from pathlib import Path
import hashlib, json

ROOT = Path('/Users/mackianni/forge')
OUT = Path(__file__).resolve().parent
def sha(path):
    h = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for chunk in iter(lambda: stream.read(1048576), b''):
            h.update(chunk)
    return h.hexdigest()

a = json.loads((OUT.parent / 'attempt-0008/dependency-snapshot.json').read_text())
b = json.loads((ROOT / 'proposals/refund-executable-feasibility/runtime-premises-20261104/records/readback.json').read_text())
inputs = dict(a['input_files'])
for path, value in b['dependency_files'].items():
    assert path not in inputs or inputs[path] == value, path
    inputs[path] = value
for rel, value in a['new_theory_files'].items():
    inputs[str(OUT.parent / 'attempt-0008/concrete-0001' / rel)] = value
for path, value in inputs.items():
    assert sha(path) == value, path
packets = {}
for name in ['exception-initialization-20261105', 'runtime-premises-20261104']:
    packet = ROOT / 'proposals/refund-executable-feasibility' / name
    manifest = json.loads((packet / 'MANIFEST.json').read_text())
    files = manifest['files'] if 'files' in manifest else manifest
    for path, value in files.items():
        assert sha(packet / path) == value, path
    packets[name] = len(files)
record = {'actual_exit': 0, 'input_files': inputs,
          'source_closure': a['closure_nodes'], 'compiler_closure': b['closure'],
          'foundation_axioms': b['closure_axioms'], 'checked_parent_packets': packets,
          'end_to_end': False}
(OUT / 'inputs.json').write_text(json.dumps(record, indent=2) + '\n')
print(json.dumps({'actual_exit': 0, 'input_files': len(inputs), 'packets': packets}))
