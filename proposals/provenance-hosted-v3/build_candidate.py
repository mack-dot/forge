#!/usr/bin/env python3
"""Build the unapplied v3 candidate: v2 plus the U104 corrections.

F1: the verifier fetches the exact commit with its own read-only credential
and rejects unlocked code beside locked bytes. F2: signing jobs need an explicit
repository variable. F3: a hash-checked Python archive replaces setup-python.
F4: the Docker key file is checked by hash. The approved contract, policy and
contract_approval_commit stay unchanged. Writes only under this directory.
"""
import difflib
import glob
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
OUT = HERE / 'candidate'
V2 = HERE.parent / 'provenance-hosted-v2'
INSTALLED_LOCK = '9b10a2376c6b6de46661819a528f3b4e1251f27d76ac21e071b1cfb971224a76'
V2_MANIFEST = 'd37d83278c17c2dba92122c71e4a53d34a5a87f88156a97977f378f1bff24585'
SETUP_PYTHON = ('      - name: Python 3.10.11 required by the gate\n'
                '        uses: actions/setup-python@6d4fd22b20465ccc0f7354476588e8df7c9ca0e0 # v7.1.0\n'
                '        with:\n'
                '          python-version: 3.10.11\n')
PINNED_PYTHON = (
    '      - name: Python 3.10.11 from a hash-checked archive\n'
    '        run: |\n'
    '          P="$RUNNER_TEMP/forge-python"\n'
    '          A="$RUNNER_TEMP/python-3.10.11.tar.gz"\n'
    '          curl -fsSL -o "$A" https://github.com/actions/python-versions/releases/download/'
    '3.10.11-11114431484/python-3.10.11-linux-24.04-x64.tar.gz\n'
    '          echo "3d10b78a944ee1cf236bf09f3913d0db359d3e80954dbda6d55f447b34099bae  $A" | sha256sum -c\n'
    '          mkdir -p "$P" && tar -xzf "$A" -C "$P"\n'
    '          LD_LIBRARY_PATH="$P/lib" "$P/bin/python3" -m ensurepip --default-pip\n'
    '          echo "$P/bin" >> "$GITHUB_PATH"\n'
    '          echo "LD_LIBRARY_PATH=$P/lib" >> "$GITHUB_ENV"\n')
