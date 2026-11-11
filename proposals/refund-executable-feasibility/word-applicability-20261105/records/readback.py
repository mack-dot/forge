"""Bind existing HOL records to their inputs; this is not a proof checker."""
from pathlib import Path
import hashlib,json,re,subprocess
ROOT=Path('/Users/mackianni/forge');OUT=Path(__file__).resolve().parent
TC=ROOT/'.toolchain/experiments/refund-cakeml-20261104'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
read=lambda p:json.loads(p.read_text())
def log(n):return ''.join((OUT/n/f).read_text() for f in ['stdout.log','stderr.log'])
assert not (OUT/'readback.json').exists()
expected=read(OUT/'expected-exits.json')
records={n:read(OUT/n/'command.json') for n in expected}
heap=sha(TC/'cakeml/misc/cakeml-heap')
for n,code in expected.items():
 r=records[n];assert r['actual_exit']==code and r['end_to_end'] is False,n
 body=OUT/n/('proof.sml' if 'completion_marker' in r else 'audit.sml')
 assert sha(body)==r['source_sha256'] and heap==r['heap_sha256'],n
 for f,h in r.get('objects',{}).items():assert sha(OUT/n/f)==h
 for src,objs in r.get('imported_objects',{}).items():
  for f,h in objs.items():assert sha(OUT/n/src/f)==h==sha(OUT/src/f)
 if 'completion_marker' in r:
  assert r['completion_marker']==(code==0),n
  if code:assert r['objects']=={},n
 else:assert r['import_complete']==(code==0),n
exports={}
for a,b in [('word-0002','word-repeat'),('data-0004','data-repeat'),('refund-word-0007','refund-word-repeat')]:
 x,y=records[a],records[b]
 assert x['actual_exit']==y['actual_exit']==0 and x['source_sha256']==y['source_sha256']
 assert x['objects']==y['objects'] and len(x['objects'])==4,(a,b)
 exports[a]=x['objects']
prior_root=ROOT/'proposals/refund-executable-feasibility/config-install-20261105/records'
for name,prior in [('space-parent','space-0002'),('trace-parent','trace-corollary-0004')]:
 r=read(OUT/name/'command.json');assert r==read(prior_root/prior/'command.json')
 for f,h in r['objects'].items():assert sha(OUT/name/f)==h==sha(prior_root/prior/f)
 exports[name]=r['objects']
account=read(OUT/'attempt-accounting.json')
assert account['per_proof_accounting']['refund_word_single_epoch']['successful_attempt']==4
prefix=(OUT/'refund-word-0004/proof.sml').read_text().split('val word_base')[0]
for n in ['refund-word-0005','refund-word-0006','refund-word-0007','refund-word-repeat']:
 assert (OUT/n/'proof.sml').read_text().split('val word_base')[0]==prefix
assert hashlib.sha256(prefix.encode()).hexdigest()==account['preserved_successful_nonfailure_prefix_sha256']
for n,reason in {'missing-data-nonfailure':'Exact statement mismatch: compiled_word_nonerror',
 'missing-data-space':'Exact statement mismatch: compiled_word_single_epoch',
 'wrong-refund-program':'Exact statement mismatch: refund_data_behavior'}.items():assert reason in log(n),n
assert len(re.findall(r'^IMPORTED .* EXACT true HYPOTHESES 0 TAGGED_AXIOMS 0$',log('word-import'),re.M))==5
assert len(re.findall(r'^IMPORTED .* EXACT true HYPOTHESES 0 TAGGED_AXIOMS 0$',log('data-import'),re.M))==2
assert len(re.findall(r'^IMPORTED .* EXACT_CONCLUSION true KERNEL_PREMISES_EQUIVALENT true HYPOTHESES 0 TAGGED_AXIOMS 0$',log('refund-import-0005'),re.M))==2
assert 'no current theory when proving' in log('refund-import')
assert 'First unsolved sub-goal is' in log('missing-input-contract') and 'stdin_content fs' in log('missing-input-contract')
assert 'unsolved goals' in log('missing-input-contract')
for n in ['missing-input-contract-0002','missing-input-contract-0003','missing-input-contract-0004']:
 assert 'First unsolved sub-goal is' in log(n) and 'stdin_content fs' in log(n) and 'unsolved goals' in log(n)
