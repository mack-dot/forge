#!/usr/bin/env python3
"""Build the unapplied v3.2 candidate: v3.1 plus the runner disk fix (U109).

The proof job records disk, memory and CPUs and removes unused preinstalled
toolchains on the disposable runner; hosted_setup.py rejects with DISK_SPACE
when too little space is free before image pulls. Contract, policy and
contract_approval_commit stay unchanged. Writes only under this directory.
"""
import difflib
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
OUT = HERE / 'candidate'
V31 = HERE.parent / 'provenance-hosted-v31'
INSTALLED_LOCK = '9b10a2376c6b6de46661819a528f3b4e1251f27d76ac21e071b1cfb971224a76'
V31_MANIFEST = '9fc1cffbeb94f9648bc000cf26fee9a91d827c1a716c5203cd455b921152697c'
MIN_FREE = 35_000_000_000
RECLAIM = (
    '      - name: Record and reclaim disk on the disposable runner\n'
    '        run: |\n'
    '          df -B1 / && nproc && free -b\n'
    '          sudo rm -rf /usr/local/lib/android /usr/share/dotnet /opt/ghc /usr/local/.ghcup \\\n'
    '            /opt/hostedtoolcache/CodeQL /usr/share/swift /usr/local/share/powershell /usr/local/share/chromium\n'
    '          docker image prune --all --force\n'
    '          df -B1 /\n')


def sha(data):
    return hashlib.sha256(data).hexdigest()


def dump(value):
    return (json.dumps(value, indent=2, sort_keys=True) + '\n').encode()


def edit(text, pairs):
    for old, new, count in pairs:
        assert text.count(old) == count, ('EDIT_ANCHOR', old[:60], text.count(old))
        text = text.replace(old, new)
    return text


def main():
    assert sha((ROOT / 'gate/provenance/implementation.lock').read_bytes()) == INSTALLED_LOCK, 'INSTALLED_LOCK'
    manifest_bytes = (V31 / 'approval-manifest.json').read_bytes()
    assert sha(manifest_bytes) == V31_MANIFEST, 'V31_MANIFEST'
    v31 = json.loads(manifest_bytes)
    base = {}
    for path, item in v31['files'].items():
        data = (V31 / 'candidate' / path).read_bytes()
        assert sha(data) == item['new_sha256'], ('V31_CANDIDATE', path)
        base[path] = data
    new = dict(base)
    new['gate/provenance/hosted_setup.py'] = edit(base['gate/provenance/hosted_setup.py'].decode(), [
        ("    for image in [stage7['checker_image'], own['builder_image']]:\n",
         "    # Private-repository runners may have less disk; fail explicitly (U109).\n"
         "    places = [root.parent] + [Path(p) for p in ['/var/lib/docker'] if Path(p).exists()]\n"
         "    free = min(shutil.disk_usage(p).free for p in places)\n"
         "    write(records.directory / 'disk.json', {'free_bytes_before_pulls': free,\n"
         "                                           'required_bytes': pins['min_free_disk_bytes']})\n"
         "    require(free >= pins['min_free_disk_bytes'], 'DISK_SPACE')\n"
         "    for image in [stage7['checker_image'], own['builder_image']]:\n", 1)]).encode()
    runtime = json.loads(base['gate/provenance/runtime.json'])
    runtime['profiles']['producer']['min_free_disk_bytes'] = MIN_FREE
    new['gate/provenance/runtime.json'] = dump(runtime)
    new['.github/workflows/provenance.yml'] = edit(base['.github/workflows/provenance.yml'].decode(), [
        ('      - name: Install pinned Docker and build Stage 7 prerequisites\n',
         RECLAIM + '      - name: Install pinned Docker and build Stage 7 prerequisites\n', 1)]).encode()
    lock = json.loads(base['gate/provenance/implementation.lock'])
    for path, data in new.items():
        if path != 'gate/provenance/implementation.lock':
            lock['files'][path] = sha(data)
    new['gate/provenance/implementation.lock'] = dump(lock)
    patch, manifest = [], {'base_lock_sha256': INSTALLED_LOCK, 'contract_unchanged': True,
                           'derived_from_v31_manifest': V31_MANIFEST, 'end_to_end': False, 'files': {}}
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
