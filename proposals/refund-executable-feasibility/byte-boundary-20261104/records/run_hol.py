"""Fresh HOL import of exact recorded objects; optional new relation proof."""
from pathlib import Path
import hashlib,json,os,resource,shutil,subprocess,sys,time
ROOT=Path('/Users/mackianni/forge');OUT=Path(__file__).resolve().parent
TC=ROOT/'.toolchain/experiments/refund-cakeml-20261104';HEAP=TC/'cakeml/misc/cakeml-heap'
SOURCE=ROOT/'results/refund-source-binding-2026-11-04/attempt-0002/hol-0004';record=json.loads((SOURCE/'command.json').read_text())
assert record['actual_exit']==0 and record['completion_marker']
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
assert sha(HEAP)=='36f7c254cab336ae1a331a76024c94925e03f9f6774ef545742be5cf9ebd8247'
case=OUT/sys.argv[1];case.mkdir(exist_ok=False);body=Path(sys.argv[2]).resolve()
for name,digest in record['objects'].items():
    assert sha(SOURCE/name)==digest
    dest=case/'imported'/name;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(SOURCE/name,dest)
(case/'audit.sml').write_bytes(body.read_bytes());(case/'input.sexp').write_bytes((SOURCE/'input.sexp').read_bytes())
assert sha(case/'input.sexp')=='58154ddffc3b54d875c51bcd9dd2f36a93334c5cc302c899987aec0d7333dd0d'
(case/'preload.sml').write_text('load "sexp_to_dafnyTheory";\nload "forge_refundTheory";\n')
argv=[str(TC/'HOL/bin/hol'),'run','--holstate='+str(HEAP),str(case/'preload.sml')]
argv += [str(case/'imported'/('forge_refundSourceBindingTheory'+suffix)) for suffix in ['.sig','.sml']]
argv += [str(case/'audit.sml')]
env=dict(os.environ,HOLDIR=str(TC/'HOL'),CAKEMLDIR=str(TC/'cakeml'),FORGE_SOURCE_SEXP=str(case/'input.sexp'),FORGE_SOURCE_PROOF_OUT=str(case))
env['PATH']=str(TC/'poly-install/bin')+os.pathsep+env['PATH']
work=TC/'cakeml/compiler/dafny/forge_refundWireProg_experiment'
result={'argv':argv,'cwd':str(work),'source_sha256':sha(body),'input_sha256':sha(case/'input.sexp'),
        'imported_objects':record['objects'],'actual_exit':None,'end_to_end':False,
        'scope':'Fresh same-host import/relation proof; not independent full-chain replay or producer authentication.'}
(case/'invocation.json').write_text(json.dumps(result,indent=2)+'\n')
def limits():
    resource.setrlimit(resource.RLIMIT_CPU,(3600,3600));resource.setrlimit(resource.RLIMIT_CORE,(0,0))
start=time.monotonic()
with (case/'stdout.log').open('wb') as out,(case/'stderr.log').open('wb') as err:
    child=subprocess.run(argv,cwd=work,env=env,stdout=out,stderr=err,preexec_fn=limits)
log=(case/'stdout.log').read_text()
result.update(actual_exit=child.returncode,wall_seconds=time.monotonic()-start,
              import_complete='SOURCE_IMPORT_COMPLETE' in log,relation_complete='SOURCE_RELATION_COMPLETE' in log,bridge_complete='BYTE_BOUNDARY_COMPLETE' in log,
              objects={str(f.relative_to(case)):sha(f) for f in (case/'.hol').rglob('*') if f.is_file()})
(case/'command.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({k:v for k,v in result.items() if k not in ['imported_objects','objects']}))
print((case/'stderr.log').read_text()[-1600:])
raise SystemExit(child.returncode)
