"""Create and read back a local integrity inventory. This does not authenticate it."""
import hashlib
import json
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parent
EXCLUDE = {'MANIFEST.sha256.json', 'SEAL.json'}

def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for data in iter(lambda: stream.read(1048576), b''):
            h.update(data)
    return h.hexdigest()

def inventory():
    result = {}
    for path in sorted(ROOT.rglob('*')):
        relative = str(path.relative_to(ROOT))
        if relative in EXCLUDE:
            continue
        if path.is_symlink():
            # Record package aliases without following them or reading other paths.
            target = os.readlink(path)
            result[relative] = {'kind': 'symlink', 'target': target,
                'bytes': len(target.encode()), 'sha256': hashlib.sha256(target.encode()).hexdigest()}
        elif path.is_file():
            result[relative] = {'kind': 'file', 'bytes': path.stat().st_size, 'sha256': sha(path)}
    return result

files = inventory()
manifest = ROOT / 'MANIFEST.sha256.json'
assert not manifest.exists(), 'Do not overwrite a completed inventory'
manifest.write_text(json.dumps(files, indent=2, sort_keys=True) + '\n')
assert json.loads(manifest.read_text()) == inventory()
result = {'exit_code': 0, 'files': len(files), 'bytes': sum(v['bytes'] for v in files.values()),
          'manifest_sha256': sha(manifest), 'read_back_matches': True,
          'inventory_authenticates_provenance': False, 'off_machine_backup_confirmed': False,
          'end_to_end': False}
(ROOT / 'SEAL.json').write_text(json.dumps(result, indent=2, sort_keys=True) + '\n')
print(json.dumps(result))
