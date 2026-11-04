"""Run real HOL mutations; require the exact proof refusal and positive repeat."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys

out = Path(__file__).resolve().parent
old = out.parents[1] / 'refund-wire-library-2026-11-04/attempt-0001'
positive = json.loads((old / 'proof-wire-0001/command.json').read_text())
source = (out / 'forge_refundWireProgScript.sml').read_text()
assert hashlib.sha256(source.encode()).hexdigest() == positive['source_sha256']
cases = [
    ('wire-swapped-response-ids', 'sexp_to_string (refund_response ok a r c q n)',
     'sexp_to_string (refund_response ok a r q c n)', 'refund_render_fields_roundtrip'),
    ('wire-accepted-trailing-error', 'INL err => INL err',
     'INL err => if err = «refund: trailing input» then INR «» else INL err',
     'refund_run_wire_decode_error'),
    ('wire-suppressed-exception', 'Inl msg => raise Fail msg',
     'Inl msg => msg', 'refund_dispatch_error'),
]
results = []
for name, original, mutation, theorem in cases:
    assert source.count(original) == 1, name
    directory = out / 'controls' / name
    directory.mkdir(parents=True, exist_ok=False)
    candidate = directory / 'forge_refundWireProgScript.sml'
    candidate.write_text(source.replace(original, mutation))
    argv = [sys.executable, '-B', str(out / 'run_wire.py'), name, str(candidate)]
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

argv = [sys.executable, '-B', str(out / 'run_wire.py'), 'wire-repeat']
with (out / 'wire-repeat-dispatch.log').open('wb') as log:
    child = subprocess.run(argv, stdout=log, stderr=subprocess.STDOUT)
repeat = json.loads((out / 'proof-wire-repeat/command.json').read_text())
same = positive['object_sha256'] == repeat['object_sha256']
results.append(dict(case='wire-repeat', argv=argv, actual_exit=child.returncode,
                    expected_exit=0, same_exports=same,
                    passed=child.returncode == repeat['actual_exit'] == 0 and same
                        and repeat['source_sha256'] == positive['source_sha256']))
code = 0 if all(r['passed'] for r in results) else 1
(out / 'wire-acceptance-matrix.json').write_text(json.dumps(
    dict(actual_exit=code, results=results, end_to_end=False,
         scope='Local HOL proof controls; not native or hosted execution'), indent=2)+'\n')
print(json.dumps(results[-1]), flush=True)
sys.exit(code)
