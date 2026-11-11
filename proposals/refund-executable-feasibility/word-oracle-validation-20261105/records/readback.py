"""Bind recorded HOL results to exact files. This does not check proofs."""
from pathlib import Path
import hashlib,json,re,subprocess
ROOT=Path('/Users/mackianni/forge');OUT=Path(__file__).resolve().parent
TC=ROOT/'.toolchain/experiments/refund-cakeml-20261104'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
read=lambda p:json.loads(p.read_text())
def logs(n):return ''.join((OUT/n/f).read_text() for f in ['stdout.log','stderr.log'])
assert not (OUT/'readback.json').exists()
expected={'oracle-0001':0,'oracle-0002':1,'normalization-diagnostic':0,'oracle-0003':0,
 'exact-import':1,'exact-import-0002':1,'exact-import-0003':0,'oracle-repeat':0,'wrong-oracle':1,'missing-pointer':1}
records={n:read(OUT/n/'command.json') for n in expected}
heap=sha(TC/'cakeml/misc/cakeml-heap')
for n,code in expected.items():
 r=records[n];assert r['actual_exit']==code and r['end_to_end'] is False,n
 source=OUT/n/('proof.sml' if 'completion_marker' in r else 'audit.sml')
 assert sha(source)==r['source_sha256'] and r['heap_sha256']==heap,n
 for f,h in r.get('objects',{}).items():assert sha(OUT/n/f)==h,(n,f)
 for parent,objects in r.get('imported_objects',{}).items():
  for f,h in objects.items():assert sha(OUT/n/parent/f)==h==sha(OUT/parent/f),(n,parent,f)
 if 'completion_marker' in r:assert r['completion_marker']==(code==0),n
 else:assert r['import_complete']==(n=='exact-import-0003'),n
assert 'REMAINING_ANTECEDENTS 13' in logs('oracle-0001')
assert 'Oracle or label premise not discharged' in logs('oracle-0002')
assert 'PREMISE_COUNT 12' in logs('normalization-diagnostic') and 'ORACLE_DIAGNOSTIC_COMPLETE' in logs('normalization-diagnostic')
assert 'UNCHANGED' in logs('exact-import-0002')
assert 'UNCHANGED' in logs('exact-import') and 'IMPORTED refund_word_oracle_binding' in logs('exact-import')
a,b=records['oracle-0003'],records['oracle-repeat']
assert a['objects']==b['objects'] and len(a['objects'])==4 and a['source_sha256']==b['source_sha256']
for n in ('oracle-0003','oracle-repeat'):assert 'REMAINING_ANTECEDENTS 11' in logs(n)
assert 'Exact statement mismatch: refund_word_oracle_binding' in logs('wrong-oracle')
assert 'UNEXPECTED_CONTROL_ACCEPTANCE' not in logs('wrong-oracle')
assert 'First unsolved sub-goal is' in logs('missing-pointer') and 'unsolved goals' in logs('missing-pointer')
assert 'ptr_eq_oracle' in logs('missing-pointer') and 'UNEXPECTED_CONTROL_ACCEPTANCE' not in logs('missing-pointer')
log=logs('exact-import-0003')
assert len(re.findall(r'^IMPORTED .* KERNEL_NORMALIZED_EXACT true HYPOTHESES 0 TAGGED_AXIOMS 0$',log,re.M))==2
assert 'IMPORTED refund_exact_oracle_single_epoch KERNEL_NORMALIZED_CONCLUSION true KERNEL_PREMISES_EQUIVALENT true HYPOTHESES 0 TAGGED_AXIOMS 0' in log
closure={n:p.split(',') if p else [] for n,p in re.findall(r'^CLOSURE_NODE ([^:]+):(.*)$',log,re.M)}
assert closure and all(p in closure for ps in closure.values() for p in ps)
axioms=set(re.findall(r'^CLOSURE_AXIOM (.*)$',log,re.M))
assert axioms=={'bool.SELECT_AX','bool.INFINITY_AX','bool.ETA_AX','bool.BOOL_CASES_AX'}
exports={'oracle-0003':a['objects']}
prior=ROOT/'proposals/refund-executable-feasibility/word-initialization-20261105'
for here,there in [('space-parent','space-parent'),('trace-parent','trace-parent'),('word-parent','word-parent'),
 ('data-parent','data-parent'),('refund-parent','refund-parent'),('init-parent','code-0003'),('epoch-parent','epoch-0002')]:
 r=read(OUT/here/'command.json');assert r==read(prior/'records'/there/'command.json')
 for f,h in r['objects'].items():assert sha(OUT/here/f)==h==sha(prior/'records'/there/f)
 exports[here]=r['objects']
