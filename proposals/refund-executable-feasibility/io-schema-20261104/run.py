import hashlib,json,os,shutil,subprocess,sys,time
from pathlib import Path
OUT=Path(__file__).resolve().parent
TC=Path('/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104')
work=TC/'cakeml/compiler/dafny/forge_refund_io_experiment'
work.mkdir(exist_ok=True)
attempt=OUT/('proof-'+sys.argv[1]);attempt.mkdir(exist_ok=False)
prior=attempt/'prior-outputs';prior.mkdir()
for pattern in ['.hol/objs/forge_refund_ioTheory.*','*.dumpedheap']:
 for f in work.glob(pattern):shutil.move(str(f),str(prior/f.name))
source=Path(sys.argv[2]) if len(sys.argv)>2 else OUT/'forge_refund_ioScript.sml'
shutil.copyfile(source,work/source.name);shutil.copyfile(source,attempt/source.name)
(work/'Holmakefile').write_text('ifdef POLY\nHOLHEAP = $(CAKEMLDIR)/misc/cakeml-heap\nendif\n')
env=os.environ.copy();env.update(HOLDIR=str(TC/'HOL'),CAKEMLDIR=str(TC/'cakeml'))
env['PATH']=str(TC/'poly-install/bin')+os.pathsep+env['PATH']
argv=[str(TC/'HOL/bin/Holmake'),'--no-cache','-j','2','forge_refund_ioTheory.uo']
t=time.monotonic()
with (attempt/'build.log').open('wb') as log:r=subprocess.run(argv,cwd=work,env=env,stdout=log,stderr=subprocess.STDOUT)
record=dict(argv=argv,cwd=str(work),actual_exit=r.returncode,wall_seconds=time.monotonic()-t,source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),native_refund_claim=False,end_to_end=False)
objects=attempt/'objects';objects.mkdir()
for f in (work/'.hol/objs').glob('forge_refund_ioTheory.*'):shutil.copyfile(f,objects/f.name)
record['object_sha256']={f.name:hashlib.sha256(f.read_bytes()).hexdigest() for f in objects.iterdir()}
log=work/'.hol/logs/forge_refund_ioTheory'
if log.exists():shutil.copyfile(log,attempt/'theory.log')
(attempt/'command.json').write_text(json.dumps(record,indent=2)+'\n')
print(json.dumps(record),flush=True);print((attempt/'build.log').read_text(errors='replace')[-1000:],flush=True)
raise SystemExit(r.returncode)
