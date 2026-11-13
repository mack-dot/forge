"""Run one recorded ARM8 step-library invocation unchanged. This is not a proof checker.

Usage: python3 -I -B run_recorded.py <case>

The argv and cwd come from U316's inspect-arm8-steps/command.json. The step
tool identities of U316 are checked before and after the child. Output goes
to the new case directory only.
"""
from pathlib import Path
import hashlib, json, os, resource, subprocess, sys, time

ROOT = Path('/Users/mackianni/forge')
OUT = Path(__file__).resolve().parent
TC = ROOT / '.toolchain/experiments/refund-cakeml-20261104'
REC = ROOT / 'proposals/refund-executable-feasibility/native-error-instructions-20261105/records'
CPU_SECONDS, WALL_SECONDS = 600, 900


def sha(path):
    digest = hashlib.sha256()
    with Path(path).open('rb') as handle:
        for block in iter(lambda: handle.read(1048576), b''):
            digest.update(block)
    return digest.hexdigest()


recorded = json.loads((REC / 'inspect-arm8-steps/command.json').read_text())
tools = {**json.loads((REC / 'baseline.json').read_text())['step_tools'],
         **json.loads((REC / 'arm8-tool-inputs.json').read_text())['files']}
argv, cwd = recorded['argv'], recorded['cwd']
tools[argv[3]] = sha(REC / 'inspect-arm8-steps/preload.sml')
tools[argv[4]] = recorded['source_sha256']


def changed():
    return [p for p, h in tools.items() if not Path(p).is_file() or sha(p) != h]


before = changed()
if before:
    print(json.dumps({'inputs_changed_before': before}, indent=1))
    raise SystemExit(2)
case = OUT / sys.argv[1]
case.mkdir(exist_ok=False)
listing = lambda: sorted((p.name, p.stat().st_size, p.stat().st_mtime_ns) for p in Path(cwd).iterdir())
cwd_before = listing()
env = dict(os.environ, HOLDIR=str(TC / 'HOL'), CAKEMLDIR=str(TC / 'cakeml'), FORGE_NATIVE_STEP_OUT=str(case))
env['PATH'] = str(TC / 'poly-install/bin') + os.pathsep + env['PATH']


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
record = {
    'case': sys.argv[1], 'argv': argv, 'cwd': cwd, 'source_sha256': recorded['source_sha256'],
    'historical_exit_U316': recorded['actual_exit'], 'cpu_seconds_limit': CPU_SECONDS,
    'wall_seconds_limit': WALL_SECONDS, 'actual_exit': child.returncode, 'wall_timeout': timed_out,
    'wall_seconds': round(time.monotonic() - start, 3),
    'child_user_cpu_seconds': round(usage.ru_utime, 3), 'child_system_cpu_seconds': round(usage.ru_stime, 3),
    'child_max_rss_bytes': usage.ru_maxrss,
    'completion_marker': 'NATIVE_STEP_COMPLETE' in stdout,
    'step_word_lines': stdout.count('STEP_WORD '), 'step_theorem_lines': stdout.count('STEP_THEOREM '),
    'stdout_sha256': sha(case / 'stdout.log'), 'stderr_sha256': sha(case / 'stderr.log'),
    'checked_tool_files': len(tools), 'tools_unchanged_after': not changed(),
    'cwd_listing_unchanged': listing() == cwd_before, 'end_to_end': False,
}
(case / 'command.json').write_text(json.dumps(record, indent=1) + '\n')
print(json.dumps({k: v for k, v in record.items() if k != 'argv'}, indent=1))
raise SystemExit(child.returncode if child.returncode is not None and child.returncode >= 0 else 1)
