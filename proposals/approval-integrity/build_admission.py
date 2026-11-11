"""Build the release-admission change (v3.4 proposal) from the installed v3.3 files.

  python3 -I build_admission.py FORGE_ROOT OUTPUT

Writes the two changed files, the new implementation.lock, proposed.diff and
approval-manifest.json into OUTPUT. Changes nothing in FORGE_ROOT.
"""
import difflib
import hashlib
import json
from pathlib import Path
import sys

ROOT, OUT = Path(sys.argv[1]).resolve(), Path(sys.argv[2]).resolve()
HERE = Path(__file__).resolve().parent
INSTALLED_LOCK = 'a809f7017ce0980b26b81896216af7be30591a67a564adff273df576e2453a55'
MARKER = '# --- proposed for gate/provenance/common.py ---\n'


def sha(data):
    return hashlib.sha256(data).hexdigest()


def dump(value):
    return (json.dumps(value, indent=2, sort_keys=True) + '\n').encode()


def edit(text, old, new):
    assert text.count(old) == 1, old
    return text.replace(old, new)


def main():
    lock_bytes = (ROOT / 'gate/provenance/implementation.lock').read_bytes()
    assert sha(lock_bytes) == INSTALLED_LOCK, 'INSTALLED_LOCK'
    lock = json.loads(lock_bytes)
    assert dump(lock) == lock_bytes, 'LOCK_FORMAT'
    old = {path: (ROOT / path).read_text() for path in ('gate/provenance/common.py', 'gate/provenance/release.py')}
    for path, text in old.items():
        assert sha(text.encode()) == lock['files'][path], path
    block = (HERE / 'lineage.py').read_text().split(MARKER, 1)[1]
    new = dict(old)
    new['gate/provenance/common.py'] = edit(old['gate/provenance/common.py'], '\n\ndef signature(',
                                            '\n\n' + block + '\n\ndef signature(')
    release = edit(old['gate/provenance/release.py'],
                   'from common import (ROOT, HERE, Rejected, Records, canonical, context, digest, files,\n',
                   'from common import (ROOT, HERE, Rejected, Records, approved_lineage, canonical, context, digest, files,\n')
    release = edit(release,
                   "    run_identity(policy, request, read(root / 'proof/receipt.json')['execution'], records)\n",
                   "    run_identity(policy, request, read(root / 'proof/receipt.json')['execution'], records)\n"
                   "    lineage = approved_lineage(policy, request['expected_source_commit'], records)\n")
    release = edit(release,
                   "            'freshness_trust_assumption': 'GitHub executed the locked workflow in the recorded run',\n",
                   "            'freshness_trust_assumption': 'GitHub executed the locked workflow in the recorded run',\n"
                   "            'approved_lineage': lineage,\n"
                   "            'approval_trust_assumption': 'only the owner uses the owner account',\n")
    new['gate/provenance/release.py'] = release
    for path, text in new.items():
        lock['files'][path] = sha(text.encode())
    new_lock = dump(lock)
    diff = ''.join(''.join(difflib.unified_diff(old[path].splitlines(True), new[path].splitlines(True),
                                                'a/' + path, 'b/' + path)) for path in sorted(old))
    diff += ''.join(difflib.unified_diff(lock_bytes.decode().splitlines(True), new_lock.decode().splitlines(True),
                                         'a/gate/provenance/implementation.lock', 'b/gate/provenance/implementation.lock'))
    OUT.mkdir(parents=True, exist_ok=False)
    for path, text in new.items():
        (OUT / Path(path).name).write_text(text)
    (OUT / 'implementation.lock').write_bytes(new_lock)
    (OUT / 'proposed.diff').write_text(diff)
    manifest = {'installed_lock_sha256': INSTALLED_LOCK, 'new_lock_sha256': sha(new_lock),
                'diff_sha256': sha(diff.encode()),
                'files': {path: {'old_sha256': sha(old[path].encode()), 'new_sha256': sha(new[path].encode())}
                          for path in sorted(new)},
                'lineage_py_sha256': sha((HERE / 'lineage.py').read_bytes()),
                'applied': False, 'end_to_end': False}
    (OUT / 'approval-manifest.json').write_bytes(dump(manifest))
    print(json.dumps(manifest, indent=2))


if __name__ == '__main__':
    main()
