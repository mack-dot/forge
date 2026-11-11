"""Build the v3.6 deployment-permission repair from the installed v3.5 files.

  python3 -I build_v36.py FORGE_ROOT OUTPUT

One change in gate/provenance/Dockerfile: create /opt/forge before COPY, so
COPY --chmod=0444 does not give the directory the file's mode (a 0444
directory has no search bit, and UID 1000 could not read the ELF). Writes
Dockerfile, implementation.lock, proposed.diff and approval-manifest.json into
OUTPUT. Changes nothing in FORGE_ROOT.
"""
import difflib
import hashlib
import json
from pathlib import Path
import sys

ROOT, OUT = Path(sys.argv[1]).resolve(), Path(sys.argv[2]).resolve()
INSTALLED_LOCK = 'a177cb07e3d1efa3f70c4af62cd707c6a1f2e1df62da8b4c53e23300a7a22be1'
PATH = 'gate/provenance/Dockerfile'
OLD = ("COPY --chown=1000:1000 --chmod=0444 gcd-selftest.elf /opt/forge/gcd-selftest.elf\n"
       "USER 1000:1000\n"
       "WORKDIR /opt/forge\n")
NEW = ("# Create the directory first: COPY --chmod would give a new parent directory\n"
       "# the file's mode 0444, which has no search bit for UID 1000.\n"
       "WORKDIR /opt/forge\n"
       "COPY --chown=1000:1000 --chmod=0444 gcd-selftest.elf /opt/forge/gcd-selftest.elf\n"
       "USER 1000:1000\n")


def sha(data):
    return hashlib.sha256(data).hexdigest()


def dump(value):
    return (json.dumps(value, indent=2, sort_keys=True) + '\n').encode()


def main():
    lock_bytes = (ROOT / 'gate/provenance/implementation.lock').read_bytes()
    assert sha(lock_bytes) == INSTALLED_LOCK, 'INSTALLED_LOCK'
    lock = json.loads(lock_bytes)
    assert dump(lock) == lock_bytes, 'LOCK_FORMAT'
    old = (ROOT / PATH).read_text()
    assert sha(old.encode()) == lock['files'][PATH], PATH
    assert old.count(OLD) == 1, 'OLD_BLOCK'
    new = old.replace(OLD, NEW)
    lock['files'][PATH] = sha(new.encode())
    new_lock = dump(lock)
    diff = ''.join(difflib.unified_diff(old.splitlines(True), new.splitlines(True), 'a/' + PATH, 'b/' + PATH))
    diff += ''.join(difflib.unified_diff(lock_bytes.decode().splitlines(True), new_lock.decode().splitlines(True),
                                         'a/gate/provenance/implementation.lock', 'b/gate/provenance/implementation.lock'))
    OUT.mkdir(parents=True, exist_ok=False)
    (OUT / 'Dockerfile').write_text(new)
    (OUT / 'implementation.lock').write_bytes(new_lock)
    (OUT / 'proposed.diff').write_text(diff)
    manifest = {'installed_lock_sha256': INSTALLED_LOCK, 'new_lock_sha256': sha(new_lock),
                'diff_sha256': sha(diff.encode()),
                'files': {PATH: {'old_sha256': sha(old.encode()), 'new_sha256': sha(new.encode())},
                          'gate/provenance/implementation.lock': {'old_sha256': INSTALLED_LOCK,
                                                                  'new_sha256': sha(new_lock)}},
                'applied': False, 'end_to_end': False}
    (OUT / 'approval-manifest.json').write_bytes(dump(manifest))
    print(json.dumps(manifest, indent=2))


if __name__ == '__main__':
    main()
