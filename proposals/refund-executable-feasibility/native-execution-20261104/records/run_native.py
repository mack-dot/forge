"""Observe exact frozen bytes at the actual refund executable's pipe boundary."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import time

OUT = Path(__file__).resolve().parent
FIXTURES = OUT.parent / 'attempt-0003'
EARLIER = OUT.parent / 'attempt-0001/native-corpus'
name = sys.argv[1]
BUILD = Path(sys.argv[2]).resolve()
build = json.loads((BUILD / 'result.json').read_text())
assert build['actual_exit'] == 0
exe = Path(build['executable'])

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

assert sha(exe) == build['executable_sha256']
assert json.loads((FIXTURES / 'readback.json').read_text())['actual_exit'] == 0
manifest = json.loads((FIXTURES / 'wire-manifest.json').read_text())
for filename, expected in manifest.items():
    assert sha(FIXTURES / 'wire' / filename) == expected
cases = json.loads((EARLIER / 'cases.json').read_text())
malformed = json.loads((FIXTURES / 'malformed-cases.json').read_text())
out = OUT / name
out.mkdir(exist_ok=False)
env = {'PATH': '/usr/bin:/bin', 'LANG': 'C', 'LC_ALL': 'C',
       'CML_HEAP_SIZE': '256', 'CML_STACK_SIZE': '256'}
records = []
for case, kind in [(c, 'typed') for c in cases] + [(c, 'malformed') for c in malformed]:
    work = out / case['name']
    work.mkdir(exist_ok=False)
    stdin = (FIXTURES / 'wire' / (case['name'] + '.stdin')).read_bytes()
    expected_stdout = (FIXTURES / 'wire' / (case['name'] + '.stdout')).read_bytes() if kind == 'typed' else b''
    assert sha(exe) == build['executable_sha256']
    argv = [str(exe)]
    started = time.monotonic()
    timed_out = False
    spawn_error = None
    try:
        result = subprocess.run(argv, input=stdin, capture_output=True, env=env, timeout=30)
        stdout, stderr, code = result.stdout, result.stderr, result.returncode
    except subprocess.TimeoutExpired as error:
        timed_out = True
        stdout, stderr, code = error.stdout or b'', error.stderr or b'', None
    except OSError as error:
        spawn_error = repr(error)
        stdout, stderr, code = b'', b'', None
    (work / 'stdin.bin').write_bytes(stdin)
    (work / 'stdout.bin').write_bytes(stdout)
    (work / 'stderr.bin').write_bytes(stderr)
    matches = stdout == expected_stdout
    # Exit0 is a concrete typed-input test criterion, not inferred from logical
    # Terminate Success. Malformed process status remains observational only.
    passed = not timed_out and matches and code is not None and (code == 0 if kind == 'typed' else code >= 0)
    record = {'case': case['name'], 'kind': kind, 'argv': argv, 'environment': env,
              'actual_exit': code, 'timed_out': timed_out,
              'spawn_error': spawn_error,
              'wall_seconds': time.monotonic() - started,
              'executable_sha256': build['executable_sha256'],
              'stdin_sha256': hashlib.sha256(stdin).hexdigest(),
              'stdout_sha256': hashlib.sha256(stdout).hexdigest(),
              'expected_stdout_sha256': hashlib.sha256(expected_stdout).hexdigest(),
              'stdout_matches_model': matches, 'observation_check_passed': passed,
              'process_exit_contract': 'TEST_EXPECTATION_0_NOT_PROOF' if kind == 'typed' else 'NOT_ESTABLISHED',
              'contract_control_verdict': ('OBSERVATION_MATCH' if passed else 'OBSERVATION_FAILURE') if kind == 'typed' else 'INCOMPLETE_NO_NATIVE_ERROR_CONTRACT',
              'end_to_end': False}
    (work / 'command.json').write_text(json.dumps(record, indent=2) + '\n')
    records.append(record)
    assert sha(exe) == build['executable_sha256']
    print(json.dumps({k: record[k] for k in ['case', 'actual_exit', 'stdout_matches_model', 'observation_check_passed']}), flush=True)
    if spawn_error or timed_out:
        break

summary = {'actual_exit': 0 if all(r['observation_check_passed'] for r in records) else 1,
           'executable_sha256': build['executable_sha256'], 'cases': records,
           'observed_case_count': len(records), 'expected_case_count': len(cases) + len(malformed),
           'scope': 'Actual native pipe observations only; malformed process-exit proof remains open',
           'native_contract_validation': 'INCOMPLETE',
           'end_to_end': False}
(out / 'result.json').write_text(json.dumps(summary, indent=2) + '\n')
raise SystemExit(summary['actual_exit'])
