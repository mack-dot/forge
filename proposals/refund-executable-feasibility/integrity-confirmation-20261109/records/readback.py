"""Independent evidence reader: no producer checker import and no proof execution."""
from pathlib import Path
from collections import Counter
import hashlib,json,re
root=Path('/Users/mackianni/forge');out=Path(__file__).resolve().parent
frozen=root/'proposals/refund-executable-feasibility/integrity-preflight-20261108/records'
sha=lambda b:hashlib.sha256(b).hexdigest()
log=(out/'hosted-job.log').read_bytes()
assert sha(log)=='b22630463ade3fc54f9481975f528de87ef283a94a05dd4dc496c062958b4187'
payloads=[]
for line in log.decode().splitlines():
 m=re.match(r'^\ufeff?\d{4}-\d\d-\d\dT\S+ (.*)$',line)
 if m:payloads.append(m.group(1))
events=[json.loads(line) for line in payloads if line.startswith('{')]
counts=Counter(e['operation'] for e in events)
expected_counts={'identity':1,'download':18,'commit_checked':2,'file_checked':10,
 'mutation_control':3,'member_checked':1493,'archive_checked':2,
 'statement_bytes_checked':1,'integrity_complete':1,'resource_usage':1}
assert dict(counts)==expected_counts,counts
assert all(e['end_to_end'] is False for e in events)
assert payloads.count('FORGE_INTEGRITY_EXIT=0')==1
assert not any(line.startswith('FORGE_INTEGRITY_EXIT=') and line!='FORGE_INTEGRITY_EXIT=0' for line in payloads)
by_kind=lambda kind:[e for e in events if e['operation']==kind]
identity=by_kind('identity')[0]
assert identity['run_id']=='42624212334' and identity['workflow_sha']=='fca212c45ccce9f27ffdf2d51ccf9ee96bce7162'
assert identity['os']=='Linux' and identity['image_os']=='ubuntu24' and identity['uid']!=0
assert identity['wall_seconds']==180 and identity['cpu_seconds']==90 and identity['address_space_bytes']==1073741824
expected_members={};expected_files=[];expected_downloads={};expected_commits=[];expected_archives=[]
pins=[('addon','21c4bdf958627e6a24e8dee9a45d90568b3e3c20','m1-hosted-cf-inputs',1475,932639,'6822e8da53f477f991bfa4a7cab02ffc59906a58460048a49af190fb42b2c105','947a3fa64f0ff0908989a01f1388f44f407e79642ea18d7462564e5e89f1babc'),
      ('base','ac05eaf972b8c98784466ae063fca505aaaf25f4','m1-hosted-sat-inputs',18,8435,'6822d1ae4ef5ca78ae14e352c5b1e222ed113bba1f3760d9b0141b70386c51a7','322245d0c39534c9be74f5dfa2ace4be2d856c1404ddc351f2087ab876d5e584')]
for name,commit,folder,count,size,manifest_sha,commit_sha256 in pins:
 raw=(frozen/('remote-'+name+'-manifest.json')).read_bytes()
 assert len(raw)==size and sha(raw)==manifest_sha
 manifest=json.loads(raw);assert len(manifest['files'])==count
 for f in manifest['files']:
  key=(name,f['path']);assert key not in expected_members;expected_members[key]=f['sha256']
 prefix='https://raw.githubusercontent.com/mack-dot/forge/'+commit+'/proposals/'+folder+'/'
 trees=[json.loads((frozen/('remote-'+name+'-tree-'+str(i)+'.json')).read_text()) for i in range(3)]
 entries={x['path']:x for x in trees[2]['tree']}
 files=[{'name':'INPUTS.json','bytes':size,'sha256':manifest_sha}]+manifest['parts']
 for f in files:
  expected_files.append((f['name'],f['bytes'],f['sha256'],entries[f['name']]['sha']))
  expected_downloads[prefix+f['name']]=(f['bytes'],f['sha256'])
 api='https://api.github.com/repos/mack-dot/forge/git/'
 expected_downloads[api+'commits/'+commit]=None
 for tree in trees:expected_downloads[api+'trees/'+tree['sha']]=None
 expected_commits.append((name,commit,commit_sha256,trees[0]['sha']))
 expected_archives.append((name,count,sum(f['bytes'] for f in manifest['files'])))
actual_members={}
for e in by_kind('member_checked'):
 key=(e['package'],e['path']);assert key not in actual_members;actual_members[key]=e['sha256']
