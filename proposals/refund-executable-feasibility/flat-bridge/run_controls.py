"""Dispatch the existing Dafny checker. This is a test runner, not a verifier."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import time

HERE = Path(__file__).resolve().parent
BASE = HERE / 'attempt-0001'
RECORD = json.loads((BASE / 'verify-command.json').read_text())
FILES = ('FlatCore.dfy', 'Bridge.dfy', 'impl/Refund.dfy', 'spec/refund/RefundSpec.dfy')

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def run(name, mutate=None, expected=0):
    directory = HERE / name
    directory.mkdir()  # Preserve all prior attempts; never overwrite one.
    for name_ in FILES:
        dest = directory / name_
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(BASE / name_, dest)
    if mutate:
        path = directory / 'FlatCore.dfy'
        path.write_text(mutate(path.read_text()))
    start = time.monotonic()
    result = subprocess.run(RECORD['argv'], cwd=directory, capture_output=True)
    duration = time.monotonic() - start
    (directory / 'stdout.log').write_bytes(result.stdout)
    (directory / 'stderr.log').write_bytes(result.stderr)
    reason_ok = result.returncode == 0 if expected == 0 else (
        b'a postcondition could not be proved' in result.stdout and
        b'FlatCore.dfy' in result.stdout)
    record = dict(argv=RECORD['argv'], cwd=str(directory), expected_exit=expected,
                  actual_exit=result.returncode, expected_reason_matched=reason_ok,
                  wall_seconds=duration, source_sha256={f: digest(directory / f) for f in FILES},
                  stdout_sha256=digest(directory / 'stdout.log'),
                  stderr_sha256=digest(directory / 'stderr.log'), end_to_end=False)
    if expected == 0:
        record['same_sources_as_original'] = record['source_sha256'] == RECORD['source_sha256']
        record['same_verifier_output_as_original'] = result.stdout == (BASE / 'verify.log').read_bytes()
    (directory / 'command.json').write_text(json.dumps(record, indent=2) + '\n')
    return record

def remove_bound(text):
    before, body = text.split('  {\n', 1)
    assert body.count('0 <= amount <= remaining') == 1
    return before + '  {\n' + body.replace('0 <= amount <= remaining', '0 <= amount', 1)

def reject_all(text):
    before, body = text.split('  {\n', 1)
    start = body.index('    authorized :=')
    end = body.index(';', start) + 1
    return before + '  {\n' + body[:start] + '    authorized := false;' + body[end:]

records = [run('repeat-0001'),
           run('over-limit-0001', remove_bound, 4),
           run('reject-all-0001', reject_all, 4)]
ok = all(r['actual_exit'] == r['expected_exit'] and r['expected_reason_matched'] for r in records)
ok = ok and records[0]['same_sources_as_original'] and records[0]['same_verifier_output_as_original']
summary = dict(actual_exit=0 if ok else 1, cases=records,
               claim='Source representation checks only; no compiled artifact established.',
               end_to_end=False)
(HERE / 'controls-result.json').write_text(json.dumps(summary, indent=2) + '\n')
print(json.dumps({"actual_exit": summary['actual_exit'], "cases": [
    {"cwd": r['cwd'], "actual_exit": r['actual_exit'], "reason_ok": r['expected_reason_matched']}
    for r in records]}))
raise SystemExit(summary['actual_exit'])
