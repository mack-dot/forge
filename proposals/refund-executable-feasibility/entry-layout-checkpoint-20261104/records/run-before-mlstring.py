"""Run the pinned HOL kernel. Preserve each invocation and actual exit."""
import hashlib,json,os,subprocess,sys,time
from pathlib import Path
ROOT=Path('/Users/mackianni/forge');OUT=Path(__file__).resolve().parent
TC=ROOT/'.toolchain/experiments/refund-cakeml-20261104'
case=sys.argv[1];assert case in ['positive','wrong-ffi-slot','halt-in-domain','repeat']
DEST=OUT/case;assert DEST.is_dir();assert not (DEST/'command.json').exists()
WORK=TC/'cakeml/compiler/dafny/forge_refundArm8Proof_experiment'
HEAP=TC/'cakeml/misc/cakeml-heap';sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
assert sha(HEAP)=='36f7c254cab336ae1a331a76024c94925e03f9f6774ef545742be5cf9ebd8247'
env=os.environ.copy();env.update(HOLDIR=str(TC/'HOL'),CAKEMLDIR=str(TC/'cakeml'),FORGE_ENTRY_MODEL_OUT=str(DEST));env['PATH']=str(TC/'poly-install/bin')+os.pathsep+env['PATH']
argv=[str(TC/'HOL/bin/hol'),'run','--holstate='+str(HEAP),str(DEST/'proof.sml')]
r={'argv':argv,'cwd':str(WORK),'source_sha256':sha(DEST/'proof.sml'),'heap_sha256':sha(HEAP),'actual_exit':None,'end_to_end':False}
(DEST/'invocation.json').write_text(json.dumps(r,indent=2)+'\n');start=time.monotonic()
with (DEST/'stdout.log').open('wb') as stdout,(DEST/'stderr.log').open('wb') as stderr:
 child=subprocess.run(argv,cwd=WORK,env=env,stdout=stdout,stderr=stderr)
r.update(actual_exit=child.returncode,wall_seconds=time.monotonic()-start,completion_marker='ENTRY_LAYOUT_COMPLETE' in (DEST/'stdout.log').read_text(),objects={str(p.relative_to(DEST)):sha(p) for p in (DEST/'.hol').rglob('*') if p.is_file()})
(DEST/'command.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r));print((DEST/'stdout.log').read_text()[-3500:]);print((DEST/'stderr.log').read_text()[-1200:]);raise SystemExit(child.returncode)
