"""Read recorded HOL outputs and bind them to files; not a proof checker."""
from pathlib import Path
import hashlib,json,re,subprocess
ROOT=Path('/Users/mackianni/forge');OUT=Path(__file__).resolve().parent
TC=ROOT/'.toolchain/experiments/refund-cakeml-20261104'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
read=lambda p:json.loads(p.read_text())
def logs(n):return ''.join((OUT/n/f).read_text() for f in ['stdout.log','stderr.log'])
assert not (OUT/'readback.json').exists()
expected={'initial-0001':1,'code-0002':1,'code-0003':0,'code-repeat':0,
 'epoch-0001':1,'epoch-0002':0,'epoch-repeat':0,'wrong-return':1,'empty-stack':1,
 'exact-import':1,'exact-import-0002':1,'exact-import-0003':1,'exact-import-0004':1,
 'premise-diagnostic':0,'exact-import-0005':0,'wrong-word-code':1,'missing-space':1}
records={n:read(OUT/n/'command.json') for n in expected}
heap=sha(TC/'cakeml/misc/cakeml-heap')
for n,exitcode in expected.items():
 r=records[n];assert r['actual_exit']==exitcode and r['end_to_end'] is False,n
 source=OUT/n/('proof.sml' if 'completion_marker' in r else 'audit.sml')
 assert sha(source)==r['source_sha256'] and heap==r['heap_sha256'],n
 for f,h in r.get('objects',{}).items():assert sha(OUT/n/f)==h
 for parent,objects in r.get('imported_objects',{}).items():
  for f,h in objects.items():assert sha(OUT/n/parent/f)==h==sha(OUT/parent/f)
 if 'completion_marker' in r:
  assert r['completion_marker']==(exitcode==0),n
  if exitcode:assert r['objects']=={},n
 else:assert r['import_complete']==(n=='exact-import-0005'),n
exports={}
for a,b in [('code-0003','code-repeat'),('epoch-0002','epoch-repeat')]:
 x,y=records[a],records[b];assert x['source_sha256']==y['source_sha256']
 assert x['objects']==y['objects'] and len(x['objects'])==4
 exports[a]=x['objects']
prior=ROOT/'proposals/refund-executable-feasibility/word-applicability-20261105'
for here,there in [('space-parent','space-parent'),('trace-parent','trace-parent'),
 ('word-parent','word-0002'),('data-parent','data-0004'),('refund-parent','refund-word-0007')]:
 r=read(OUT/here/'command.json');assert r==read(prior/'records'/there/'command.json')
 for f,h in r['objects'].items():assert sha(OUT/here/f)==h==sha(prior/'records'/there/f)
 exports[here]=r['objects']
for n in ['wrong-return','empty-stack']:
 assert 'First unsolved sub-goal is\n\nF' in logs(n) and 'unsolved goals' in logs(n)
 assert 'UNEXPECTED_CONTROL_ACCEPTANCE' not in logs(n)
