#!/usr/bin/env python3
"""Compile the approved Dafny source with its real compiler; expose JS exports."""

import json
from pathlib import Path
import subprocess
import sys

from javascript_env import ROOT, check, digest, pin_file


def main():
    check()
    pins = json.loads((ROOT / pin_file('dafny')).read_text())
    lock = json.loads((ROOT / 'spec.lock').read_text())
    if digest((ROOT / 'spec/LedgerSpec.dfy').read_bytes()) != lock['spec_sha256']:
        raise RuntimeError('SPEC_LOCK: changed specification')
    dafny = ROOT / '.toolchain/dafny-4.11.0/dafny/dafny'
    if digest(dafny.read_bytes()) != pins['dafny']['executable_sha256']:
        raise RuntimeError('TOOLCHAIN_ERROR: Dafny executable differs')
    directory = ROOT / 'build/js'
    directory.mkdir(parents=True, exist_ok=True)
    paths = ['impl/Ledger.dfy', 'spec/LedgerSpec.dfy', 'spec.lock', 'interop/export.cjs',
             pin_file('dafny'), pin_file('javascript'), 'package-lock.json']
    before = {path: digest((ROOT / path).read_bytes()) for path in paths}
    for name in ('ledger.js', 'ledger.cjs', 'build.json'):
        (directory / name).unlink(missing_ok=True)
    command = [str(dafny), 'build', 'impl/Ledger.dfy', '--target', 'js', '--output',
               'build/js/ledger', *pins['verification_options']]
    result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True)
    (directory / 'compile.log').write_text(result.stdout + result.stderr)
    print(result.stdout + result.stderr, end='')
    if result.returncode:
        return result.returncode
    if before != {path: digest((ROOT / path).read_bytes()) for path in paths}:
        raise RuntimeError('INPUT_CHANGED: compiler inputs changed during build')
    source = (directory / 'ledger.js').read_bytes()
    module = source + (ROOT / 'interop/export.cjs').read_bytes()
    (directory / 'ledger.cjs').write_bytes(module)
    record = {'compiler': 'Dafny', 'tool_version': pins['dafny']['version_output'],
              'command': ['.toolchain/dafny-4.11.0/dafny/dafny', *command[1:]],
              'exit_code': result.returncode, 'input_sha256': before,
              'generated_source_sha256': digest(source),
              'artifact': {'kind': 'module', 'sha256': digest(module),
                           'build_cmd': 'python3 scripts/build_model.py'},
              'source_to_module_proved': False, 'end_to_end': False}
    (directory / 'build.json').write_text(json.dumps(record, sort_keys=True, separators=(',', ':')) + '\n')
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (OSError, ValueError, RuntimeError, subprocess.CalledProcessError) as error:
        print('BUILD_ERROR: ' + str(error), file=sys.stderr)
        sys.exit(2)
