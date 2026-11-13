"""Dispatch one HOL case in the pinned CakeML heap context. This is not a proof checker.

Usage: python3 -I -B run_case.py <case> <source.sml> [<theory .sig/.sml path> ...]

The tool is that of the recorded bridge-0005 command (U298). The heap and cwd are those
of the published in-logic compile of the refund program (forge_refundArm8Compile).
Extra arguments are exported theory files loaded before the source. A resource
guard refuses to start when memory or disk is low or another HOL child runs.
"""
from pathlib import Path
import hashlib, json, os, resource, shutil, subprocess, sys, time

ROOT = Path('/Users/mackianni/forge')
OUT = Path(__file__).resolve().parent
TC = ROOT / '.toolchain/experiments/refund-cakeml-20261104'
RECORDED = ROOT / 'results/refund-target-install-bridge-2026-11-05/attempt-0001/bridge-0005/command.json'
CWD = str(ROOT / '.toolchain/experiments/refund-cakeml-20261104/cakeml/compiler/dafny/forge_refundArm8Compile_experiment')
import os as _os
CPU_SECONDS = int(_os.environ.get('FORGE_CPU_SECONDS', '600'))
WALL_SECONDS = CPU_SECONDS + 300
MARKERS = ('N1_PROOF_COMPLETE', 'N1_IMPORT_COMPLETE', 'AFTER_POSITIVE_AUDIT',
           'UNEXPECTED_CONTROL_ACCEPTANCE', 'EXPLORE_COMPLETE')


def sha(path):
    digest = hashlib.sha256()
    with Path(path).open('rb') as handle:
        for block in iter(lambda: handle.read(1048576), b''):
            digest.update(block)
    return digest.hexdigest()


def guard():
    free = int(subprocess.run(['memory_pressure'], capture_output=True, text=True).stdout.rsplit(':', 1)[1].strip().rstrip('%'))
    stat = os.statvfs('/System/Volumes/Data')
    disk = stat.f_bavail * stat.f_frsize / 2 ** 30
    other = subprocess.run(['pgrep', '-f', 'cakeml-heap|arm8-heap|cake_compile_heap'], capture_output=True, text=True).stdout.split()
    state = {'memory_free_percent': free, 'disk_free_gib': round(disk, 2), 'other_hol_pids': other}
    if free < 25 or disk < 3 or other:
        print(json.dumps({'resource_guard_refused': state}))
        raise SystemExit(3)
    return state


recorded = json.loads(RECORDED.read_text())
HEAP = TC / 'cakeml/cv_translator/cake_compile_heap'
argv = [recorded['argv'][0], 'run', '--holstate=' + str(HEAP)]
inputs = {argv[0]: sha(argv[0]), str(HEAP): sha(HEAP)}
for extra in sys.argv[3:]:
    # HOL resolves a theory file <dir>/<name> to <dir>/.hol/objs/<name>.
    stored = Path(extra) if Path(extra).is_file() else Path(extra).parent / '.hol/objs' / Path(extra).name
    inputs[str(stored)] = sha(stored)
    argv.append(extra)
state = guard()
case = OUT / sys.argv[1]
source = OUT / sys.argv[2]
case.mkdir(exist_ok=False)
shutil.copyfile(source, case / 'proof.sml')
argv.append(str(case / 'proof.sml'))
env = dict(os.environ, HOLDIR=str(TC / 'HOL'), CAKEMLDIR=str(TC / 'cakeml'), FORGE_N1_OUT=str(case))
env['PATH'] = str(TC / 'poly-install/bin') + os.pathsep + env['PATH']
record = {'case': sys.argv[1], 'argv': argv, 'cwd': CWD, 'source': sys.argv[2],
          'source_sha256': sha(source), 'input_sha256': inputs, 'resource_guard': state,
          'cpu_seconds_limit': CPU_SECONDS, 'wall_seconds_limit': WALL_SECONDS, 'end_to_end': False}
(case / 'invocation.json').write_text(json.dumps(record, indent=1) + '\n')


def limits():
    resource.setrlimit(resource.RLIMIT_CPU, (CPU_SECONDS, CPU_SECONDS))
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))


start = time.monotonic()
timed_out = False
with (case / 'stdout.log').open('xb') as out, (case / 'stderr.log').open('xb') as err:
    child = subprocess.Popen(argv, cwd=CWD, env=env, stdout=out, stderr=err, preexec_fn=limits)
    try:
        child.wait(timeout=WALL_SECONDS)
    except subprocess.TimeoutExpired:
        timed_out = True
        child.kill()
        child.wait()
usage = resource.getrusage(resource.RUSAGE_CHILDREN)
lines = (case / 'stdout.log').read_text(errors='replace').splitlines()
record.update({
    'actual_exit': child.returncode, 'wall_timeout': timed_out, 'wall_seconds': round(time.monotonic() - start, 3),
    'child_user_cpu_seconds': round(usage.ru_utime, 3), 'child_max_rss_bytes': usage.ru_maxrss,
    'markers': [m for m in MARKERS if m in lines],
    'stdout_sha256': sha(case / 'stdout.log'), 'stderr_sha256': sha(case / 'stderr.log'),
    'objects': {str(p.relative_to(case)): sha(p) for p in sorted((case / '.hol').rglob('*')) if p.is_file()},
    'inputs_unchanged_after': all(sha(p) == h for p, h in inputs.items()),
})
(case / 'command.json').write_text(json.dumps(record, indent=1) + '\n')
print(json.dumps({k: v for k, v in record.items() if k not in ('argv', 'input_sha256')}, indent=1))
raise SystemExit(child.returncode if child.returncode is not None and child.returncode >= 0 else 1)
