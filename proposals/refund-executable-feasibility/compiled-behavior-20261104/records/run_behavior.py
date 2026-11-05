"""Check the existing compiler-correctness composition after exact compilation."""
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
compile_attempt = out / ('compile-' + sys.argv[2])
compiled = json.loads((compile_attempt / 'command.json').read_text())
assert compiled['actual_exit'] == 0 and compiled['status'] == 'FINISHED'
assert len(compiled['object_sha256']) == 6
assert compiled['assembly_sha256']
digest = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
compile_work = tc / 'cakeml/compiler/dafny/forge_refundArm8Compile_experiment'
assert digest(compile_work / 'forge_refundArm8CompileScript.sml') == compiled['source_sha256']
assert digest(compile_work / 'refund.S') == compiled['assembly_sha256']
for member, expected in compiled['object_sha256'].items():
    assert digest(compile_work / '.hol/objs' / member) == expected
    assert digest(compile_attempt / 'objects' / member) == expected

work = tc / 'cakeml/compiler/dafny/forge_refundArm8Proof_experiment'
work.mkdir(exist_ok=True)
attempt = out / ('behavior-' + sys.argv[1])
attempt.mkdir(exist_ok=False)
prior = attempt / 'prior-outputs'
prior.mkdir()
for pattern in ['.hol/objs/forge_refundArm8ProofTheory.*', '*.dumpedheap']:
    for file in work.glob(pattern):
        shutil.move(str(file), str(prior / file.name))
source = out / 'forge_refundArm8ProofScript.sml'
shutil.copyfile(source, work / source.name)
shutil.copyfile(source, attempt / source.name)
holmakefile = 'INCLUDES = ../forge_refundArm8Compile_experiment ../../backend/arm8/proofs\n'
(work / 'Holmakefile').write_text(holmakefile)
(attempt / 'Holmakefile').write_text(holmakefile)
env = os.environ.copy()
env.update(HOLDIR=str(tc / 'HOL'), CAKEMLDIR=str(tc / 'cakeml'))
env['PATH'] = str(tc / 'poly-install/bin') + os.pathsep + env['PATH']
argv = [str(tc / 'HOL/bin/Holmake'), '--no-cache', '-j', '2', 'forge_refundArm8ProofTheory.uo']
invocation = dict(argv=argv, cwd=str(work), actual_exit=None, status='STARTING',
                  source_sha256=digest(source), compiler_record=compiled,
                  end_to_end=False, native_execution='NOT RUN', signing='NOT RUN')
(attempt / 'invocation.json').write_text(json.dumps(invocation, indent=2)+'\n')
started = time.monotonic()
with (attempt / 'build.log').open('wb') as log:
    result = subprocess.run(argv, cwd=work, env=env, stdout=log, stderr=subprocess.STDOUT)
objects = attempt / 'objects'
objects.mkdir()
for file in (work / '.hol/objs').glob('forge_refundArm8ProofTheory.*'):
    shutil.copyfile(file, objects / file.name)
theory_log = work / '.hol/logs/forge_refundArm8ProofTheory'
if theory_log.exists():
    shutil.copyfile(theory_log, attempt / 'theory.log')
record = dict(invocation, actual_exit=result.returncode, status='FINISHED',
              wall_seconds=time.monotonic()-started,
              object_sha256={f.name:digest(f) for f in objects.iterdir()})
(attempt / 'command.json').write_text(json.dumps(record, indent=2)+'\n')
print(json.dumps(record), flush=True)
print((attempt / 'build.log').read_text(errors='replace')[-3000:], flush=True)
sys.exit(result.returncode)
