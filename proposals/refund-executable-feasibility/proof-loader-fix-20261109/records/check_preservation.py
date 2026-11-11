from pathlib import Path
import ast,hashlib,json
root=Path('/Users/mackianni/forge');out=Path(__file__).resolve().parent
base=root/'proposals/refund-executable-feasibility'
sha=lambda b:hashlib.sha256(b).hexdigest()
read=lambda p:json.loads(p.read_text())
original=base/'hosted-integrity-run-20261109/records'
source=(out/'driver.py').read_text();old=(original/'proposed-proof-driver.py').read_text()
changes=read(out/'PREPARATION.json')['changes']
for before,after in changes:
 assert source.count(after)==1;source=source.replace(after,before,1)
assert source==old
assert sha((out/'driver.py').read_bytes())==read(out/'PREPARATION.json')['driver_sha256']
assert sha((out/'workflow.yml').read_bytes())==read(out/'PREPARATION.json')['workflow_sha256']
for n in ['driver.py','prepare_fix.py','test_loader.py']:ast.parse((out/n).read_text())
manifest=read(base/'integrity-preflight-20261108/records/remote-addon-manifest.json')
special=[f for f in manifest['files'] if f['path'].endswith('/generic-read-0001.sml') or 'prepared-inputs/' in f['path']]
for f in special:
 b=(root/f['path']).read_bytes();assert len(b)==f['bytes'] and sha(b)==f['sha256']
baseline=read(base/'native-audit-20261104/records/baseline.json')
for n,h in baseline['protected'].items():assert sha((root/n).read_bytes())==h,n
assert sha((root/'FORGE_MISSION.md').read_bytes())==baseline['mission_sha256']
before=read(out/'tracking-before.json')
for n,r in before.items():
 b=(root/n).read_bytes();assert len(b)==r['bytes'] and sha(b)==r['sha256']
reg=read(out/'REGRESSION.json')
assert [r['actual_exit'] for r in reg['results']]==[1,0] and reg['old_path_reproduces_exact_ENOENT'] is True
for r in reg['results']:
 mode=r['mode'];case=out/('loader-v2-'+mode)
 assert sha((case/'stdout.log').read_bytes())==r['stdout_sha256']
 assert sha((case/'stderr.log').read_bytes())==r['stderr_sha256']
r={'actual_exit':0,'driver_change_expressions':2,'all_other_driver_bytes_unchanged':True,
 'frozen_candidate_and_controls_match':len(special),'protected_paths':len(baseline['protected']),
 'mission_matches':True,'regression_exits':[1,0],'no_theorem_execution':True,'no_hosted_execution':True,'end_to_end':False}
(out/'PRESERVATION.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r))
