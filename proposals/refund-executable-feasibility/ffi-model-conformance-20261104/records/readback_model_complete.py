"""Bind actual HOL results to captured bytes and enumerate imported file identities."""
import hashlib
import json
import re
from pathlib import Path

ROOT = Path('/Users/mackianni/forge')
OUT = Path(__file__).resolve().parent
TC = ROOT / '.toolchain/experiments/refund-cakeml-20261104'
POS = OUT / 'model-positive-0004'
REP = OUT / 'model-repeat'
AUDIT = OUT / 'model-import-audit'
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
read = lambda p: json.loads(p.read_text())
assert not (OUT/'model-complete-readback.json').exists()
records = [read(p/'command.json') for p in [POS,REP,AUDIT]]
assert all(r['actual_exit']==0 and r['completion_marker'] for r in records)
assert (POS/'check.sml').read_bytes() == (REP/'check.sml').read_bytes()
assert records[0]['objects'] == records[1]['objects']
for directory,record in zip([POS,REP],records[:2]):
    assert sha(directory/'check.sml') == record['source_sha256']
    for name,digest in record['objects'].items():
        assert sha(directory/name) == digest
    assert re.findall(r'^OBSERVED_FFI_(\d+)_CHECKED$',(directory/'stdout.log').read_text(),re.M)==['0','1','2','3']

controls=[]
for case,index,prefix in [('altered-read-byte-0004',0,[]),('wrong-write-descriptor-0004',3,['0','1','2'])]:
    p=OUT/('model-'+case);record=read(p/'command.json')
    stdout=(p/'stdout.log').read_text();stderr=(p/'stderr.log').read_text()
    assert record['actual_exit']==1 and not record['completion_marker'] and not record['objects']
    assert re.search(r'First unsolved sub-goal is\s+F\s',stdout)
    assert 'Failed to prove theorem "observed_ffi_'+str(index)+'"' in stderr
    assert re.findall(r'^OBSERVED_FFI_(\d+)_CHECKED$',stdout,re.M)==prefix
    assert sha(p/'check.sml')==record['source_sha256']
    controls.append({'case':case,'actual_exit':1,'expected_exit':1,'residual':'F',
                     'failed_theorem':'observed_ffi_'+str(index),'command_sha256':sha(p/'command.json')})

arrays={int(i):bytes(int(v) for v in body.split(',')) for i,body in re.findall(r'val captured_bytes_(\d+) = byte_terms \[([0-9,]*)\];',(POS/'check.sml').read_text())}
assert len(arrays)==12
capture_files={}
for case in ['capture-0001','capture-repeat']:
    capture=OUT/case;record=read(capture/'command.json')
    assert record['actual_exit']==0 and record['executable_unchanged']
    assert record['executable_sha256']=='b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8'
    for i in range(4):
        for j,suffix in enumerate(['conf-before','data-before','data-after']):
            f=capture/('call-%02d-%s.bin'%(i,suffix));assert f.read_bytes()==arrays[3*i+j]
            capture_files[str(f.relative_to(OUT))]=sha(f)
native=ROOT/'results/refund-native-audit-2026-11-04/attempt-0004/native-build-0001/refund'
assert sha(native)=='b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8'
pins=read(OUT/'semantics-inputs.json')
for name,digest in pins['source_sha256'].items():assert sha(TC/'cakeml'/name)==digest

log=(AUDIT/'stdout.log').read_text()
own=re.findall(r'^IMPORTED_THEOREM (observed_ffi_\d) EXACT_STATEMENT true HYPOTHESES 0 TAGGED_AXIOMS 0 ORACLES (.*)$',log,re.M)
assert [n for n,_ in own]==['observed_ffi_0','observed_ffi_1','observed_ffi_2','observed_ffi_3']
assert all(not tags or tags=='DISK_THM' for _,tags in own)
closure={n:parents.split(',') if parents else [] for n,parents in re.findall(r'^CLOSURE_NODE ([^:]+):(.*)$',log,re.M)}
assert 'forge_refundObservedFFI' in closure
assert all(parent in closure for parents in closure.values() for parent in parents)
axioms=re.findall(r'^CLOSURE_AXIOM (.+)$',log,re.M)
assert set(axioms)=={'bool.SELECT_AX','bool.INFINITY_AX','bool.ETA_AX','bool.BOOL_CASES_AX'}
index={}
for file in TC.rglob('*Theory.dat'):
    index.setdefault(file.name,set()).add(file.resolve())
dependencies={}
for name in closure:
    candidates={POS/'.hol/objs/forge_refundObservedFFITheory.dat'} if name=='forge_refundObservedFFI' else index.get(name+'Theory.dat',set())
    assert len(candidates)==1,(name,[str(p) for p in candidates])
    data=next(iter(candidates))
    for suffix in ['.dat','.sig','.sml','.uo','.ui']:
        file=data.with_suffix(suffix)
        if file.exists():dependencies[str(file)]=sha(file)
    for suffix in ['.dat','.sig','.sml']:assert data.with_suffix(suffix).exists(),(name,suffix)
result={'actual_exit':0,'positive_exit':records[0]['actual_exit'],'repeat_exit':records[1]['actual_exit'],
        'import_exit':records[2]['actual_exit'],'source_sha256':sha(POS/'check.sml'),
        'identical_exports':records[0]['objects'],'captured_buffers_checked':capture_files,
        'controls':controls,'closure':closure,'closure_node_count':len(closure),
        'closure_axioms':axioms,'dependency_files':dependencies,'dependency_file_count':len(dependencies),
        'own_theorem_count':len(own),'native_sha256':sha(native),
        'scope':'Exact finite model equations and local replay/import; no universal physical FFI or independent full-chain replay claim',
        'end_to_end':False}
(OUT/'model-complete-readback.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({k:v for k,v in result.items() if k not in ['dependency_files','closure','captured_buffers_checked']},indent=2))
