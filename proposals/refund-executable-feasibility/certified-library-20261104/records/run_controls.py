"""Dispatch real HOL builds and check explicit adversarial outcomes."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys

out = Path(__file__).resolve().parent
positive = json.loads((out / 'proof-library-0005/command.json').read_text())
assert positive['actual_exit'] == 0
source = (out / 'forge_refundCertifiedProgScript.sml').read_text()
assert hashlib.sha256(source.encode()).hexdigest() == positive['source_sha256']
cases = [
    ('altered-amount', '(if ok then amount else 0)', '(if ok then amount + 1 else 0)',
     'refund_fields_original_method'),
    ('swapped-wrapper-ids',
     '    refund_fields charge request original remaining enabled opened candidate amount reason;',
     '    refund_fields request charge original remaining enabled opened candidate amount reason;',
     'refund_verified_spec'),
]
results = []
for name, old, new, theorem in cases:
    assert source.count(old) == 1, name
    directory = out / 'controls' / name
    directory.mkdir(parents=True, exist_ok=False)
    candidate = directory / 'forge_refundCertifiedProgScript.sml'
    candidate.write_text(source.replace(old, new))
    argv = [sys.executable, '-B', str(out / 'run.py'), name, str(candidate)]
    with (directory / 'dispatch.log').open('wb') as log:
        child = subprocess.run(argv, stdout=log, stderr=subprocess.STDOUT)
    attempt = out / ('proof-' + name)
    record = json.loads((attempt / 'command.json').read_text())
    log = (attempt / 'theory.log').read_text()
    intended_reason = 'Tactic failure proving "' + theorem + '"' in log
    accepted_export = any(n.endswith('Theory.dat') for n in record['object_sha256'])
    result = dict(case=name, argv=argv, actual_exit=child.returncode,
                  expected_exit=1, theorem=theorem, intended_reason=intended_reason,
                  accepted_export=accepted_export,
                  passed=child.returncode == 1 and record['actual_exit'] == 1
                      and intended_reason and not accepted_export)
    results.append(result)
    print(json.dumps(result), flush=True)

# Restore the exact positive candidate and require byte-identical exports.
argv = [sys.executable, '-B', str(out / 'run.py'), 'repeat']
with (out / 'repeat-dispatch.log').open('wb') as log:
    child = subprocess.run(argv, stdout=log, stderr=subprocess.STDOUT)
repeat = json.loads((out / 'proof-repeat/command.json').read_text())
same = positive['object_sha256'] == repeat['object_sha256']
results.append(dict(case='repeat', argv=argv, actual_exit=child.returncode,
                    expected_exit=0, same_exports=same,
                    passed=child.returncode == 0 and same
                        and repeat['source_sha256'] == positive['source_sha256']))
code = 0 if all(x['passed'] for x in results) else 1
(out / 'acceptance-matrix.json').write_text(json.dumps(
    dict(actual_exit=code, results=results, end_to_end=False,
         scope='Local full-result library proposal; no native or hosted execution'), indent=2) + '\n')
print(json.dumps(results[-1]), flush=True)
sys.exit(code)
