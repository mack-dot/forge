"""Check I/O-specific substitutions and restore the exact positive source."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys

out = Path(__file__).resolve().parent
positive = json.loads((out / 'proof-stdio-0004/command.json').read_text())
source = (out / 'forge_refundStdioProgScript.sml').read_text()
assert positive['actual_exit'] == 0
assert hashlib.sha256(source.encode()).hexdigest() == positive['source_sha256']
assert json.loads((out / 'wire-acceptance-matrix.json').read_text())['actual_exit'] == 0
cases = [
    ('stdio-suppressed-output', 'TextIO.print (refund_dispatch wire)',
     'let val unused = refund_dispatch wire in () end', 'refund_main_valid'),
    ('stdio-substituted-input', 'TextIO.inputAllFrom None',
     'TextIO.inputAllFrom (Some "substituted-input")', 'refund_main_valid'),
]
results = []
for name, original, mutation, theorem in cases:
    assert source.count(original) == 1, name
    directory = out / 'controls' / name
    directory.mkdir(parents=True, exist_ok=False)
    candidate = directory / 'forge_refundStdioProgScript.sml'
    candidate.write_text(source.replace(original, mutation))
    argv = [sys.executable, '-B', str(out / 'run_stdio.py'), name, str(candidate)]
    with (directory / 'dispatch.log').open('wb') as log:
        child = subprocess.run(argv, stdout=log, stderr=subprocess.STDOUT)
    attempt = out / ('proof-' + name)
    record = json.loads((attempt / 'command.json').read_text())
    intended = ('Tactic failure proving "' + theorem + '"') in (attempt / 'theory.log').read_text()
    accepted = bool(record['object_sha256'])
    result = dict(case=name, argv=argv, actual_exit=child.returncode, expected_exit=1,
                  theorem=theorem, intended_reason=intended, accepted_export=accepted,
                  passed=child.returncode == record['actual_exit'] == 1 and intended and not accepted)
    results.append(result)
    print(json.dumps(result), flush=True)
argv = [sys.executable, '-B', str(out / 'run_stdio.py'), 'stdio-repeat']
with (out / 'stdio-repeat-dispatch.log').open('wb') as log:
    child = subprocess.run(argv, stdout=log, stderr=subprocess.STDOUT)
repeat = json.loads((out / 'proof-stdio-repeat/command.json').read_text())
same = positive['object_sha256'] == repeat['object_sha256']
results.append(dict(case='stdio-repeat', argv=argv, actual_exit=child.returncode,
                    expected_exit=0, same_exports=same,
                    passed=child.returncode == repeat['actual_exit'] == 0 and same
                        and repeat['source_sha256'] == positive['source_sha256']))
code = 0 if all(r['passed'] for r in results) else 1
(out / 'stdio-acceptance-matrix.json').write_text(json.dumps(
    dict(actual_exit=code, results=results, end_to_end=False,
         scope='Local HOL proof controls; not native or hosted execution'), indent=2)+'\n')
print(json.dumps(results[-1]), flush=True)
sys.exit(code)
