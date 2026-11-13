"""Run one recorded HOL invocation unchanged, with output in a scratch directory.

Usage: python3 -I -B run_candidate.py <recorded command.json> <new case directory> [proof.sml override]

The argv, cwd and CPU limit come from the recorded command.json. Every recorded
input hash is checked before and after the run. Nothing is written in the repository.
"""
from pathlib import Path
import hashlib, json, os, resource, subprocess, sys, time

TC = Path('/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104')


def sha(path):
    digest = hashlib.sha256()
    with Path(path).open('rb') as handle:
        for block in iter(lambda: handle.read(1048576), b''):
            digest.update(block)
    return digest.hexdigest()


recorded = json.loads(Path(sys.argv[1]).read_text())
case = Path(sys.argv[2])
case.mkdir(parents=True, exist_ok=False)
argv = list(recorded['argv'])
if len(sys.argv) > 3:
    argv[-1] = sys.argv[3]
inputs = recorded['input_files']
before = [p for p, h in inputs.items() if not Path(p).is_file() or sha(p) != h]
if before:
    print(json.dumps({'inputs_changed_before': before[:20], 'count': len(before)}, indent=1))
    raise SystemExit(2)
source = sha(argv[-1])
env = dict(os.environ, HOLDIR=str(TC / 'HOL'), CAKEMLDIR=str(TC / 'cakeml'), FORGE_READ_OUT=str(case))
env['PATH'] = str(TC / 'poly-install/bin') + os.pathsep + env['PATH']
cpu = int(recorded.get('cpu_seconds', 120))


def limits():
    resource.setrlimit(resource.RLIMIT_CPU, (cpu, cpu))
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))


start = time.monotonic()
with (case / 'stdout.log').open('wb') as out, (case / 'stderr.log').open('wb') as err:
    result = subprocess.run(argv, cwd=recorded['cwd'], env=env, stdout=out, stderr=err, preexec_fn=limits)
wall = time.monotonic() - start
usage = resource.getrusage(resource.RUSAGE_CHILDREN)
after = [p for p, h in inputs.items() if not Path(p).is_file() or sha(p) != h]
record = {
    'argv': argv, 'cwd': recorded['cwd'], 'source_sha256': source,
    'recorded_source_sha256': recorded['source_sha256'], 'cpu_seconds_limit': cpu,
    'actual_exit': result.returncode, 'wall_seconds': round(wall, 3),
    'child_user_cpu_seconds': round(usage.ru_utime, 3), 'child_system_cpu_seconds': round(usage.ru_stime, 3),
    'child_max_rss_bytes': usage.ru_maxrss,
    'checked_input_files': len(inputs), 'inputs_unchanged_after': not after,
    'stdout_sha256': sha(case / 'stdout.log'), 'stderr_sha256': sha(case / 'stderr.log'),
    'objects': {str(p.relative_to(case)): sha(p) for p in sorted(case.rglob('*'))
                if p.is_file() and p.name not in ('stdout.log', 'stderr.log')},
}
(case / 'command.json').write_text(json.dumps(record, indent=1) + '\n')
print(json.dumps(record, indent=1))
raise SystemExit(result.returncode)
