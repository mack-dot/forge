"""Run one bounded environment diagnostic, without SAT or proof execution."""
from pathlib import Path
import hashlib
import json
import os
import platform
import resource
import subprocess

ROOT = Path('/Users/mackianni/forge')
OUT = Path(__file__).resolve().parent
TC = ROOT / '.toolchain/experiments/refund-cakeml-20261104'
OLD = ROOT / 'results/refund-native-audit-2026-11-04/attempt-0011'

def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def read(path):
    return json.loads(Path(path).read_text())

def save(name, data):
    with (OUT / name).open('x') as handle:
        json.dump(data, handle, indent=2)
        handle.write('\n')

pins = {
    **read(OLD / 'baseline.json')['step_tools'],
    **read(OLD / 'arm8-tool-inputs.json')['files'],
}
built = read(ROOT / 'proposals/refund-executable-feasibility/verified-backend-20261104/built-tool-identities.json')
for item in built['tool_files']:
    pins[item['path']] = item['sha256']
original = OLD / 'dependency-diagnostic/proof.sml'
pins[str(original)] = 'bc3fb212a4037ae8e8ebd500f9843bff9cd93cbfcbc76501c7a152a9004af108'
protected = read(OLD.parent / 'attempt-0001/baseline.json')
for name, digest in protected['protected'].items():
    pins[str(ROOT / name)] = digest
pins[str(ROOT / 'FORGE_MISSION.md')] = protected['mission_sha256']
for path, digest in pins.items():
    assert sha(path) == digest, path

dylib = TC / 'poly-install/lib/libpolyml.16.dylib'
current_files = {str(path): sha(path) for path in [
    dylib, Path('/bin/sh'), Path('/usr/bin/true'), OUT / 'operations.sml',
    OUT / 'run_operations.py',
]}
limit_names = ['RLIMIT_CPU','RLIMIT_CORE','RLIMIT_AS','RLIMIT_DATA',
               'RLIMIT_STACK','RLIMIT_NOFILE','RLIMIT_NPROC']
limits = {name: list(resource.getrlimit(getattr(resource,name)))
          for name in limit_names if hasattr(resource,name)}
argv = [str(TC / 'HOL/bin/hol'), 'run',
        '--holstate=' + str(TC / 'HOL/examples/l3-machine-code/arm8/step/arm8-heap'),
        str(OUT / 'operations.sml')]
cwd = TC / 'HOL/examples/l3-machine-code/arm8/step'
env = dict(os.environ, HOLDIR=str(TC / 'HOL'), CAKEMLDIR=str(TC / 'cakeml'),
           FORGE_DIAG_READ=str(original))
env['PATH'] = str(TC / 'poly-install/bin') + os.pathsep + env['PATH']
save('preflight.json', {
    'scope': 'Current managed context, operation-specific observation only; not a replacement or independent replay environment.',
    'authority': 'Owner requested read-only execution-environment diagnostic with operation-specific instrumentation. Payload reads an existing file, allocates memory, queries access, and calls /usr/bin/true. No tmpName, SAT, Holmake, sandbox creation, or workaround.',
    'architecture': platform.machine(), 'os': platform.system(),
    'os_release': platform.release(), 'effective_uid': os.geteuid(),
    'prior_pins_match': pins, 'current_operation_input_hashes': current_files,
    'inherited_resource_limits': limits,
    'child_limit_overrides': {'RLIMIT_CPU':[3600,3600],'RLIMIT_CORE':[0,0]},
    'permission_changes': False, 'environment_replacement_validated': False,
    'independent_source_bootstrap_provenance': 'NOT_ESTABLISHED',
    'end_to_end': False,
})
save('invocation.json', {'argv':argv,'cwd':str(cwd),
                       'environment_overrides':{'HOLDIR':env['HOLDIR'],
                           'CAKEMLDIR':env['CAKEMLDIR'],
                           'FORGE_DIAG_READ':env['FORGE_DIAG_READ'],
                           'PATH_prefix':str(TC / 'poly-install/bin')},
                       'other_environment':'Inherited; no sandbox, temp-path, solver or dynamic-loader override introduced.',
                       'end_to_end':False})
def child_limits():
    resource.setrlimit(resource.RLIMIT_CPU,(3600,3600))
    resource.setrlimit(resource.RLIMIT_CORE,(0,0))

with (OUT / 'stdout.log').open('xb') as stdout, (OUT / 'stderr.log').open('xb') as stderr:
    result = subprocess.run(argv,cwd=cwd,env=env,stdout=stdout,stderr=stderr,
                            preexec_fn=child_limits)
save('command.json', {'argv':argv,'cwd':str(cwd),'actual_exit':result.returncode,
                      'stdout_sha256':sha(OUT / 'stdout.log'),
                      'stderr_sha256':sha(OUT / 'stderr.log'),
                      'end_to_end':False})
for path, digest in {**pins,**current_files}.items():
    assert sha(path) == digest, path
save('postflight.json', {'all_recorded_input_hashes_unchanged':True,
                        'protected_paths_unchanged':len(protected['protected']),
                        'actual_diagnostic_exit':result.returncode,
                        'unchanged_SAT_diagnostic':'NOT_RUN',
                        'proof_or_swarm_execution':'NOT_RUN','end_to_end':False})
print((OUT / 'stdout.log').read_text(),end='')
print((OUT / 'stderr.log').read_text(),end='')
print('DIAGNOSTIC_EXIT',result.returncode)
raise SystemExit(result.returncode)
