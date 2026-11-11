"""Bind actual HOL outcomes, exact claims, dependencies and preserved inputs."""
from pathlib import Path
import hashlib,json,re
ROOT=Path('/Users/mackianni/forge');OUT=Path(__file__).resolve().parent
HT=ROOT/'.toolchain/experiments/refund-cakeml-20261104'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
read=lambda p:json.loads(p.read_text())
assert not (OUT/'readback.json').exists()
expected={'precise-0001':1,'precise-0002':1,'precise-0003':0,'precise-repeat':0,
          'exact-import':0,'missing-space':1,'changed-limits':1}
records={n:read(OUT/n/'command.json') for n in expected}
log=lambda n:(OUT/n/'stdout.log').read_text()+(OUT/n/'stderr.log').read_text()
for n,code in expected.items():
    r=records[n];assert r['actual_exit']==code and r['end_to_end'] is False,n
    src=OUT/n/('audit.sml' if 'imported_objects' in r else 'proof.sml')
    assert sha(src)==r['source_sha256']
    for p,digest in r.get('objects',{}).items():assert sha(OUT/n/p)==digest
    for p,digest in r.get('imported_objects',{}).items():
        assert sha(OUT/n/'imported'/p)==digest
        assert sha(OUT/'precise-0003'/p)==digest
assert 'Attempt to unify different type operators' in log('precise-0001')
assert 'ground const vs. polymorphic const' in log('precise-0002')
for n in ['precise-0001','precise-0002']:
    assert not records[n]['completion_marker'] and not records[n]['objects']
assert records['precise-0003']['objects']==records['precise-repeat']['objects']
assert len(records['precise-0003']['objects'])==4
assert records['precise-0003']['source_sha256']==records['precise-repeat']['source_sha256']==sha(OUT/'precise.sml')
for n in ['precise-0003','precise-repeat']:assert records[n]['completion_marker']
assert records['exact-import']['import_complete']
import_log=log('exact-import')
assert len(re.findall(r'^IMPORTED .* EXACT true HYPOTHESES 0 TAGGED_AXIOMS 0$',import_log,re.M))==3
assert sha(OUT/'expected.sml')==records['exact-import']['source_sha256']
original=(OUT/'expected.sml').read_text()
fragment='''  (!po. backendProof$is_safe_for_space (:64) (basis_ffi$basis_ffi ext cl fs) po
    arm8_target$arm8_config (backend$set_oracle arm8_config$arm8_backend_config oracle)
    forge_refundWholeProg$refund_prog (stack_limit,heap_limit))'''
assert original.count(fragment)==1
assert (OUT/'missing-space.sml').read_text()==original.replace(fragment,'  T')
assert (OUT/'changed-limits.sml').read_text()==original.replace('    (stack_limit,heap_limit) /\\','    (stack_limit,heap_limit + 1) /\\',1)
for n in ['missing-space','changed-limits']:
    assert 'Exact statement mismatch: refund_compiled_precise' in log(n)
    assert not records[n]['import_complete']
    assert 'RUNTIME_IMPORT_COMPLETE' not in log(n)
    assert not (OUT/n/'.hol').exists()
closure={n:ps.split(',') if ps else [] for n,ps in re.findall(r'^CLOSURE_NODE ([^:]+):(.*)$',import_log,re.M)}
assert all(p in closure for parents in closure.values() for p in parents)
axioms=set(re.findall(r'^CLOSURE_AXIOM (.*)$',import_log,re.M))
assert axioms=={'bool.SELECT_AX','bool.INFINITY_AX','bool.ETA_AX','bool.BOOL_CASES_AX'}
index={}
for p in HT.rglob('*Theory.dat'):index.setdefault(p.name,set()).add(p.resolve())
files={};builtin={}
for name in closure:
    if name=='min':
        assert closure[name]==[]
        p=HT/'HOL/src/postkernel/Theory.sml'
        assert 'The "min" theory is already installed; it has no parents.' in p.read_text()
        builtin[name]={'source_sha256':sha(p),'heap_sha256':sha(HT/'cakeml/misc/cakeml-heap')}
        continue
    candidates=({OUT/'precise-0003/.hol/objs/forge_refundPreciseBehaviorTheory.dat'}
                if name=='forge_refundPreciseBehavior' else index.get(name+'Theory.dat',set()))
    assert len(candidates)==1,(name,list(map(str,candidates)))
    p=next(iter(candidates))
    for ext in ['.dat','.sig','.sml']:assert p.with_suffix(ext).exists()
    for ext in ['.dat','.sig','.sml','.uo','.ui']:
        f=p.with_suffix(ext)
        if f.exists():files[str(f)]=sha(f)
runtime=read(OUT/'runtime-readback.json');assert runtime['actual_exit']==0
for p,digest in runtime['upstream_source_hashes'].items():
    assert sha(OUT/'upstream'/p)==digest==sha(HT/'cakeml'/p)
baseline=read(ROOT/'results/refund-native-audit-2026-11-04/attempt-0001/baseline.json')
for p,digest in baseline['protected'].items():assert sha(ROOT/p)==digest
assert sha(ROOT/'FORGE_MISSION.md')==baseline['mission_sha256']
packets={}
for name in ['byte-boundary-20261104','compiled-behavior-20261104','resource-binding-20261104']:
    p=ROOT/'proposals/refund-executable-feasibility'/name;m=read(p/'manifest.json')
    for f,digest in m.items():assert sha(p/f)==digest
    packets[name]=len(m)
result={'actual_exit':0,'recorded_exits':expected,'proof_sha256':sha(OUT/'precise.sml'),
        'expected_claim_sha256':sha(OUT/'expected.sml'),
        'identical_exports':records['precise-0003']['objects'],'exact_import_statements':3,
        'negative_reasons':{n:'Exact statement mismatch: refund_compiled_precise' for n in ['missing-space','changed-limits']},
        'closure':closure,'closure_node_count':len(closure),'closure_axioms':sorted(axioms),
        'dependency_files':files,'dependency_file_count':len(files),'builtin_dependencies':builtin,
        'runtime_readback_sha256':sha(OUT/'runtime-readback.json'),
        'protected_files_unchanged':len(baseline['protected']),'prior_packet_members':packets,
        'scope':'Conditional model theorem, same-host reproduction/import and claim-binding controls. Resource sufficiency and physical runtime relation remain unproved.',
        'independent_full_chain_replay':'NOT RUN','end_to_end':False}
(OUT/'readback.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({k:v for k,v in result.items() if k not in ['closure','dependency_files','identical_exports']},indent=2))