assert 'Exact statement mismatch: refund_word_code_rel' in logs('wrong-word-code')
assert 'First unsolved sub-goal is' in logs('missing-space') and 'data_lang_safe_for_space' in logs('missing-space')
assert 'unsolved goals' in logs('missing-space')
assert '"Loc" not found in theory "backend_common"' in logs('initial-0001') or '\\"Loc\\" not found' in logs('initial-0001')
assert 'isa_bits' in logs('code-0002') and 'not found' in logs('code-0002')
assert 'data_to_word$gc_kind and backend_common$tra' in logs('epoch-0001')
assert 'Attempt to unify fixed variable type' in logs('exact-import')
assert 'Exact conclusion mismatch' in logs('exact-import-0002')
assert 'Run out of store' in logs('exact-import-0003')
assert records['exact-import-0003']['source_sha256']==records['exact-import-0004']['source_sha256']
assert 'PREMISE_COUNTS 16 16' in logs('premise-diagnostic')
assert 'INITIALIZATION_DIAGNOSTIC_COMPLETE' in logs('premise-diagnostic')
log=logs('exact-import-0005')
assert len(re.findall(r'^IMPORTED .* EXACT true HYPOTHESES 0 TAGGED_AXIOMS 0$',log,re.M))==7
assert 'IMPORTED refund_initialized_single_epoch KERNEL_NORMALIZED_CONCLUSION true KERNEL_PREMISES_EQUIVALENT true HYPOTHESES 0 TAGGED_AXIOMS 0' in log
closure={}
for n,parents in re.findall(r'^CLOSURE_NODE ([^:]+):(.*)$',log,re.M):closure[n]=parents.split(',') if parents else []
assert closure and all(p in closure for ps in closure.values() for p in ps)
axioms=set(re.findall(r'^CLOSURE_AXIOM (.*)$',log,re.M))
assert axioms=={'bool.SELECT_AX','bool.INFINITY_AX','bool.ETA_AX','bool.BOOL_CASES_AX'}
index={}
for p in TC.rglob('*Theory.dat'):index.setdefault(p.name,set()).add(p.resolve())
own={Path(f).name:OUT/n/f for n,objs in exports.items() for f in objs if f.endswith('Theory.dat')}
files={};builtins={}
for n in closure:
 if n=='min':
  p=TC/'HOL/src/postkernel/Theory.sml';assert closure[n]==[]
  assert 'The "min" theory is already installed; it has no parents.' in p.read_text()
  builtins[n]={'source_sha256':sha(p),'heap_sha256':heap};continue
 fn=n+'Theory.dat';paths={own[fn]} if fn in own else index.get(fn,set())
 assert len(paths)==1,(n,paths);p=next(iter(paths))
 for ext in ['.dat','.sig','.sml']:assert p.with_suffix(ext).is_file()
 for ext in ['.dat','.sig','.sml','.uo','.ui']:
  q=p.with_suffix(ext)
  if q.exists():files[str(q)]=sha(q)
base=read(OUT/'baseline.json');sources={**base['source_hashes'],**read(OUT/'additional-sources.json')['hashes']}
for n,h in sources.items():
 b=subprocess.check_output(['git','show','cd9155694c16831373ab695a670794f23282ed62:'+n],cwd=TC/'cakeml')
 assert hashlib.sha256(b).hexdigest()==h==sha(OUT/'upstream'/n)==sha(TC/'cakeml'/n)
for n,h in base['protected'].items():assert sha(ROOT/n)==h,n
assert sha(ROOT/'FORGE_MISSION.md')==base['mission_sha256']
native=ROOT/'results/refund-native-audit-2026-11-04/attempt-0004/native-build-0001/refund'
assert sha(native)==base['native_sha256']
pins={'cakeml':'cd9155694c16831373ab695a670794f23282ed62','HOL':'9783a49979c94c401ff8c0e51b2eefae7ea95ae3'}
for n,pin in pins.items():
 assert subprocess.check_output(['git','rev-parse','HEAD'],cwd=TC/n).decode().strip()==pin
 assert subprocess.run(['git','diff','--quiet','HEAD'],cwd=TC/n).returncode==0
prior_packets={}
for n in ['runtime-premises-20261104','installation-premise-20261104','target-install-bridge-20261105','closure-install-20261105','config-install-20261105','word-applicability-20261105']:
 p=ROOT/'proposals/refund-executable-feasibility'/n;m=read(p/'manifest.json')
 for f,h in m.items():assert sha(p/f)==h
 prior_packets[n]={'manifest_sha256':sha(p/'manifest.json'),'members':len(m)}
r={'actual_exit':0,'recorded_child_exits':expected,'new_theorems':8,'checked_statements':8,
 'remaining_antecedents':16,'new_identical_exports':{n:exports[n] for n in ['code-0003','epoch-0002']},
 'closure':closure,'closure_node_count':len(closure),'closure_axioms':sorted(axioms),
 'dependency_files':files,'dependency_file_count':len(files),'builtin_dependencies':builtins,
 'pinned_source_hashes':sources,'toolchain_commits':pins,'tracked_toolchain_diffs':0,
 'protected_files_unchanged':len(base['protected']),'prior_packets':prior_packets,
 'native_sha256':sha(native),'mission_sha256':sha(ROOT/'FORGE_MISSION.md'),
 'scope':'Exact refund code relations and defined word initializer compose with conditional trace. Resources, lower-pass events and physical applicability remain open.',
 'independent_full_chain_replay':'NOT RUN','new_native_or_hosted_execution':'NOT RUN','end_to_end':False}
(OUT/'readback.json').write_text(json.dumps(r,indent=2,sort_keys=True)+'\n')
print(json.dumps({k:v for k,v in r.items() if k not in ['dependency_files','closure','pinned_source_hashes','new_identical_exports']},indent=2))
