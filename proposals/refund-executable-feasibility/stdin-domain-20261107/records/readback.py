from pathlib import Path
import hashlib, json

ROOT = Path('/Users/mackianni/forge')
OUT = Path(__file__).resolve().parent
def sha(p):
    h=hashlib.sha256()
    with Path(p).open('rb') as f:
        for b in iter(lambda:f.read(1048576),b''):h.update(b)
    return h.hexdigest()
def read(p):return json.loads(Path(p).read_text())
exits={'model-0002':1,'model-0003':0,'model-0004':0,
       'lookup-diagnostic':1,'lookup-diagnostic-0002':1,
       'lookup-diagnostic-0003':1,'lookup-diagnostic-0004':0,
       'repeat':0,'fresh-import':0,'wrong-status':1,'missing-stdin-guard':1}
records={}
for case,code in exits.items():
    r=read(OUT/case/'command.json')
    assert r['actual_exit']==code and r['inputs_unchanged'],case
    assert sha(OUT/case/'proof.sml')==r['source_sha256'],case
    assert sha(OUT/case/'stdout.log')==r['stdout_sha256'],case
    assert sha(OUT/case/'stderr.log')==r['stderr_sha256'],case
    for p,h in r['objects'].items():assert sha(OUT/case/p)==h,(case,p)
    records[case]=r
assert records['model-0004']['objects']==records['repeat']['objects']
assert len(records['repeat']['objects'])==4
assert records['model-0004']['source_sha256']==records['repeat']['source_sha256']
for case in ['wrong-status','missing-stdin-guard']:
    assert 'Exact statement mismatch: stdin_ffi_read_status_zero' in (OUT/case/'stderr.log').read_text()
    assert not records[case]['completion_marker'] and not records[case]['objects']
inputs=records['fresh-import']['input_files']
for p,h in inputs.items():assert sha(p)==h,p
old=ROOT/'results/refund-native-audit-2026-11-04/attempt-0010/model-0007/.hol/objs'
historical={'dat':'32d97ebfdd39e761c4b9ea8905a2f6090df23b9c9985dafc2c508b266abaf050',
 'sig':'98b325ea103bbb9dfcb071b88248755bd09d036eb7f03baaa73d702015f7daf1',
 'sml':'8410c0787767d5f6ddbf9c932f788f7721f93616bb74041a4317ed1cdd1f3f49'}
for ext,h in historical.items():assert sha(old/('forge_refundReadBoundaryTheory.'+ext))==h
log=(OUT/'fresh-import/stdout.log').read_text()
for marker in ['IMPORTED_THEOREM ','IMPORTED_ORACLES DISK_THM','IMPORTED_HYPOTHESES 0','IMPORTED_TAGGED_AXIOMS 0']:
    assert log.count(marker)==4,marker
assert 'EXACT_EXPECTED_STATEMENTS true' in log
nodes,axioms={},[]
for line in log.splitlines():
    if line.startswith('CLOSURE_NODE '):
        name,parents=line.removeprefix('CLOSURE_NODE ').split(':',1)
        assert name not in nodes
        nodes[name]=parents.split(',') if parents else []
    if line.startswith('CLOSURE_AXIOM '):axioms.append(line.removeprefix('CLOSURE_AXIOM '))
assert set(axioms)=={'bool.SELECT_AX','bool.INFINITY_AX','bool.ETA_AX','bool.BOOL_CASES_AX'}
for name,parents in nodes.items():
    assert set(parents)<=set(nodes),name
    if name!='min':assert any(Path(p).name==name+'Theory.dat' for p in inputs),name
closure={p:h for p,h in inputs.items() if any(Path(p).name.startswith(n+'Theory.') or Path(p).name==n+'Script.sml' for n in nodes)}
(OUT/'dependency-snapshot.json').write_text(json.dumps({'nodes':nodes,'foundation_axioms':axioms,
 'parent_files':closure,'proof_source_sha256':sha(OUT/'proof-0003.sml'),
 'scope':'Fresh local import with hashed cached parents; not independent source replay.',
 'end_to_end':False},indent=2)+'\n')
baseline=read(ROOT/'results/refund-native-audit-2026-11-04/attempt-0001/baseline.json')
for p,h in baseline['protected'].items():assert sha(ROOT/p)==h,p
assert sha(ROOT/'FORGE_MISSION.md')==baseline['mission_sha256']
hosted=read(ROOT/'proposals/refund-executable-feasibility/hosted-macos-nosudo-20261107/INPUTS.json')
runtime={}
for item in hosted['files']:
    if Path(item['source']).name in ['hol','libpolyml.16.dylib','libgmp.10.dylib','hol.state','hol.state0','numheap']:
        assert sha(item['source'])==item['sha256'],item['source']
        runtime[item['source']]=item['sha256']
native=read(OUT/'native-errno/observations.json')
assert sha(native['executable'])==native['executable_sha256']
assert [(r['read_return'],r['errno'],r['actual_native_exit']) for r in native['records']]==[(-1,35,0),(0,0,0)]
for r in native['records']:
    for stream in ['stdout','stderr']:
        p=OUT/'native-errno'/(r['case']+'.'+stream)
        assert sha(p)==r[stream+'_sha256'] and p.stat().st_size==r[stream+'_bytes']
    assert r['buffer_before_hex']==r['buffer_after_hex']
sources={}
tc=ROOT/'.toolchain/experiments/refund-cakeml-20261104'
for rel in ['cakeml/basis/basis_ffi.c','cakeml/basis/fsFFIScript.sml','cakeml/basis/fsFFIPropsScript.sml','cakeml/basis/TextIOProgScript.sml']:
    sources[str(tc/rel)]=sha(tc/rel)
result={'actual_exit':0,'commands':exits,'theorems':4,'identical_exports':4,
 'closure_nodes':len(nodes),'closure_parent_files':len(closure),'checked_input_files':len(inputs),
 'foundation_axioms':axioms,'data_sha256':sha(OUT/'model-0004/.hol/objs/forge_refundStdinDomainTheory.dat'),
 'proof_source_sha256':sha(OUT/'proof-0003.sml'),'native_sha256':native['executable_sha256'],
 'native_exit_codes':[r['actual_native_exit'] for r in native['records']],
 'protected_paths':len(baseline['protected']),'frozen_mission_unchanged':True,
 'runtime_pins':runtime,'inspected_sources':sources,'end_to_end':False,
 'scope':'Separate local artifact readback by the producing agent; not independent full-chain replay.'}
(OUT/'readback.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
