"""Run the existing HOL4 checker on the local refund semantics experiment."""
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
build = json.loads((OUT / 'tool-build/commands.json').read_text())
assert build[-1]['label'] == 'hol-build' and build[-1]['actual_exit'] == 0
attempt = OUT / 'refund_kernel' / ('attempt-' + sys.argv[1])
attempt.mkdir(exist_ok=False)
work = TC / 'cakeml/compiler/dafny/forge_refund_experiment'
work.mkdir(exist_ok=True)
source = Path(sys.argv[2]).resolve() if len(sys.argv) > 2 else OUT / 'refund_kernel/forge_refundScript.sml'
assert not (work / source.name).is_symlink()
prior = attempt / 'prior-outputs'
prior.mkdir()
for old in (work / '.hol/objs').glob('forge_refundTheory.*'):
    shutil.move(str(old), str(prior / old.name))
for old in work.glob('*.dumpedheap'):
    shutil.move(str(old), str(prior / old.name))
shutil.copyfile(source, work / source.name)
shutil.copy2(source, attempt / source.name)
(work / 'Holmakefile').write_text('ifdef POLY\nHOLHEAP = $(CAKEMLDIR)/misc/cakeml-heap\nendif\n')
env = os.environ.copy()
env['HOLDIR'] = str(TC / 'HOL')
env['CAKEMLDIR'] = str(TC / 'cakeml')
env['PATH'] = str(TC / 'poly-install/bin') + os.pathsep + env['PATH']
argv = [str(TC / 'HOL/bin/Holmake'), '--no-cache', '-j', '2', 'forge_refundTheory.uo']
t = time.monotonic()
with (attempt / 'build.log').open('wb') as log:
    p = subprocess.run(argv, cwd=work, env=env, stdout=log, stderr=subprocess.STDOUT)
record = dict(argv=argv, cwd=str(work), actual_exit=p.returncode,
              wall_seconds=time.monotonic()-t, source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),
              compiled_refund_claim_established=False, unicode_correspondence_established=False,
              end_to_end=False)
objects = attempt / 'objects'
objects.mkdir()
for path in (work / '.hol/objs').glob('forge_refundTheory.*'):
    shutil.copy2(path,objects/path.name)
record['object_sha256'] = {p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(objects.iterdir())}
record['proof_outputs_accepted'] = p.returncode == 0 and (objects/'forge_refundTheory.dat').is_file()
logs = work / '.hol/logs/forge_refundTheory'
if logs.is_file(): shutil.copy2(logs,attempt/'theory.log')
(attempt / 'command.json').write_text(json.dumps(record,indent=2)+'\n')
print(json.dumps(record),flush=True)
print((attempt/'build.log').read_text(errors='replace')[-3500:],flush=True)
raise SystemExit(p.returncode)
