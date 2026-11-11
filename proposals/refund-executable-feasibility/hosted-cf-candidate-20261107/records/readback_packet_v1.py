from pathlib import Path
import ast,base64,hashlib,io,json,tarfile,zlib
ROOT=Path('/Users/mackianni/forge');OUT=Path(__file__).resolve().parent
PACKET=ROOT/'proposals/refund-executable-feasibility/hosted-cf-candidate-20261107'
sha=lambda b:hashlib.sha256(b).hexdigest()
read=lambda p:json.loads(Path(p).read_text())
mraw=(PACKET/'payload/INPUTS.json').read_bytes();m=json.loads(mraw)
assert sha(mraw)=='6822e8da53f477f991bfa4a7cab02ffc59906a58460048a49af190fb42b2c105' and len(mraw)==932639
parts=[]
for r in m['parts']:
    b=(PACKET/'payload'/r['name']).read_bytes();assert len(b)==r['bytes'] and sha(b)==r['sha256'];parts.append(b)
archive=b''.join(parts);assert len(archive)==9882464 and sha(archive)==m['archive_sha256']
expected={r['path']:r for r in m['files']}
with tarfile.open(fileobj=io.BytesIO(archive),mode='r:xz') as tar:
    members=tar.getmembers();assert len(members)==1475 and {x.name for x in members}==set(expected)
    for x in members:
        assert x.isfile() and not Path(x.name).is_absolute() and '..' not in Path(x.name).parts
        b=tar.extractfile(x).read();r=expected[x.name];assert len(b)==r['bytes'] and sha(b)==r['sha256']
        assert Path(r['source']).read_bytes()==b
base=read(PACKET/'records/BASE-INPUTS.json')
assert sha((PACKET/'records/BASE-INPUTS.json').read_bytes())=='6822d1ae4ef5ca78ae14e352c5b1e222ed113bba1f3760d9b0141b70386c51a7'
assert len(base['files'])==18 and not {r['path'] for r in base['files']}&set(expected)
for r in base['files']:assert sha(Path(r['source']).read_bytes())==r['sha256']
for case in ['parents','loader-metadata']:
    rec=read(PACKET/'records'/case/'command.json');assert rec['actual_exit']==0
    for stream in ['stdout','stderr']:assert sha((PACKET/'records'/case/(stream+'.log')).read_bytes())==rec[stream+'_sha256']
events=[json.loads(x) for x in (PACKET/'records/local-inspection.jsonl').read_text().splitlines()]
assert [x['actual_exit'] for x in events if x['operation']=='child_result']==[0]
for rec in [x for x in events if x['operation']=='file']:
    chunks=sorted([x for x in events if x['operation']=='file_chunk' and x['file']==rec['file']],key=lambda x:x['index'])
    assert [x['index'] for x in chunks]==list(range(rec['chunks']))
    b=zlib.decompress(base64.b64decode(''.join(x['data'] for x in chunks),validate=True))
    assert len(b)==rec['bytes'] and sha(b)==rec['sha256'] and b==(PACKET/'records/local-inspection'/rec['file']).read_bytes()
stdout=(PACKET/'records/local-inspection/stdout.log').read_text()
for marker in ['CANDIDATE_TERM_PARSED','NO_THEOREM_ATTEMPTED','RELOCATION_INSPECTION_COMPLETE']:assert marker in stdout
assert 'load "cfLib"' not in (PACKET/'records/local-inspection/bootstrap.sml').read_text()
assert read(PACKET/'records/LOCAL-INSPECTION.json')['objects']=={}
for case in ['wrong-hash','path-traversal','symlink']:
    rec=read(PACKET/'records/transport-controls'/case/'command.json');assert rec['actual_exit']==1
    for stream in ['stdout','stderr']:assert sha((PACKET/'records/transport-controls'/case/(stream+'.log')).read_bytes())==rec[stream+'_sha256']
review=read(PACKET/'records/WORKFLOW-REVIEW.json')
assert sha((PACKET/'records/proposed-workflow.yml').read_bytes())==review['proposed_workflow_sha256']
assert sha((PACKET/'records/hosted-driver.py').read_bytes())==review['driver_sha256']
assert review['approval']=='PENDING' and not review['published']
ast.parse((PACKET/'records/hosted-driver.py').read_text())
baseline=read(ROOT/'results/refund-native-audit-2026-11-04/attempt-0001/baseline.json')
for workspace in [ROOT,Path('/private/tmp/forge-native-audit-review-20261104')]:
    for p,h in baseline['protected'].items():assert sha((workspace/p).read_bytes())==h,p
    assert sha((workspace/'FORGE_MISSION.md').read_bytes())==baseline['mission_sha256']
candidate=ROOT/'results/refund-read-event-gap-20261107/attempt-0001/generic-read-0001.sml'
assert sha(candidate.read_bytes())=='7e36c4867615e1d7fdce3d49143ced0788f0f28517df49a1f611ef95a684ffc6'
result={'actual_exit':0,'new_archive_files':1475,'reused_base_files':18,'all_source_bytes_match':True,
        'metadata_child_exits':[0,0],'local_parse_child_exit':0,'transport_negative_child_exits':[1,1,1],
        'protected_paths_per_workspace':len(baseline['protected']),'frozen_mission_unchanged':True,
        'manifest_sha256':sha(mraw),'driver_sha256':review['driver_sha256'],
        'workflow_template_sha256':review['proposed_workflow_sha256'],
        'scope':'Separate readback by producing agent; not independent assurance or full-chain replay.',
        'new_theorem':'NOT_ESTABLISHED','hosted':'NOT_RUN','approval':'PENDING','end_to_end':False}
(OUT/'readback.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
