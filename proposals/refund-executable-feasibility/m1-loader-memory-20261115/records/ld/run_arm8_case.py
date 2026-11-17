"""Dispatch one HOL case in U316's recorded ARM8 step context. This is not a proof checker.

Usage: python3 -I -B run_arm8_case.py <case> <source.sml> [<theory-case> <theory-name>]

The argv prefix (tool, heap, preload) and cwd come from U316's recorded
inspect-arm8-steps/command.json. The step tool identities of U316 are checked
before and after the child. With a theory case, that case's exported theory is
loaded before the source.
"""
from pathlib import Path
import hashlib, json, os, resource, shutil, subprocess, sys, time

ROOT = Path('/Users/mackianni/forge')
OUT = Path(__file__).resolve().parent
TC = ROOT / '.toolchain/experiments/refund-cakeml-20261104'
REC = ROOT / 'proposals/refund-executable-feasibility/native-error-instructions-20261105/records'
CPU_SECONDS, WALL_SECONDS = 600, 900
MARKERS = ('NATIVE_STEP_COMPLETE', 'NATIVE_IMPORT_COMPLETE', 'AFTER_POSITIVE_AUDIT', 'UNEXPECTED_CONTROL_ACCEPTANCE',
           'EXPLORE_COMPLETE')


def sha(path):
    digest = hashlib.sha256()
    with Path(path).open('rb') as handle:
        for block in iter(lambda: handle.read(1048576), b''):
            digest.update(block)
    return digest.hexdigest()


recorded = json.loads((REC / 'inspect-arm8-steps/command.json').read_text())
inputs = {**json.loads((REC / 'baseline.json').read_text())['step_tools'],
          **json.loads((REC / 'arm8-tool-inputs.json').read_text())['files']}
inputs[recorded['argv'][3]] = sha(REC / 'inspect-arm8-steps/preload.sml')
case = OUT / sys.argv[1]
source = OUT / sys.argv[2]
argv = list(recorded['argv'][:4])
if len(sys.argv) > 3:
    theory_case, theory = OUT / sys.argv[3], sys.argv[4]
    prior = json.loads((theory_case / 'command.json').read_text())
    assert prior['actual_exit'] == 0 and 'NATIVE_STEP_COMPLETE' in prior['markers'] and len(prior['objects']) == 4
    for name, digest in prior['objects'].items():
        inputs[str(theory_case / name)] = digest
    argv += [str(theory_case / (theory + 'Theory' + suffix)) for suffix in ('.sig', '.sml')]


def changed():
    return [p for p, h in inputs.items() if not Path(p).is_file() or sha(p) != h]


before = changed()
if before:
    print(json.dumps({'inputs_changed_before': before}, indent=1))
    raise SystemExit(2)
case.mkdir(exist_ok=False)
shutil.copyfile(source, case / 'proof.sml')
argv.append(str(case / 'proof.sml'))
cwd = recorded['cwd']
listing = lambda: sorted((p.name, p.stat().st_size, p.stat().st_mtime_ns) for p in Path(cwd).iterdir())
cwd_before = listing()
env = dict(os.environ, HOLDIR=str(TC / 'HOL'), CAKEMLDIR=str(TC / 'cakeml'), FORGE_NATIVE_STEP_OUT=str(case))
env['PATH'] = str(TC / 'poly-install/bin') + os.pathsep + env['PATH']
record = {'case': sys.argv[1], 'argv': argv, 'cwd': cwd, 'source': sys.argv[2], 'source_sha256': sha(source),
          'cpu_seconds_limit': CPU_SECONDS, 'wall_seconds_limit': WALL_SECONDS,
          'checked_input_files': len(inputs), 'end_to_end': False}
(case / 'invocation.json').write_text(json.dumps(record, indent=1) + '\n')


def limits():
    resource.setrlimit(resource.RLIMIT_CPU, (CPU_SECONDS, CPU_SECONDS))
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))


start = time.monotonic()
timed_out = False
with (case / 'stdout.log').open('xb') as out, (case / 'stderr.log').open('xb') as err:
    child = subprocess.Popen(argv, cwd=cwd, env=env, stdout=out, stderr=err, preexec_fn=limits)
    try:
        child.wait(timeout=WALL_SECONDS)
    except subprocess.TimeoutExpired:
        timed_out = True
        child.kill()
        child.wait()
usage = resource.getrusage(resource.RUSAGE_CHILDREN)
stdout = (case / 'stdout.log').read_text(errors='replace')
record.update({
    'actual_exit': child.returncode, 'wall_timeout': timed_out, 'wall_seconds': round(time.monotonic() - start, 3),
    'child_user_cpu_seconds': round(usage.ru_utime, 3), 'child_system_cpu_seconds': round(usage.ru_stime, 3),
    'child_max_rss_bytes': usage.ru_maxrss, 'markers': [m for m in MARKERS if m in stdout.splitlines()],
    'stdout_sha256': sha(case / 'stdout.log'), 'stderr_sha256': sha(case / 'stderr.log'),
    'objects': {str(p.relative_to(case)): sha(p) for p in sorted((case / '.hol').rglob('*')) if p.is_file()},
    'inputs_unchanged_after': not changed(), 'cwd_listing_unchanged': listing() == cwd_before,
})
(case / 'command.json').write_text(json.dumps(record, indent=1) + '\n')
print(json.dumps({k: v for k, v in record.items() if k != 'argv'}, indent=1))
raise SystemExit(child.returncode if child.returncode is not None and child.returncode >= 0 else 1)
