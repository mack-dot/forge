"""Validate observed JavaScript installation content; no correctness decision."""

import hashlib
import json
from pathlib import Path
import platform
import shutil
import subprocess

ROOT = Path(__file__).resolve().parent.parent
# Same table as gate/common.py (kept standalone so the harness has no gate import).
PIN_FILES = {
    ('Darwin', 'arm64'): {'dafny': 'toolchain/pins.json', 'javascript': 'toolchain/javascript-pins.json'},
    ('Linux', 'x86_64'): {'dafny': 'toolchain/linux-pins.json', 'javascript': 'toolchain/javascript-linux-pins.json'},
}


def pin_file(kind):
    key = (platform.system(), platform.machine())
    if key not in PIN_FILES:
        raise RuntimeError('TOOLCHAIN_ERROR: no pinned toolchain profile for ' + '/'.join(key))
    return PIN_FILES[key][kind]


def digest(data):
    return hashlib.sha256(data).hexdigest()


def package_digest(folder):
    manifest = [{'path': path.relative_to(folder).as_posix(), 'sha256': digest(path.read_bytes())}
                for path in sorted(folder.rglob('*')) if path.is_file()]
    return digest((json.dumps(manifest, sort_keys=True, separators=(',', ':')) + '\n').encode())


def check():
    pins = json.loads((ROOT / pin_file('javascript')).read_text())
    node = shutil.which('node')
    if not node or digest(Path(node).read_bytes()) != pins['node_executable_sha256']:
        raise RuntimeError('JAVASCRIPT_TOOLCHAIN: Node executable differs from pin')
    version = subprocess.run([node, '--version'], capture_output=True, text=True, check=True)
    if version.stdout.strip() != 'v' + pins['node_version']:
        raise RuntimeError('JAVASCRIPT_TOOLCHAIN: Node version differs from pin')
    lock = ROOT / 'package-lock.json'
    if digest(lock.read_bytes()) != pins['package_lock_sha256']:
        raise RuntimeError('JAVASCRIPT_TOOLCHAIN: dependency lock digest differs')
    for relative, expected in pins['packages'].items():
        folder = ROOT / relative
        metadata = json.loads((folder / 'package.json').read_text())
        if metadata['version'] != expected['version'] or package_digest(folder) != expected['content_sha256']:
            raise RuntimeError('JAVASCRIPT_TOOLCHAIN: installed package differs: ' + relative)
    return pins


if __name__ == '__main__':
    check()
    print('JAVASCRIPT_TOOLCHAIN: installed versions and content match recorded pins')
