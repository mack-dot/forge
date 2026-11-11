"""Bind local kernel outcomes to exact claims and preserved inputs."""
from pathlib import Path
import hashlib, json, re, subprocess
R=Path('/Users/mackianni/forge'); O=Path(__file__).resolve().parent
T=R/'.toolchain/experiments/refund-cakeml-20261104'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
read=lambda p:json.loads(p.read_text())
assert not (O/'readback.json').exists()
expected={'bridge-0001':1,'bridge-0002':-2,'bridge-0003':1,'bridge-0004':1,
 'bridge-0005':0,'bridge-repeat':0,'counterexample-0001':1,'counterexample-0002':-2,
 'counterexample-0003':1,'counterexample-0004':0,'counterexample-repeat':0,
 'wrong-outcome':1,'exact-import':0,'missing-exclusion':1,'finite-exclusion':1,
 'complete-prefix-0001':1,'complete-prefix-0002':1,'complete-prefix-0003':1,
 'complete-prefix-0004':0,'complete-prefix-repeat':0,'complete-import':0,'missing-halt':1}
records={n:read(O/n/'command.json') for n in expected}
def log(n):return (O/n/'stdout.log').read_text()+(O/n/'stderr.log').read_text()
for n,code in expected.items():
 c=records[n];assert c['actual_exit']==code and c['end_to_end'] is False,n
 p=O/n/('proof.sml' if (O/n/'proof.sml').exists() else 'audit.sml')
 assert sha(p)==c['source_sha256'],n
 for f,h in c.get('objects',{}).items():assert sha(O/n/f)==h
 for source,objects in c.get('imported_objects',{}).items():
  for f,h in objects.items():assert sha(O/n/source/f)==h==sha(O/source/f)
 if 'completion_marker' in c:
  assert c['completion_marker']==(code==0)
  if code:assert c['objects']=={}
 else:assert c['import_complete']==(code==0)
for n in ['bridge-0002','counterexample-0002']:
 assert read(O/n/'interrupt.json')['signal']=='SIGINT'
exports={}
for first,repeat,source in [('bridge-0005','bridge-repeat','bridge.sml'),
 ('counterexample-0004','counterexample-repeat','counterexample.sml'),
 ('complete-prefix-0004','complete-prefix-repeat','complete-prefix.sml')]:
 a,b=records[first],records[repeat]
 assert a['objects']==b['objects'] and len(a['objects'])==4
 assert a['source_sha256']==b['source_sha256']==sha(O/source)
 exports[first]=a['objects']
for case,count in [('exact-import',3),('complete-import',4)]:
 assert len(re.findall(r'^IMPORTED .* EXACT true HYPOTHESES 0 TAGGED_AXIOMS 0$',log(case),re.M))==count
source=(O/'counterexample.sml').read_text();needle='(targetSem$Error,2,ffi)'
assert source.count(needle)==1
assert (O/'wrong-outcome.sml').read_text()==source.replace(needle,'(targetSem$Halt ffi$Success,2,ffi)')
assert 'First unsolved sub-goal is\n\nF' in log('wrong-outcome')
original=(O/'expected.sml').read_text()
fragment='''  (!j ms' ffi'.
    targetSem$evaluate mc ffi j ms = (targetSem$TimeOut,ms',ffi') ==>
    mc.target.get_pc ms' <> mc.install_pc)'''
assert original.count(fragment)==1
assert (O/'missing-exclusion.sml').read_text()==original.replace(fragment,'  T')
assert (O/'finite-exclusion.sml').read_text()==original.replace(fragment,fragment.replace('    targetSem$evaluate mc ffi j ms =','    j < 21 /\\ targetSem$evaluate mc ffi j ms ='))
for n in ['missing-exclusion','finite-exclusion']:
 assert 'Exact statement mismatch: machine_sem_install_irrelevant' in log(n)