assert 'Exact conclusion mismatch: refund_word_single_epoch' in log('refund-import-0002')
assert 'TYPE_SUB' in log('refund-type-diagnostic') and "mlstring list # IO_fs" in log('refund-type-diagnostic')
closure={};combined=''.join(log(n) for n in ['word-import','data-import','refund-import-0005'])
for n,parents in re.findall(r'^CLOSURE_NODE ([^:]+):(.*)$',combined,re.M):
 ps=parents.split(',') if parents else [];assert n not in closure or closure[n]==ps;closure[n]=ps
assert all(p in closure for ps in closure.values() for p in ps)
axioms=set(re.findall(r'^CLOSURE_AXIOM (.*)$',combined,re.M))
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
 assert len(paths)==1,(n,paths)
 p=next(iter(paths))
 for ext in ['.dat','.sig','.sml']:assert p.with_suffix(ext).is_file()
 for ext in ['.dat','.sig','.sml','.uo','.ui']:
  q=p.with_suffix(ext)
  if q.exists():files[str(q)]=sha(q)
pins={'cakeml':'cd9155694c16831373ab695a670794f23282ed62','HOL':'9783a49979c94c401ff8c0e51b2eefae7ea95ae3'}
for name,pin in pins.items():
 assert subprocess.check_output(['git','rev-parse','HEAD'],cwd=TC/name).decode().strip()==pin
 assert subprocess.run(['git','diff','--quiet','HEAD'],cwd=TC/name).returncode==0
base=read(OUT/'baseline.json');sources={**base['source_hashes'],**read(OUT/'additional-sources.json')['hashes']}
for n,h in sources.items():
 b=subprocess.check_output(['git','show','cd9155694c16831373ab695a670794f23282ed62:'+n],cwd=TC/'cakeml')
 assert hashlib.sha256(b).hexdigest()==h==sha(OUT/'upstream'/n)==sha(TC/'cakeml'/n)
for n,h in base['protected'].items():assert sha(ROOT/n)==h
assert sha(ROOT/'FORGE_MISSION.md')==base['mission_sha256']
native=ROOT/'results/refund-native-audit-2026-11-04/attempt-0004/native-build-0001/refund'
assert sha(native)==base['native_sha256']
prior={}
for n in ['runtime-premises-20261104','installation-premise-20261104','target-install-bridge-20261105','closure-install-20261105','config-install-20261105']:
 p=ROOT/'proposals/refund-executable-feasibility'/n;m=read(p/'manifest.json')
 for f,h in m.items():assert sha(p/f)==h
 prior[n]={'manifest_sha256':sha(p/'manifest.json'),'members':len(m)}
result={'actual_exit':0,'recorded_child_exits':expected,'new_theorems':9,'checked_statements':9,
 'identical_exports':exports,'proof_hashes':{n:sha(OUT/n) for n in ['data-pairs.sml','word-qualified.sml','refund-word-instantiate.sml','expected-data.sml','expected-word.sml','expected-refund.sml']},
 'attempt_accounting':account,'closure':closure,'closure_node_count':len(closure),'closure_axioms':sorted(axioms),
 'dependency_files':files,'dependency_file_count':len(files),'builtin_dependencies':builtins,
 'pinned_source_hashes':sources,'toolchain_commits':pins,'tracked_toolchain_diffs':0,'protected_files_unchanged':len(base['protected']),'prior_packets':prior,
 'native_sha256':sha(native),'mission_sha256':base['mission_sha256'],
 'scope':'Exact refund data behavior/nonfailure and conditional word trace composition. Runtime word-state applicability and target event correspondence remain unestablished.',
 'independent_full_chain_replay':'NOT RUN','new_native_or_hosted_execution':'NOT RUN','end_to_end':False}
(OUT/'readback.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({k:v for k,v in result.items() if k not in ['closure','dependency_files','pinned_source_hashes','identical_exports','attempt_accounting']},indent=2))
