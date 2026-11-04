import json
import os
from pathlib import Path
import subprocess
import time

out = Path(__file__).resolve().parent
tc = Path('/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104')
work = tc / 'cakeml/compiler/dafny/forge_refundArm8Compile_experiment'
assert not (out / 'closure-audit-0002-command.json').exists()
env = os.environ.copy()
env.update(HOLDIR=str(tc / 'HOL'), CAKEMLDIR=str(tc / 'cakeml'))
env['PATH'] = str(tc / 'poly-install/bin') + os.pathsep + env['PATH']
argv = [str(tc / 'HOL/bin/hol')]
start = time.monotonic()
with (out / 'closure-audit-0002.sml').open('rb') as inp, (out / 'closure-audit-0002.log').open('wb') as log:
    child = subprocess.run(argv, cwd=work, env=env, stdin=inp, stdout=log, stderr=subprocess.STDOUT)
record = dict(argv=argv, cwd=str(work), actual_exit=child.returncode,
              wall_seconds=time.monotonic()-start,
              scope='Fresh import and closure inspection; not replay of every upstream source')
(out / 'closure-audit-0002-command.json').write_text(json.dumps(record, indent=2)+'\n')
print(json.dumps(record))
raise SystemExit(child.returncode)
