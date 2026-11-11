"""Run existing HOL commands serially; stop on an unexpected process result."""
from pathlib import Path
import json
import subprocess
import sys

OUT = Path(__file__).resolve().parent
ROOT = Path('/Users/mackianni/forge')
parent = 'init-parent:forge_refundSuccessfulInitialization'
static = 'static-0003:forge_refundInitializationStatic'
record = json.loads((OUT/'static-0003/command.json').read_text())
assert record['actual_exit'] == 0 and record['completion_marker']
assert 'REMAINING_ANTECEDENTS 15' in (OUT/'static-0003/stdout.log').read_text()
cases = [
    ('exact-import-0002', 'run_import.py', 'expected.sml', [parent, static], 0),
    ('parent-repeat', 'run_composed.py', 'init-parent/proof.sml', [], 0),
    ('static-repeat', 'run_composed.py', 'static-normalized.sml', [parent], 0),
    ('wrong-code', 'run_import.py', 'wrong-code.sml', [parent, static], 1),
    ('wrong-oracle', 'run_import.py', 'wrong-oracle.sml', [parent, static], 1),
    ('missing-memory', 'run_import.py', 'missing-memory.sml', [parent, static], 1),
]
results = []
for name, wrapper, source, imports, required_exit in cases:
    argv = [sys.executable, '-B', str(OUT/wrapper), name, str(OUT/source), *imports]
    print('START ' + name, flush=True)
    child = subprocess.run(argv, cwd=ROOT, capture_output=True, text=True)
    item = {'case': name, 'argv': argv, 'actual_exit': child.returncode,
            'expected_exit': required_exit, 'end_to_end': False}
    results.append(item)
    (OUT/(name+'-wrapper-output.log')).write_text(child.stdout + child.stderr)
    (OUT/'validation-sequence-progress.json').write_text(json.dumps(results, indent=2)+'\n')
    print(json.dumps(item), flush=True)
    if child.returncode != required_exit:
        print('STOP: unexpected process result; inspect the preserved logs.', flush=True)
        raise SystemExit(1)
    log = ''.join((OUT/name/f).read_text() for f in ['stdout.log', 'stderr.log'])
    if required_exit == 0:
        marker = 'TRACE_IMPORT_COMPLETE' if wrapper == 'run_import.py' else 'RUNTIME_PROOF_COMPLETE'
        assert marker in log
    else:
        assert 'AFTER_POSITIVE_AUDIT' in log and 'UNEXPECTED_CONTROL_ACCEPTANCE' not in log
        if name == 'wrong-code':
            assert 'Exact statement mismatch: refund_lab_code' in log
        if name == 'wrong-oracle':
            assert 'Exact statement mismatch: refund_lab_oracle' in log
        if name == 'missing-memory':
            assert 'unsolved goals' in log and 'memory_assumption' in log
result = {'actual_exit': 0, 'cases': results, 'end_to_end': False}
(OUT/'validation-sequence.json').write_text(json.dumps(result, indent=2)+'\n')
print('VALIDATION_SEQUENCE_COMPLETE', flush=True)
