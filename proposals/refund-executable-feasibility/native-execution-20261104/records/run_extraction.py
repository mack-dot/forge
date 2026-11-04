"""Use pinned HOL to extract exact compiled values after checking the saved theory files."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import time

ROOT = Path('/Users/mackianni/forge')
OUT = Path(__file__).resolve().parent
TC = ROOT / '.toolchain/experiments/refund-cakeml-20261104'
COMPILE = ROOT / 'results/refund-arm8-compile-2026-11-04/attempt-0001/compile-0001'
positive = json.loads((COMPILE / 'command.json').read_text())
assert positive['actual_exit'] == 0
work = Path(positive['cwd'])

def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            h.update(block)
    return h.hexdigest()

def check_parent():
    for name, expected in positive['object_sha256'].items():
        assert sha(work / '.hol/objs' / name) == expected, name

check_parent()
record = OUT / sys.argv[1]
record.mkdir(exist_ok=False)
source = OUT / 'extract_compiled.sml'
shutil.copyfile(source, record / source.name)
heap = TC / 'cakeml/cv_translator/cake_compile_heap'
heap_hash = sha(heap)
env = os.environ.copy()
env.update(HOLDIR=str(TC / 'HOL'), CAKEMLDIR=str(TC / 'cakeml'))
env['PATH'] = str(TC / 'poly-install/bin') + os.pathsep + env['PATH']
argv = [str(TC / 'HOL/bin/hol'), 'run', '--holstate=' + str(heap), str(source)]
start = time.monotonic()
(record / 'invocation.json').write_text(json.dumps({
    'argv': argv, 'cwd': str(work), 'actual_exit': None,
    'source_sha256': sha(source), 'heap_sha256': heap_hash,
    'status': 'STARTING', 'end_to_end': False}, indent=2) + '\n')
interrupted = False
with (record / 'stdout.log').open('wb') as stdout, (record / 'stderr.log').open('wb') as stderr:
    process = subprocess.Popen(argv, cwd=work, env=env, stdout=stdout, stderr=stderr)
    (record / 'process.json').write_text(json.dumps({'pid': process.pid, 'argv': argv}, indent=2) + '\n')
    try:
        code = process.wait()
    except KeyboardInterrupt:
        interrupted = True
        if process.poll() is None:
            process.send_signal(signal.SIGINT)
        code = process.wait()
summary = {'argv': argv, 'cwd': str(work), 'actual_exit': code,
           'manual_interruption': interrupted,
           'wall_seconds': time.monotonic() - start,
           'source_sha256': sha(source), 'heap_sha256': heap_hash,
           'hol_executable_sha256': sha(TC / 'HOL/bin/hol'),
           'compiled_theory_files': positive['object_sha256'],
           'end_to_end': False}
(record / 'command.json').write_text(json.dumps(summary, indent=2) + '\n')
print(json.dumps(summary), flush=True)
check_parent()
assert sha(heap) == heap_hash
print((record / 'stdout.log').read_text(errors='replace')[-1300:])
print((record / 'stderr.log').read_text(errors='replace')[-1300:])
raise SystemExit(130 if interrupted else code)
