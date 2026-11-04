"""Replay this fixed runtime observation with the existing producer/observer."""
import argparse,hashlib,json,os,subprocess,time,uuid
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--out',type=Path,required=True);a=p.parse_args()
root=Path(__file__).resolve().parent;out=a.out.resolve();out.mkdir(parents=True,exist_ok=False)
actual={}
for path in sorted(root.rglob('*')):
 name=str(path.relative_to(root))
 if name=='MANIFEST.json':continue
 if path.is_symlink():actual[name]={'kind':'symlink','target':os.readlink(path)}
 elif path.is_file():actual[name]={'kind':'file','sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
assert actual==json.loads((root/'MANIFEST.json').read_text()),'PACKET_CONTENTS_CHANGED'
(out/'producer-chain').mkdir();(out/'capture').mkdir()
records=[]
for item in json.loads((root/'commands.json').read_text()):
 cmd=[s.replace('{ROOT}',str(root)).replace('{OUT}',str(out)) for s in item['argv']]
 cmd[cmd.index('--name')+1]='forge-fixed-runtime-replay-'+uuid.uuid4().hex
 start=time.monotonic()
 with (out/(item['name']+'.log')).open('xb') as log:result=subprocess.run(cmd,stdout=log,stderr=subprocess.STDOUT)
 records.append({'name':item['name'],'argv':cmd,'actual_exit':result.returncode,'wall_seconds':time.monotonic()-start})
 (out/'commands.json').write_text(json.dumps(records,indent=2)+'\n')
 assert result.returncode==0,item['name']
(out/'result.json').write_text(json.dumps({'actual_exit':0,'scope':'Fresh finite observation; no runtime theorem or admission','producer_chain_rechecked':True,'end_to_end':False},indent=2)+'\n')
