"""Local byte transport and term parsing only. Never loads cfLib or proves the candidate."""
from pathlib import Path
import contextlib,hashlib,importlib.util,json,os
OUT=Path(__file__).resolve().parent
ROOT=Path('/Users/mackianni/forge')
sha=lambda b:hashlib.sha256(b).hexdigest()
spec=importlib.util.spec_from_file_location('prepared_driver',OUT/'hosted-driver.py')
driver=importlib.util.module_from_spec(spec);spec.loader.exec_module(driver)
base=json.loads((ROOT/'proposals/refund-executable-feasibility/hosted-macos-nosudo-20261107/INPUTS.json').read_text())
addon=json.loads((OUT/'upload/INPUTS.json').read_text())
stage=OUT/'local-private-inputs';stage.mkdir(mode=0o700,exist_ok=False)
for r in base['files']:
    b=Path(r['source']).read_bytes();assert len(b)==r['bytes'] and sha(b)==r['sha256']
    p=stage/r['path'];p.parent.mkdir(parents=True,exist_ok=True,mode=0o700)
    with p.open('xb') as f:f.write(b)
    p.chmod(r['mode'])
parts=[]
for r in addon['parts']:
    b=(OUT/'upload'/r['name']).read_bytes();assert len(b)==r['bytes'] and sha(b)==r['sha256'];parts.append(b)
driver.unpack(stage,addon,b''.join(parts))
expected=base['files']+addon['files']
assert len({x['path'] for x in expected})==len(expected)
def verify():
    for r in expected:
        p=stage/r['path'];assert p.stat().st_size==r['bytes'] and sha(p.read_bytes())==r['sha256']
verify()
assert 'load "cfLib"' not in driver.bootstrap(stage,'inspect')
with (OUT/'local-inspection.jsonl').open('x') as f,contextlib.redirect_stdout(f):
    result=driver.run_case(stage,'inspect')
verify()
code,objects,stdout,stderr=result
record={'actual_exit':code,'input_files':len(expected),'all_before_after_hashes_match':True,
        'candidate_sha256':sha((stage/driver.CANDIDATE).read_bytes()),
        'term_parsed':'CANDIDATE_TERM_PARSED' in stdout,
        'no_theorem_attempted':'NO_THEOREM_ATTEMPTED' in stdout,
        'relocation_complete':'RELOCATION_INSPECTION_COMPLETE' in stdout,
        'objects':objects,'cf_library_loaded':False,'hosted':False,'end_to_end':False}
(OUT/'LOCAL-INSPECTION.json').write_text(json.dumps(record,indent=2)+'\n')
print(json.dumps(record,indent=2))
raise SystemExit(0 if code==0 and record['term_parsed'] and record['no_theorem_attempted'] and record['relocation_complete'] and not objects else 1)
