"""Adversarial controls for v3.1 pre-execution authentication (U106).

Run from a scratch copy with v3.1 applied and committed as a Git repository.
Every attack plants code that writes a marker file if it ever runs, so each
result records both the exit code and whether attacker code executed. The
inline check is the exact command from the candidate workflows.
"""
import argparse
import json
import os
from pathlib import Path
import py_compile
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'gate/provenance'))

from common import Records, Rejected, source_tree  # noqa: E402

INLINE = ('import hashlib, json, sys\n'
          'lock = open("gate/provenance/implementation.lock", "rb").read()\n'
          'if hashlib.sha256(lock).hexdigest() != sys.argv[1]: sys.exit("IMPLEMENTATION_LOCK")\n'
          'boot = open("gate/provenance/bootstrap.py", "rb").read()\n'
          'if hashlib.sha256(boot).hexdigest() != json.loads(lock)["files"]["gate/provenance/bootstrap.py"]:'
          ' sys.exit("BOOTSTRAP_BYTES")')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--implementation-sha256', required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=False)
    markers = args.output / 'markers'
    markers.mkdir()
    lock = args.implementation_sha256
    results = []

    def payload(name):
        return f"open({str(markers / name)!r}, 'w').write('ran')\nraise SystemExit(9)\n"

    def run(argv, env=None):
        child = subprocess.run(argv, cwd=ROOT, capture_output=True, text=True,
                               env=env if env is not None else dict(os.environ))
        return child.returncode, (child.stdout + child.stderr).strip().splitlines()[-1:] or ['']

    def control(name, expected_exit, plant, argv, env=None, restore=True):
        plant()
        code, last = run(argv, env)
        executed = (markers / name).exists()
        results.append({'control': name, 'exit': code, 'expected_exit': expected_exit, 'last_line': last[0],
                        'attacker_code_executed': executed, 'pass': code == expected_exit and not executed})
        print(json.dumps(results[-1]), flush=True)
        if restore:
            subprocess.run(['git', 'checkout', '-q', '--', '.'], cwd=ROOT, check=True)
            subprocess.run(['git', 'clean', '-fdxq', '--', 'gate', 'scripts', 'examples'], cwd=ROOT, check=True)

    py = sys.executable
    check = [py, '-I', '-S', '-B', 'gate/provenance/bootstrap.py', '--implementation-sha256', lock, '--check']
    launch = [py, '-I', '-S', '-B', 'gate/provenance/bootstrap.py', '--implementation-sha256', lock, '--',
              'gate/provenance/release.py', '--help']
    inline = [py, '-I', '-S', '-B', '-c', INLINE, lock]

    def write(path, text):
        return lambda: (ROOT / path).write_text(text)

    control('clean checkout', 0, lambda: None, check)
    control('shadow module beside the verifier', 1, write('gate/provenance/json.py', payload('shadow module beside the verifier')), launch)
    control('shadow module in scripts', 1, write('scripts/json.py', payload('shadow module in scripts')), launch)
    control('sitecustomize beside the verifier', 1,
            write('gate/provenance/sitecustomize.py', payload('sitecustomize beside the verifier')), launch)

    def plant_pyc():
        source = Path(tempfile.mkdtemp()) / 'common.py'
        source.write_text(payload('unchecked-hash bytecode for common.py'))
        (ROOT / 'gate/provenance/__pycache__').mkdir(exist_ok=True)
        py_compile.compile(str(source), cfile=str(ROOT / 'gate/provenance/__pycache__/common.cpython-310.pyc'),
                           invalidation_mode=py_compile.PycInvalidationMode.UNCHECKED_HASH)
    control('unchecked-hash bytecode for common.py', 1, plant_pyc, launch)

    evil = Path(tempfile.mkdtemp())
    (evil / 'argparse.py').write_text(payload('PYTHONPATH injection'))
    control('PYTHONPATH injection', 0, lambda: None, launch, env=dict(os.environ, PYTHONPATH=str(evil)))
    control('bootstrap without isolation flags', 1, lambda: None,
            [py, 'gate/provenance/bootstrap.py', '--implementation-sha256', lock, '--check'])
    original = (ROOT / 'gate/provenance/bootstrap.py').read_text()
    control('tampered bootstrap.py stopped by the inline check', 1,
            write('gate/provenance/bootstrap.py', payload('tampered bootstrap.py stopped by the inline check') + original),
            inline)
    forged = json.loads((ROOT / 'gate/provenance/implementation.lock').read_text())
    forged['files']['gate/provenance/bootstrap.py'] = '0' * 64
    control('forged lock stopped by the inline check', 1,
            write('gate/provenance/implementation.lock', json.dumps(forged, indent=2, sort_keys=True) + '\n'), inline)
    control('changed locked file', 1,
            lambda: (ROOT / 'gate/provenance/release.py').write_text(
                payload('changed locked file') + (ROOT / 'gate/provenance/release.py').read_text()), launch)
    control('unlocked script launched', 1, lambda: None,
            [py, '-I', '-S', '-B', 'gate/provenance/bootstrap.py', '--implementation-sha256', lock, '--',
             'proposals/provenance-hosted/dry_run.py'])
    # A check passes, then a file changes before the next launch: each launch re-checks.
    control('file changed after an earlier passing check (check step)', 0, lambda: None, check, restore=False)
    control('file changed after an earlier passing check', 1,
            lambda: (ROOT / 'gate/provenance/release.py').write_text(
                payload('file changed after an earlier passing check') + (ROOT / 'gate/provenance/release.py').read_text()),
            launch)

    # Verifier: a candidate commit that carries a different lock.
    base = subprocess.run(['git', 'rev-parse', 'HEAD'], cwd=ROOT, capture_output=True, text=True).stdout.strip()
    (ROOT / 'gate/provenance/implementation.lock').write_text(json.dumps(forged, indent=2, sort_keys=True) + '\n')
    subprocess.run(['git', '-c', 'user.name=c', '-c', 'user.email=c@invalid', 'commit', '-qam', 'forged lock'],
                   cwd=ROOT, check=True)
    commit = subprocess.run(['git', 'rev-parse', 'HEAD'], cwd=ROOT, capture_output=True, text=True).stdout.strip()
    subprocess.run(['git', 'checkout', '-q', '--detach', base], cwd=ROOT, check=True)
    implementation = json.loads((ROOT / 'gate/provenance/implementation.lock').read_text())
    try:
        source_tree(ROOT / '.git', commit, implementation, Records(args.output / 'verifier'))
        observed = 'ACCEPTED'
    except Rejected as error:
        observed = error.reason
    results.append({'control': 'candidate commit with a forged lock (verifier)', 'observed': observed,
                    'attacker_code_executed': False, 'pass': observed == 'IMPLEMENTATION_LOCK_AT_COMMIT'})
    print(json.dumps(results[-1]), flush=True)
    (args.output / 'results.json').write_text(json.dumps({'controls': results, 'end_to_end': False}, indent=2) + '\n')
    shutil.rmtree(evil)
    return 0 if all(r['pass'] for r in results) else 1


if __name__ == '__main__':
    sys.exit(main())
