#!/usr/bin/env python3
"""Run one command and preserve argv, real exit code and raw output.

Usage: record.py RECORD_DIRECTORY -- ARGV...
The record directory must not exist. This script makes no verdict.
"""
import hashlib
import json
from pathlib import Path
import subprocess
import sys


def main():
    split = sys.argv.index('--')
    directory = Path(sys.argv[1])
    argv = sys.argv[split + 1:]
    directory.mkdir(parents=True, exist_ok=False)
    with (directory / 'stdout.log').open('xb') as out, (directory / 'stderr.log').open('xb') as err:
        code = subprocess.run(argv, stdout=out, stderr=err, check=False).returncode
    record = {'argv': argv, 'cwd': str(Path.cwd()), 'exit_code': code,
              'stdout_sha256': hashlib.sha256((directory / 'stdout.log').read_bytes()).hexdigest(),
              'stderr_sha256': hashlib.sha256((directory / 'stderr.log').read_bytes()).hexdigest()}
    (directory / 'command.json').write_text(json.dumps(record, sort_keys=True, indent=1) + '\n')
    print(json.dumps({'record': str(directory), 'exit_code': code}))
    return code


if __name__ == '__main__':
    raise SystemExit(main())
