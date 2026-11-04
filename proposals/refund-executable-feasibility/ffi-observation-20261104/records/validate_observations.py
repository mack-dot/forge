"""Check saved observations and byte identity; not a runtime semantic verifier."""
from pathlib import Path
import hashlib,json,re,subprocess
ROOT=Path('/Users/mackianni/forge');OUT=Path(__file__).resolve().parent
NATIVE=ROOT/'results/refund-native-audit-2026-11-04/attempt-0004';FIX=ROOT/'results/refund-native-audit-2026-11-04/attempt-0003/wire'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
assert sha(NATIVE/'native-build-0001/refund')=='b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8'
assert not (OUT/'observations-validated.json').exists()
commands=[];captures=[]
def cmp(a,b):
    argv=['/usr/bin/cmp',str(a),str(b)];p=subprocess.run(argv,capture_output=True)
    commands.append({'argv':argv,'actual_exit':p.returncode,'stdout':p.stdout.decode(),'stderr':p.stderr.decode()})
    assert p.returncode==0,(a,b)
for name in ['capture-0001','capture-repeat']:
    cap=OUT/name;r=json.loads((cap/'command.json').read_text())
    assert r['actual_exit']==0 and r['executable_unchanged'] and not r['end_to_end']
    assert sha(cap/'commands.lldb')==r['commands_sha256']
    log=(cap/'debugger.log').read_text();assert 'error:' not in log.lower()
    exits=re.findall(r'Process (\d+) exited with status = (\d+)',log)
    assert len(exits)==2 and len(set(exits))==1 and exits[0][1]=='0'
    blocks=re.findall(r'^\(lldb\) register read ([^\n]+)\n(.*?)(?=^\(lldb\)|\Z)',log,re.M|re.S)
    snaps=[{n:int(v,16) for n,v in re.findall(r'^\s*(x\d+|fp|lr|sp|pc|cpsr) = (0x[0-9a-fA-F]+)',body,re.M)} for args,body in blocks]
    assert len(snaps)==11;assert snaps[0]==snaps[1]
    entry=snaps[0];calls=[]
    for i in range(4):
        before,after=snaps[2+2*i:4+2*i]
        assert after['pc']==before['lr'] and before['sp']==after['sp'] and before['sp']%16==0
        assert entry['pc']<=after['pc']<entry['pc']+130436
        assert all(before[f'x{n}']==after[f'x{n}'] for n in range(19,29))
        assert before['pc']-entry['pc']==([0x25170]*3+[0x251e0])[i]-0x40d0
        for kind,count in [('conf',before['x1']),('data',before['x3'])]:
            for side in ['before','after']:assert (cap/f'call-{i:02d}-{kind}-{side}.bin').stat().st_size==count
        cmp(cap/f'call-{i:02d}-conf-before.bin',cap/f'call-{i:02d}-conf-after.bin')
        calls.append({'index':i,'name':'read' if i<3 else 'write','before':before,'after':after,'return_pc_and_callee_saved_and_sp_match':True})
    assert snaps[-1]['x0']==0 and snaps[-1]['pc']-entry['pc']==0x25464-0x40d0
    for i in range(7,11):
        assert f'one-shot breakpoint {i}' in log
        section=log.split(f'{i}: address = ',1)[1].split('(lldb) process continue',1)[0]
        assert 'hardware = true' in section
    final=log.rsplit('(lldb) breakpoint list --verbose',1)[1]
    for i,count in [(2,3),(3,1),(4,0),(5,0),(6,1)]:
        b=final.split(f'\n{i}: address = ',1)[1].split('\n\n\n',1)[0]
        assert 'resolved = true' in b and 'hardware = true' in b
        assert f'hit count = {count} ' in b
    for a,b in [(cap/'loaded-code.bin',NATIVE/'compiled-extraction/code.bin'),(cap/'code-before-exit.bin',NATIVE/'compiled-extraction/code.bin'),(cap/'loaded-bitmaps.bin',NATIVE/'identity-0001/expected-bitmaps.bin'),(cap/'native.stdout',FIX/'eligible_duplicate.stdout')]:cmp(a,b)
    assert (cap/'native.stderr').stat().st_size==0
    captures.append({'capture':name,'calls':calls,'cml_exit_argument':0,'actual_native_exit':0,'sha256':{p.name:sha(p) for p in cap.iterdir() if p.is_file()}})
for p in (OUT/'capture-0001').glob('*.bin'):
    if p.name=='heap-header.bin':continue # ASLR-dependent observed pointers
    cmp(p,OUT/'capture-repeat'/p.name)
cmp(OUT/'capture-0001/run.py',OUT/'capture-repeat/run.py')
cmp(OUT/'capture-0001/native.stdout',OUT/'capture-repeat/native.stdout')
record={'actual_exit':0,'comparison_count':len(commands),'comparisons':commands,'captures':captures,'full_memory_frame':'NOT_ESTABLISHED','universal_FFI_refinement':'NOT_ESTABLISHED','end_to_end':False}
(OUT/'observations-validated.json').write_text(json.dumps(record,indent=2)+'\n')
print(json.dumps({'actual_exit':0,'captures':len(captures),'comparisons':len(commands),'end_to_end':False}))
