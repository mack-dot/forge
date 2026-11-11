from pathlib import Path
import hashlib, json, os, resource, shutil, subprocess, sys

ROOT = Path('/Users/mackianni/forge')
OUT = Path(__file__).resolve().parent
TC = ROOT / '.toolchain/experiments/refund-cakeml-20261104'

def sha(path):
    h = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for chunk in iter(lambda: stream.read(1048576), b''):
            h.update(chunk)
    return h.hexdigest()

inputs = json.loads((OUT / 'inputs.json').read_text())['input_files']
for path, value in inputs.items():
    assert sha(path) == value, path
case = OUT / sys.argv[1]
source = OUT / sys.argv[2]
mode = sys.argv[3] if len(sys.argv) > 3 else 'proof'
case.mkdir(exist_ok=False)
shutil.copyfile(source, case / 'proof.sml')
(case / 'preload.sml').write_text('load "forge_refundArm8ProofTheory";\n')
argv = [str(TC / 'HOL/bin/hol'), 'run',
        '--holstate=' + str(TC / 'cakeml/misc/cakeml-heap'), str(case / 'preload.sml')]
parents = [
    (OUT.parent / 'attempt-0006/export-0002', 'forge_refundRejectDirect'),
    (OUT.parent / 'attempt-0007/stdio-0003', 'forge_refundRejectSemantics'),
    (OUT.parent / 'attempt-0008/concrete-0001', 'forge_refundRejectBasis'),
    (ROOT / 'results/refund-runtime-premises-2026-11-04/attempt-0002/precise-0003', 'forge_refundPreciseBehavior'),
]
if mode == 'import':
    own = json.loads((OUT / 'accepted-inputs.json').read_text())['objects']
    for rel, value in own.items():
        assert sha(OUT / 'accepted' / rel) == value, rel
        inputs[str(OUT / 'accepted' / rel)] = value
    parents.append((OUT / 'accepted', 'forge_refundRejectCompiled'))
for directory, name in parents:
    argv.extend(str(directory / (name + 'Theory' + suffix)) for suffix in ['.sig', '.sml'])
argv.append(str(case / 'proof.sml'))
env = dict(os.environ, HOLDIR=str(TC / 'HOL'), CAKEMLDIR=str(TC / 'cakeml'), FORGE_ERROR_OUT=str(case))
env['PATH'] = str(TC / 'poly-install/bin') + os.pathsep + env['PATH']
cwd = TC / 'cakeml/compiler/dafny/forge_refundArm8Proof_experiment'
record = {'argv': argv, 'cwd': str(cwd), 'source_sha256': sha(source),
          'validated_input_files': len(inputs), 'cpu_seconds_per_process': 3600,
          'mode': mode, 'end_to_end': False}
(case / 'invocation.json').write_text(json.dumps(record, indent=2) + '\n')
def limits():
    resource.setrlimit(resource.RLIMIT_CPU, (3600, 3600))
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
with (case / 'stdout.log').open('wb') as stdout, (case / 'stderr.log').open('wb') as stderr:
    child = subprocess.run(argv, cwd=cwd, env=env, stdout=stdout, stderr=stderr, preexec_fn=limits)
for path, value in inputs.items():
    assert sha(path) == value, path
record.update(actual_exit=child.returncode,
              completion_marker='ERROR_COMPILER_COMPLETE' in (case / 'stdout.log').read_text(),
              objects={str(p.relative_to(case)): sha(p) for p in (case / '.hol').rglob('*') if p.is_file()})
(case / 'command.json').write_text(json.dumps(record, indent=2) + '\n')
print(json.dumps(record, indent=2))
raise SystemExit(child.returncode if child.returncode else (0 if record['completion_marker'] else 1))
