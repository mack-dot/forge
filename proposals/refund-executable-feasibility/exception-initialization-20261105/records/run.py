from pathlib import Path
import hashlib
import json
import os
import shutil
import subprocess
import sys

ROOT = Path('/Users/mackianni/forge')
OUT = Path(__file__).resolve().parent
TC = ROOT / '.toolchain/experiments/refund-cakeml-20261104'
HEAP = TC / 'cakeml/misc/cakeml-heap'
PARENT = OUT.parent / 'attempt-0007'
DECL = OUT.parent / 'attempt-0006/export-0002'
EXPORT = PARENT / 'stdio-0003'
WHOLE = TC / 'cakeml/compiler/dafny/forge_refundWholeProg_experiment'

def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()

snapshot = json.loads((PARENT / 'dependency-snapshot.json').read_text())
inputs = dict(snapshot['input_files'])
inputs.update({str(EXPORT / rel): value for rel, value in snapshot['new_theory_files'].items()})
for path, expected in inputs.items():
    assert sha(Path(path)) == expected, path
attempt = OUT / sys.argv[1]
source = OUT / (sys.argv[2] if len(sys.argv) > 2 else 'proof.sml')
diagnostic = len(sys.argv) > 3 and sys.argv[3] == 'diagnostic'
attempt.mkdir(exist_ok=False)
shutil.copy2(source, attempt / source.name)
(attempt / 'Holmakefile').write_text('INCLUDES = ' + str(WHOLE) + '\n')
(attempt / 'preload.sml').write_text('load "forge_refundWholeProgTheory";\nload "cfMainTheory";\n')
argv = [str(TC / 'HOL/bin/hol'), 'run', '--holstate=' + str(HEAP),
        str(attempt / 'preload.sml'), str(DECL / 'forge_refundRejectDirectTheory.sig'),
        str(DECL / 'forge_refundRejectDirectTheory.sml'),
        str(EXPORT / 'forge_refundRejectSemanticsTheory.sig'),
        str(EXPORT / 'forge_refundRejectSemanticsTheory.sml'), str(attempt / source.name)]
env = os.environ.copy()
env.update(HOLDIR=str(TC / 'HOL'), CAKEMLDIR=str(TC / 'cakeml'))
env['PATH'] = str(TC / 'poly-install/bin') + os.pathsep + env['PATH']
record = {'argv': argv, 'cwd': str(attempt), 'source_sha256': sha(source),
          'heap_sha256': sha(HEAP), 'validated_input_files': len(inputs),
          'scope': 'New basis event-replay obligation; direct pinned HOL, unchanged approved specification',
          'end_to_end': False}
(attempt / 'invocation.json').write_text(json.dumps(record, indent=2) + '\n')
with (attempt / 'stdout.log').open('wb') as stdout, (attempt / 'stderr.log').open('wb') as stderr:
    child = subprocess.run(argv, cwd=attempt, env=env, stdout=stdout, stderr=stderr)
record['actual_exit'] = child.returncode
record['object_sha256'] = {str(p.relative_to(attempt)): sha(p)
    for p in attempt.rglob('forge_refundRejectBasisTheory.*') if p.is_file()}
record['diagnostic_only'] = diagnostic
record['completion_marker'] = ('DIAGNOSTIC_COMPLETE' if diagnostic else 'EXCEPTION_BASIS_COMPLETE') in (attempt / 'stdout.log').read_text()
for path, expected in inputs.items():
    assert sha(Path(path)) == expected, path
(attempt / 'command.json').write_text(json.dumps(record, indent=2) + '\n')
print(json.dumps(record, indent=2))
raise SystemExit(child.returncode if child.returncode else (0 if record['completion_marker'] and (diagnostic or record['object_sha256']) else 1))
