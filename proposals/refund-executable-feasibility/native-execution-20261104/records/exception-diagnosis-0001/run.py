from pathlib import Path
import hashlib
import json
import os
import subprocess
import time

OUT = Path(__file__).resolve().parent
ROOT = Path('/Users/mackianni/forge')
TC = ROOT / '.toolchain/experiments/refund-cakeml-20261104'
WORK = TC / 'cakeml/compiler/dafny/forge_refundRejectProof_experiment'
EARLIER = ROOT / 'results/refund-exception-bridge-2026-11-04/attempt-0001'
def sha(p):
    h = hashlib.sha256()
    with p.open('rb') as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()
heaps = json.loads((EARLIER / 'failure-heaps.json').read_text())['preserved']
for item in heaps:
    assert sha(Path(item['path'])) == item['sha256']
heap = WORK / 'forge_refundRejectProof.refund_call_main_exception.dumpedheap'
argv = [str(TC / 'HOL/bin/hol'), '--holstate=' + str(heap)]
env = os.environ.copy()
env.update(HOLDIR=str(TC / 'HOL'), CAKEMLDIR=str(TC / 'cakeml'))
env['PATH'] = str(TC / 'poly-install/bin') + os.pathsep + env['PATH']
record = {'argv': argv, 'cwd': str(WORK), 'heap_sha256': sha(heap),
          'script_sha256': sha(OUT / 'inspect.sml'), 'scope': 'Inspection only; no theorem export',
          'original_failed_checks': 5, 'new_full_lemma_attempts': 0, 'end_to_end': False}
(OUT / 'invocation.json').write_text(json.dumps(record, indent=2) + '\n')
start = time.monotonic()
with (OUT / 'inspect.sml').open('rb') as inp, (OUT / 'stdout.log').open('wb') as log:
    child = subprocess.run(argv, cwd=WORK, env=env, stdin=inp, stdout=log, stderr=subprocess.STDOUT)
record.update(actual_exit=child.returncode, wall_seconds=time.monotonic() - start)
for item in heaps:
    assert sha(Path(item['path'])) == item['sha256']
(OUT / 'command.json').write_text(json.dumps(record, indent=2) + '\n')
print(json.dumps(record))
raise SystemExit(child.returncode)
