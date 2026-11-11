"""Bind downloaded logs, stream artifacts and provider records; no HOL invocation."""
from pathlib import Path
from collections import Counter
from datetime import datetime
import hashlib,json,re

root=Path('/Users/mackianni/forge');out=Path(__file__).resolve().parent
base=root/'proposals/refund-executable-feasibility'
sha=lambda b:hashlib.sha256(b).hexdigest()
read=lambda p:json.loads(p.read_text())
write=lambda p,v:p.write_text(json.dumps(v,indent=2)+'\n')
def api(name):
 r=read(out/('remote-'+name+'.json'));assert not r.get('isError'),name
 return json.loads(r['structuredContent']['content'])
log=(out/'hosted-job.log').read_bytes()
assert len(log)==67204 and sha(log)=='7fea30873cceeb1b199bfa468ccb4dde56ad2a4f884b95ef902241185c7d7cca'
rows=read(out/'events.json');events=[x['record'] for x in rows]
by=lambda name:[e for e in events if e['operation']==name]
expected_counts={'identity':1,'command':4,'resources':1,'mkstemp':1,'read_write':1,'negative_permission':1,'memory_probe':1,'private_root':1,'download':10,'inputs_before':1,'invocation':1,'file':3,'file_chunk':3,'child_result':1,'inputs_after_proof':1,'runtime_path_gate':1,'case_gate':1,'run_complete':1}
assert dict(Counter(e['operation'] for e in events))==expected_counts
assert all(e['end_to_end'] is False for e in events)
identity=by('identity')[0]
assert identity['system']=='Darwin' and identity['architecture']=='arm64' and identity['uid']==501
assert identity['image_version']=='20261104.0514.1' and identity['image_os']=='macos15'
assert identity['run_id']=='42661020831'
assert identity['source_sha']==identity['workflow_sha']=='f1e4a080fd4c33aa1072c93fe4757e16805ab484'
wf=read(out/'remote-workflow.json')['structuredContent']['content'].encode()
assert sha(wf)=='1af894a0f8f13b279c3c4752f77366c02c32075959041d08174c996c01b560a1'
manifests=[];downloads=[];member_map={}
for kind,digest in [('base','6822d1ae4ef5ca78ae14e352c5b1e222ed113bba1f3760d9b0141b70386c51a7'),('addon','6822e8da53f477f991bfa4a7cab02ffc59906a58460048a49af190fb42b2c105')]:
 raw=(base/'integrity-preflight-20261108/records'/('remote-'+kind+'-manifest.json')).read_bytes()
 assert sha(raw)==digest
 m=json.loads(raw);manifests.append(m)
 downloads.append(('INPUTS.json',len(raw),sha(raw)))
 downloads.extend((p['name'],p['bytes'],p['sha256']) for p in m['parts'])
 for f in m['files']:
  assert f['path'] not in member_map;member_map[f['path']]=f
assert [(e['file'],e['bytes'],e['sha256']) for e in by('download')]==downloads
assert sum(x[1] for x in downloads)==26196042 and len(member_map)==1493
for name in ['inputs_before','inputs_after_proof']:
 e=by(name)[0];assert e['files']==1493 and e['all_match'] is True
assert all(e['actual_exit']==0 for e in by('command'))
assert by('mkstemp')[0]['return_value']>=0 and by('mkstemp')[0]['errno']==0
assert by('read_write')[0]['equal'] is True
assert by('negative_permission')[0]['errno']==13
assert by('memory_probe')[0]['touched_bytes']==67108864
private=by('private_root')[0];assert private['mode']=='0700' and private['uid']==501
remote_root=private['path'];tc=remote_root+'/.toolchain/experiments/refund-cakeml-20261104'
inv=by('invocation')[0]
assert inv['case']=='proof' and inv['argv']==[tc+'/HOL/bin/hol','--maxheap','1536','run','--poly',remote_root+'/outputs/proof/bootstrap.sml']
assert inv['cwd']==tc+'/cakeml/basis'
assert (inv['cpu_seconds'],inv['wall_seconds'],inv['maxheap_MiB'],inv['stream_file_limit_bytes'])==(120,150,1536,4194304)
child=by('child_result')[0]
assert child['case']=='proof' and child['actual_exit']==1 and child['wall_timeout'] is False and child['objects']=={}
assert by('case_gate')[0]['expected_observation_met'] is False
assert by('runtime_path_gate')[0]['private_libraries_match'] is True
assert by('run_complete')[0]['failed_case']=='proof'
assert by('run_complete')[0]['full_chain_replay']=='NOT_RUN'
assert log.count(b'##[error]Process completed with exit code 1.')==1
for e in by('file'):
 b=(out/'decoded'/e['case']/e['file']).read_bytes()
 assert len(b)==e['bytes'] and sha(b)==e['sha256']
