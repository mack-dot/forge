"""Check exact retained observations and runtime inputs; no semantic inference."""
from pathlib import Path
import hashlib,json,subprocess
ROOT=Path('/Users/mackianni/forge');OUT=Path(__file__).resolve().parent
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
read=lambda p:json.loads(p.read_text())
assert not (OUT/'runtime-readback.json').exists()
tc=ROOT/'.toolchain/experiments/refund-cakeml-20261104/cakeml'
pin='cd9155694c16831373ab695a670794f23282ed62'
inputs=read(OUT/'input-readback.json'); sources={}
for name,row in inputs['sources'].items():
    p=OUT/'upstream'/name
    assert sha(p)==row['sha256']==sha(tc/name)
    blob=subprocess.run(['git','show',pin+':'+name],cwd=tc,capture_output=True,check=True).stdout
    assert blob==p.read_bytes()
    sources[name]=sha(p)
for name in ['translator/ml_progScript.sml','compiler/backend/semantics/targetPropsScript.sml',
             'compiler/backend/backendScript.sml']:
    p=OUT/'upstream'/name;assert not p.exists();p.parent.mkdir(parents=True,exist_ok=True)
    blob=subprocess.run(['git','show',pin+':'+name],cwd=tc,capture_output=True,check=True).stdout
    assert blob==(tc/name).read_bytes();p.write_bytes(blob);sources[name]=sha(p)
cap=ROOT/'results/refund-entry-observation-2026-11-04/attempt-fullmap'
for name,digest in inputs['inputs']['capture_members'].items():assert sha(cap/name)==digest
text=(cap/'debugger.log').read_text()
assert '[0x0000000100504000-0x000000010052c000) r-x __TEXT' in text
assert 0x100504000 <= 4300373588 < 4300374016 <= 0x10052c000
runtime=ROOT/'results/refund-native-audit-2026-11-04/attempt-0001/runtime-build-0002'
build=read(runtime/'command.json');assert build['actual_exit']==0
assert sha(runtime/'basis_ffi.c')==build['source_sha256']==sources['basis/basis_ffi.c']
assert sha(runtime/'basis_ffi.o')==build['object_sha256']
assert not any(x.startswith('-DEVAL') for x in build['argv'])
native=ROOT/'results/refund-native-audit-2026-11-04/attempt-0004/native-build-0001'
assert sha(native/'basis_ffi.o')==build['object_sha256']
assert sha(native/'refund')==inputs['inputs']['native_sha256']
oldpacket=ROOT/'proposals/refund-executable-feasibility/arm8-assurance-audit-20261104'
manifest=read(oldpacket/'SHA256.json');oldraw=OUT.parent/'attempt-0001';rawchecked=[]
for name,digest in manifest.items():
    assert sha(oldpacket/name)==digest
    if (oldraw/name).is_file():
        assert sha(oldraw/name)==digest;rawchecked.append(name)
baseline=read(ROOT/'results/refund-native-audit-2026-11-04/attempt-0001/baseline.json')
for name,digest in baseline['protected'].items():assert sha(ROOT/name)==digest
assert sha(ROOT/'FORGE_MISSION.md')==baseline['mission_sha256']
records={}
for label,p in [('runtime-command',runtime/'command.json'),('native-inputs',native/'inputs.json')]:
    dest=OUT/(label+'.json');assert not dest.exists();dest.write_bytes(p.read_bytes());records[label]=sha(dest)
result={'actual_exit':0,'source_commit':pin,'upstream_source_hashes':sources,
        'record_hashes':records,'runtime_object_sha256':build['object_sha256'],
        'native_sha256':sha(native/'refund'),'runtime_argv':build['argv'],
        'runtime_has_DEVAL_flag':False,'code_buffer_observed_mapping':'r-x __TEXT',
        'code_buffer_range':[4300373588,4300374016],
        'installation_conformance':'NOT_ESTABLISHED; no physical counterexample or unreachability proof executed',
        'old_packet_members_intact':len(manifest),'old_raw_members_matching_packet':rawchecked,
        'protected_files_unchanged':len(baseline['protected']),
        'capture_members_unchanged':len(inputs['inputs']['capture_members']),
        'new_native_execution':'NOT RUN','independent_archive_restore':'NOT RUN',
        'scope':'Exact source, flags, captured permissions and identity audit, not proof of runtime semantics.',
        'end_to_end':False}
(OUT/'runtime-readback.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({k:v for k,v in result.items() if k not in ['upstream_source_hashes','old_raw_members_matching_packet']},indent=2))
