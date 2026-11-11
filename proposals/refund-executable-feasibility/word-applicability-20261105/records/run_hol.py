"""Dispatch the existing HOL kernel; preserve exact commands and results."""
from pathlib import Path
import hashlib,json,os,resource,shutil,subprocess,sys,time
ROOT=Path('/Users/mackianni/forge');OUT=Path(__file__).resolve().parent
TC=ROOT/'.toolchain/experiments/refund-cakeml-20261104';HEAP=TC/'cakeml/misc/cakeml-heap'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
assert sha(HEAP)=='36f7c254cab336ae1a331a76024c94925e03f9f6774ef545742be5cf9ebd8247'
case=OUT/sys.argv[1];case.mkdir(exist_ok=False);source=Path(sys.argv[2]).resolve()
(case/'proof.sml').write_bytes(source.read_bytes())
argv=[str(TC/'HOL/bin/hol'),'run','--holstate='+str(HEAP),str(case/'proof.sml')]
imports={}
if len(sys.argv)>3:
    (case/'preload.sml').write_text('load "forge_refundArm8ProofTheory";\nload "wordPropsTheory";\n')
    argv=argv[:-1]+[str(case/'preload.sml')]
    for sourcecase,theory in [v.split(':') for v in sys.argv[3:]]:
        src=OUT/sourcecase;prior=json.loads((src/'command.json').read_text())
        assert prior['actual_exit']==0 and prior['completion_marker']
        for name,digest in prior['objects'].items():
            assert sha(src/name)==digest
            dest=case/sourcecase/name;dest.parent.mkdir(parents=True,exist_ok=True)
            shutil.copyfile(src/name,dest)
        imports[sourcecase]=prior['objects']
        argv += [str(case/sourcecase/(theory+'Theory'+suffix)) for suffix in ['.sig','.sml']]
    argv += [str(case/'proof.sml')]
env=dict(os.environ,HOLDIR=str(TC/'HOL'),CAKEMLDIR=str(TC/'cakeml'),FORGE_RUNTIME_OUT=str(case))
env['PATH']=str(TC/'poly-install/bin')+os.pathsep+env['PATH']
cwd=TC/'cakeml/compiler/dafny/forge_refundArm8Proof_experiment'
record={'argv':argv,'cwd':str(cwd),'source_sha256':sha(source),'heap_sha256':sha(HEAP),
        'cpu_seconds_per_process':3600,'actual_exit':None,'end_to_end':False}
if imports:record['imported_objects']=imports
(case/'invocation.json').write_text(json.dumps(record,indent=2)+'\n')
def limits():
    resource.setrlimit(resource.RLIMIT_CPU,(3600,3600));resource.setrlimit(resource.RLIMIT_CORE,(0,0))
start=time.monotonic()
with (case/'stdout.log').open('wb') as stdout,(case/'stderr.log').open('wb') as stderr:
    p=subprocess.run(argv,cwd=cwd,env=env,stdout=stdout,stderr=stderr,preexec_fn=limits)
record.update(actual_exit=p.returncode,wall_seconds=time.monotonic()-start,
              completion_marker='RUNTIME_PROOF_COMPLETE' in (case/'stdout.log').read_text(),
              objects={str(f.relative_to(case)):sha(f) for f in (case/'.hol').rglob('*') if f.is_file()})
(case/'command.json').write_text(json.dumps(record,indent=2)+'\n')
print(json.dumps({k:v for k,v in record.items() if k!='objects'}),flush=True)
print((case/'stderr.log').read_text()[-1800:],flush=True)
raise SystemExit(p.returncode)
