"""Authenticate this checkout before any repository Python runs.

Run only with an isolated interpreter, so that nothing but the standard
library loads:

    python3 -I -S -B gate/provenance/bootstrap.py --implementation-sha256 HEX --check
    python3 -I -S -B gate/provenance/bootstrap.py --implementation-sha256 HEX -- SCRIPT [ARGS...]

The second form re-checks, then runs a locked SCRIPT with environment paths
removed and an empty bytecode cache. Check this file's bytes against the lock
before running it; this file cannot vouch for itself.
"""
import hashlib
import json
import os
import stat
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
LOCK = 'gate/provenance/implementation.lock'
EXECUTABLE_ROOTS = ('gate/provenance/', 'scripts/', 'examples/binary/')
CODE_SUFFIXES = ('.py', '.pyc', '.pyo', '.pyd', '.so', '.dylib', '.pth', '.v', '.vo', '.vos', '.vok',
                 '.glob', '.c', '.h', '.sh')


def fail(reason):
    sys.stderr.write('BOOTSTRAP_REJECTED: ' + reason + '\n')
    raise SystemExit(1)


def sha(path):
    digest = hashlib.sha256()
    with open(path, 'rb') as stream:
        for chunk in iter(lambda: stream.read(1 << 20), b''):
            digest.update(chunk)
    return digest.hexdigest()


def check(expected):
    lock_path = os.path.join(ROOT, LOCK)
    if sha(lock_path) != expected:
        fail('IMPLEMENTATION_LOCK')
    with open(lock_path, 'rb') as stream:
        files = json.loads(stream.read())['files']
    for top in EXECUTABLE_ROOTS:
        for directory, dirnames, filenames in os.walk(os.path.join(ROOT, top), followlinks=False):
            for name in sorted(dirnames + filenames):
                full = os.path.join(directory, name)
                rel = os.path.relpath(full, ROOT).replace(os.sep, '/')
                mode = os.lstat(full).st_mode
                if stat.S_ISLNK(mode):
                    fail('SYMLINK:' + rel)
                if name == '__pycache__':
                    fail('BYTECODE_CACHE:' + rel)
                if stat.S_ISDIR(mode) or rel == LOCK:
                    continue
                if not stat.S_ISREG(mode):
                    fail('ENTRY_TYPE:' + rel)
                if rel not in files and (rel.startswith('gate/provenance/') or rel.endswith(CODE_SUFFIXES)):
                    fail('UNLOCKED_EXECUTABLE:' + rel)
    for rel, expected_file in sorted(files.items()):
        path = os.path.join(ROOT, rel)
        if os.path.islink(path) or not os.path.isfile(path) or sha(path) != expected_file:
            fail('LOCKED_INPUT:' + rel)
    return files


def main():
    if not (sys.flags.isolated and sys.flags.no_site and sys.flags.dont_write_bytecode):
        fail('INTERPRETER_FLAGS: run with python3 -I -S -B')
    args = sys.argv[1:]
    if len(args) < 3 or args[0] != '--implementation-sha256':
        fail('USAGE')
    files = check(args[1])
    if args[2:] == ['--check']:
        print('BOOTSTRAP_VERIFIED', flush=True)
        return 0
    if args[2] != '--' or len(args) < 4:
        fail('USAGE')
    script = os.path.abspath(args[3])
    if os.path.relpath(script, ROOT).replace(os.sep, '/') not in files:
        fail('SCRIPT_NOT_LOCKED:' + args[3])
    cache = tempfile.mkdtemp(prefix='forge-pycache-')
    # Children inherit no Python path variables and use the same empty cache.
    env = {k: v for k, v in os.environ.items() if not k.startswith('PYTHON')}
    env.update(PYTHONPYCACHEPREFIX=cache, PYTHONDONTWRITEBYTECODE='1', PYTHONNOUSERSITE='1')
    os.execve(sys.executable, [sys.executable, '-E', '-s', '-B', '-X', 'pycache_prefix=' + cache, script]
              + args[4:], env)


if __name__ == '__main__':
    raise SystemExit(main())
