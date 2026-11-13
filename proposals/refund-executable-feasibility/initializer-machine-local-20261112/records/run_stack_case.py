"""Dispatch one HOL case with U314's recorded code-0003 context. This is not a proof checker.

Usage: python3 -I -B run_stack_case.py <case> <source.sml> [<theory-case> <theory-name>]

The argv prefix, cwd, heap and imported parent objects come from U314's
recorded code-0003/command.json. Only the final source argument differs.
With a theory case, that case's exported theory is loaded before the source.
"""
from pathlib import Path
import hashlib, json, os, resource, shutil, subprocess, sys, time

ROOT = Path('/Users/mackianni/forge')
OUT = Path(__file__).resolve().parent
TC = ROOT / '.toolchain/experiments/refund-cakeml-20261104'
OLD = ROOT / 'results/refund-initial-stack-code-2026-11-05/attempt-0001/code-0003'
RECORDED = ROOT / 'proposals/refund-executable-feasibility/initial-stack-code-checkpoint-20261105/records/code-0003/command.json'
CPU_SECONDS, WALL_SECONDS = 600, 900


def sha(path):
    digest = hashlib.sha256()
    with Path(path).open('rb') as handle:
        for block in iter(lambda: handle.read(1048576), b''):
            digest.update(block)
    return digest.hexdigest()


recorded = json.loads(RECORDED.read_text())
inputs = {str(OLD / 'preload.sml'): sha(OLD / 'preload.sml')}
for parent, objects in recorded['imported_objects'].items():
    for name, digest in objects.items():
        inputs[str(OLD / parent / name)] = digest
inputs[str(TC / 'cakeml/misc/cakeml-heap')] = recorded['heap_sha256']
inputs[str(TC / 'HOL/bin/hol')] = '736c669e220381ddb6042fda624db79326aaa0075fe6ff9de4751bad75e8c4dd'


def changed():
    return [p for p, h in inputs.items() if not Path(p).is_file() or sha(p) != h]


before = changed()
if before:
    print(json.dumps({'inputs_changed_before': before}, indent=1))
    raise SystemExit(2)
case = OUT / sys.argv[1]
source = OUT / sys.argv[2]
case.mkdir(exist_ok=False)
shutil.copyfile(source, case / 'proof.sml')
argv = list(recorded['argv'][:-1])
if len(sys.argv) > 3:
    theory_case, theory = OUT / sys.argv[3], sys.argv[4]
    prior = json.loads((theory_case / 'command.json').read_text())
    assert prior['actual_exit'] == 0 and prior['completion_marker'] and len(prior['objects']) == 4
    extra = sys.argv[5:]
    for name, digest in prior['objects'].items():
        inputs[str(theory_case / name)] = digest
    argv += [str(theory_case / (theory + 'Theory' + suffix)) for suffix in ('.sig', '.sml')]
    for more_case, more_theory in zip(extra[0::2], extra[1::2]):
        more = OUT / more_case
        more_prior = json.loads((more / 'command.json').read_text())
        assert more_prior['actual_exit'] == 0 and more_prior['completion_marker'] and len(more_prior['objects']) == 4
        for name, digest in more_prior['objects'].items():
            inputs[str(more / name)] = digest
        argv += [str(more / (more_theory + 'Theory' + suffix)) for suffix in ('.sig', '.sml')]
    assert not changed()
argv.append(str(case / 'proof.sml'))
env = dict(os.environ, HOLDIR=str(TC / 'HOL'), CAKEMLDIR=str(TC / 'cakeml'), FORGE_RUNTIME_OUT=str(case))
env['PATH'] = str(TC / 'poly-install/bin') + os.pathsep + env['PATH']
record = {'case': sys.argv[1], 'argv': argv, 'cwd': recorded['cwd'], 'source': sys.argv[2],
          'source_sha256': sha(source), 'recorded_code_0003_source_sha256': recorded['source_sha256'],
          'cpu_seconds_limit': CPU_SECONDS, 'wall_seconds_limit': WALL_SECONDS,
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
    'completion_marker': 'RUNTIME_PROOF_COMPLETE' in (case / 'stdout.log').read_text(errors='replace'),
    'markers': [m for m in ('RUNTIME_PROOF_COMPLETE', 'TRACE_IMPORT_COMPLETE', 'AFTER_POSITIVE_AUDIT',
                             'UNEXPECTED_CONTROL_ACCEPTANCE', 'EXPLORE_COMPLETE',
                             'CONTROL_HARNESS_PROVES_ORIGINAL')
                if m in (case / 'stdout.log').read_text(errors='replace')],
    'stdout_sha256': sha(case / 'stdout.log'), 'stderr_sha256': sha(case / 'stderr.log'),
    'objects': {str(p.relative_to(case)): sha(p) for p in sorted((case / '.hol').rglob('*')) if p.is_file()},
    'inputs_unchanged_after': not changed(),
})
(case / 'command.json').write_text(json.dumps(record, indent=1) + '\n')
print(json.dumps({k: v for k, v in record.items() if k != 'argv'}, indent=1))
raise SystemExit(child.returncode if child.returncode is not None and child.returncode >= 0 else 1)
