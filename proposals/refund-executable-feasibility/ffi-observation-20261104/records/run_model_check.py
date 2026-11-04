"""Dispatch the pinned HOL kernel; do not implement filesystem semantics."""
import hashlib,json,os,subprocess,sys,time
from pathlib import Path
ROOT=Path('/Users/mackianni/forge');OUT=Path(__file__).resolve().parent
case=sys.argv[1];assert case in ['positive','altered-read-byte','wrong-write-descriptor','positive-0002','altered-read-byte-0002','wrong-write-descriptor-0002','repeat']
DEST=OUT/('model-'+case);assert DEST.is_dir();assert not (DEST/'command.json').exists()
TC=ROOT/'.toolchain/experiments/refund-cakeml-20261104'
WORK=TC/'cakeml/compiler/dafny/forge_refundWholeProg_experiment'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
HEAP=TC/'cakeml/misc/cakeml-heap'
assert sha(HEAP)=='36f7c254cab336ae1a331a76024c94925e03f9f6774ef545742be5cf9ebd8247'
argv=[str(TC/'HOL/bin/hol'),'run','--holstate='+str(HEAP),str(DEST/'check.sml')]
env=os.environ.copy();env.update(HOLDIR=str(TC/'HOL'),CAKEMLDIR=str(TC/'cakeml'));env['PATH']=str(TC/'poly-install/bin')+os.pathsep+env['PATH']
r={'argv':argv,'cwd':str(WORK),'source_sha256':sha(DEST/'check.sml'),'heap_sha256':sha(HEAP),'actual_exit':None,'end_to_end':False}
(DEST/'invocation.json').write_text(json.dumps(r,indent=2)+'\n');started=time.monotonic()
with (DEST/'stdout.log').open('wb') as stdout,(DEST/'stderr.log').open('wb') as stderr:
    p=subprocess.run(argv,cwd=WORK,env=env,stdout=stdout,stderr=stderr)
r.update(actual_exit=p.returncode,wall_seconds=time.monotonic()-started,completion_marker='OBSERVED_FFI_MODEL_CHECK_COMPLETE' in (DEST/'stdout.log').read_text(),objects={str(p.relative_to(DEST)):sha(p) for p in (DEST/'.hol').rglob('*') if p.is_file()})
(DEST/'command.json').write_text(json.dumps(r,indent=2)+'\n')
print(json.dumps(r));print((DEST/'stdout.log').read_text()[-3500:]);print((DEST/'stderr.log').read_text()[-1500:]);raise SystemExit(p.returncode)
