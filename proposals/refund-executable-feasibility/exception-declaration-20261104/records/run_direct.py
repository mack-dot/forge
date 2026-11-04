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
WORK = TC / 'cakeml/compiler/dafny/forge_refundRejectProof_experiment'
HEAP = WORK / 'forge_refundRejectProof.refund_call_main_exception.dumpedheap'
def sha(p):
    h = hashlib.sha256()
    with p.open('rb') as f:
        for chunk in iter(lambda: f.read(1048576), b''):
            h.update(chunk)
    return h.hexdigest()
assert sha(HEAP) == '7357572346bb83f5c807a96aa226a4e87160693d3a14c958c09bcf37d237034c'
assert sha(TC / 'HOL/bin/hol') == '736c669e220381ddb6042fda624db79326aaa0075fe6ff9de4751bad75e8c4dd'
SOURCE = OUT / 'direct-proof.sml'
ATTEMPT = OUT / sys.argv[1]
ATTEMPT.mkdir(exist_ok=False)
shutil.copy2(SOURCE, ATTEMPT / SOURCE.name)
argv = [str(TC / 'HOL/bin/hol'), 'run', '--holstate=' + str(HEAP), str(ATTEMPT / SOURCE.name)]
env = os.environ.copy()
env.update(HOLDIR=str(TC / 'HOL'), CAKEMLDIR=str(TC / 'cakeml'))
env['PATH'] = str(TC / 'poly-install/bin') + os.pathsep + env['PATH']
record = {'argv': argv, 'cwd': str(WORK), 'source_sha256': sha(SOURCE),
          'heap_sha256': sha(HEAP), 'scope': 'Direct exact-goal proof check; Holmake build remains failed',
          'prior_failed_checks': 5, 'subsequent_builder_exit': 1, 'end_to_end': False}
(ATTEMPT / 'invocation.json').write_text(json.dumps(record, indent=2) + '\n')
with (ATTEMPT / 'stdout.log').open('wb') as log, (ATTEMPT / 'stderr.log').open('wb') as err:
    child = subprocess.run(argv, cwd=WORK, env=env, stdout=log, stderr=err)
record['actual_exit'] = child.returncode
record['heap_unchanged'] = sha(HEAP) == record['heap_sha256']
text = (ATTEMPT / 'stdout.log').read_text()
record['completion_marker'] = 'DIRECT_PROOF_COMPLETE' in text
(ATTEMPT / 'command.json').write_text(json.dumps(record, indent=2) + '\n')
print(json.dumps(record, indent=2))
raise SystemExit(child.returncode if child.returncode else (0 if record['completion_marker'] and record['heap_unchanged'] else 1))
