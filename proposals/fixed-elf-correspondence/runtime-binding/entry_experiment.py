"""Actual unchanged observer, with one deliberately changed entry register."""
import hashlib,json,subprocess,sys,time,uuid
from pathlib import Path
OUT=Path(__file__).resolve().parent
OLD=Path('/Users/mackianni/forge/results/executable-correspondence-2026-11-03/attempt-0001')
PACKET=OLD/'runtime-packet'
rows=[]
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
assert digest(OLD/'runtime-packet.tar.gz')=='55eec1b9063b6982c23acf6d8d6624dbbc85fabe9e1fed191c070e57ffc37912'
assert digest(PACKET/'MANIFEST.json')=='24afcae2976fbcf38a024afc29455d310510d7eedb40320cb982fc226bdd5db0'
def run(name,cmd):
 start=time.monotonic()
 with (OUT/(name+'.log')).open('xb') as f:p=subprocess.run(cmd,stdout=f,stderr=subprocess.STDOUT)
 row={'name':name,'argv':cmd,'actual_exit':p.returncode,'wall_seconds':time.monotonic()-start}
 rows.append(row);(OUT/'entry-commands.json').write_text(json.dumps(rows,indent=2)+'\n')
 print(name+': '+str(p.returncode),flush=True)
 assert p.returncode==0,name
baseline=OUT/'baseline'
run('unchanged-runtime-replay',[sys.executable,'-I','-B',str(PACKET/'replay.py'),'--out',str(baseline)])
case=OUT/'changed-entry';case.mkdir(mode=0o700);capture=case/'capture';capture.mkdir()
original=(PACKET/'commands.gdb').read_text()
needle='printf "FORGE_ENTRY_PC='
assert original.count(needle)==1
modified=original.replace(needle,'set $a0 = 1\n'+needle,1)
(case/'commands.gdb').write_text(modified)
commands=json.loads((baseline/'commands.json').read_text())
cmd=next(x['argv'] for x in commands if x['name']=='baseline').copy()
cmd=[x.replace(str(baseline/'capture'),str(capture)).replace('source='+str(PACKET/'commands.gdb'),'source='+str(case/'commands.gdb')) for x in cmd]
cmd[cmd.index('--name')+1]='forge-changed-entry-'+uuid.uuid4().hex
run('changed-entry-observer',cmd)
post=next(x['argv'] for x in commands if x['name']=='baseline-producer-post').copy()
post=[x.replace(str(baseline/'capture'),str(capture)) for x in post]
post[post.index('--name')+1]='forge-changed-entry-post-'+uuid.uuid4().hex
run('changed-entry-producer-post',post)
b=json.loads((baseline/'capture/result.json').read_text());c=json.loads((capture/'result.json').read_text())
assert b['qemu_exit']==c['qemu_exit']==0
bh=digest(baseline/'capture/instruction-trace.log');ch=digest(capture/'instruction-trace.log')
assert bh=='526c4a2107262bd8624cc19e9762fa4875d536e0b7697324a1a2b468bdf9ed49'
assert bh!=ch
result={'actual_exit':0,'baseline_qemu_exit':b['qemu_exit'],'changed_entry_qemu_exit':c['qemu_exit'],
 'original_observer_exit_for_changed_entry':0,'baseline_trace_sha256':bh,'changed_trace_sha256':ch,
 'original_gdb_script_sha256':digest(PACKET/'commands.gdb'),'control_gdb_script_sha256':digest(case/'commands.gdb'),
 'entry_control':'Set a0 to 1 before the initial capture; ELF overwrites a0 before computation.',
 'finding':'Successful observation/exit0 alone does not establish the exact initializer or trace identity.',
 'old_observer_claim_scope':'Finite observation only; it did not claim theorem applicability.',
 'end_to_end':False}
(OUT/'entry-result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result),flush=True)
