#!/usr/bin/env python3
"""Build the unapplied v3.1 candidate: v3 plus pre-execution authentication.

Adds gate/provenance/bootstrap.py, routes every workflow Python step through it
after an inline byte check, makes the verifier require the commit's lock to equal
its own, uses a fresh Git store per verification, and reports HTTP errors as
rejections. Contract, policy and contract_approval_commit stay unchanged.
Writes only under this directory.
"""
import difflib
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
OUT = HERE / 'candidate'
V3 = HERE.parent / 'provenance-hosted-v3'
INSTALLED_LOCK = '9b10a2376c6b6de46661819a528f3b4e1251f27d76ac21e071b1cfb971224a76'
V3_MANIFEST = '18b8f59b6ed32b4958985c04e82e937616b6e9a3c9363a837ac186c47477b1c8'
AUTH_STEP = (
    '      - name: Authenticate the checkout before any repository code\n'
    '        run: |\n'
    '          python3 -I -S -B -c \'import hashlib, json, sys\n'
    '          lock = open("gate/provenance/implementation.lock", "rb").read()\n'
    '          if hashlib.sha256(lock).hexdigest() != sys.argv[1]: sys.exit("IMPLEMENTATION_LOCK")\n'
    '          boot = open("gate/provenance/bootstrap.py", "rb").read()\n'
    '          if hashlib.sha256(boot).hexdigest() != json.loads(lock)["files"]["gate/provenance/bootstrap.py"]:'
    ' sys.exit("BOOTSTRAP_BYTES")\' "$FORGE_STAGE9_IMPLEMENTATION"\n'
    '          python3 -I -S -B gate/provenance/bootstrap.py --implementation-sha256'
    ' "$FORGE_STAGE9_IMPLEMENTATION" --check\n')
BOOT = 'python3 -I -S -B gate/provenance/bootstrap.py --implementation-sha256 "$FORGE_STAGE9_IMPLEMENTATION" -- '


def sha(data):
    return hashlib.sha256(data).hexdigest()


def dump(value):
    return (json.dumps(value, indent=2, sort_keys=True) + '\n').encode()


def edit(text, pairs):
    for old, new, count in pairs:
        assert text.count(old) == count, ('EDIT_ANCHOR', old[:60], text.count(old))
        text = text.replace(old, new)
    return text


def pinned_python(text):
    start = text.index('      - name: Python 3.10.11 from a hash-checked archive\n')
    end = text.index('          echo "LD_LIBRARY_PATH=$P/lib" >> "$GITHUB_ENV"\n', start)
    return text[start:end] + '          echo "LD_LIBRARY_PATH=$P/lib" >> "$GITHUB_ENV"\n'


def workflow(text, runs):
    block = pinned_python(text)
    count = text.count(block)
    return edit(text, [(block, block + AUTH_STEP, count),
                       ('run: python3 gate/provenance/', 'run: ' + BOOT + 'gate/provenance/', runs)])