index={}
for p in TC.rglob('*Theory.dat'):index.setdefault(p.name,set()).add(p.resolve())
own={Path(f).name:OUT/n/f for n,objs in exports.items() for f in objs if f.endswith('Theory.dat')}
files={};builtins={}
for n in closure:
 if n=='min':
  p=TC/'HOL/src/postkernel/Theory.sml';assert closure[n]==[]
  assert 'The "min" theory is already installed; it has no parents.' in p.read_text()
  builtins[n]={'source_sha256':sha(p),'heap_sha256':heap};continue
 fn=n+'Theory.dat';paths={own[fn]} if fn in own else index.get(fn,set());assert len(paths)==1,(n,paths)
 p=next(iter(paths))
 for ext in ['.dat','.sig','.sml']:assert p.with_suffix(ext).is_file()
 for ext in ['.dat','.sig','.sml','.uo','.ui']:
  q=p.with_suffix(ext)
  if q.exists():files[str(q)]=sha(q)
base=read(OUT/'baseline.json');sources={**base['source_hashes'],**read(OUT/'next-source.json')}
for n,h in sources.items():
 data=subprocess.check_output(['git','show','cd9155694c16831373ab695a670794f23282ed62:'+n],cwd=TC/'cakeml')
 assert hashlib.sha256(data).hexdigest()==h==sha(OUT/'upstream'/n)==sha(TC/'cakeml'/n)
hol_sources=read(OUT/'hol-source.json')
for n,h in hol_sources.items():
 data=subprocess.check_output(['git','show','9783a49979c94c401ff8c0e51b2eefae7ea95ae3:'+n],cwd=TC/'HOL')
 assert hashlib.sha256(data).hexdigest()==h==sha(OUT/'upstream-HOL'/n)==sha(TC/'HOL'/n)
for n,h in base['protected'].items():assert sha(ROOT/n)==h,n
assert sha(ROOT/'FORGE_MISSION.md')==base['mission_sha256']
native=ROOT/'results/refund-native-audit-2026-11-04/attempt-0004/native-build-0001/refund'
assert sha(native)==base['native_sha256']
pins={'cakeml':'cd9155694c16831373ab695a670794f23282ed62','HOL':'9783a49979c94c401ff8c0e51b2eefae7ea95ae3'}
for n,pin in pins.items():
 assert subprocess.check_output(['git','rev-parse','HEAD'],cwd=TC/n).decode().strip()==pin
 assert subprocess.run(['git','diff','--quiet','HEAD'],cwd=TC/n).returncode==0
prior_packets={}
for n in ['runtime-premises-20261104','installation-premise-20261104','target-install-bridge-20261105','closure-install-20261105',
 'config-install-20261105','word-applicability-20261105','word-initialization-20261105','word-oracle-20261105']:
 p=ROOT/'proposals/refund-executable-feasibility'/n;m=read(p/'manifest.json')
 for f,h in m.items():assert sha(p/f)==h,(n,f)
 prior_packets[n]={'manifest_sha256':sha(p/'manifest.json'),'members':len(m)}
r={'actual_exit':0,'recorded_child_exits':expected,'new_theorems':3,'checked_statements':3,'remaining_antecedents':11,
 'identical_exports':a['objects'],'closure':closure,'closure_node_count':len(closure),'closure_axioms':sorted(axioms),
 'dependency_files':files,'dependency_file_count':len(files),'builtin_dependencies':builtins,'pinned_source_hashes':sources,
 'hol_source_hashes':hol_sources,'toolchain_commits':pins,'tracked_toolchain_diffs':0,'protected_files_unchanged':len(base['protected']),'prior_packets':prior_packets,
 'native_sha256':sha(native),'mission_sha256':sha(ROOT/'FORGE_MISSION.md'),
 'scope':'Exact compiler oracle and future label bounds discharge two combined premises. Eleven resource/state/compiler/input/pointer conditions remain.',
 'independent_full_chain_replay':'NOT RUN','new_native_or_hosted_execution':'NOT RUN','end_to_end':False}
(OUT/'readback.json').write_text(json.dumps(r,indent=2,sort_keys=True)+'\n')
print(json.dumps({k:v for k,v in r.items() if k not in ['dependency_files','closure','pinned_source_hashes','identical_exports']},indent=2))
