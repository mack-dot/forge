from pathlib import Path
import hashlib, json, os, resource, shutil, subprocess, sys
ROOT = Path('/Users/mackianni/forge')
OUT = Path(__file__).resolve().parent
TC = ROOT / '.toolchain/experiments/refund-cakeml-20261104'
def sha(path):
    h = hashlib.sha256()
    with Path(path).open('rb') as f:
        for data in iter(lambda: f.read(1048576), b''): h.update(data)
    return h.hexdigest()
inputs = json.loads((OUT.parent / 'attempt-0009/inputs.json').read_text())['input_files']
for p,h in inputs.items(): assert sha(p) == h, p
extra = json.loads((OUT / 'baseline.json').read_text())['step_tools']
for p,h in extra.items(): assert sha(p) == h, p
case = OUT / sys.argv[1]
case.mkdir(exist_ok=False)
source = OUT / sys.argv[2]
shutil.copyfile(source, case / 'proof.sml')
(case / 'preload.sml').write_text('load "arm8_stepLib";\n')
argv = [str(TC / 'HOL/bin/hol'), 'run', '--holstate=' + str(TC / 'cakeml/misc/cakeml-heap'), str(case / 'preload.sml')]
if len(sys.argv) > 3:
    for suffix in ['.sig','.sml']:
        argv.append(str(OUT / sys.argv[3] / ('forge_refundNativeReadErrorTheory' + suffix)))
argv.append(str(case / 'proof.sml'))
env = dict(os.environ, HOLDIR=str(TC / 'HOL'), CAKEMLDIR=str(TC / 'cakeml'), FORGE_NATIVE_STEP_OUT=str(case))
env['PATH'] = str(TC / 'poly-install/bin') + os.pathsep + env['PATH']
cwd = TC / 'cakeml/basis'
record = {'argv':argv,'cwd':str(cwd),'source_sha256':sha(source),'validated_parent_files':len(inputs),'cpu_seconds_per_process':3600,'end_to_end':False}
(case / 'invocation.json').write_text(json.dumps(record,indent=2)+'\n')
def limits():
    resource.setrlimit(resource.RLIMIT_CPU,(3600,3600));resource.setrlimit(resource.RLIMIT_CORE,(0,0))
with (case / 'stdout.log').open('wb') as stdout,(case / 'stderr.log').open('wb') as stderr:
    result = subprocess.run(argv,cwd=cwd,env=env,stdout=stdout,stderr=stderr,preexec_fn=limits)
for p,h in inputs.items(): assert sha(p) == h, p
for p,h in extra.items(): assert sha(p) == h, p
record.update(actual_exit=result.returncode,completion_marker='NATIVE_STEP_COMPLETE' in (case / 'stdout.log').read_text(),objects={str(p.relative_to(case)):sha(p) for p in (case / '.hol').rglob('*') if p.is_file()})
(case / 'command.json').write_text(json.dumps(record,indent=2)+'\n');print(json.dumps(record,indent=2))
raise SystemExit(result.returncode if result.returncode else (0 if record['completion_marker'] else 1))
