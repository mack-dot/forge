"""Run the published in-logic compiler only. Never link, sign or execute output."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time

root = Path('/Users/mackianni/forge')
out = Path(__file__).resolve().parent
tc = root / '.toolchain/experiments/refund-cakeml-20261104'
previous = root / 'results/refund-stdio-composition-2026-11-04/attempt-0001'
matrix = json.loads((previous / 'whole-acceptance-matrix.json').read_text())
assert matrix['actual_exit'] == 0 and all(x['passed'] for x in matrix['results'])
assert json.loads((previous / 'whole-readback.json').read_text())['actual_exit'] == 0
positive = json.loads((previous / 'proof-whole-repeat/command.json').read_text())
assert positive['actual_exit'] == 0
work = tc / 'cakeml/compiler/dafny/forge_refundArm8Compile_experiment'
work.mkdir(exist_ok=True)
attempt = out / ('compile-' + sys.argv[1])
attempt.mkdir(exist_ok=False)
prior = attempt / 'prior-outputs'
prior.mkdir()
for pattern in ['.hol/objs/forge_refundArm8CompileTheory.*', '*.dumpedheap', 'refund.S']:
    for file in work.glob(pattern):
        shutil.move(str(file), str(prior / file.name))
source = out / 'forge_refundArm8CompileScript.sml'
shutil.copyfile(source, work / source.name)
shutil.copyfile(source, attempt / source.name)
holmakefile = ('INCLUDES = ../forge_refundWholeProg_experiment ../../../cv_translator\n'
               'ifdef POLY\nHOLHEAP = $(CAKEMLDIR)/cv_translator/cake_compile_heap\nendif\n')
(work / 'Holmakefile').write_text(holmakefile)
(attempt / 'Holmakefile').write_text(holmakefile)
env = os.environ.copy()
env.update(HOLDIR=str(tc / 'HOL'), CAKEMLDIR=str(tc / 'cakeml'))
env['PATH'] = str(tc / 'poly-install/bin') + os.pathsep + env['PATH']
argv = [str(tc / 'HOL/bin/Holmake'), '--no-cache', '-j', '2', 'forge_refundArm8CompileTheory.uo']
digest = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
parent = work.parent / 'forge_refundWholeProg_experiment'
assert digest(parent / 'forge_refundWholeProgScript.sml') == positive['source_sha256']
for member, expected in positive['object_sha256'].items():
    assert digest(parent / '.hol/objs' / member) == expected
start_record = dict(argv=argv, cwd=str(work), actual_exit=None, status='STARTING',
                    source_sha256=digest(source), whole_program=positive,
                    end_to_end=False, native_execution='NOT RUN', signing='NOT RUN')
(attempt / 'invocation.json').write_text(json.dumps(start_record, indent=2)+'\n')
started = time.monotonic()
with (attempt / 'build.log').open('wb') as log:
    result = subprocess.run(argv, cwd=work, env=env, stdout=log, stderr=subprocess.STDOUT)
objects = attempt / 'objects'
objects.mkdir()
for file in (work / '.hol/objs').glob('forge_refundArm8CompileTheory.*'):
    shutil.copyfile(file, objects / file.name)
log = work / '.hol/logs/forge_refundArm8CompileTheory'
if log.exists():
    shutil.copyfile(log, attempt / 'theory.log')
assembly = work / 'refund.S'
if assembly.exists():
    shutil.copyfile(assembly, attempt / assembly.name)
record = dict(start_record, actual_exit=result.returncode, status='FINISHED',
              wall_seconds=time.monotonic()-started,
              object_sha256={f.name:digest(f) for f in objects.iterdir()},
              assembly_sha256=digest(assembly) if assembly.exists() else None)
(attempt / 'command.json').write_text(json.dumps(record, indent=2)+'\n')
print(json.dumps(record), flush=True)
print((attempt / 'build.log').read_text(errors='replace')[-3000:], flush=True)
sys.exit(result.returncode)
