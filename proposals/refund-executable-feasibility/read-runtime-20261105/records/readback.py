from pathlib import Path
import hashlib, json

ROOT = Path('/Users/mackianni/forge')
OUT = Path(__file__).resolve().parent
OLD = OUT.parent / 'attempt-0009'
def sha(p):
    h = hashlib.sha256()
    with Path(p).open('rb') as f:
        for b in iter(lambda: f.read(1048576), b''): h.update(b)
    return h.hexdigest()
def read(p): return json.loads(Path(p).read_text())
inputs = read(OLD / 'inputs.json')['input_files']
for p,h in inputs.items(): assert sha(p) == h, p
exits = {**{f'model-{n:04d}':1 for n in range(1,7)},
         'status-diagnostic':0,'model-0007':0,'repeat':0,'import-0001':0,
         'wrong-ready-status':1,'changed-error-frame':1}
records = {}
for case,code in exits.items():
    r = read(OUT / case / 'command.json')
    assert r['actual_exit'] == code, case
    assert sha(OUT / case / 'proof.sml') == r['source_sha256'], case
    for p,h in r['objects'].items(): assert sha(OUT / case / p) == h, (case,p)
    records[case] = r
assert records['model-0007']['objects'] == records['repeat']['objects']
assert len(records['model-0007']['objects']) == 4
assert records['model-0007']['source_sha256'] == records['repeat']['source_sha256'] == sha(OUT / 'read-model-0007.sml')
for case in ['wrong-ready-status','changed-error-frame']:
    log = (OUT / case / 'stdout.log').read_text()
    assert 'EXACT_EXPECTED_STATEMENTS true' in log
    assert log.count('IMPORTED_THEOREM ') == 4
    assert 'Exact statement mismatch: '+case in (OUT / case / 'stderr.log').read_text()
    assert not records[case]['completion_marker'] and not records[case]['objects']
log = (OUT / 'import-0001/stdout.log').read_text()
for marker in ['IMPORTED_THEOREM ','IMPORTED_ORACLES DISK_THM','IMPORTED_HYPOTHESES 0','IMPORTED_TAGGED_AXIOMS 0']:
    assert log.count(marker) == 4, marker
assert 'EXACT_EXPECTED_STATEMENTS true' in log
nodes,axioms = {},[]
for line in log.splitlines():
    if line.startswith('CLOSURE_NODE '):
        name,parents = line.removeprefix('CLOSURE_NODE ').split(':',1)
        assert name not in nodes
        nodes[name] = parents.split(',') if parents else []
    if line.startswith('CLOSURE_AXIOM '): axioms.append(line.removeprefix('CLOSURE_AXIOM '))
assert set(axioms) == {'bool.SELECT_AX','bool.INFINITY_AX','bool.ETA_AX','bool.BOOL_CASES_AX'}
for name,parents in nodes.items():
    assert set(parents) <= set(nodes), name
    if name not in ['min','forge_refundReadBoundary']:
        assert any(Path(p).name == name+'Theory.dat' for p in inputs), name
closure_files = {p:h for p,h in inputs.items() if any(Path(p).name.startswith(n+'Theory.') or Path(p).name == n+'Script.sml' for n in nodes)}
(OUT / 'dependency-snapshot.json').write_text(json.dumps({'nodes':nodes,'foundation_axioms':axioms,'parent_files':closure_files,'scope':'Same-host exact import with hashed cached parents; not independent clean source replay.','end_to_end':False},indent=2)+'\n')
native_runs = []
for run in ['native-0001','native-repeat']:
    observations = read(OUT / run / 'observations.json')
    assert len(observations) == 8
    for rec in observations:
        case = OUT / run / rec['case']
        assert read(case / 'command.json') == rec
        assert sha(case / 'stdout.bin') == rec['stdout_sha256']
        assert sha(case / 'stderr.bin') == rec['stderr_sha256']
        assert sha(case / 'offered-input.bin') == rec['offered_input_sha256']
        assert sha(rec['argv'][0]) == rec['executable_sha256']
        assert rec['actual_exit'] == (-13 if rec['case']=='closed_stdout_reader' else 0)
        assert rec['stdout_captured'] == (rec['case']!='closed_stdout_reader')
        if rec['case'] in ['valid_regular','nonblocking_ready_pipe']:
            assert rec['matches_valid_expected'] and rec['stdout_bytes']==64
        elif rec['stdout_captured']: assert rec['stdout_bytes']==0
        assert rec['stderr_bytes']==0
    native_runs.append(observations)
assert native_runs[0] == native_runs[1]
for case in ['directory-observation-0001','positive-observer-check']:
    r = read(OUT / case / 'command.json')
    assert r['actual_debugger_exit']==1 and r['executable_unchanged']
    assert sha(OUT / case / 'commands.lldb')==r['commands_sha256']
    assert 'no such process' in (OUT / case / 'debugger.log').read_text()
assert read(OUT / 'observer-static/command.json')['actual_exit']==1
native = read(OUT / 'native-readback/result.json')
assert native['actual_exit']==0
assert all(r['actual_exit']==0 for r in read(OUT / 'native-readback/commands.json'))
packets = {}
for name in ['exception-compiler-20261105','runtime-premises-20261104']:
    p = ROOT / 'proposals/refund-executable-feasibility' / name
    m = read(p / 'MANIFEST.json')
    files = m['files'] if 'files' in m else m
    for rel,h in files.items(): assert sha(p / rel)==h, (name,rel)
    packets[name]=len(files)
chain = read(OUT.parent / 'attempt-0004/chain-inputs-0001/manifest.json')
for p,h in chain.items(): assert sha(p)==h, p
baseline = read(OUT.parent / 'attempt-0001/baseline.json')
for rel,h in baseline['protected'].items(): assert sha(ROOT / rel)==h, rel
assert sha(ROOT / 'FORGE_MISSION.md')==baseline['mission_sha256']
replay = read(OUT / 'replay-preflight.json')
assert replay['actual_exit']==0 and replay['source_snapshots_verified']==21
assert replay['replay_gate']=='NO_GO' and replay['independent_full_chain_replay']=='NOT_RUN'
result = {'actual_exit':0,'commands':exits,'exact_statements':4,'identical_exports':4,
          'closure_nodes':len(nodes),'closure_parent_files':len(closure_files),
          'validated_U310_parent_bindings':len(inputs),'foundation_axioms':axioms,
          'source_sha256':sha(OUT / 'read-model-0007.sml'),
          'data_sha256':sha(OUT / 'model-0007/.hol/objs/forge_refundReadBoundaryTheory.dat'),
          'native_sha256':native['existing_builds'][0]['executable_sha256'],
          'native_processes':16,'native_runs_identical':True,
          'historical_chain_files':len(chain),'standard_checksum_members':native['standard_checksum_members'],
          'existing_signature_exits':[r['actual_exit'] for r in read(OUT / 'native-readback/commands.json') if 'signature' in r['label']],
          'protected_files_unchanged':len(baseline['protected']),'prior_packet_members':packets,
          'replay_gate':'NO_GO','independent_full_chain_replay':'NOT_RUN','end_to_end':False}
(OUT / 'readback.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
