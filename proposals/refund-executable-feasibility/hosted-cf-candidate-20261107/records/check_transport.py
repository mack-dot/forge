from pathlib import Path
import ast,base64,hashlib,importlib.util,json,subprocess,sys,zlib
OUT=Path(__file__).resolve().parent
sha=lambda b:hashlib.sha256(b).hexdigest()
spec=importlib.util.spec_from_file_location('prepared_driver',OUT/'hosted-driver.py')
d=importlib.util.module_from_spec(spec);spec.loader.exec_module(d)
oldspec=importlib.util.spec_from_file_location('previous_driver',OUT/'hosted-driver-v0.py')
old=importlib.util.module_from_spec(oldspec);oldspec.loader.exec_module(old)
stage=OUT/'local-private-inputs'
assert d.bootstrap(stage,'inspect')==old.bootstrap(stage,'inspect')
ast.parse((OUT/'hosted-driver.py').read_text())
events=[json.loads(x) for x in (OUT/'local-inspection.jsonl').read_text().splitlines()]
files=[]
for rec in [x for x in events if x['operation']=='file']:
    chunks=[x for x in events if x['operation']=='file_chunk' and x['case']==rec['case'] and x['file']==rec['file']]
    assert len(chunks)==rec['chunks'] and sorted(x['index'] for x in chunks)==list(range(len(chunks)))
    b=zlib.decompress(base64.b64decode(''.join(x['data'] for x in sorted(chunks,key=lambda x:x['index'])),validate=True))
    assert len(b)==rec['bytes'] and sha(b)==rec['sha256']
    assert b==(stage/'outputs'/rec['case']/rec['file']).read_bytes()
    files.append({'path':rec['file'],'bytes':len(b),'sha256':sha(b)})
controls=[]
for mode in ['wrong-hash','path-traversal','symlink']:
    argv=[sys.executable,'-B',str(OUT/'transport_probe.py'),mode]
    p=subprocess.run(argv,capture_output=True)
    for name,b in [('stdout.log',p.stdout),('stderr.log',p.stderr)]:
        (OUT/'transport-controls'/mode/name).write_bytes(b)
    record={'case':mode,'argv':argv,'actual_exit':p.returncode,
            'stdout_sha256':sha(p.stdout),'stderr_sha256':sha(p.stderr),'assertion_refusal':b'AssertionError' in p.stderr}
    (OUT/'transport-controls'/mode/'command.json').write_text(json.dumps(record,indent=2)+'\n')
    controls.append(record)
    assert p.returncode==1 and record['assertion_refusal']
    assert not (OUT/'transport-controls/escape').exists()
summary={'actual_exit':0,'roundtrip_files':files,'controls':controls,
         'inspected_bootstrap_unchanged':True,'process_wall_limit_change_executed':False,
         'proof_claim':False,'hosted_run':'NOT_RUN','end_to_end':False}
(OUT/'TRANSPORT-CHECK.json').write_text(json.dumps(summary,indent=2)+'\n')
print(json.dumps({'actual_exit':0,'roundtrip_files':len(files),'negative_child_exits':[r['actual_exit'] for r in controls],
                  'inspected_bootstrap_unchanged':True,'end_to_end':False},indent=2))
