"""Dispatch one HOL case with the pinned local tools. This is not a proof checker.

Usage: python3 -I -B run_case.py <case> <source.sml> [<theory-case> <theory-name>]

The argv prefix, cwd, heap and input identities come from U328's recorded
generic-0001/command.json. The case directory must not exist. Every recorded
input hash is checked before and after the child. With a theory case, the
exported theory's virtual .sig/.sml paths are loaded before the source.
"""
from pathlib import Path
import hashlib, json, os, resource, shutil, subprocess, sys, time

ROOT = Path('/Users/mackianni/forge')
OUT = Path(__file__).resolve().parent
TC = ROOT / '.toolchain/experiments/refund-cakeml-20261104'
RECORDED = ROOT / 'proposals/refund-executable-feasibility/read-event-gap-20261107/records/generic-0001/command.json'
CPU_SECONDS, WALL_SECONDS = 120, 150


def sha(path):
    digest = hashlib.sha256()
    with Path(path).open('rb') as handle:
        for block in iter(lambda: handle.read(1048576), b''):
            digest.update(block)
    return digest.hexdigest()


def changed(inputs):
    return [p for p, h in inputs.items() if not Path(p).is_file() or sha(p) != h]


recorded = json.loads(RECORDED.read_text())
inputs = dict(recorded['input_files'])
case = OUT / sys.argv[1]
source = OUT / sys.argv[2]
case.mkdir(exist_ok=False)
shutil.copyfile(source, case / 'proof.sml')
argv = list(recorded['argv'][:-1])
assert argv[0] == str(TC / 'HOL/bin/hol') and argv[2] == '--holstate=' + str(TC / 'cakeml/misc/cakeml-heap')
if len(sys.argv) > 3:
    theory_case, theory = OUT / sys.argv[3], sys.argv[4]
    for suffix in ('.sig', '.sml'):
        argv.append(str(theory_case / (theory + 'Theory' + suffix)))
    for path in sorted((theory_case / '.hol/objs').iterdir()):
        inputs[str(path)] = sha(path)
argv.append(str(case / 'proof.sml'))
before = changed(inputs)
if before:
    print(json.dumps({'inputs_changed_before': before[:20], 'count': len(before)}, indent=1))
    raise SystemExit(2)
env = dict(os.environ, HOLDIR=str(TC / 'HOL'), CAKEMLDIR=str(TC / 'cakeml'), FORGE_READ_OUT=str(case))
env['PATH'] = str(TC / 'poly-install/bin') + os.pathsep + env['PATH']
record = {'case': sys.argv[1], 'argv': argv, 'cwd': recorded['cwd'], 'source': sys.argv[2],
          'source_sha256': sha(source), 'cpu_seconds_limit': CPU_SECONDS, 'wall_seconds_limit': WALL_SECONDS,
          'heap_sha256': sha(TC / 'cakeml/misc/cakeml-heap'), 'hol_binary_sha256': sha(TC / 'HOL/bin/hol'),
          'checked_input_files': len(inputs), 'end_to_end': False}
(case / 'invocation.json').write_text(json.dumps(record, indent=1) + '\n')


def limits():
    resource.setrlimit(resource.RLIMIT_CPU, (CPU_SECONDS, CPU_SECONDS))
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))


start = time.monotonic()
timed_out = False
with (case / 'stdout.log').open('xb') as out, (case / 'stderr.log').open('xb') as err:
    child = subprocess.Popen(argv, cwd=recorded['cwd'], env=env, stdout=out, stderr=err, preexec_fn=limits)
    try:
        child.wait(timeout=WALL_SECONDS)
    except subprocess.TimeoutExpired:
        timed_out = True
        child.kill()
        child.wait()
usage = resource.getrusage(resource.RUSAGE_CHILDREN)
record.update({
    'actual_exit': child.returncode, 'wall_timeout': timed_out,
    'wall_seconds': round(time.monotonic() - start, 3),
    'child_user_cpu_seconds': round(usage.ru_utime, 3), 'child_system_cpu_seconds': round(usage.ru_stime, 3),
    'child_max_rss_bytes': usage.ru_maxrss,
    'stdout_sha256': sha(case / 'stdout.log'), 'stderr_sha256': sha(case / 'stderr.log'),
    'objects': {str(p.relative_to(case)): sha(p) for p in sorted((case / '.hol').rglob('*')) if p.is_file()},
    'inputs_unchanged_after': not changed(inputs),
})
(case / 'command.json').write_text(json.dumps(record, indent=1) + '\n')
print(json.dumps({k: v for k, v in record.items() if k != 'argv'}, indent=1))
raise SystemExit(child.returncode if child.returncode is not None and child.returncode >= 0 else 1)
