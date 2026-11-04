"""Run the documented HOL batch interface with preserved output and exact identities."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time

OUT = Path(__file__).resolve().parent
TC = Path('/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104')
WORK = TC / 'cakeml/compiler/dafny/forge_refundWireProg_experiment'
record = OUT / sys.argv[1]
record.mkdir(exist_ok=False)
source = Path(sys.argv[2]) if len(sys.argv) > 2 else OUT / 'fixtures.sml'
shutil.copyfile(source, record / source.name)
env = os.environ.copy()
env.update(HOLDIR=str(TC / 'HOL'), CAKEMLDIR=str(TC / 'cakeml'))
env['PATH'] = str(TC / 'poly-install/bin') + os.pathsep + env['PATH']
argv = [str(TC / 'HOL/bin/hol'), 'run',
        '--holstate=' + str(TC / 'cakeml/misc/cakeml-heap'),
        str(source)]
start = time.monotonic()
with (record / 'stdout.log').open('wb') as stdout, (record / 'stderr.log').open('wb') as stderr:
    result = subprocess.run(argv, cwd=WORK, env=env, stdout=stdout, stderr=stderr)
summary = {'argv': argv, 'cwd': str(WORK), 'actual_exit': result.returncode,
           'wall_seconds': time.monotonic() - start,
           'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
           'hol_executable_sha256': hashlib.sha256((TC / 'HOL/bin/hol').read_bytes()).hexdigest(),
           'heap_sha256': hashlib.sha256((TC / 'cakeml/misc/cakeml-heap').read_bytes()).hexdigest(),
           'native_execution': 'NOT_RUN', 'end_to_end': False}
(record / 'command.json').write_text(json.dumps(summary, indent=2) + '\n')
if result.returncode == 0:
    copies = record / 'wire'
    shutil.copytree(OUT / 'wire', copies)
    (record / 'wire-sha256.json').write_text(json.dumps({
        p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(copies.iterdir())
    }, indent=2) + '\n')
print(json.dumps(summary), flush=True)
print((record / 'stdout.log').read_text(errors='replace')[-1500:])
print((record / 'stderr.log').read_text(errors='replace')[-1500:])
raise SystemExit(result.returncode)
