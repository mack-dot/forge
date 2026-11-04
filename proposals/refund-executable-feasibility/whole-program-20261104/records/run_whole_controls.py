"""Refuse a substituted main entry and reproduce the exact source theorem."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys

out = Path(__file__).resolve().parent
positive = json.loads((out / 'proof-whole-0001/command.json').read_text())
source = (out / 'forge_refundWholeProgScript.sml').read_text()
assert positive['actual_exit'] == 0
assert hashlib.sha256(source.encode()).hexdigest() == positive['source_sha256']
old = 'prove_sem_thm "refund_main" "refund_prog" refund_request_whole_prog_spec'
new = 'prove_sem_thm "refund_dispatch" "refund_prog" refund_request_whole_prog_spec'
assert source.count(old) == 1
directory = out / 'controls/whole-substituted-entry'
directory.mkdir(parents=True, exist_ok=False)
candidate = directory / 'forge_refundWholeProgScript.sml'
candidate.write_text(source.replace(old, new))
argv = [sys.executable, '-B', str(out / 'run_whole.py'), 'whole-substituted-entry', str(candidate)]
with (directory / 'dispatch.log').open('wb') as log:
    child = subprocess.run(argv, stdout=log, stderr=subprocess.STDOUT)
attempt = out / 'proof-whole-substituted-entry'
record = json.loads((attempt / 'command.json').read_text())
log = (attempt / 'theory.log').read_text()
# The published helper must reach its actual name/value binding check and fail.
reached = 'prove_sem_thm: using nsLookup for refund_dispatch in env' in log
completed = 'prove_sem_thm: done' in log
accepted = bool(record['object_sha256'])
result = dict(case='whole-substituted-entry', argv=argv, actual_exit=child.returncode,
              expected_exit=1, reached_entry_check=reached, bridge_completed=completed,
              accepted_export=accepted,
              passed=child.returncode == record['actual_exit'] == 1 and reached
                  and not completed and not accepted)
results = [result]
print(json.dumps(result), flush=True)
argv = [sys.executable, '-B', str(out / 'run_whole.py'), 'whole-repeat']
with (out / 'whole-repeat-dispatch.log').open('wb') as log:
    child = subprocess.run(argv, stdout=log, stderr=subprocess.STDOUT)
repeat = json.loads((out / 'proof-whole-repeat/command.json').read_text())
same = positive['object_sha256'] == repeat['object_sha256']
results.append(dict(case='whole-repeat', argv=argv, actual_exit=child.returncode,
                    expected_exit=0, same_exports=same,
                    passed=child.returncode == repeat['actual_exit'] == 0 and same
                        and repeat['source_sha256'] == positive['source_sha256']))
code = 0 if all(r['passed'] for r in results) else 1
(out / 'whole-acceptance-matrix.json').write_text(json.dumps(
    dict(actual_exit=code, results=results, end_to_end=False,
         scope='Local whole-program source semantics, not native machine code'), indent=2)+'\n')
print(json.dumps(results[-1]), flush=True)
sys.exit(code)