NEW_FETCH = '''def fetch(url, records, label, *, token_name=None):
    # HTTPS transport/JSON handling only; this does not verify a signature.
    headers = {'Accept': 'application/vnd.github+json', 'User-Agent': 'forge-stage9'}
    if token_name is not None:
        # Each caller names its own read-only token; records never contain it.
        token = os.environ.get(token_name, '')
        require(re.fullmatch(r'[A-Za-z0-9_]{20,255}', token), 'GITHUB_TOKEN_REQUIRED:' + token_name)
        headers['Authorization'] = 'Bearer ' + token
    req = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(req) as response:
'''
NEW_IDENTITY = '''# Roots the sign job (gate/provenance) and the proof container (scripts,
# examples/binary) can import or load. Code there must be locked, so an added
# module cannot run beside approved bytes (U104, F1).
EXECUTABLE_ROOTS = ('gate/provenance/', 'scripts/', 'examples/binary/')
CODE_SUFFIXES = ('.py', '.pyc', '.pyo', '.pyd', '.so', '.dylib', '.pth', '.v', '.vo', '.vos', '.vok',
                 '.glob', '.c', '.h', '.sh')


def source_tree(git_dir, commit, implementation, records):
    """Check locked bytes and reject unlocked code at an exact commit in a Git store."""
    _, out, _ = records.run(['git', '--git-dir', git_dir, 'rev-parse', '--verify', commit + '^{commit}'],
                            'source-commit')
    require(out.decode().strip() == commit, 'SOURCE_COMMIT')
    _, listing, _ = records.run(['git', '--git-dir', git_dir, 'ls-tree', '-r', '-z', '--full-tree', commit],
                                'source-tree')
    entries = {}
    for item in listing.split(b'\\0'):
        if item:
            meta, path = item.split(b'\\t', 1)
            mode, kind, obj = meta.decode().split()
            entries[path.decode()] = (mode, kind, obj)
    locked = implementation['files']
    for path, (mode, kind, obj) in sorted(entries.items()):
        if path.startswith(EXECUTABLE_ROOTS) and path != 'gate/provenance/implementation.lock':
            require(mode in ('100644', '100755') and kind == 'blob', 'SOURCE_ENTRY_TYPE:' + path)
            require('__pycache__' not in path.split('/') and (path in locked or (
                not path.startswith('gate/provenance/') and not path.endswith(CODE_SUFFIXES))),
                'UNLOCKED_EXECUTABLE:' + path)
    for path, expected in sorted(locked.items()):
        require(path in entries and entries[path][1] == 'blob', 'AUTHENTICATED_WORKFLOW_INPUT:' + path)
        _, data, _ = records.run(['git', '--git-dir', git_dir, 'cat-file', 'blob', entries[path][2]], 'source-blob')
        require(sha(data) == expected, 'AUTHENTICATED_WORKFLOW_INPUT:' + path)


def repository_identity(policy, implementation, commit, records):
    # Only the independent release verifier runs this, with its own read-only
    # credential and its own Git store; never inside a workflow job.
    require(os.environ.get('GITHUB_ACTIONS') != 'true', 'VERIFIER_NOT_INDEPENDENT')
    require(re.fullmatch('[0-9a-f]{40}', commit), 'EXPECTED_SOURCE_COMMIT')
    repo = policy['signer']['repository']
    info = parse(fetch('https://api.github.com/repos/' + repo, records, 'repository',
                       token_name='FORGE_VERIFIER_GITHUB_TOKEN'))
    require(info['full_name'] == repo and info['id'] == policy['signer']['repository_id']
            and info['owner']['id'] == policy['signer']['owner_id'], 'REPOSITORY_IDENTITY')
    git_dir = Path(os.environ.get('FORGE_VERIFIER_GIT_DIR', '')).resolve()
    require(os.environ.get('FORGE_VERIFIER_GIT_DIR') and not git_dir.is_relative_to(ROOT),
            'VERIFIER_GIT_DIR_LOCATION')
    if not git_dir.exists():
        records.run(['git', 'init', '-q', '--bare', git_dir], 'source-store')
    # The credential reaches git only through the environment, never argv or records.
    basic = base64.b64encode(('x-access-token:' + os.environ['FORGE_VERIFIER_GITHUB_TOKEN']).encode()).decode()
    env = dict(os.environ, GIT_TERMINAL_PROMPT='0', GIT_CONFIG_COUNT='1',
               GIT_CONFIG_KEY_0='http.https://github.com/.extraheader',
               GIT_CONFIG_VALUE_0='AUTHORIZATION: basic ' + basic)
    records.run(['git', '--git-dir', git_dir, 'fetch', '-q', '--depth', '1',
                 'https://github.com/' + repo + '.git', commit], 'source-fetch', env=env)
    source_tree(git_dir, commit, implementation, records)
'''


def sha(data):
    return hashlib.sha256(data).hexdigest()


def dump(value):
    return (json.dumps(value, indent=2, sort_keys=True) + '\n').encode()


def edit(text, pairs):
    for old, new, count in pairs:
        assert text.count(old) == count, ('EDIT_ANCHOR', old[:60], text.count(old))
        text = text.replace(old, new)
    return text


def common(text):
    start = text.index('def fetch(url, records, label):\n')
    end = text.index('    with urllib.request.urlopen(req) as response:\n', start)
    end += len('    with urllib.request.urlopen(req) as response:\n')
    text = text[:start] + NEW_FETCH + text[end:]
    start = text.index('def repository_identity(policy, implementation, commit, records):\n')
    end = text.index("'AUTHENTICATED_WORKFLOW_INPUT:' + path)\n", start) + len("'AUTHENTICATED_WORKFLOW_INPUT:' + path)\n")
    text = text[:start] + NEW_IDENTITY + text[end:]
    return edit(text, [('import hashlib\nimport json\n', 'import base64\nimport hashlib\nimport json\n', 1)])


