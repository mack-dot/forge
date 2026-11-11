"""Fresh HOL import of fixed proof exports and explicit expected statements."""
from pathlib import Path
import hashlib,json,os,resource,shutil,subprocess,sys,time
ROOT=Path('/Users/mackianni/forge');OUT=Path(__file__).resolve().parent
TC=ROOT/'.toolchain/experiments/refund-cakeml-20261104';HEAP=TC/'cakeml/misc/cakeml-heap'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
assert sha(HEAP)=='36f7c254cab336ae1a331a76024c94925e03f9f6774ef545742be5cf9ebd8247'
case=OUT/sys.argv[1];case.mkdir(exist_ok=False);body=Path(sys.argv[2]).resolve()
(case/'audit.sml').write_bytes(body.read_bytes())
(case/'preload.sml').write_text('load "wordPropsTheory";\nload "data_to_wordProofTheory";\n')
argv=[str(TC/'HOL/bin/hol'),'run','--holstate='+str(HEAP),str(case/'preload.sml')]
inputs={}
for source,theory in [x.split(':') for x in sys.argv[3:]]:
    original=OUT/source;rec=json.loads((original/'command.json').read_text())
    assert rec['actual_exit']==0 and rec['completion_marker']
    for name,digest in rec['objects'].items():
        assert sha(original/name)==digest
        dest=case/source/name;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(original/name,dest)
    inputs[source]=rec['objects']
    argv += [str(case/source/(theory+'Theory'+suffix)) for suffix in ['.sig','.sml']]
argv += [str(case/'audit.sml')]
env=dict(os.environ,HOLDIR=str(TC/'HOL'),CAKEMLDIR=str(TC/'cakeml'))
env['PATH']=str(TC/'poly-install/bin')+os.pathsep+env['PATH']
cwd=TC/'cakeml/compiler/dafny/forge_refundArm8Proof_experiment'
result={'argv':argv,'cwd':str(cwd),'source_sha256':sha(body),'heap_sha256':sha(HEAP),
        'imported_objects':inputs,'actual_exit':None,'end_to_end':False,'cpu_seconds_per_process':3600,
        'scope':'Fresh same-host import, not independent full-chain replay or authenticated production.'}
(case/'invocation.json').write_text(json.dumps(result,indent=2)+'\n')
def limits():
    resource.setrlimit(resource.RLIMIT_CPU,(3600,3600));resource.setrlimit(resource.RLIMIT_CORE,(0,0))
start=time.monotonic()
with (case/'stdout.log').open('wb') as out,(case/'stderr.log').open('wb') as err:
    p=subprocess.run(argv,cwd=cwd,env=env,stdout=out,stderr=err,preexec_fn=limits)
result.update(actual_exit=p.returncode,wall_seconds=time.monotonic()-start,
              import_complete='TRACE_IMPORT_COMPLETE' in (case/'stdout.log').read_text())
(case/'command.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({k:v for k,v in result.items() if k!='imported_objects'}))
print((case/'stderr.log').read_text()[-1800:])
raise SystemExit(p.returncode)
