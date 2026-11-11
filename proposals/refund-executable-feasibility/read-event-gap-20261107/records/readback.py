from pathlib import Path
import hashlib,json,subprocess

ROOT=Path('/Users/mackianni/forge')
OUT=Path(__file__).resolve().parent
TC=ROOT/'.toolchain/experiments/refund-cakeml-20261104'
def sha(p):
    h=hashlib.sha256()
    with Path(p).open('rb') as f:
        for b in iter(lambda:f.read(1048576),b''):h.update(b)
    return h.hexdigest()
def read(p):return json.loads(Path(p).read_text())
exits={'model-0001':0,'repeat':0,'fresh-import':0,'wrong-replay-result':1,'omitted-error-event':1}
records={}
for case,code in exits.items():
    r=read(OUT/case/'command.json');records[case]=r
    assert r['actual_exit']==code and r['inputs_unchanged'],case
    assert sha(OUT/case/'proof.sml')==r['source_sha256'],case
    for stream in ['stdout','stderr']:assert sha(OUT/case/(stream+'.log'))==r[stream+'_sha256']
    for p,h in r['objects'].items():assert sha(OUT/case/p)==h,(case,p)
assert records['model-0001']['objects']==records['repeat']['objects']
assert len(records['repeat']['objects'])==4
assert records['model-0001']['source_sha256']==records['repeat']['source_sha256']
for case in ['wrong-replay-result','omitted-error-event']:
    assert 'Exact statement mismatch: stdin_error_event_rejected' in (OUT/case/'stderr.log').read_text()
    assert not records[case]['completion_marker'] and not records[case]['objects']
inputs=records['fresh-import']['input_files']
for p,h in inputs.items():assert sha(p)==h,p
u327=ROOT/'results/refund-stdin-domain-20261107/attempt-0001/model-0004/.hol/objs/forge_refundStdinDomainTheory.dat'
assert sha(u327)=='3192e34a57ac581727a3ce8c56770e7354242577d35bc4229903fe28020e671d'
log=(OUT/'fresh-import/stdout.log').read_text()
for marker in ['IMPORTED_THEOREM ','IMPORTED_ORACLES DISK_THM','IMPORTED_HYPOTHESES 0','IMPORTED_TAGGED_AXIOMS 0']:
    assert log.count(marker)==4,marker
assert 'EXACT_EXPECTED_STATEMENTS true' in log
nodes,axioms={},[]
for line in log.splitlines():
    if line.startswith('CLOSURE_NODE '):
        name,parents=line.removeprefix('CLOSURE_NODE ').split(':',1)
        assert name not in nodes;nodes[name]=parents.split(',') if parents else []
    if line.startswith('CLOSURE_AXIOM '):axioms.append(line.removeprefix('CLOSURE_AXIOM '))
assert set(axioms)=={'bool.SELECT_AX','bool.INFINITY_AX','bool.ETA_AX','bool.BOOL_CASES_AX'}
for name,parents in nodes.items():
    assert set(parents)<=set(nodes),name
    if name!='min':assert any(Path(p).name==name+'Theory.dat' for p in inputs),name
closure={p:h for p,h in inputs.items() if any(Path(p).name.startswith(n+'Theory.') or Path(p).name==n+'Script.sml' for n in nodes)}
(OUT/'dependency-snapshot.json').write_text(json.dumps({'nodes':nodes,'foundation_axioms':axioms,
 'parent_files':closure,'scope':'Local cached-parent proof and fresh import; not independent source replay.',
 'end_to_end':False},indent=2)+'\n')
baseline=read(ROOT/'results/refund-native-audit-2026-11-04/attempt-0001/baseline.json')
for p,h in baseline['protected'].items():assert sha(ROOT/p)==h,p
assert sha(ROOT/'FORGE_MISSION.md')==baseline['mission_sha256']
lock=read(ROOT/'spec/refund/spec.lock')
assert sha(ROOT/lock['spec_file'])==lock['spec_sha256']
assert sha(ROOT/lock['protocol_file'])==lock['protocol_sha256']
source_rels=['basis/basis_ffiScript.sml','basis/TextIOProofScript.sml','basis/TextIOProgScript.sml',
 'basis/fsFFIScript.sml','semantics/ffi/ffiScript.sml','characteristic/cfScript.sml',
 'characteristic/cfHeapsBaseScript.sml','characteristic/cfTacticsLib.sml']
commands=[['git','-C',str(TC/'cakeml'),'rev-parse','HEAD'],
 ['git','-C',str(TC/'cakeml'),'diff','--exit-code','HEAD','--']+source_rels]
source_records=[]
for argv in commands:
    r=subprocess.run(argv,capture_output=True,text=True)
    source_records.append({'argv':argv,'actual_exit':r.returncode,'stdout':r.stdout,'stderr':r.stderr})
(OUT/'source-commands.json').write_text(json.dumps(source_records,indent=2)+'\n')
assert all(r['actual_exit']==0 for r in source_records)
assert source_records[0]['stdout'].strip()=='cd9155694c16831373ab695a670794f23282ed62'
scope_files=['spec/refund/protocol.md','spec/refund/RefundSpec.dfy','spec/refund/spec.lock',
 'proposals/refund-executable-feasibility/README.md',
 'proposals/refund-executable-feasibility/stdio-contract-20261104/REPORT.md',
 'proposals/refund-executable-feasibility/runtime-premises-20261104/CORRESPONDENCE.md',
 'proposals/refund-executable-feasibility/exception-compiler-20261105/records/expected.sml']
result={'actual_exit':0,'commands':exits,'theorems':4,'identical_exports':4,
 'closure_nodes':len(nodes),'closure_parent_files':len(closure),'checked_input_files':len(inputs),
 'foundation_axioms':axioms,'data_sha256':sha(OUT/'model-0001/.hol/objs/forge_refundReadEventGapTheory.dat'),
 'proof_source_sha256':sha(OUT/'proof-0001.sml'),'protected_paths':len(baseline['protected']),
 'frozen_mission_unchanged':True,'source_files':{str(TC/'cakeml'/p):sha(TC/'cakeml'/p) for p in source_rels},
 'scope_files':{p:sha(ROOT/p) for p in scope_files},'end_to_end':False,
 'scope':'Separate local readback by the producing agent; not independent replay or human review.'}
(OUT/'readback.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
