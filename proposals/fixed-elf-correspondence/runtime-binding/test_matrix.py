"""Exercise exact observation-binding refusals with preserved actual child exits."""
import hashlib,json,os,shutil,subprocess,sys,time
from pathlib import Path
OUT=Path(__file__).resolve().parent
PACKET=Path('/Users/mackianni/forge/results/executable-correspondence-2026-11-03/attempt-0001/runtime-packet')
base=OUT/'bound-baseline/runtime/capture'
assert json.loads((OUT/'bound-baseline/binding-result.json').read_text())['actual_exit']==0
cases=OUT/'controls';cases.mkdir()
records=[]
def run(name,cmd,code,reason=None):
 start=time.monotonic();r=subprocess.run(cmd,capture_output=True)
 (cases/(name+'.stdout')).write_bytes(r.stdout);(cases/(name+'.stderr')).write_bytes(r.stderr)
 row={'name':name,'argv':cmd,'actual_exit':r.returncode,'expected_exit':code,
      'expected_reason':reason,'wall_seconds':time.monotonic()-start}
 records.append(row);(OUT/'matrix-commands.json').write_text(json.dumps(records,indent=2)+'\n')
 assert r.returncode==code,(name,r.returncode,r.stderr)
 if reason:assert reason in r.stderr.decode(),(name,r.stderr)
 print(name+': '+str(r.returncode),flush=True)
def compare(name,capture,code,reason=None):
 run(name,[sys.executable,'-I','-B',str(OUT/'test_capture.py'),str(capture)],code,reason)
def copy(name):
 folder=cases/name;shutil.copytree(base,folder);return folder
def change_json(folder,name,edit):
 p=folder/name;data=json.loads(p.read_text());edit(data);p.write_text(json.dumps(data,indent=2)+'\n')
compare('valid-record',base,0)
compare('actual-changed-entry',OUT/'changed-entry/capture',1,'TRACE_IDENTITY_MISMATCH')
f=copy('changed-trace');p=f/'instruction-trace.log';data=bytearray(p.read_bytes());data[0]^=1;p.write_bytes(data)
compare('changed-trace',f,1,'TRACE_IDENTITY_MISMATCH')
f=copy('extra-trace');p=f/'instruction-trace.log';p.write_bytes(p.read_bytes()+b'EXTRA\n')
compare('extra-trace',f,1,'TRACE_IDENTITY_MISMATCH')
f=copy('missing-trace');(f/'instruction-trace.log').unlink()
compare('missing-trace',f,1,'MISSING_OR_LINKED_INPUT:instruction-trace.log')
f=copy('changed-load');p=f/'live-load-text.bin';data=bytearray(p.read_bytes());data[0]^=1;p.write_bytes(data)
compare('changed-load',f,1,'LOAD_IDENTITY_MISMATCH:text')
f=copy('stale-elf');change_json(f,'execution-before.json',lambda d:d.update(elf_sha256='0'*64))
compare('stale-elf',f,1,'EXECUTION_IDENTITY_MISMATCH:elf_sha256')
f=copy('changed-harness');change_json(f,'execution-before.json',lambda d:d.update(commands_sha256='0'*64))
compare('changed-harness',f,1,'EXECUTION_IDENTITY_MISMATCH:commands_sha256')
f=copy('missing-command');change_json(f,'execution-before.json',lambda d:d.pop('qemu_argv'))
compare('missing-command',f,1,'EXECUTION_COMMAND_MISMATCH')
f=copy('parent-nonzero');change_json(f,'qemu-command.json',lambda d:d.update(actual_exit=1))
compare('parent-nonzero',f,1,'PARENT_EXIT_NOT_ZERO')
f=copy('parent-false');change_json(f,'qemu-command.json',lambda d:d.update(actual_exit=False))
compare('parent-false',f,1,'PARENT_EXIT_NOT_ZERO')
f=copy('observer-killed');change_json(f,'qemu-command.json',lambda d:d.update(terminated_by_observer=True))
compare('observer-killed',f,1,'OBSERVER_TERMINATED_OR_UNKNOWN')
f=copy('scope-upgrade');change_json(f,'result.json',lambda d:d.update(end_to_end=True))
compare('scope-upgrade',f,1,'UNAUTHORIZED_SCOPE_UPGRADE')
bound=[sys.executable,'-I','-B',str(OUT/'run_bound_observation.py')]
missing=cases/'missing-anchor';missing.mkdir()
run('missing-anchor',bound+['--runtime-packet',str(missing),'--out',str(cases/'missing-anchor-out')],1,'MISSING_OR_LINKED_INPUT:MANIFEST.json')
coordinated=cases/'coordinated-packet';shutil.copytree(PACKET,coordinated,symlinks=True)
p=coordinated/'commands.gdb';p.write_text(p.read_text().replace('continue\n','set $a0 = 1\ncontinue\n',1))
p=coordinated/'MANIFEST.json';data=json.loads(p.read_text())
data['commands.gdb']['sha256']=hashlib.sha256((coordinated/'commands.gdb').read_bytes()).hexdigest()
p.write_text(json.dumps(data,indent=2)+'\n')
run('coordinated-packet',bound+['--runtime-packet',str(coordinated),'--out',str(cases/'coordinated-out')],1,'PACKET_ANCHOR_MISMATCH')
for folder in ['missing-anchor-out','coordinated-out']:
 assert not (cases/folder/'invocation.json').exists()
prior=(OUT/'bound-baseline/binding-result.json').read_bytes()
run('existing-output',bound+['--runtime-packet',str(PACKET),'--out',str(OUT/'bound-baseline')],1,'FileExistsError')
assert (OUT/'bound-baseline/binding-result.json').read_bytes()==prior
result={'actual_exit':0,'cases':len(records),'positive_record_comparisons':1,
 'expected_refusals':len(records)-1,'actual_changed_entry_exit':0,
 'old_observer_scope_was_observation_only':True,'no_new_authoritative_evidence':True,
 'kernel_replayed_this_turn':False,'end_to_end':False}
(OUT/'matrix-result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result),flush=True)
