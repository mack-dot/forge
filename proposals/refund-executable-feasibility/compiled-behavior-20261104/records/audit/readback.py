"""Bind the completed compiler result, repeat, claim controls and closure."""
from pathlib import Path
import hashlib,json,re
ROOT=Path('/Users/mackianni/forge');OUT=Path(__file__).resolve().parent
TC=ROOT/'.toolchain/experiments/refund-cakeml-20261104'
BUILDS=ROOT/'results/refund-arm8-compile-2026-11-04/attempt-0001'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
read=lambda p:json.loads(p.read_text())
assert not (OUT/'readback.json').exists()
pos=read(BUILDS/'behavior-0001/command.json');rep=read(BUILDS/'behavior-0002/command.json')
assert pos['actual_exit']==rep['actual_exit']==0
assert pos['object_sha256']==rep['object_sha256'] and len(pos['object_sha256'])==6
assert pos['source_sha256']==rep['source_sha256']=='7cb940489138a6f81eb5b169e5397df7217170a84267e9565600273f36ff40ca'
for case,r in [('behavior-0001',pos),('behavior-0002',rep)]:
 p=BUILDS/case
 assert sha(p/'forge_refundArm8ProofScript.sml')==r['source_sha256']
 for name,digest in r['object_sha256'].items():assert sha(p/'objects'/name)==digest
 log=(p/'theory.log').read_text()
 assert 'Saved theorem _______ "refund_compiled_behavior"' in log
 assert 'FORGE_HYPOTHESES 0' in log and 'FORGE_AXIOMS \n' in log
 assert 'extend_with_resource_limit' in log
audit=read(OUT/'import-0002/command.json')
assert audit['actual_exit']==0 and audit['completion_marker']
log=(OUT/'import-0002/stdout.log').read_text()
assert 'EXACT_BEHAVIOR_BINDING' in log
assert 'CHECKED_ORACLES DISK_THM\nCHECKED_HYPOTHESES 0\nCHECKED_TAGGED_AXIOMS 0' in log
controls=[]
for case in ['substituted-code','changed-result']:
 p=OUT/case;r=read(p/'command.json');err=(p/'stderr.log').read_text()
 assert r['actual_exit']==1 and not r['completion_marker']
 assert 'Exact compiler behavior statement mismatch' in err
 assert 'No such file or directory' not in err and 'Type error' not in err
 assert 'EXACT_BEHAVIOR_BINDING' not in (p/'stdout.log').read_text()
 for name,digest in pos['object_sha256'].items():assert sha(p/'imported/.hol/objs'/name)==digest
 controls.append({'case':case,'actual_exit':1,'reason':'Exact compiler behavior statement mismatch','scope':'Refusal of substituted claim; not a native behavioral counterexample.'})
normal=(OUT/'import-0002/audit.sml').read_text()
assert (OUT/'substituted-code/audit.sml').read_text()==normal.replace('targetSem$installed forge_refundArm8Compile$code','targetSem$installed (0w::forge_refundArm8Compile$code)')
needle='forge_refundCertifiedProg$refund_fields charge request original remaining\n             enabled opened candidate amount reason'
assert normal.count(needle)==1
assert (OUT/'changed-result/audit.sml').read_text()==normal.replace(needle,needle.replace('candidate amount reason','candidate (amount+1) reason'))
closure={n:parents.split(',') if parents else [] for n,parents in re.findall(r'^CLOSURE_NODE ([^:]+):(.*)$',log,re.M)}
assert 'forge_refundArm8Proof' in closure and 'arm8_targetProof' in closure
assert all(p in closure for parents in closure.values() for p in parents)
axioms=re.findall(r'^CLOSURE_AXIOM (.+)$',log,re.M)
assert set(axioms)=={'bool.SELECT_AX','bool.INFINITY_AX','bool.ETA_AX','bool.BOOL_CASES_AX'}
index={}
for f in TC.rglob('*Theory.dat'):index.setdefault(f.name,set()).add(f.resolve())
dependencies={};builtins={}
for name in closure:
 if name=='min':
  assert closure[name]==[]
  source=TC/'HOL/src/postkernel/Theory.sml'
  assert 'The "min" theory is already installed; it has no parents.' in source.read_text()
  builtins[name]={'kind':'Built-in kernel root','source_sha256':sha(source),'heap_sha256':sha(TC/'cakeml/misc/cakeml-heap')}
  continue
 candidates={BUILDS/'behavior-0001/objects/forge_refundArm8ProofTheory.dat'} if name=='forge_refundArm8Proof' else index.get(name+'Theory.dat',set())
 assert len(candidates)==1,(name,[str(p) for p in candidates])
 data=next(iter(candidates))
 for suffix in ['.dat','.sig','.sml']:assert data.with_suffix(suffix).exists(),(name,suffix)
 for suffix in ['.dat','.sig','.sml','.uo','.ui']:
  f=data.with_suffix(suffix)
  if f.exists():dependencies[str(f)]=sha(f)
compiler=pos['compiler_record']
for name,digest in compiler['object_sha256'].items():
 assert sha(BUILDS/'compile-repeat/objects'/name)==digest
 assert sha(TC/'cakeml/compiler/dafny/forge_refundArm8Compile_experiment/.hol/objs'/name)==digest
native=ROOT/'results/refund-native-audit-2026-11-04/attempt-0004/native-build-0001/refund'
assert sha(native)=='b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8'
code=ROOT/'results/refund-entry-observation-2026-11-04/attempt-fullmap/loaded-code.bin'
bitmaps=code.parent/'loaded-bitmaps.bin'
assert sha(code)=='3c67983c93b3f7bbb340c2c517f6315ae2dc6260f2b401fb09d3b5a24ba15deb'
assert sha(bitmaps)=='68d3f080066fdaeb12ff1c061a875b1502172be0857a2af02f77f6f18f36fb76'
base=read(ROOT/'results/refund-native-audit-2026-11-04/attempt-0001/baseline.json')
for name,digest in base['protected'].items():assert sha(ROOT/name)==digest
assert sha(ROOT/'FORGE_MISSION.md')==base['mission_sha256']
result={'actual_exit':0,'positive_exit':0,'repeat_exit':0,'import_exit':0,'source_sha256':pos['source_sha256'],
 'identical_exports':pos['object_sha256'],'controls':controls,'closure':closure,'closure_node_count':len(closure),
 'closure_axioms':axioms,'builtin_dependencies':builtins,'dependency_files':dependencies,'dependency_file_count':len(dependencies),
 'protected_files_unchanged':len(base['protected']),'native_sha256':sha(native),'saved_loaded_code_sha256':sha(code),'saved_loaded_bitmaps_sha256':sha(bitmaps),
 'positive_wall_seconds':pos['wall_seconds'],'repeat_wall_seconds':rep['wall_seconds'],
 'scope':'Conditional compiled model behavior with resource-limit prefixes; same-host rebuild/import. Physical correspondence and independent complete-chain replay remain open.',
 'end_to_end':False}
(OUT/'readback.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({k:v for k,v in result.items() if k not in ['dependency_files','closure','identical_exports']},indent=2))
