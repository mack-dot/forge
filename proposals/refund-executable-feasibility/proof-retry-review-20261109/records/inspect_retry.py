"""Scheduling metadata review and retry request preparation; no external writes."""
from pathlib import Path
import hashlib,json,yaml

root=Path('/Users/mackianni/forge')
base=root/'proposals/refund-executable-feasibility'
out=Path(__file__).resolve().parent
sha=lambda b:hashlib.sha256(b).hexdigest()
read=lambda p:json.loads(p.read_text())
write=lambda p,v:p.write_text(json.dumps(v,indent=2)+'\n')
def api(name):
    r=read(out/('remote-'+name+'.json'));assert not r.get('isError'),name
    return json.loads(r['structuredContent']['content'])
run=api('run');jobs=api('jobs');repo=api('repository')
assert run['id']==42661020831 and run['run_attempt']==1
assert run['head_sha']=='f1e4a080fd4c33aa1072c93fe4757e16805ab484' and run['conclusion']=='failure'
assert jobs['total_count']==len(jobs['jobs'])==1
job=jobs['jobs'][0]
assert job['id']==129312292711 and job['conclusion']=='cancelled'
assert job['runner_id']==0 and job['runner_name']=='' and job['steps']==[] and job['labels']==['macos-15']
assert repo['full_name']=='mack-dot/forge' and not repo['private'] and not repo['archived'] and not repo['disabled']
for n in ['queued','in-progress']:
    d=api(n);assert d['total_count']==0 and d['workflow_runs']==[]
assert api('pending-deployments')==[]
remote=read(out/'remote-frozen-workflow.json');assert not remote.get('isError')
content=remote['structuredContent']['content'].encode()
assert content==(base/'hosted-proof-run-20261109/records/workflow.yml').read_bytes()
assert sha(content)=='1af894a0f8f13b279c3c4752f77366c02c32075959041d08174c996c01b560a1'
assert remote['structuredContent']['sha']=='c6bdbde3f8612de474d1423216efce545c813f25'
w=yaml.load(content,Loader=yaml.BaseLoader)
assert w['concurrency']=={'group':'forge-m1-macos-environment-preflight','cancel-in-progress':'false'}
assert w['permissions']=={} and len(w['jobs'])==1
j=next(iter(w['jobs'].values()))
assert j['runs-on']=='macos-15' and j['timeout-minutes']=='15'
assert j['if']=="github.repository == 'mack-dot/forge' && github.event.repository.private == false"
assert 'environment' not in j and 'needs' not in j
assert len(j['steps'])==1 and j['steps'][0]['shell']=='bash --noprofile --norc -euo pipefail {0}'
candidate=root/'results/refund-read-event-gap-20261107/attempt-0001/generic-read-0001.sml'
assert sha(candidate.read_bytes())=='7e36c4867615e1d7fdce3d49143ced0788f0f28517df49a1f611ef95a684ffc6'
request={'tool':'mcp__codex_apps__github_rerun_workflow_job',
         'arguments':{'repo_full_name':'mack-dot/forge','job_id':129312292711},
         'authorization':'NOT_GRANTED','maximum_calls':1,'debug_logging':False,
         'workflow_commit':run['head_sha'],'workflow_sha256':sha(content),
         'expected_current_attempt':1,'expected_next_attempt':2,
         'job_timeout_minutes':15,'automatic_further_retry':False,'end_to_end':False}
write(out/'PROPOSED-REQUEST.json',request)
result={'actual_exit':0,'run_id':run['id'],'job_id':job['id'],'current_attempt':1,
        'workflow_sha256':sha(content),'candidate_sha256':sha(candidate.read_bytes()),
        'concurrency':w['concurrency'],'runner_labels':job['labels'],'job_if':j['if'],
        'permissions':w['permissions'],'declared_environment':None,'dependent_jobs':0,
        'repository_public_active':True,'queued_runs_now':0,'in_progress_runs_now':0,'pending_deployments_now':[],
        'precise_cancellation_cause':'UNKNOWN','historical_concurrency_contention':'NOT_ESTABLISHED',
        'workflow_enabled_and_account_actions_restrictions':'NOT_OBSERVED: connector endpoint not supported',
        'log_404_is_causal_evidence':False,'proof_status':'UNESTABLISHED, not disproved',
        'HOL_executed':False,'retry_dispatched':False,'end_to_end':False}
write(out/'INSPECTION.json',result)
write(out/'tracking-before.json',{n:{'bytes':len((root/n).read_bytes()),'sha256':sha((root/n).read_bytes())} for n in ['ROADMAP.md','FORGE_MISSION_STATUS.md','unsure.md']})
assert b'U339' not in (root/'unsure.md').read_bytes()
print(json.dumps(result))
