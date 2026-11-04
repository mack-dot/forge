import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time

out = Path(__file__).resolve().parent
tc = Path('/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104')
work = tc / 'cakeml/compiler/dafny/forge_refundRejectProof_experiment'
name = sys.argv[1]
source = out / (name + '.sml')
log = out / (name + '.log')
record_path = out / (name + '-command.json')
assert not log.exists() and not record_path.exists()
env = os.environ.copy()
env.update(HOLDIR=str(tc / 'HOL'), CAKEMLDIR=str(tc / 'cakeml'))
env['PATH'] = str(tc / 'poly-install/bin') + os.pathsep + env['PATH']
argv = [str(tc / 'HOL/bin/hol'), '--holstate=' + str(work / 'forge_refundRejectProof.refund_call_main_exception.dumpedheap')]
start = time.monotonic()
with source.open('rb') as inp, log.open('wb') as output:
    child = subprocess.run(argv, cwd=work, env=env, stdin=inp, stdout=output, stderr=subprocess.STDOUT)
record = dict(argv=argv, cwd=str(work), actual_exit=child.returncode,
              wall_seconds=time.monotonic()-start,
              source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),
              scope='Diagnostic against saved failed exception goal; not a full source build or exported theorem')
record_path.write_text(json.dumps(record, indent=2)+'\n')
print(json.dumps(record))
print(log.read_text(errors='replace')[-10000:])
sys.exit(child.returncode)
