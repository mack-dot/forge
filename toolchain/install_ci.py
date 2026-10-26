#!/usr/bin/env python3
"""Install only the recorded Linux distributions and check their content pins."""

import hashlib
import importlib.metadata
import json
from pathlib import Path
import platform
import subprocess
import sys
import urllib.request
import zipfile


ROOT = Path(__file__).resolve().parents[1]
PINS = json.loads((ROOT / 'toolchain/linux-pins.json').read_text())


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run(command):
    child = subprocess.run(command, cwd=ROOT, capture_output=True, text=True)
    print('COMMAND ' + json.dumps({'argv': command, 'exit_code': child.returncode}), flush=True)
    if child.returncode:
        raise RuntimeError(child.stdout + child.stderr)
    return child.stdout.strip()


def main():
    if (platform.system(), platform.machine(), platform.python_version()) != ('Linux', 'x86_64', '3.10.11'):
        raise RuntimeError('TOOLCHAIN_ERROR: expected Linux/x86_64, Python 3.10.11')
    if digest(Path(sys.executable)) != PINS['python']['executable_sha256']:
        raise RuntimeError('TOOLCHAIN_ERROR: Python distribution differs from recorded executable')
    if importlib.metadata.version('pip') != PINS['pip_version']:
        raise RuntimeError('TOOLCHAIN_ERROR: pip version differs from pin')
    downloads = ROOT / '.toolchain/downloads'
    downloads.mkdir(parents=True, exist_ok=True)
    archive = downloads / 'dafny-4.11.0-linux.zip'
    urllib.request.urlretrieve(PINS['dafny']['url'], archive)
    if digest(archive) != PINS['dafny']['archive_sha256']:
        raise RuntimeError('TOOLCHAIN_ERROR: Dafny archive digest mismatch')
    destination = ROOT / '.toolchain/dafny-4.11.0'
    if destination.exists():
        raise RuntimeError('TOOLCHAIN_ERROR: expected a fresh installation')
    with zipfile.ZipFile(archive) as package:
        for member in package.infolist():
            if Path(member.filename).is_absolute() or '..' in Path(member.filename).parts:
                raise RuntimeError('TOOLCHAIN_ERROR: unsafe archive member')
        package.extractall(destination)
        for member in package.infolist():
            mode = (member.external_attr >> 16) & 0o777
            if mode and not member.is_dir():
                (destination / member.filename).chmod(mode)
    dafny = destination / 'dafny/dafny'
    solver = ROOT / PINS['z3']['path']
    for executable, expected in ((dafny, PINS['dafny']['executable_sha256']),
                                 (solver, PINS['z3']['executable_sha256'])):
        if digest(executable) != expected:
            raise RuntimeError('TOOLCHAIN_ERROR: executable digest mismatch: ' + str(executable))
    if run([str(dafny), '--version']) != PINS['dafny']['version_output']:
        raise RuntimeError('TOOLCHAIN_ERROR: Dafny version mismatch')
    if run([str(solver), '--version']) != PINS['z3']['version_output']:
        raise RuntimeError('TOOLCHAIN_ERROR: Z3 version mismatch')
    run([sys.executable, '-m', 'pip', '--isolated', 'install', '--require-hashes',
         '--no-deps', '--only-binary=:all:', '--force-reinstall',
         '-r', 'toolchain/requirements-linux.txt'])
    sys.path.insert(0, str(ROOT / 'gate'))
    from dependencies import check_dependencies
    from backends.dafny import prepare
    check_dependencies('linux')
    prepare('impl/Ledger.dfy', 'linux')
    print('PINNED_LINUX_TOOLCHAIN_READY', flush=True)
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (OSError, ValueError, RuntimeError, zipfile.BadZipFile) as error:
        print(str(error), file=sys.stderr)
        sys.exit(2)