assert set(e['file'] for e in by('file'))=={'bootstrap.sml','stdout.log','stderr.log'}
boot=(out/'decoded/proof/bootstrap.sml').read_text()
stdout=(out/'decoded/proof/stdout.log').read_text()
stderr=(out/'decoded/proof/stderr.log').read_text()
parent='results/refund-native-audit-2026-11-04/attempt-0010/model-0007'
single=parent+'/.hol/objs/forge_refundReadBoundaryTheory.sig'
double=parent+'/.hol/objs/.hol/objs/forge_refundReadBoundaryTheory.sig'
assert single in member_map and double not in member_map
assert 'QUse.use '+json.dumps(remote_root+'/'+single)+';' in boot
assert remote_root+'/'+double in stderr and 'SOME ENOENT' in stderr
assert 'PHASE basis-theory-load' in stdout and stdout.count('LOADED_STATE ')==4
assert 'PHASE cf-library-load' not in stdout and 'PHASE unchanged-source' not in stdout
assert 'READ_EVENT_GAP_COMPLETE' not in stdout and 'CHECKED read_error_generic' not in stdout
candidate=root/'results/refund-read-event-gap-20261107/attempt-0001/generic-read-0001.sml'
b=candidate.read_bytes();assert sha(b)=='7e36c4867615e1d7fdce3d49143ced0788f0f28517df49a1f611ef95a684ffc6'
term=b.split(b'store_thm ("read_error_generic", ``',1)[1].split(b'``,',1)[0]
assert sha(term)=='289b8be8c848dc3debddbac5184e613e2c1e127c56dddd574e5b43087cc8c29a'
(out/'FROZEN-UNEXECUTED-STATEMENT.txt').write_bytes(term)
run=api('run-final');jobs=api('jobs-07')
assert run['run_attempt']==2 and run['status']=='completed' and run['conclusion']=='failure'
assert run['head_sha']==identity['source_sha'] and run['id']==42661020831
assert jobs['total_count']==len(jobs['jobs'])==1
job=jobs['jobs'][0]
assert job['id']==129430257438 and job['run_attempt']==2 and job['conclusion']=='failure'
assert job['runner_id']==1000000100 and job['labels']==['macos-15']
assert [s['conclusion'] for s in job['steps']]==['success','failure','success']
assert read(out/'remote-final-summary.json')['structuredContent']['jobs'][0]['id']==job['id']
assert read(out/'remote-trigger.json')['structuredContent']['success'] is True
timing=api('timing')
assert timing['billable']['MACOS']['jobs']==2
assert [r['job_id'] for r in timing['billable']['MACOS']['job_runs']]==[129312292711,129430257438]
assert all(r['duration_ms']==0 for r in timing['billable']['MACOS']['job_runs'])
parse=lambda t:datetime.fromisoformat(re.sub(r'(\.\d{6})\d+(?=Z$)',r'\1',t).replace('Z','+00:00'))
step=job['steps'][1];step_seconds=(parse(step['completed_at'])-parse(step['started_at'])).total_seconds()
times={e['record']['operation']:e['provider_log_time'] for e in rows if e['record']['operation'] in ['invocation','child_result']}
interval=(parse(times['child_result'])-parse(times['invocation'])).total_seconds()
result={'status':'HOL_PARENT_LOAD_ENOENT','actual_validation_exit':0,'run_id':run['id'],'job_id':job['id'],'attempt':2,
 'HOL_process_exit':1,'workflow_step_exit':1,'wall_timeout':False,'candidate_theorem_reached':False,
 'conditional_cases':'NOT_RUN','theorem_exports':{},'new_dependency_closure':'NOT_PRODUCED',
 'workflow_sha256':sha(wf),'log_sha256':sha(log),'statement_sha256':sha(term),
 'environment':identity,'resources':by('resources')[0],'provider_timing':timing,
 'step_seconds':step_seconds,'invocation_to_result_log_interval_seconds':interval,
 'actual_child_cpu_seconds':None,'actual_peak_RSS':None,
 'download_bytes':26196042,'inputs_before_and_after':1493,
 'missing_path':remote_root+'/'+double,'packaged_parent':member_map[single],
 'retry_calls':1,'additional_attempt_authorized':False,'end_to_end':False}
write(out/'INDEPENDENT-READBACK.json',result)
print(json.dumps({k:result[k] for k in ['status','actual_validation_exit','HOL_process_exit','workflow_step_exit','candidate_theorem_reached','conditional_cases','download_bytes','step_seconds','invocation_to_result_log_interval_seconds','end_to_end']}))
