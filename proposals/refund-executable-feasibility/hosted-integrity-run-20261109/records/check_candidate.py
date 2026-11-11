from pathlib import Path
import contextlib,hashlib,importlib.util,json
root=Path('/Users/mackianni/forge');out=Path(__file__).resolve().parent
old=root/'proposals/refund-executable-feasibility/integrity-preflight-20261108/records'
spec=importlib.util.spec_from_file_location('candidate_integrity',out/'integrity_driver.py')
d=importlib.util.module_from_spec(spec);spec.loader.exec_module(d)
fixtures={}
for c in d.CONFIGS:
 api='https://api.github.com/repos/mack-dot/forge/git/'
 fixtures[api+'commits/'+c['commit']]=(old/('remote-'+c['name']+'-commit.json')).read_bytes()
 for level in range(3):
  b=(old/('remote-'+c['name']+'-tree-'+str(level)+'.json')).read_bytes()
  fixtures[api+'trees/'+json.loads(b)['sha']]=b
 prefix='https://raw.githubusercontent.com/mack-dot/forge/'+c['commit']+'/proposals/'+c['folder']+'/'
 b=(old/('remote-'+c['name']+'-manifest.json')).read_bytes();fixtures[prefix+'INPUTS.json']=b
 folder=root/('proposals/refund-executable-feasibility/hosted-cf-candidate-20261107/payload' if c['name']=='addon' else 'results/hosted-macos-preflight-20261106/attempt-0001')
 for part in json.loads(b)['parts']:fixtures[prefix+part['name']]=(folder/part['name']).read_bytes()
def fetch(url,limit):
 b=fixtures[url];assert len(b)<=limit;return b
work=out/'local-candidate-check';work.mkdir(exist_ok=False)
with (out/'candidate-check.stdout.log').open('x') as log:
 with contextlib.redirect_stdout(log):d.run_integrity(fetch,work)
events=[json.loads(s) for s in (out/'candidate-check.stdout.log').read_text().splitlines()]
assert len([e for e in events if e['operation']=='member_checked'])==1493
controls=[e for e in events if e['operation']=='mutation_control']
assert [e['name'] for e in controls]==['changed-commit','changed-manifest','changed-part']
assert all(e['rejected'] is True and e['exception']=='ValueError' for e in controls)
assert events[-1]['operation']=='integrity_complete'
triggers=json.loads((out/'TRIGGER-READBACK.json').read_text())
assert len(triggers)==13
for e in triggers:
 assert not e.get('missing')
 assert 'workflow_run' not in e['on']
 if 'push' in e['on']:
  assert set(e['on']['push']['branches'])<= {'main','proposal/m1-macos-preflight-20261106'}
r={'actual_exit':0,'local_fixture_members':1493,'mutation_controls':controls,
 'existing_workflow_triggers_checked':13,'network_used':False,
 'remote_transfer_integrity':'NOT_ESTABLISHED','end_to_end':False}
(out/'CANDIDATE-CHECK.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r))
