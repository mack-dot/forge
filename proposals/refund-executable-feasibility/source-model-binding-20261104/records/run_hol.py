from pathlib import Path
import hashlib,json,os,resource,subprocess,sys,time
ROOT=Path('/Users/mackianni/forge');OUT=Path(__file__).resolve().parent
TC=ROOT/'.toolchain/experiments/refund-cakeml-20261104';HEAP=TC/'cakeml/misc/cakeml-heap'
case=OUT/sys.argv[1];case.mkdir(exist_ok=False)
source=Path(sys.argv[2]).resolve();sexp=Path(sys.argv[3]).resolve()
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
assert sha(HEAP)=='36f7c254cab336ae1a331a76024c94925e03f9f6774ef545742be5cf9ebd8247'
(case/'proof.sml').write_bytes(source.read_bytes());(case/'input.sexp').write_bytes(sexp.read_bytes())
env=dict(os.environ,HOLDIR=str(TC/'HOL'),CAKEMLDIR=str(TC/'cakeml'),FORGE_SOURCE_SEXP=str(case/'input.sexp'),FORGE_SOURCE_PROOF_OUT=str(case))
env['PATH']=str(TC/'poly-install/bin')+os.pathsep+env['PATH']
argv=[str(TC/'HOL/bin/hol'),'run','--holstate='+str(HEAP),str(case/'proof.sml')]
work=TC/'cakeml/compiler/dafny/forge_refund_call_experiment'
record={'argv':argv,'cwd':str(work),'source_sha256':sha(source),'input_sha256':sha(sexp),'heap_sha256':sha(HEAP),'actual_exit':None,'end_to_end':False}
(case/'invocation.json').write_text(json.dumps(record,indent=2)+'\n')
def limits():
    resource.setrlimit(resource.RLIMIT_CPU,(3600,3600));resource.setrlimit(resource.RLIMIT_CORE,(0,0))
start=time.monotonic()
with (case/'stdout.log').open('wb') as out,(case/'stderr.log').open('wb') as err:
    p=subprocess.run(argv,cwd=work,env=env,stdout=out,stderr=err,preexec_fn=limits)
record.update(actual_exit=p.returncode,wall_seconds=time.monotonic()-start,
              completion_marker='SOURCE_BINDING_COMPLETE' in (case/'stdout.log').read_text(),
              objects={str(f.relative_to(case)):sha(f) for f in (case/'.hol').rglob('*') if f.is_file()})
(case/'command.json').write_text(json.dumps(record,indent=2)+'\n')
print(json.dumps({k:v for k,v in record.items() if k!='objects'}),flush=True)
print((case/'stderr.log').read_text()[-1600:])
raise SystemExit(p.returncode)
