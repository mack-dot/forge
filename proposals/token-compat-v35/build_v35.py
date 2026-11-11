"""Build the v3.5 token-compatibility change from the installed v3.4 files.

  python3 -I build_v35.py FORGE_ROOT OUTPUT

One rule changes in gate/provenance/common.py: GitHub tokens are opaque
(stateless installation tokens are about 520 characters and contain '.' and
'-'). Writes common.py, implementation.lock, proposed.diff and
approval-manifest.json into OUTPUT. Changes nothing in FORGE_ROOT.
"""
import difflib
import hashlib
import json
from pathlib import Path
import sys

ROOT, OUT = Path(sys.argv[1]).resolve(), Path(sys.argv[2]).resolve()
INSTALLED_LOCK = '9bf8f905c9359cd6e5f926657ff434354b80028f45417f962635d6ee86284c90'
PATH = 'gate/provenance/common.py'
OLD_RULE = ("        token = os.environ.get(token_name, '')\n"
            "        require(re.fullmatch(r'[A-Za-z0-9_]{20,255}', token), 'GITHUB_TOKEN_REQUIRED:' + token_name)\n")
NEW_RULE = ("        token = os.environ.get(token_name, '')\n"
            "        # Tokens are opaque and vary in length (stateless installation tokens are\n"
            "        # about 520 characters). RFC 6750 token characters only: no space, quote,\n"
            "        # control character or line break can reach the request header.\n"
            "        require(20 <= len(token) <= 4096 and re.fullmatch(r'[A-Za-z0-9._~+/-]+=*', token),\n"
            "                'GITHUB_TOKEN_REQUIRED:' + token_name)\n")


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
    assert old.count(OLD_RULE) == 1, 'OLD_RULE'
    new = old.replace(OLD_RULE, NEW_RULE)
    lock['files'][PATH] = sha(new.encode())
    new_lock = dump(lock)
    diff = ''.join(difflib.unified_diff(old.splitlines(True), new.splitlines(True), 'a/' + PATH, 'b/' + PATH))
    diff += ''.join(difflib.unified_diff(lock_bytes.decode().splitlines(True), new_lock.decode().splitlines(True),
                                         'a/gate/provenance/implementation.lock', 'b/gate/provenance/implementation.lock'))
    OUT.mkdir(parents=True, exist_ok=False)
    (OUT / 'common.py').write_text(new)
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