def main():
    lock_path = ROOT / 'gate/provenance/implementation.lock'
    assert sha(lock_path.read_bytes()) == INSTALLED_LOCK, 'INSTALLED_LOCK'
    installed = json.loads(lock_path.read_bytes())
    assert sha((V2 / 'approval-manifest.json').read_bytes()) == V2_MANIFEST, 'V2_MANIFEST'
    v2 = json.loads((V2 / 'approval-manifest.json').read_bytes())
    base = {}
    for path, item in v2['files'].items():
        data = (V2 / 'candidate' / path).read_bytes()
        assert sha(data) == item['new_sha256'], ('V2_CANDIDATE', path)
        base[path] = data
    data = (ROOT / 'gate/provenance/common.py').read_bytes()
    assert sha(data) == installed['files']['gate/provenance/common.py'], 'INSTALLED_COMMON'
    new = dict(base)
    new['gate/provenance/common.py'] = common(data.decode()).encode()
    new['gate/provenance/preflight.py'] = edit(base['gate/provenance/preflight.py'].decode(), [
        ("                              records, 'producer-run'))\n",
         "                              records, 'producer-run', token_name='FORGE_PRODUCER_GITHUB_TOKEN'))\n", 1),
    ]).encode()
    new['gate/provenance/hosted_setup.py'] = edit(base['gate/provenance/hosted_setup.py'].decode(), [
        ('from common import ROOT, HERE, Records, context, files, read, require, write\n',
         'from common import ROOT, HERE, Records, context, digest, files, read, require, write\n', 1),
        ("    require(fingerprints[:1] == [apt['key_fingerprint']], 'DOCKER_APT_KEY')\n",
         "    # The exact key file, not only its first fingerprint (U104, F4).\n"
         "    require(digest(key) == apt['key_sha256'] and fingerprints[:1] == [apt['key_fingerprint']],\n"
         "            'DOCKER_APT_KEY')\n", 1),
    ]).encode()
    runtime = json.loads(base['gate/provenance/runtime.json'])
    runtime['profiles']['producer']['docker_apt']['key_sha256'] = \
        '1500c1f56fa9e26b9b8f42452a553675796ade0807cdce11975eb98170b3a570'
    new['gate/provenance/runtime.json'] = dump(runtime)
    new['.github/workflows/provenance.yml'] = edit(base['.github/workflows/provenance.yml'].decode(), [
        (SETUP_PYTHON, PINNED_PYTHON, 2),
        ("    needs: proof\n    runs-on: ubuntu-24.04\n",
         "    needs: proof\n    if: vars.FORGE_SIGNING_AUTHORIZED == 'true'\n    runs-on: ubuntu-24.04\n", 1),
    ]).encode()
    new['.github/workflows/provenance-negative.yml'] = edit(
        base['.github/workflows/provenance-negative.yml'].decode(), [
            (SETUP_PYTHON, PINNED_PYTHON, 1),
            ("    if: github.repository == 'mack-dot/forge' && github.ref == 'refs/heads/main'\n",
             "    if: github.repository == 'mack-dot/forge' && github.ref == 'refs/heads/main'"
             " && vars.FORGE_SIGNING_AUTHORIZED == 'true'\n", 1),
            ("      - name: Check pins and authenticate producer run metadata\n"
             "        env:\n          FORGE_STAGE7_ROOT: ${{ runner.temp }}/seed\n",
             "      - name: Check pins and authenticate producer run metadata\n"
             "        env:\n          FORGE_STAGE7_ROOT: ${{ runner.temp }}/seed\n"
             "          FORGE_PRODUCER_GITHUB_TOKEN: ${{ github.token }}\n", 1),
        ]).encode()
    lock = json.loads(base['gate/provenance/implementation.lock'])
    for path, data in new.items():
        if path != 'gate/provenance/implementation.lock':
            lock['files'][path] = sha(data)
    # Every script the proof container can import is now locked (U104, F1).
    for path in sorted(glob.glob('scripts/*.py', root_dir=ROOT)):
        lock['files'].setdefault(path, sha((ROOT / path).read_bytes()))
    new['gate/provenance/implementation.lock'] = dump(lock)
    patch, manifest = [], {'base_lock_sha256': INSTALLED_LOCK, 'contract_unchanged': True,
                           'derived_from_v2_manifest': V2_MANIFEST, 'end_to_end': False, 'files': {}}
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
    print(json.dumps({k: manifest[k] for k in ('diff_sha256', 'new_lock_sha256', 'locked_files')}, indent=2))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
