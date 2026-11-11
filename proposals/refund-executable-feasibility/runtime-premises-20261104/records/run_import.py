"""Dispatch HOL on exact archived objects and an explicit expected statement."""
from pathlib import Path
import hashlib,json,os,resource,shutil,subprocess,sys,time
ROOT=Path('/Users/mackianni/forge'); OUT=Path(__file__).resolve().parent
TC=ROOT/'.toolchain/experiments/refund-cakeml-20261104'; HEAP=TC/'cakeml/misc/cakeml-heap'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
assert sha(HEAP)=='36f7c254cab336ae1a331a76024c94925e03f9f6774ef545742be5cf9ebd8247'
SOURCE=OUT/'precise-0003'; record=json.loads((SOURCE/'command.json').read_text())
assert record['actual_exit']==0 and record['completion_marker']
case=OUT/sys.argv[1]; case.mkdir(exist_ok=False); body=Path(sys.argv[2]).resolve()
for name,digest in record['objects'].items():
    assert sha(SOURCE/name)==digest
    dest=case/'imported'/name; dest.parent.mkdir(parents=True,exist_ok=True); shutil.copyfile(SOURCE/name,dest)
(case/'audit.sml').write_bytes(body.read_bytes())
(case/'preload.sml').write_text('load "forge_refundArm8ProofTheory";\n')
argv=[str(TC/'HOL/bin/hol'),'run','--holstate='+str(HEAP),str(case/'preload.sml')]
argv += [str(case/'imported'/('forge_refundPreciseBehaviorTheory'+suffix)) for suffix in ['.sig','.sml']]
argv += [str(case/'audit.sml')]
env=dict(os.environ,HOLDIR=str(TC/'HOL'),CAKEMLDIR=str(TC/'cakeml'))
env['PATH']=str(TC/'poly-install/bin')+os.pathsep+env['PATH']
cwd=TC/'cakeml/compiler/dafny/forge_refundArm8Proof_experiment'
result={'argv':argv,'cwd':str(cwd),'source_sha256':sha(body),'heap_sha256':sha(HEAP),
        'imported_objects':record['objects'],'actual_exit':None,'end_to_end':False,
        'cpu_seconds_per_process':3600,
        'scope':'Fresh same-host import; not independent full-chain replay or producer authentication.'}
(case/'invocation.json').write_text(json.dumps(result,indent=2)+'\n')
def limits():
    resource.setrlimit(resource.RLIMIT_CPU,(3600,3600)); resource.setrlimit(resource.RLIMIT_CORE,(0,0))
start=time.monotonic()
with (case/'stdout.log').open('wb') as out,(case/'stderr.log').open('wb') as err:
    child=subprocess.run(argv,cwd=cwd,env=env,stdout=out,stderr=err,preexec_fn=limits)
result.update(actual_exit=child.returncode,wall_seconds=time.monotonic()-start,
              import_complete='RUNTIME_IMPORT_COMPLETE' in (case/'stdout.log').read_text())
(case/'command.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({k:v for k,v in result.items() if k!='imported_objects'}))
print((case/'stderr.log').read_text()[-1800:])
raise SystemExit(child.returncode)
