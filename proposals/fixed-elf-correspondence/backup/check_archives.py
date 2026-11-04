"""Check archive bytes and all members without extracting or printing contents."""
import hashlib
import json
from pathlib import Path, PurePosixPath
import sys
import tarfile

EXPECTED = {
    'raw': ('e2491743d39ee0fad290c34c558b3f147e4a72125e72171615cee49674f2986b',
            'd2f6313b583ba77e1f6c44f29566ac258d44d6d62137e9f62ae2ff73aed204f8'),
    'sanitized': ('ac84dd27cfe9b7a57f1eb085fd37d06df787d7dddc7f9b94fe52c06c92996570',
                  'f4a8651e992778eba621d7b2214abde6a94945323ca080d25c3ddba91c281c77'),
}

def sha(data):
    return hashlib.sha256(data).hexdigest()

def check(directory):
    manifests = {}
    rows = []
    for kind, (archive_hash, manifest_hash) in EXPECTED.items():
        stem = 'forge-records-' + kind + '-2026-11-01'
        archive = directory / (stem + '.tar.xz')
        manifest_bytes = (directory / (stem + '.manifest.json')).read_bytes()
        if sha(archive.read_bytes()) != archive_hash or sha(manifest_bytes) != manifest_hash:
            raise ValueError(kind + ': archive or manifest digest mismatch')
        manifest = json.loads(manifest_bytes)
        manifests[kind] = manifest
        with tarfile.open(archive, 'r:xz') as stream:
            members = stream.getmembers()
            names = [member.name for member in members]
            if len(names) != len(set(names)) or set(names) != set(manifest) | {'MANIFEST.sha256.json'}:
                raise ValueError(kind + ': member set mismatch')
            for member in members:
                path = PurePosixPath(member.name)
                if not member.isfile() or path.is_absolute() or '..' in path.parts:
                    raise ValueError(kind + ': unsafe member type or path')
                data = stream.extractfile(member).read()
                if member.name == 'MANIFEST.sha256.json':
                    if data != manifest_bytes:
                        raise ValueError(kind + ': embedded manifest mismatch')
                elif sha(data) != manifest[member.name]['sha256'] or len(data) != manifest[member.name]['bytes']:
                    raise ValueError(kind + ': member digest or length mismatch')
        rows.append({'kind': kind, 'archive_sha256': archive_hash,
                     'manifest_sha256': manifest_hash, 'members_checked': len(manifest),
                     'embedded_manifest_matches': True, 'mismatches': 0})
    if set(manifests['raw']) != set(manifests['sanitized']):
        raise ValueError('raw/sanitized member sets differ')
    for name, entry in manifests['sanitized'].items():
        if entry['raw_sha256'] != manifests['raw'][name]['sha256']:
            raise ValueError('raw/sanitized map mismatch')
        if entry['modified'] != (entry['sha256'] != entry['raw_sha256']):
            raise ValueError('sanitization flag mismatch')
    return {'archives': rows, 'raw_sanitized_map_matches': True,
            'off_machine_copy_established': False,
            'note': 'Integrity only. Storage independence requires separate evidence.'}

if __name__ == '__main__':
    try:
        result = check(Path(sys.argv[1]))
    except Exception as error:
        print(json.dumps({'result': 'failed', 'error_type': type(error).__name__, 'error': str(error)}))
        sys.exit(1)
    print(json.dumps(result, indent=2, sort_keys=True))
