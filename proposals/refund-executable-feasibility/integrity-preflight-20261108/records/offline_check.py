"""Checks the new byte verifier on frozen local bytes and captured API responses.
This fixture adapter never represents local fixture bytes as remote readback.
"""
from pathlib import Path
import contextlib,hashlib,importlib.util,json,subprocess,sys
OUT=Path(__file__).resolve().parent;ROOT=Path('/Users/mackianni/forge')
spec=importlib.util.spec_from_file_location('integrity_driver',OUT/'integrity_driver.py')
driver=importlib.util.module_from_spec(spec);spec.loader.exec_module(driver)
mode=sys.argv[1] if len(sys.argv)>1 else 'parent'
sha=lambda b:hashlib.sha256(b).hexdigest()
if mode!='parent':
    work=OUT/'offline'/mode;work.mkdir(parents=True,exist_ok=False)
    fixtures={}
    for c in driver.CONFIGS:
        api='https://api.github.com/repos/mack-dot/forge/git/'
        raw=(OUT/('remote-'+c['name']+'-commit.json')).read_bytes()
        if mode=='changed-commit' and c['name']=='addon':
            d=json.loads(raw);d['message']+=' changed';raw=json.dumps(d).encode()
        fixtures[api+'commits/'+c['commit']]=raw
        for level in range(3):
            raw=(OUT/('remote-'+c['name']+'-tree-'+str(level)+'.json')).read_bytes();d=json.loads(raw)
            fixtures[api+'trees/'+d['sha']]=raw
        prefix='https://raw.githubusercontent.com/mack-dot/forge/'+c['commit']+'/proposals/'+c['folder']+'/'
        raw=(OUT/('remote-'+c['name']+'-manifest.json')).read_bytes()
        if mode=='changed-manifest' and c['name']=='addon':raw=raw.replace(b'"mode": 256',b'"mode": 257',1)
        fixtures[prefix+'INPUTS.json']=raw;m=json.loads(raw)
        folder=ROOT/('proposals/refund-executable-feasibility/hosted-cf-candidate-20261107/payload' if c['name']=='addon' else 'results/hosted-macos-preflight-20261106/attempt-0001')
        for part in m['parts']:
            raw=(folder/part['name']).read_bytes()
            if mode=='changed-part' and c['name']=='addon' and part==m['parts'][0]:raw=bytes([raw[0]^1])+raw[1:]
            fixtures[prefix+part['name']]=raw
    def fetch(url,limit):
        b=fixtures[url];driver.require(len(b)<=limit,'fixture too large');return b
    driver.run_integrity(fetch,work)
    print('OFFLINE_FIXTURE_CHECK_COMPLETE; REMOTE_BINARY_READBACK_NOT_ESTABLISHED')
    raise SystemExit(0)
results=[]
for mode in ['positive','changed-commit','changed-manifest','changed-part']:
    case=OUT/'checks'/mode;case.mkdir(parents=True,exist_ok=False)
    argv=[sys.executable,'-B',str(Path(__file__).resolve()),mode]
    with (case/'stdout.log').open('xb') as stdout,(case/'stderr.log').open('xb') as stderr:
        process=subprocess.run(argv,stdout=stdout,stderr=stderr,timeout=60)
    expected=0 if mode=='positive' else 1
    rec={'case':mode,'argv':argv,'actual_exit':process.returncode,'expected_exit':expected}
    for name in ['stdout','stderr']:
        b=(case/(name+'.log')).read_bytes();rec[name+'_bytes']=len(b);rec[name+'_sha256']=sha(b)
    (case/'command.json').write_text(json.dumps(rec,indent=2)+'\n');results.append(rec)
    if process.returncode!=expected:
        (OUT/'OFFLINE-FAILURE.json').write_text(json.dumps(results,indent=2)+'\n')
        print(json.dumps(rec,indent=2));raise SystemExit(1)
events=[json.loads(line) for line in (OUT/'checks/positive/stdout.log').read_text().splitlines() if line.startswith('{')]
assert sum(x['operation']=='member_checked' for x in events)==1493
assert sum(x['operation']=='file_checked' for x in events)==10
assert sum(x['operation']=='commit_checked' for x in events)==2
assert any(x['operation']=='statement_bytes_checked' for x in events)
for case,marker in [('changed-commit','commit identity mismatch'),('changed-manifest','size/SHA256 mismatch: INPUTS.json'),('changed-part','size/SHA256 mismatch: inputs.part-000')]:
    assert marker in (OUT/'checks'/case/'stderr.log').read_text()
result={'actual_exit':0,'cases':results,'checked_local_members':1493,'api_commit_identities_recomputed':2,
        'source_premises_byte_identical':True,'remote_manifests_match':True,'remote_binary_readback':'NOT_ESTABLISHED',
        'hosted_job':'NOT_RUN','proof':'NOT_RUN','end_to_end':False}
(OUT/'OFFLINE-CHECK.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({k:v for k,v in result.items() if k!='cases'},indent=2))
