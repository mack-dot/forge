#!/usr/bin/env python3
"""Measure a real Linux toolchain. This script emits no acceptance evidence."""

import hashlib
import importlib.metadata
import json
import os
from pathlib import Path
import platform
import shlex
import subprocess
import sys
import urllib.request
import zipfile


ROOT = Path(__file__).resolve().parents[1]
PINS = json.loads((ROOT / 'toolchain/ci-bootstrap.json').read_text())
COMMANDS = []


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run(command, expected=0):
    child = subprocess.run(command, cwd=ROOT, capture_output=True, text=True)
    COMMANDS.append({'command': shlex.join(command), 'exit_code': child.returncode})
    if child.returncode != expected:
        print(child.stdout + child.stderr, file=sys.stderr)
        raise RuntimeError('TOOLCHAIN_ERROR: expected exit ' + str(expected)
                           + ', observed ' + str(child.returncode) + ': ' + shlex.join(command))
    return child.stdout.strip()


def main():
    if (platform.system() != 'Linux' or platform.machine() != 'x86_64'
            or platform.python_version() != PINS['python_version']):
        raise RuntimeError('TOOLCHAIN_ERROR: expected Linux/x86_64 and Python 3.10.11')
    pip_output = run([sys.executable, '-m', 'pip', '--version'])
    if not pip_output.startswith('pip ' + PINS['pip_version'] + ' '):
        raise RuntimeError('TOOLCHAIN_ERROR: pip version mismatch: ' + pip_output)
    local = ROOT / '.toolchain'
    downloads = local / 'ci-downloads'
    downloads.mkdir(parents=True, exist_ok=True)
    archive = downloads / 'dafny-4.11.0-x64-ubuntu-22.04.zip'
    urllib.request.urlretrieve(PINS['dafny']['url'], archive)
    if sha(archive) != PINS['dafny']['archive_sha256']:
        raise RuntimeError('TOOLCHAIN_ERROR: official Dafny archive SHA-256 mismatch')
    installation = local / 'dafny-4.11.0'
    if installation.exists():
        raise RuntimeError('TOOLCHAIN_ERROR: expected a fresh Dafny installation')
    with zipfile.ZipFile(archive) as package:
        for member in package.infolist():
            if Path(member.filename).is_absolute() or '..' in Path(member.filename).parts:
                raise RuntimeError('TOOLCHAIN_ERROR: unsafe archive member path')
        package.extractall(installation)
        for member in package.infolist():
            mode = (member.external_attr >> 16) & 0o777
            if mode and not member.is_dir():
                (installation / member.filename).chmod(mode)
    dafny = installation / 'dafny/dafny'
    solver = installation / 'dafny/z3/bin/z3-4.12.1'
    version = run([str(dafny), '--version'])
    if version != PINS['dafny']['version_output']:
        raise RuntimeError('TOOLCHAIN_ERROR: Dafny version mismatch: ' + version)
    solver_version = run([str(solver), '--version'])
    if not solver_version.startswith('Z3 version 4.12.1 '):
        raise RuntimeError('TOOLCHAIN_ERROR: Z3 version mismatch: ' + solver_version)

    wheels = downloads / 'wheels'
    wheels.mkdir()
    requirements = [name + '==' + version for name, version in sorted(PINS['packages'].items())]
    run([sys.executable, '-m', 'pip', 'download', '--no-deps', '--only-binary=:all:',
         '--dest', str(wheels), *requirements])
    wheel_digests = {path.name: sha(path) for path in sorted(wheels.iterdir())}
    if len(wheel_digests) != len(requirements):
        raise RuntimeError('TOOLCHAIN_ERROR: expected one pinned wheel per package')
    run([sys.executable, '-m', 'pip', 'install', '--force-reinstall', '--no-index', '--no-deps',
         '--find-links', str(wheels), *requirements])
    packages = {}
    for name, version in sorted(PINS['packages'].items()):
        dist = importlib.metadata.distribution(name)
        if dist.version != version:
            raise RuntimeError('TOOLCHAIN_ERROR: package version mismatch: ' + name)
        files = {}
        for entry in sorted(dist.files or [], key=str):
            filename = str(entry)
            if ('..' in Path(filename).parts or Path(filename).is_absolute()
                    or '__pycache__' in Path(filename).parts or filename.endswith('.pyc')
                    or Path(filename).name in ('RECORD', 'INSTALLER', 'REQUESTED', 'direct_url.json')):
                continue
            files[filename] = sha(Path(dist.locate_file(entry)))
        if not files:
            raise RuntimeError('TOOLCHAIN_ERROR: empty package file inventory: ' + name)
        packages[name] = {'version': version, 'files': files}
    # Exercise the actual established validators before accepting the inventory.
    run([sys.executable, '-c',
         'from jsonschema import Draft202012Validator; import yaml; '
         'Draft202012Validator({"type":"integer"}).validate(1); '
         'assert yaml.safe_load("value: 1") == {"value":1}'])

    build = ROOT / 'build/ci-inventory'
    build.mkdir(parents=True)
    true_lemma = build / 'True.dfy'
    false_lemma = build / 'False.dfy'
    true_lemma.write_text('lemma TrueLemma(x: int) ensures x + 0 == x {}\n')
    false_lemma.write_text('lemma FalseLemma(x: int) ensures x + 1 == x {}\n')
    options = ['--solver-path', str(solver), '--resource-limit', '1000000',
               '--verification-time-limit', '0', '--cores', '1']
    run([str(dafny), 'verify', str(true_lemma), *options])
    run([str(dafny), 'verify', str(false_lemma), *options], expected=4)
    report = {
        'stage': 4, 'stage_exit': False, 'accepts_artifacts': False, 'end_to_end': False,
        'platform': {'os': platform.system(), 'architecture': platform.machine(),
                     'runner_image': os.environ.get('ImageOS'),
                     'runner_image_version_observed': os.environ.get('ImageVersion')},
        'python': {'version': platform.python_version(), 'executable_sha256': sha(Path(sys.executable))},
        'pip_version': PINS['pip_version'],
        'dafny': dict(PINS['dafny'], executable_sha256=sha(dafny)),
        'z3': {'version_output': solver_version, 'executable_sha256': sha(solver),
               'path': '.toolchain/dafny-4.11.0/dafny/z3/bin/z3-4.12.1'},
        'validator_pins': {'python_version': platform.python_version(), 'packages': packages},
        'wheel_sha256': wheel_digests, 'commands': COMMANDS,
        'limits': PINS['limits'],
    }
    destination = build / 'inventory.json'
    destination.write_text(json.dumps(report, sort_keys=True, indent=2) + '\n')
    print('INVENTORY_COMPLETE; no PR or artifact accepted; sha256=' + sha(destination))
    # Keep a text copy in the real job log for connectors that cannot open ZIPs.
    encoded = json.dumps(report, sort_keys=True, separators=(',', ':'))
    for start in range(0, len(encoded), 12000):
        print('FORGE_INVENTORY_CHUNK ' + json.dumps({'offset': start, 'text': encoded[start:start + 12000]}))
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (OSError, RuntimeError, ValueError, zipfile.BadZipFile) as error:
        print(str(error), file=sys.stderr)
        sys.exit(2)
