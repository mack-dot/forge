from pathlib import Path
import hashlib, json, os, resource, shutil, subprocess, sys

ROOT = Path('/Users/mackianni/forge')
OUT = Path(__file__).resolve().parent
TC = ROOT / '.toolchain/experiments/refund-cakeml-20261104'
OLD = ROOT / 'results/refund-native-audit-2026-11-04/attempt-0010'
def sha(p):
    h = hashlib.sha256()
    with Path(p).open('rb') as f:
        for b in iter(lambda: f.read(1048576), b''): h.update(b)
    return h.hexdigest()
inputs = json.loads((OLD.parent / 'attempt-0009/inputs.json').read_text())['input_files']
for p,h in inputs.items(): assert sha(p) == h, p
case = OUT / sys.argv[1]
case.mkdir(exist_ok=False)
source = OUT / sys.argv[2]
shutil.copyfile(source, case / 'proof.sml')
(case / 'preload.sml').write_text('load "fsFFIPropsTheory";\n')
argv = [str(TC / 'HOL/bin/hol'), 'run',
        '--holstate=' + str(TC / 'cakeml/misc/cakeml-heap'), str(case / 'preload.sml')]
parents = [OLD / 'model-0007']
if len(sys.argv) > 3: parents.append(OUT / sys.argv[3])
for parent in parents:
    name = 'forge_refundReadBoundary' if parent == parents[0] else 'forge_refundStdinDomain'
    for suffix in ['.sig','.sml']:
        p = parent / (name + 'Theory' + suffix)
        argv.append(str(p))
        physical = parent / '.hol/objs' / p.name
        inputs[str(physical)] = sha(physical)
    p = parent / '.hol/objs' / (name + 'Theory.dat')
    inputs[str(p)] = sha(p)
argv.append(str(case / 'proof.sml'))
env = dict(os.environ, HOLDIR=str(TC / 'HOL'), CAKEMLDIR=str(TC / 'cakeml'),
           FORGE_READ_OUT=str(case))
env['PATH'] = str(TC / 'poly-install/bin') + os.pathsep + env['PATH']
record = {'argv':argv, 'cwd':str(TC / 'cakeml/basis'), 'source_sha256':sha(source),
          'input_files':inputs, 'cpu_seconds':120, 'end_to_end':False}
(case / 'invocation.json').write_text(json.dumps(record,indent=2)+'\n')
def limits():
    resource.setrlimit(resource.RLIMIT_CPU,(120,120))
    resource.setrlimit(resource.RLIMIT_CORE,(0,0))
with (case / 'stdout.log').open('wb') as stdout, (case / 'stderr.log').open('wb') as stderr:
    result = subprocess.run(argv,cwd=record['cwd'],env=env,stdout=stdout,stderr=stderr,preexec_fn=limits)
record['actual_exit'] = result.returncode
record['completion_marker'] = 'STDIN_DOMAIN_COMPLETE' in (case / 'stdout.log').read_text()
record['stdout_sha256'] = sha(case / 'stdout.log')
record['stderr_sha256'] = sha(case / 'stderr.log')
record['objects'] = {str(p.relative_to(case)):sha(p) for p in (case / '.hol').rglob('*') if p.is_file()}
record['inputs_unchanged'] = all(sha(p)==h for p,h in inputs.items())
(case / 'command.json').write_text(json.dumps(record,indent=2)+'\n')
print(json.dumps({k:v for k,v in record.items() if k!='input_files'},indent=2))
raise SystemExit(result.returncode if result.returncode else
                 (0 if record['completion_marker'] and record['inputs_unchanged'] else 1))