complete=(O/'expected-complete.sml').read_text()
frag='  targetSem$evaluate mc ffi k ms = (targetSem$Halt outcome,final_ms,final_ffi)'
assert complete.count(frag)==1
assert (O/'missing-halt.sml').read_text()==complete.replace(frag,'  T')
assert 'Exact statement mismatch: complete_prefix_suffices' in log('missing-halt')
closure={n:ps.split(',') if ps else [] for n,ps in re.findall(r'^CLOSURE_NODE ([^:]+):(.*)$',log('complete-import'),re.M)}
assert all(p in closure for ps in closure.values() for p in ps)
axs=set(re.findall(r'^CLOSURE_AXIOM (.*)$',log('complete-import'),re.M))
assert axs=={'bool.SELECT_AX','bool.INFINITY_AX','bool.ETA_AX','bool.BOOL_CASES_AX'}
index={}
for p in T.rglob('*Theory.dat'):index.setdefault(p.name,set()).add(p.resolve())
own={}
for n,objects in exports.items():
 for f in objects:
  if f.endswith('Theory.dat'):own[Path(f).name]=O/n/f
files={};builtin={}
for n in closure:
 if n=='min':
  p=T/'HOL/src/postkernel/Theory.sml';assert closure[n]==[]
  assert 'The "min" theory is already installed; it has no parents.' in p.read_text()
  builtin[n]={'source_sha256':sha(p),'heap_sha256':sha(T/'cakeml/misc/cakeml-heap')};continue
 name=n+'Theory.dat';ps={own[name]} if name in own else index.get(name,set())
 assert len(ps)==1,(n,ps)
 p=next(iter(ps))
 for ext in ['.dat','.sig','.sml']:assert p.with_suffix(ext).exists()
 for ext in ['.dat','.sig','.sml','.uo','.ui']:
  f=p.with_suffix(ext)
  if f.exists():files[str(f)]=sha(f)
base=read(O/'baseline.json');sources={**base['source_hashes'],**read(O/'additional-sources.json')['hashes']}
for n,h in sources.items():
 b=subprocess.run(['git','show','cd9155694c16831373ab695a670794f23282ed62:'+n],cwd=T/'cakeml',capture_output=True,check=True).stdout
 assert hashlib.sha256(b).hexdigest()==h==sha(O/'upstream'/n)==sha(T/'cakeml'/n)
for p,h in base['protected'].items():assert sha(R/p)==h
assert sha(R/'FORGE_MISSION.md')==base['mission_sha256']
native=R/'results/refund-native-audit-2026-11-04/attempt-0004/native-build-0001/refund'
assert sha(native)==base['native_sha256']
prior={}
for n in ['installation-premise-20261104','runtime-premises-20261104']:
 p=R/'proposals/refund-executable-feasibility'/n;m=read(p/'manifest.json')
 for f,h in m.items():assert sha(p/f)==h
 prior[n]={'manifest_sha256':sha(p/'manifest.json'),'members':len(m)}
result={'actual_exit':0,'recorded_child_exits':expected,'interrupted_wrapper_exits':{'bridge-0002':254,'counterexample-0002':254},
 'proof_hashes':{n:sha(O/n) for n in ['bridge.sml','counterexample.sml','complete-prefix.sml','expected.sml','expected-complete.sml']},
 'identical_exports':exports,'exact_import_statements':4,'closure':closure,'closure_node_count':len(closure),
 'closure_axioms':sorted(axs),'dependency_files':files,'dependency_file_count':len(files),'builtin_dependencies':builtin,
 'pinned_source_hashes':sources,'protected_files_unchanged':len(base['protected']),'prior_packets':prior,
 'native_sha256':sha(native),'scope':'Conditional target-model bridge and complete-prefix corollary. Exact refund exclusion and physical applicability NOT_ESTABLISHED.',
 'native_or_hosted_execution':'NOT RUN','independent_full_chain_replay':'NOT RUN','end_to_end':False}
(O/'readback.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({k:v for k,v in result.items() if k not in ['closure','dependency_files','pinned_source_hashes','identical_exports']},indent=2))
