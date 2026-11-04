import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time

out = Path(__file__).resolve().parent
tc = Path('/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104')
work = tc / 'cakeml/compiler/dafny/forge_refundWholeProg_experiment'
work.mkdir(exist_ok=True)
attempt = out / ('proof-' + sys.argv[1])
attempt.mkdir(exist_ok=False)
prior = attempt / 'prior-outputs'
prior.mkdir()
for pattern in ['.hol/objs/forge_refundWholeProgTheory.*', '*.dumpedheap']:
    for f in work.glob(pattern):
        shutil.move(str(f), str(prior / f.name))
source = Path(sys.argv[2]) if len(sys.argv) > 2 else out / 'forge_refundWholeProgScript.sml'
shutil.copyfile(source, work / source.name)
shutil.copyfile(source, attempt / source.name)
(work / 'Holmakefile').write_text(
    'INCLUDES = ../forge_refundStdioProg_experiment\n'
    'ifdef POLY\nHOLHEAP = $(CAKEMLDIR)/misc/cakeml-heap\nendif\n')
env = os.environ.copy()
env.update(HOLDIR=str(tc / 'HOL'), CAKEMLDIR=str(tc / 'cakeml'))
env['PATH'] = str(tc / 'poly-install/bin') + os.pathsep + env['PATH']
argv = [str(tc / 'HOL/bin/Holmake'), '--no-cache', '-j', '2', 'forge_refundWholeProgTheory.uo']
started = time.monotonic()
with (attempt / 'build.log').open('wb') as log:
    result = subprocess.run(argv, cwd=work, env=env, stdout=log, stderr=subprocess.STDOUT)
objects = attempt / 'objects'
objects.mkdir()
for f in (work / '.hol/objs').glob('forge_refundWholeProgTheory.*'):
    shutil.copyfile(f, objects / f.name)
log = work / '.hol/logs/forge_refundWholeProgTheory'
if log.exists():
    shutil.copyfile(log, attempt / 'theory.log')
digest = lambda f: hashlib.sha256(f.read_bytes()).hexdigest()
record = dict(argv=argv, cwd=str(work), actual_exit=result.returncode,
              wall_seconds=time.monotonic() - started, source_sha256=digest(source),
              parent_source_sha256=digest(work.parent / 'forge_refundProg_experiment/forge_refundProgScript.sml'),
              parent_data_sha256=digest(work.parent / 'forge_refundProg_experiment/.hol/objs/forge_refundProgTheory.dat'),
              object_sha256={f.name: digest(f) for f in objects.iterdir()},
              verified_library_source_sha256=digest(work.parent / 'forge_refundCertifiedProg_experiment/forge_refundCertifiedProgScript.sml'),
              verified_library_data_sha256=digest(work.parent / 'forge_refundCertifiedProg_experiment/.hol/objs/forge_refundCertifiedProgTheory.dat'),
              wire_source_sha256=digest(work.parent / 'forge_refundWireProg_experiment/forge_refundWireProgScript.sml'),
              wire_data_sha256=digest(work.parent / 'forge_refundWireProg_experiment/.hol/objs/forge_refundWireProgTheory.dat'),
              stdio_source_sha256=digest(work.parent / 'forge_refundStdioProg_experiment/forge_refundStdioProgScript.sml'),
              stdio_data_sha256=digest(work.parent / 'forge_refundStdioProg_experiment/.hol/objs/forge_refundStdioProgTheory.dat'),
              end_to_end=False, native_refund_claim=False)
(attempt / 'command.json').write_text(json.dumps(record, indent=2) + '\n')
print(json.dumps(record), flush=True)
print((attempt / 'build.log').read_text(errors='replace')[-2000:], flush=True)
sys.exit(result.returncode)
