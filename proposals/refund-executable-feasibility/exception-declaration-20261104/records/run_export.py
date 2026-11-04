from pathlib import Path
import hashlib
import json
import os
import shutil
import subprocess
import sys

OUT = Path(__file__).resolve().parent
ROOT = Path('/Users/mackianni/forge')
TC = ROOT / '.toolchain/experiments/refund-cakeml-20261104'
HEAP = TC / 'cakeml/misc/cakeml-heap'
WHOLE = TC / 'cakeml/compiler/dafny/forge_refundWholeProg_experiment'
def sha(p):
    h = hashlib.sha256()
    with p.open('rb') as f:
        for chunk in iter(lambda: f.read(1048576), b''):
            h.update(chunk)
    return h.hexdigest()
assert sha(HEAP) == '36f7c254cab336ae1a331a76024c94925e03f9f6774ef545742be5cf9ebd8247'
assert sha(TC / 'HOL/bin/hol') == '736c669e220381ddb6042fda624db79326aaa0075fe6ff9de4751bad75e8c4dd'
PARENT = ROOT / 'results/refund-stdio-composition-2026-11-04/attempt-0001/proof-whole-repeat/command.json'
parent_record = json.loads(PARENT.read_text())
for name, digest in parent_record['object_sha256'].items():
    assert sha(WHOLE / '.hol/objs' / name) == digest
ATTEMPT = OUT / sys.argv[1]
SOURCE = OUT / (sys.argv[2] if len(sys.argv) > 2 else 'export-proof.sml')
ATTEMPT.mkdir(exist_ok=False)
shutil.copy2(SOURCE, ATTEMPT / SOURCE.name)
(ATTEMPT / 'Holmakefile').write_text('INCLUDES = ' + str(WHOLE) + '\n')
argv = [str(TC / 'HOL/bin/hol'), 'run', '--holstate=' + str(HEAP), str(ATTEMPT / SOURCE.name)]
env = os.environ.copy()
env.update(HOLDIR=str(TC / 'HOL'), CAKEMLDIR=str(TC / 'cakeml'))
env['PATH'] = str(TC / 'poly-install/bin') + os.pathsep + env['PATH']
record = {'argv': argv, 'cwd': str(ATTEMPT), 'source_sha256': sha(SOURCE),
          'heap_sha256': sha(HEAP), 'parent_theory_files': parent_record['object_sha256'],
          'saved_failure_heap_used': False, 'scope': 'Direct HOL source replay with standard pinned heap and parent imports',
          'end_to_end': False}
(ATTEMPT / 'invocation.json').write_text(json.dumps(record, indent=2) + '\n')
with (ATTEMPT / 'stdout.log').open('wb') as log, (ATTEMPT / 'stderr.log').open('wb') as err:
    child = subprocess.run(argv, cwd=ATTEMPT, env=env, stdout=log, stderr=err)
record['actual_exit'] = child.returncode
record['object_sha256'] = {str(p.relative_to(ATTEMPT)): sha(p) for p in ATTEMPT.rglob('forge_refundRejectDirectTheory.*') if p.is_file()}
record['completion_marker'] = 'DIRECT_EXPORT_COMPLETE' in (ATTEMPT / 'stdout.log').read_text()
for name, digest in parent_record['object_sha256'].items():
    assert sha(WHOLE / '.hol/objs' / name) == digest
(ATTEMPT / 'command.json').write_text(json.dumps(record, indent=2) + '\n')
print(json.dumps(record, indent=2))
raise SystemExit(child.returncode if child.returncode else (0 if record['completion_marker'] and record['object_sha256'] else 1))
