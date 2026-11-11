"""Independent binding of terminal provider evidence; no proof execution."""
from pathlib import Path
import hashlib, json

root=Path('/Users/mackianni/forge')
base=root/'proposals/refund-executable-feasibility'
out=Path(__file__).resolve().parent
sha=lambda b:hashlib.sha256(b).hexdigest()
read=lambda p:json.loads(p.read_text())
def api(name):
    response=read(out/('remote-'+name+'.json'))
    assert not response.get('isError'), name
    return json.loads(response['structuredContent']['content'])
run=api('run-final');runs=api('final-run-list');full=api('full-jobs')
assert run['id']==42661020831 and run['status']=='completed' and run['conclusion']=='failure'
assert run['run_attempt']==1 and run['head_sha']=='f1e4a080fd4c33aa1072c93fe4757e16805ab484'
assert run['path']=='.github/workflows/m1-macos-preflight.yml' and run['event']=='push'
assert runs['total_count']==len(runs['workflow_runs'])==1 and runs['workflow_runs'][0]['id']==run['id']
assert full['total_count']==len(full['jobs'])==1
job=full['jobs'][0]
assert job['id']==129312292711 and job['run_id']==run['id'] and job['head_sha']==run['head_sha']
assert job['run_attempt']==1 and job['status']=='completed' and job['conclusion']=='cancelled'
assert job['steps']==[] and job['runner_id']==0 and job['runner_name']==''
assert job['labels']==['macos-15']
summary=read(out/'remote-jobs-17.json')['structuredContent']['jobs']
assert len(summary)==1 and summary[0]['id']==job['id'] and summary[0]['conclusion']==job['conclusion']
timing=api('timing')
assert timing['run_duration_ms']==902000
assert timing['billable']['MACOS']=={'total_ms':0,'jobs':1,'job_runs':[{'job_id':job['id'],'duration_ms':0}]}
logs=read(out/'remote-logs.json')
assert logs['isError'] is True and '404' in logs['structuredContent']['error'] and 'BlobNotFound' in logs['structuredContent']['error']
artifacts=read(out/'remote-artifacts.json')
assert not artifacts.get('isError') and artifacts['structuredContent']['artifacts']==[]
workflow=read(out/'remote-workflow-readback.json')['structuredContent']
data=workflow['content'].encode()
assert data==(out/'workflow.yml').read_bytes()
assert data==(base/'hosted-integrity-run-20261109/records/proposed-proof-workflow.yml').read_bytes()
assert len(data)==16385 and sha(data)=='1af894a0f8f13b279c3c4752f77366c02c32075959041d08174c996c01b560a1'
assert hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()==workflow['sha']=='c6bdbde3f8612de474d1423216efce545c813f25'
commit=api('commit-readback')
assert commit['sha']==run['head_sha'] and [x['sha'] for x in commit['parents']]==['8ad9de1e538edd48a2084796510e784913eaef8b']
assert len(commit['files'])==1 and commit['files'][0]['filename']==run['path'] and commit['files'][0]['sha']==workflow['sha']
assert commit['commit']['tree']['sha']==read(out/'remote-created-tree.json')['structuredContent']['sha']
assert api('final-head')['object']['sha']==run['head_sha']
prior=[]
for name in ['integrity-preflight-20261108','integrity-preflight-20261109','hosted-integrity-run-20261109','integrity-confirmation-20261109','proof-approval-review-20261109']:
    packet=base/name;manifest=read(packet/'MANIFEST.json')
    for n,h in manifest['files'].items():assert sha((packet/n).read_bytes())==h,(name,n)
    prior.append({'packet':name,'members':len(manifest['files']),'manifest_sha256':sha((packet/'MANIFEST.json').read_bytes())})
baseline=read(base/'native-audit-20261104/records/baseline.json')
for n,h in baseline['protected'].items():assert sha((root/n).read_bytes())==h,n
assert sha((root/'FORGE_MISSION.md').read_bytes())==baseline['mission_sha256']
initial=read(out/'tracking-before.json')
for n,row in initial.items():
    b=(root/n).read_bytes();assert len(b)==row['bytes'] and sha(b)==row['sha256'],n
assert b'U338' not in (root/'unsure.md').read_bytes()
r={'status':'HOSTED_RUNNER_NOT_ASSIGNED','run_id':run['id'],'job_id':job['id'],
   'run_conclusion':run['conclusion'],'job_conclusion':job['conclusion'],'attempt':1,
   'workflow_commit':run['head_sha'],'workflow_sha256':sha(data),'runner_id':job['runner_id'],
   'steps':job['steps'],'logs':'UNAVAILABLE: 404 BlobNotFound','artifacts':[],
   'proof_actual_exit':None,'repeat_actual_exit':None,'import_actual_exit':None,
   'negative_control_actual_exits':None,'theorem_statement_output':None,'dependency_closure_output':None,
   'runner_image':'NOT_OBSERVED; required 20261104.0514.1 guard did not run',
   'timing':timing,'proof_cpu_seconds':None,'proof_peak_RSS':None,
   'resource_limit_execution':'NOT_OBSERVED: no runner or steps',
   'scheduler_cause':'UNKNOWN: metadata establishes absence of runner, not the underlying allocation cause',
   'prior_packets':prior,'protected_paths':len(baseline['protected']),'mission_matches':True,
   'HOL_executed':False,'new_payload_transfer':'NOT_RUN in this job; U335/U336 integrity retained',
   'retry_authorized':False,'end_to_end':False}
(out/'TERMINAL-READBACK.json').write_text(json.dumps(r,indent=2)+'\n')
print(json.dumps({k:r[k] for k in ['status','run_id','job_id','run_conclusion','job_conclusion','proof_actual_exit','HOL_executed','retry_authorized','end_to_end']}))
