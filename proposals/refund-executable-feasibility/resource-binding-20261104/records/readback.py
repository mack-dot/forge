"""Record exact HOL outcomes, binding controls and imported dependency identities."""
from pathlib import Path
import hashlib,json,re,subprocess
ROOT=Path('/Users/mackianni/forge')
OUT=Path(__file__).resolve().parent
TC=ROOT/'.toolchain/experiments/refund-cakeml-20261104'
POS=OUT/'positive-0002';REP=OUT/'repeat';AUDIT=OUT/'import-audit'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
read=lambda p:json.loads(p.read_text())
assert not (OUT/'readback.json').exists()
records=[read(p/'command.json') for p in [POS,REP,AUDIT]]
assert all(r['actual_exit']==0 and r['completion_marker'] for r in records)
assert (POS/'proof.sml').read_bytes()==(REP/'proof.sml').read_bytes()
assert records[0]['objects']==records[1]['objects']
for p,r in zip([POS,REP],records):
 assert sha(p/'proof.sml')==r['source_sha256']
 for name,digest in r['objects'].items():assert sha(p/name)==digest
controls=[]
for case in ['wrong-limit-0002','stale-midpoint-0002']:
 p=OUT/case;r=read(p/'command.json')
 assert r['actual_exit']==1 and not r['objects'] and not r['completion_marker']
 assert re.search(r'First unsolved sub-goal is\s+F\s',(p/'stdout.log').read_text())
 assert 'Failed to prove theorem "recorded_limits"' in (p/'stderr.log').read_text()
 assert 'Saved theorem _______ "recorded_config"' in (p/'stdout.log').read_text()
 assert sha(p/'proof.sml')==r['source_sha256']
 controls.append({'case':case,'actual_exit':1,'required_rejection':'recorded_limits reduces to F','objects':r['objects']})
pos_source=(POS/'proof.sml').read_text()
assert (OUT/'wrong-limit-0002/proof.sml').read_text()==pos_source.replace('(33554384,16777216)','(33554384,16777217)')
assert (OUT/'stale-midpoint-0002/proof.sml').read_text()==pos_source.replace('496811114496w','496811114512w')
cap=ROOT/'results/refund-entry-observation-2026-11-04/attempt-fullmap/readback.json'
assert sha(cap)==read(OUT/'inputs.json')['capture_readback_sha256']
assert {k:read(cap)['registers'][k] for k in ['x1','x2','x3']}==read(OUT/'inputs.json')['recorded_registers']
for record in read(OUT/'source-identity.json')['sources']:
 assert sha(TC/'cakeml'/record['path'])==record['sha256']
base=read(ROOT/'results/refund-native-audit-2026-11-04/attempt-0001/baseline.json')
for name,digest in base['protected'].items():assert sha(ROOT/name)==digest
assert sha(ROOT/'FORGE_MISSION.md')==base['mission_sha256']
log=(AUDIT/'stdout.log').read_text()
own=re.findall(r'^IMPORTED_THEOREM (\S+) EXACT_STATEMENT true HYPOTHESES 0 TAGGED_AXIOMS 0 ORACLES (.*)$',log,re.M)
assert [name for name,_ in own]==['recorded_config','recorded_limits','recorded_read_limits']
assert all(not tags or tags=='DISK_THM' for _,tags in own)
closure={n:parents.split(',') if parents else [] for n,parents in re.findall(r'^CLOSURE_NODE ([^:]+):(.*)$',log,re.M)}
assert 'forge_refundResourceBinding' in closure
assert all(p in closure for parents in closure.values() for p in parents)
axioms=re.findall(r'^CLOSURE_AXIOM (.+)$',log,re.M)
assert set(axioms)=={'bool.SELECT_AX','bool.INFINITY_AX','bool.ETA_AX','bool.BOOL_CASES_AX'}
index={}
for file in TC.rglob('*Theory.dat'):index.setdefault(file.name,set()).add(file.resolve())
dependencies={};builtins={}
for name in closure:
 if name=='min':
  assert closure[name]==[]
  source=TC/'HOL/src/postkernel/Theory.sml'
  assert 'The "min" theory is already installed; it has no parents.' in source.read_text()
  builtins[name]={'kind':'Built-in kernel root','source_sha256':sha(source),'heap_sha256':sha(TC/'cakeml/misc/cakeml-heap')}
  continue
 candidates={POS/'.hol/objs/forge_refundResourceBindingTheory.dat'} if name=='forge_refundResourceBinding' else index.get(name+'Theory.dat',set())
 assert len(candidates)==1,(name,[str(p) for p in candidates])
 data=next(iter(candidates))
 for suffix in ['.dat','.sig','.sml']:assert data.with_suffix(suffix).exists(),(name,suffix)
 for suffix in ['.dat','.sig','.sml','.uo','.ui']:
  f=data.with_suffix(suffix)
  if f.exists():dependencies[str(f)]=sha(f)
result={'actual_exit':0,'positive_exit':0,'repeat_exit':0,'import_exit':0,'source_sha256':sha(POS/'proof.sml'),
 'identical_exports':records[0]['objects'],'controls':controls,'closure':closure,'closure_node_count':len(closure),
 'closure_axioms':axioms,'builtin_dependencies':builtins,'dependency_files':dependencies,'dependency_file_count':len(dependencies),
 'own_theorem_count':len(own),'protected_files_unchanged':len(base['protected']),
 'scope':'Exact conditional model resource-limit binding; not resource sufficiency, complete installed state, physical refinement or independent full-chain replay.',
 'end_to_end':False}
(OUT/'readback.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({k:v for k,v in result.items() if k not in ['dependency_files','closure','identical_exports']},indent=2))
