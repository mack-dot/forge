"""Use fresh HOL to check the exact imported claims and enumerate their ancestry."""
from pathlib import Path
import hashlib,json,os,subprocess,time
ROOT=Path('/Users/mackianni/forge')
OUT=Path(__file__).resolve().parent
TC=ROOT/'.toolchain/experiments/refund-cakeml-20261104'
SOURCE=OUT/'positive-0002'
AUDIT=OUT/'import-audit'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
record=json.loads((SOURCE/'command.json').read_text())
assert record['actual_exit']==0 and record['completion_marker']
assert len(record['objects'])==4
for name,digest in record['objects'].items():assert sha(SOURCE/name)==digest
HEAP=TC/'cakeml/misc/cakeml-heap'
assert sha(HEAP)=='36f7c254cab336ae1a331a76024c94925e03f9f6774ef545742be5cf9ebd8247'
AUDIT.mkdir()
(AUDIT/'Holmakefile').write_text('INCLUDES = '+str(TC/'cakeml/compiler/dafny/forge_refundArm8Proof_experiment')+'\n')
(AUDIT/'preload.sml').write_text('load "backendProofTheory";\nload "arm8_configTheory";\n')
body=(OUT/'expected.sml').read_text()+r'''
val checked = [
 ("recorded_config",expected_config,forge_refundResourceBindingTheory.recorded_config),
 ("recorded_limits",expected_limits,forge_refundResourceBindingTheory.recorded_limits),
 ("recorded_read_limits",expected_read_limits,forge_refundResourceBindingTheory.recorded_read_limits)];
val _ = if length(DB.theorems "forge_refundResourceBinding")=3 then ()
 else raise Fail "Unexpected own theorem count";
val _ = List.app (fn (name,expected,th) =>
 let val (ors,axs)=Tag.dest_tag(Thm.tag th) in
  if aconv expected (concl th) then () else raise Fail("Statement mismatch: "^name);
  if null(hyp th) andalso null axs andalso List.all(fn s=>s="DISK_THM") ors
  then () else raise Fail("Unexpected assumption or oracle: "^name);
  print("IMPORTED_THEOREM "^name^" EXACT_STATEMENT true HYPOTHESES 0 TAGGED_AXIOMS 0 ORACLES "^String.concatWith "," ors^"\n")
 end) checked;
val closure="forge_refundResourceBinding"::Theory.ancestry "forge_refundResourceBinding";
val _=List.app(fn n=>print("CLOSURE_NODE "^n^":"^String.concatWith "," (Theory.parents n)^"\n")) closure;
val _=List.app(fn n=>List.app(fn (a,_)=>print("CLOSURE_AXIOM "^n^"."^a^"\n")) (DB.axioms n)) closure;
val _=print "RESOURCE_IMPORT_COMPLETE\n";
val _=OS.Process.exit OS.Process.success;
'''
(AUDIT/'audit.sml').write_text(body)
argv=[str(TC/'HOL/bin/hol'),'run','--holstate='+str(HEAP),str(AUDIT/'preload.sml')]
argv += [str(SOURCE/('forge_refundResourceBindingTheory'+suffix)) for suffix in ['.sig','.sml']]
argv.append(str(AUDIT/'audit.sml'))
env=os.environ.copy();env.update(HOLDIR=str(TC/'HOL'),CAKEMLDIR=str(TC/'cakeml'))
env['PATH']=str(TC/'poly-install/bin')+os.pathsep+env['PATH']
r={'argv':argv,'cwd':str(AUDIT),'audit_source_sha256':sha(AUDIT/'audit.sml'),
   'expected_source_sha256':sha(OUT/'expected.sml'),'imported_objects':record['objects'],
   'actual_exit':None,'end_to_end':False,
   'scope':'Fresh same-host import. Not independent full-source replay or authenticated producer evidence.'}
(AUDIT/'invocation.json').write_text(json.dumps(r,indent=2)+'\n');start=time.monotonic()
with (AUDIT/'stdout.log').open('wb') as stdout,(AUDIT/'stderr.log').open('wb') as stderr:
 child=subprocess.run(argv,cwd=AUDIT,env=env,stdout=stdout,stderr=stderr)
log=(AUDIT/'stdout.log').read_text()
r.update(actual_exit=child.returncode,wall_seconds=time.monotonic()-start,
         completion_marker='RESOURCE_IMPORT_COMPLETE' in log)
(AUDIT/'command.json').write_text(json.dumps(r,indent=2)+'\n')
print(json.dumps(r));print(log[-1400:]);print((AUDIT/'stderr.log').read_text()[-1000:])
raise SystemExit(child.returncode if child.returncode else (0 if r['completion_marker'] else 1))