def common(text):
    return edit(text, [
        ('import sys\nimport urllib.request\n', 'import sys\nimport tempfile\nimport urllib.error\nimport urllib.request\n', 1),
        ("    with urllib.request.urlopen(req) as response:\n        data = response.read()\n"
         "        require(response.status == 200, 'GITHUB_HTTP_STATUS')\n",
         "    try:\n        with urllib.request.urlopen(req) as response:\n            data = response.read()\n"
         "            require(response.status == 200, 'GITHUB_HTTP_STATUS')\n"
         "    except urllib.error.HTTPError as error:\n"
         "        # Missing, invalid or under-scoped credentials end here as explicit\n"
         "        # rejections, never as accepted metadata.\n"
         "        raise Rejected('GITHUB_HTTP_STATUS:' + str(error.code)) from None\n", 1),
        ("    locked = implementation['files']\n",
         "    locked = implementation['files']\n"
         "    # The commit must carry exactly the verifier's own approved lock.\n"
         "    lock_entry = entries.get('gate/provenance/implementation.lock')\n"
         "    require(lock_entry is not None and lock_entry[1] == 'blob', 'IMPLEMENTATION_LOCK_AT_COMMIT')\n"
         "    _, data, _ = records.run(['git', '--git-dir', git_dir, 'cat-file', 'blob', lock_entry[2]], 'source-lock')\n"
         "    require(data == (HERE / 'implementation.lock').read_bytes(), 'IMPLEMENTATION_LOCK_AT_COMMIT')\n", 1),
        ("    git_dir = Path(os.environ.get('FORGE_VERIFIER_GIT_DIR', '')).resolve()\n"
         "    require(os.environ.get('FORGE_VERIFIER_GIT_DIR') and not git_dir.is_relative_to(ROOT),\n"
         "            'VERIFIER_GIT_DIR_LOCATION')\n"
         "    if not git_dir.exists():\n"
         "        records.run(['git', 'init', '-q', '--bare', git_dir], 'source-store')\n",
         "    # A fresh store per verification: no stale or locally altered objects.\n"
         "    git_dir = Path(tempfile.mkdtemp(prefix='forge-verifier-git-'))\n"
         "    require(not git_dir.is_relative_to(ROOT), 'VERIFIER_GIT_DIR_LOCATION')\n"
         "    records.run(['git', 'init', '-q', '--bare', git_dir], 'source-store')\n", 1),
    ])


def main():
    assert sha((ROOT / 'gate/provenance/implementation.lock').read_bytes()) == INSTALLED_LOCK, 'INSTALLED_LOCK'
    manifest_bytes = (V3 / 'approval-manifest.json').read_bytes()
    assert sha(manifest_bytes) == V3_MANIFEST, 'V3_MANIFEST'
    v3 = json.loads(manifest_bytes)
    base = {}
    for path, item in v3['files'].items():
        data = (V3 / 'candidate' / path).read_bytes()
        assert sha(data) == item['new_sha256'], ('V3_CANDIDATE', path)
        base[path] = data
    new = dict(base)
    new['gate/provenance/common.py'] = common(base['gate/provenance/common.py'].decode()).encode()
    new['.github/workflows/provenance.yml'] = workflow(base['.github/workflows/provenance.yml'].decode(), 5).encode()
    new['.github/workflows/provenance-negative.yml'] = workflow(
        base['.github/workflows/provenance-negative.yml'].decode(), 2).encode()
    new['gate/provenance/bootstrap.py'] = (HERE / 'src/bootstrap.py').read_bytes()
    lock = json.loads(base['gate/provenance/implementation.lock'])
    for path, data in new.items():
        if path != 'gate/provenance/implementation.lock':
            lock['files'][path] = sha(data)
    new['gate/provenance/implementation.lock'] = dump(lock)
    patch, manifest = [], {'base_lock_sha256': INSTALLED_LOCK, 'contract_unchanged': True,
                           'derived_from_v3_manifest': sha(manifest_bytes), 'end_to_end': False, 'files': {}}
    for path in sorted(new):
        old = (ROOT / path).read_bytes() if (ROOT / path).exists() else b''
        target = OUT / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(new[path])
        lines = list(difflib.unified_diff(old.decode().splitlines(True), new[path].decode().splitlines(True),
                                          'a/' + path if old else '/dev/null', 'b/' + path, n=3))
        patch.append(''.join([f'diff --git a/{path} b/{path}\n'] + (['new file mode 100644\n'] if not old else [])
                             + lines))
        manifest['files'][path] = {'old_sha256': sha(old) if old else None, 'new_sha256': sha(new[path])}
    diff = ''.join(patch).encode()
    (HERE / 'proposed.diff').write_bytes(diff)
    manifest.update(diff_sha256=sha(diff), new_lock_sha256=sha(new['gate/provenance/implementation.lock']),
                    locked_files=len(lock['files']))
    (HERE / 'approval-manifest.json').write_bytes(dump(manifest))
    print(json.dumps({k: manifest[k] for k in ('derived_from_v3_manifest', 'diff_sha256', 'new_lock_sha256',
                                               'locked_files')}, indent=2))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
