from pathlib import Path
import base64, hashlib, json, re

ROOT = Path('/Users/mackianni/forge')
P = Path(__file__).parent
OLD = ROOT / 'proposals/refund-executable-feasibility/hosted-macos-run-20261106'
sha = lambda b: hashlib.sha256(b).hexdigest()
remote = json.loads((P/'REMOTE-READBACK.json').read_text())
manifest = json.loads((OLD/'INPUTS.json').read_text())
ops = json.loads((P/'OPERATIONS.json').read_text())
assert remote['workflow_readback'].encode() == (P/'m1-macos-preflight.yml').read_bytes()
assert sha(remote['workflow_readback'].encode()) == '65e3addb289c29650fd7c84b2d3894c8d468a351a422778e9a1c9a9ec6a87027'
changed = remote['workflow_compare']['files']
assert len(changed) == 1 and changed[0]['filename'] == '.github/workflows/m1-macos-preflight.yml'
jobs = remote['jobs']['jobs']
assert len(jobs) == 1
job = jobs[0]
assert job['id'] == 128488158467 and job['run_attempt'] == 1
assert job['head_sha'] == '8ad9de1e538edd48a2084796510e784913eaef8b'
assert job['status'] == 'completed' and job['conclusion'] == 'success'
single = {op['operation']: op for op in ops}
assert single['identity']['architecture'] == 'arm64'
assert single['identity']['image_version'] == '20261104.0514.1'
assert single['access']['return_value'] == 0 and single['access']['errno'] == 0
assert single['mkstemp']['return_value'] >= 0 and single['mkstemp']['errno'] == 0
assert single['read_write']['equal'] is True
assert single['negative_permission']['errno'] == 13
assert single['writable_installation_root']['mode'] == '0700'
assert single['writable_installation_root']['uid'] == single['identity']['effective_uid'] != 0
assert single['sat_result']['actual_exit'] == 0
assert all(op['actual_exit'] == 0 for op in ops if op['operation'] == 'command')

expected = {e['path']: e for e in manifest['files']}
for label in ('input_before', 'input_after'):
    rows = [op for op in ops if op['operation'] == label]
    assert len(rows) == len(expected) == 18
    assert {r['file'] for r in rows} == set(expected)
    for row in rows:
        e = expected[row['file']]
        assert row['sha256'] == e['sha256'] and row['bytes'] == e['bytes']
for e in expected.values():
    assert sha(Path(e['source']).read_bytes()) == e['sha256']

streams = {}
for op in ops:
    if op['operation'] == 'sat_stream':
        data = base64.b64decode(op['base64'], validate=True)
        assert len(data) == op['bytes'] and sha(data) == op['sha256']
        assert data == (P/('sat.'+op['stream'])).read_bytes()
        streams[op['stream']] = data
stdout = streams['stdout'].decode()
stderr = streams['stderr'].decode()
assert 'FROZEN_SOLVER_EXECUTABLE false\n' in stdout
assert 'DIAGNOSTIC_SAT_THEOREM ⊢ probe ∨ ¬probe\n' in stdout
assert 'NATIVE_STEP_COMPLETE\n' in stdout
assert 'DIAGNOSTIC_DEPENDENCY_FAILURE' not in stdout
states = [line.removeprefix('LOADED_STATE ') for line in stdout.splitlines() if line.startswith('LOADED_STATE ')]
assert len(states) == 5
root = single['writable_installation_root']['path']
for state in states:
    assert state.startswith(root+'/') and state[len(root)+1:] in expected
for lib in ('poly-install/lib/libpolyml.16.dylib', 'transport/lib/libgmp.10.dylib'):
    assert root+'/.toolchain/experiments/refund-cakeml-20261104/'+lib in stderr
assert 'Process completed with exit code' not in remote['raw_job_log'] or 'exit code 0' in remote['raw_job_log']
assert remote['timing']['billable']['MACOS']['total_ms'] == 0

baseline = json.loads((ROOT/'results/refund-environment-recovery-20261106/attempt-0004/preflight.json').read_text())['pins']
protected = {p:h for p,h in baseline.items() if p in (str(ROOT/'spec.lock'),str(ROOT/'FORGE_MISSION.md')) or any(p.startswith(str(ROOT/d)+'/') for d in ('spec','policy','gate'))}
for path, digest in protected.items():
    assert sha(Path(path).read_bytes()) == digest

result = {
    'actual_exit': 0, 'run_id': job['run_id'], 'job_id': job['id'], 'run_attempt': 1,
    'actual_SAT_exit': 0, 'workflow_sha256': sha(remote['workflow_readback'].encode()),
    'raw_log_sha256': sha(remote['raw_job_log'].encode()),
    'streams': {name:{'bytes':len(data),'sha256':sha(data)} for name,data in streams.items()},
    'input_identity_checks': 36, 'source_inputs_unchanged':18,
    'loaded_saved_states':states, 'protected_paths_plus_frozen_mission_matched':len(protected),
    'solver_binding': 'unchanged; original absolute native MiniSat path is not executable',
    'fallback_classification': 'Published unchanged SAT_PROVE/invoke_solver contains DPLL_TAUT fallback; successful theorem is not native MiniSat execution evidence',
    'cost':remote['timing'],
    'remaining_trust': ['HOL logic/kernel and previously built pinned states', 'PolyML and host OS/loader', 'GitHub VM/control plane; no independently controlled full-chain replay'],
    'physical_ffiread_correspondence':'NOT_ESTABLISHED', 'end_to_end':False,
}
(P/'RESULT-REVIEW.json').write_text(json.dumps(result,indent=2,sort_keys=True)+'\n')
print(json.dumps(result,sort_keys=True))
