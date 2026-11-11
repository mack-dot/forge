"""One default tmpName dependency probe. No SAT rerun or permission workaround."""
from pathlib import Path
import hashlib
import json
import os
import resource
import subprocess

ROOT = Path('/Users/mackianni/forge')
OUT = Path(__file__).resolve().parent
TC = ROOT / '.toolchain/experiments/refund-cakeml-20261104'
PREVIOUS = OUT.parent / 'attempt-0003'

def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def read(path):
    return json.loads(Path(path).read_text())

def save(name, value):
    with (OUT / name).open('x') as handle:
        json.dump(value,handle,indent=2);handle.write('\n')

prior = read(PREVIOUS / 'preflight.json')
pins = {**prior['prior_pins_match'], **prior['current_operation_input_hashes']}
u318 = ROOT / 'proposals/refund-executable-feasibility/environment-recovery-20261106/records/source-audit.json'
for rel, digest in read(u318)['sources'].items():
    pins[str(TC / rel)] = digest
for path, digest in pins.items():
    assert sha(path) == digest, path
new_sources = {}
for rel in ['libpolyml/osmemunix.cpp','libpolyml/basicio.cpp']:
    argv = ['git','-C',str(TC / 'polyml'),'show',
            '4557554077078decce4ce5f90da00a713cfc32e4:' + rel]
    proc = subprocess.run(argv,capture_output=True)
    assert proc.returncode == 0
    data = (TC / 'polyml' / rel).read_bytes()
    assert data == proc.stdout
    target = OUT / Path(rel).name
    with target.open('xb') as handle:
        handle.write(data)
    new_sources[rel] = {'sha256':sha(target),'git_argv':argv,'git_actual_exit':proc.returncode}

private = OUT / 'private-scratch'
private.mkdir(mode=0o700)
assert private.stat().st_mode & 0o777 == 0o700
argv = [str(TC / 'HOL/bin/hol'),'run',
        '--holstate=' + str(TC / 'HOL/examples/l3-machine-code/arm8/step/arm8-heap'),
        str(OUT / 'temp_requirement.sml')]
cwd = TC / 'HOL/examples/l3-machine-code/arm8/step'
env = dict(os.environ,HOLDIR=str(TC / 'HOL'),CAKEMLDIR=str(TC / 'cakeml'),
           FORGE_PRIVATE_PROBE_FILE=str(private / 'read-write.txt'))
env['PATH'] = str(TC / 'poly-install/bin') + os.pathsep + env['PATH']
save('preflight.json',{
    'authority':'Latest owner goal requests read/write and temporary-file controls and diagnosis of the unchanged SAT dependency. One default tmpName probe is instrumented; the full SAT diagnostic is not rerun.',
    'scope':'Current managed context; no validated replacement environment.',
    'pins':pins,'new_source_identity':new_sources,
    'diagnostic_source_sha256':sha(OUT / 'temp_requirement.sml'),
    'runner_sha256':sha(Path(__file__)),
    'private_scratch_path':str(private),'private_scratch_mode':'0700',
    'inherited_TMPDIR':os.environ.get('TMPDIR'),
    'TMPDIR_override':False,'permission_changes':False,
    'inherited_resource_limits':{name:list(resource.getrlimit(getattr(resource,name)))
        for name in ['RLIMIT_CPU','RLIMIT_CORE','RLIMIT_AS','RLIMIT_DATA','RLIMIT_STACK','RLIMIT_NOFILE','RLIMIT_NPROC']},
    'child_resource_limits':{'RLIMIT_CPU':[3600,3600],'RLIMIT_CORE':[0,0]},
    'end_to_end':False})
save('invocation.json',{'argv':argv,'cwd':str(cwd),
     'environment_overrides':{'HOLDIR':env['HOLDIR'],'CAKEMLDIR':env['CAKEMLDIR'],
         'FORGE_PRIVATE_PROBE_FILE':env['FORGE_PRIVATE_PROBE_FILE'],
         'PATH_prefix':str(TC / 'poly-install/bin')},
     'temp_solver_or_security_override':False,'end_to_end':False})
def limits():
    resource.setrlimit(resource.RLIMIT_CPU,(3600,3600))
    resource.setrlimit(resource.RLIMIT_CORE,(0,0))

with (OUT / 'stdout.log').open('xb') as stdout,(OUT / 'stderr.log').open('xb') as stderr:
    proc = subprocess.run(argv,cwd=cwd,env=env,stdout=stdout,stderr=stderr,preexec_fn=limits)
save('command.json',{'argv':argv,'cwd':str(cwd),'actual_exit':proc.returncode,
                    'stdout_sha256':sha(OUT / 'stdout.log'),
                    'stderr_sha256':sha(OUT / 'stderr.log'),'end_to_end':False})
for path,digest in pins.items():
    assert sha(path) == digest,path
save('postflight.json',{'all_pinned_inputs_unchanged':True,
    'private_scratch_contents':{p.name:sha(p) for p in private.iterdir() if p.is_file()},
    'actual_diagnostic_exit':proc.returncode,'unchanged_SAT':'NOT_RUN',
    'new_refund_theorem':'NOT_RUN','independent_replay':'NOT_RUN','end_to_end':False})
print((OUT / 'stdout.log').read_text(),end='')
print((OUT / 'stderr.log').read_text(),end='')
print('TEMP_REQUIREMENT_EXIT',proc.returncode)
raise SystemExit(proc.returncode)