assert actual_members==expected_members
assert len({path for package,path in actual_members})==1493
assert Counter((e['file'],e['bytes'],e['sha256'],e['git_blob']) for e in by_kind('file_checked'))==Counter(expected_files)
assert Counter((e['package'],e['commit'],e['raw_sha256'],e['tree']) for e in by_kind('commit_checked'))==Counter(expected_commits)
assert Counter((e['package'],e['members'],e['raw_file_bytes']) for e in by_kind('archive_checked'))==Counter(expected_archives)
downloads=by_kind('download');assert len({e['url'] for e in downloads})==18
assert set(e['url'] for e in downloads)==set(expected_downloads)
for e in downloads:
 expected=expected_downloads[e['url']]
 if expected is None:assert e['bytes']<=1048576 and re.fullmatch('[0-9a-f]{64}',e['sha256'])
 else:assert (e['bytes'],e['sha256'])==expected
payload_bytes=sum(e['bytes'] for e in downloads if e['url'].startswith('https://raw.githubusercontent.com/'))
assert payload_bytes==26196042
reasons={'changed-commit':'commit identity mismatch','changed-manifest':'size/SHA256 mismatch: INPUTS.json','changed-part':'size/SHA256 mismatch: inputs.part-000'}
controls=by_kind('mutation_control');assert {e['name'] for e in controls}==set(reasons)
for e in controls:
 assert e['rejected'] is True and e['exception']=='ValueError' and e['reason']==reasons[e['name']]
 assert e['process_exit']=='NOT_APPLICABLE: in-process control'
candidate=(root/'results/refund-read-event-gap-20261107/attempt-0001/generic-read-0001.sml').read_bytes()
assert sha(candidate)=='7e36c4867615e1d7fdce3d49143ced0788f0f28517df49a1f611ef95a684ffc6'
term=candidate.split(b'store_thm ("read_error_generic", ``',1)[1].split(b'``,',1)[0]
statement=by_kind('statement_bytes_checked')[0]
assert statement['candidate_sha256']==sha(candidate) and statement['quotation_sha256']==sha(term) and statement['quotation_bytes']==len(term)
assert statement['proof_result']=='NOT_RUN'
complete=by_kind('integrity_complete')[0]
assert complete['files']==1493 and complete['addon_files']==1475 and complete['base_files']==18
assert complete['proof_executed'] is False and complete['transferred_code_executed'] is False
resources=by_kind('resource_usage')[0];assert resources['intended_exit']==0 and resources['wall_seconds']<180
def api_record(name):
 d=json.loads((out/name).read_text());assert not d.get('isError');return json.loads(d['structuredContent']['content'])
run=api_record('run-detail-01.json');runs=api_record('final-run-list.json')
assert run['id']==42624212334 and run['head_sha']==identity['workflow_sha'] and run['run_attempt']==1
assert run['status']=='completed' and run['conclusion']=='success' and run['path']=='.github/workflows/m1-input-integrity.yml'
assert runs['total_count']==1 and len(runs['workflow_runs'])==1 and runs['workflow_runs'][0]['id']==run['id']
jobs=json.loads((out/'run-jobs-01.json').read_text())['structuredContent']['jobs']
assert len(jobs)==1 and jobs[0]['id']==129183679727 and jobs[0]['conclusion']=='success'
assert len(jobs[0]['steps'])==3 and all(s['conclusion']=='success' for s in jobs[0]['steps'])
usage=api_record('run-timing.json')
assert usage['billable']['UBUNTU']['jobs']==1
r={'actual_exit':0,'status':'TRANSFER_INTEGRITY_ESTABLISHED','scope':'Exact frozen transferred bytes; TESTED, not a formal theorem or independent administrative assurance',
 'run_id':run['id'],'job_id':jobs[0]['id'],'workflow_commit':identity['workflow_sha'],
 'workflow_sha256':'b8c96c19049e04aedc5b2902b9342ec26db4234690d2c5cce589bbd1730016e9',
 'log_sha256':sha(log),'actual_checker_exit':0,'event_counts':dict(counts),
 'payload_bytes':payload_bytes,'metadata_bytes':sum(e['bytes'] for e in downloads if e['url'].startswith('https://api.github.com/')),
 'source_commits':[p[1] for p in pins],'members_checked':1493,'mutation_controls_rejected':3,
 'candidate_sha256':sha(candidate),'quotation_sha256':sha(term),'quotation_bytes':len(term),
 'environment':identity,'resource_usage':resources,'provider_usage':usage,
 'proof_executed':False,'end_to_end':False}
(out/'INDEPENDENT-READBACK.json').write_text(json.dumps(r,indent=2)+'\n')
print(json.dumps({k:r[k] for k in ['actual_exit','status','actual_checker_exit','members_checked','mutation_controls_rejected','payload_bytes','metadata_bytes','quotation_sha256','proof_executed','end_to_end']}))
