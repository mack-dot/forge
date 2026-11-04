"""Rebuild these two proofs and dispatch the existing full recursive checker.

Authenticate the packet digest against the separately reviewed expectation first.
This fixed-ELF replay creates no signature, release receipt or admission.
"""
import argparse,hashlib,json,shutil,subprocess,time,uuid
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--out',required=True,type=Path);p.add_argument('--rebuild-only',action='store_true');a=p.parse_args()
root=Path(__file__).resolve().parent;out=a.out.resolve();out.mkdir(parents=True,exist_ok=False)
sha=lambda path:hashlib.sha256(path.read_bytes()).hexdigest()
manifest=json.loads((root/'MANIFEST.json').read_text())
actual={str(x.relative_to(root)):sha(x) for x in root.rglob('*') if x.is_file() and x.name!='MANIFEST.json'}
assert actual==manifest,'PACKET_CONTENTS_CHANGED'
expected=json.loads((root/'expected.json').read_text())
targets=json.loads((root/'mount-targets.json').read_text())
image='ghcr.io/theorem-labs/oss-fuzz-theorems-checker@sha256:cc9ae43a9f4b0dd59d7c8d30727d36e039bfe72a2a9f9c4a99c68e413037e902'
flags=expected['kernel_command'][4:-len(expected['root_modules'])]
assert all(flags[i]=='-Q' for i in range(0,len(flags),3))
base=['docker','run','--pull','never','--platform','linux/amd64','--network','none','--read-only','--user','1000:1000','--cpuset-cpus','1','--memory','4g','--memory-swap','4g','--pids-limit','512','--ulimit','stack=-1:-1','--cap-drop','ALL','--security-opt','no-new-privileges:true','--tmpfs','/tmp:rw,nosuid,nodev,size=256m']
overrides={};records=[]
def invocation():
 cmd=base+['--name','forge-correspondence-replay-'+uuid.uuid4().hex]
 for target in targets:
  source=overrides.get(target,root/'inputs'/target.lstrip('/'))
  assert source.exists(),str(source)
  cmd+=['--mount','type=bind,source='+str(source)+',target='+target+',readonly']
 return cmd
def run(label,cmd):
 start=time.monotonic()
 with (out/(label+'.log')).open('xb') as f:r=subprocess.run(cmd,stdout=f,stderr=subprocess.STDOUT)
 records.append({'label':label,'argv':cmd,'actual_exit':r.returncode,'wall_seconds':time.monotonic()-start})
 (out/'commands.json').write_text(json.dumps(records,indent=2)+'\n')
 assert r.returncode==0,label
for target,name,logical in [('/behavior','Behavior','ForgeSlice'),('/bridge','ExitBridge','ForgeExitBridge')]:
 work=out/name;work.mkdir();shutil.copyfile(root/'inputs'/target.lstrip('/')/(name+'.v'),work/(name+'.v'))
 cmd=invocation()+['--mount','type=bind,source='+str(work)+',target=/trial','-w','/trial',image,'rocq','compile']
 selected=[]
 for i in range(0,len(flags),3):
  if flags[i+1]!=target:selected+=flags[i:i+3]
 cmd+=selected+['-Q','/trial',logical,'/trial/'+name+'.v']
 run(name,cmd)
 assert sha(work/(name+'.vo'))==expected['closure_sha256'][target+'/'+name+'.vo'],'OBJECT_NOT_REPRODUCIBLE'
 overrides[target]=work
if not a.rebuild_only:
 records_dir=out/'kernel';records_dir.mkdir()
 cmd=invocation()+['--mount','type=bind,source='+str(root/'expected.json')+',target=/expected.json,readonly',
  '--mount','type=bind,source='+str(root/'recheck_inside.py')+',target=/recheck_inside.py,readonly',
  '--mount','type=bind,source='+str(records_dir)+',target=/records','-w','/work',image,'python3','-I','-S','-B','/recheck_inside.py']
 run('full-kernel',cmd)
(out/'result.json').write_text(json.dumps({'actual_exit':0,'byte_identical_rebuilds':2,'full_kernel_executed':not a.rebuild_only,'admitted':False,'end_to_end':False},indent=2)+'\n')
