from pathlib import Path
import hashlib,json,yaml
root=Path('/Users/mackianni/forge');out=Path(__file__).resolve().parent
base=root/'proposals/refund-executable-feasibility';old=base/'hosted-integrity-run-20261109/records'
sha=lambda b:hashlib.sha256(b).hexdigest()
read=lambda p:json.loads(p.read_text())
write=lambda p,v:p.write_text(json.dumps(v,indent=2)+'\n')
def api(name):
 r=read(out/('remote-'+name+'.json'));assert not r.get('isError');return json.loads(r['structuredContent']['content'])
r=api('run-before');j=api('jobs-before')
assert r['id']==42661020831 and r['run_attempt']==1 and r['status']=='completed' and r['conclusion']=='failure'
assert r['head_sha']=='f1e4a080fd4c33aa1072c93fe4757e16805ab484'
assert j['total_count']==len(j['jobs'])==1 and j['jobs'][0]['id']==129312292711
assert j['jobs'][0]['conclusion']=='cancelled' and j['jobs'][0]['run_attempt']==1
for name in ['queued-before','running-before']:
 d=api(name);assert d['total_count']==0 and d['workflow_runs']==[]
response=read(out/'remote-workflow.json');assert not response.get('isError')
b=response['structuredContent']['content'].encode()
assert b==(old/'proposed-proof-workflow.yml').read_bytes()
assert len(b)==16385 and sha(b)=='1af894a0f8f13b279c3c4752f77366c02c32075959041d08174c996c01b560a1'
assert response['structuredContent']['sha']=='c6bdbde3f8612de474d1423216efce545c813f25'
driver=(old/'proposed-proof-driver.py').read_bytes()
assert sha(driver)=='2667f6d8f81e4286c04a80bf3e856b66c74ce15141d5e80c18e1fb4662d45fd8'
w=yaml.load(b,Loader=yaml.BaseLoader);assert len(w['jobs'])==1 and w['permissions']=={}
job=next(iter(w['jobs'].values()));assert job['timeout-minutes']=='15' and job['runs-on']=='macos-15'
assert 'needs' not in job and len(job['steps'])==1
step=job['steps'][0];assert step['shell']=='bash --noprofile --norc -euo pipefail {0}'
assert step['run'].split("<<'PY'\n",1)[1].rsplit('\nPY\n',1)[0].encode()+b'\n'==driver
assert b"os.environ.get('ImageVersion')=='20261104.0514.1'" in driver
assert b"platform.machine()=='arm64'" in driver
manifest_hashes={}
for name,h in [('addon','6822e8da53f477f991bfa4a7cab02ffc59906a58460048a49af190fb42b2c105'),('base','6822d1ae4ef5ca78ae14e352c5b1e222ed113bba1f3760d9b0141b70386c51a7')]:
 raw=(base/'integrity-preflight-20261108/records'/('remote-'+name+'-manifest.json')).read_bytes()
 assert sha(raw)==h;manifest_hashes[name]=h
candidate=root/'results/refund-read-event-gap-20261107/attempt-0001/generic-read-0001.sml'
assert sha(candidate.read_bytes())=='7e36c4867615e1d7fdce3d49143ced0788f0f28517df49a1f611ef95a684ffc6'
approval=base/'proof-retry-review-20261109/APPROVAL.md'
assert sha(approval.read_bytes())==read(approval.parent/'MANIFEST.json')['files']['APPROVAL.md']
assert b'U340' not in (root/'unsure.md').read_bytes()
write(out/'tracking-before.json',{n:{'bytes':len((root/n).read_bytes()),'sha256':sha((root/n).read_bytes())} for n in ['ROADMAP.md','FORGE_MISSION_STATUS.md','unsure.md']})
result={'actual_exit':0,'run_id':42661020831,'current_attempt':1,'retry_target_job':129312292711,
 'workflow_commit':r['head_sha'],'workflow_sha256':sha(b),'driver_sha256':sha(driver),
 'approval_sha256':sha(approval.read_bytes()),'manifest_hashes':manifest_hashes,'candidate_sha256':sha(candidate.read_bytes()),
 'job_count':1,'timeout_minutes':15,'permissions':{},'required_image':'20261104.0514.1',
 'authorization':'Owner confirms the single frozen retry from U339; exactly one call, no additional attempt.',
 'retry_calls_so_far':0,'HOL_executed':False,'end_to_end':False}
write(out/'PREFLIGHT.json',result)
print(json.dumps(result))
