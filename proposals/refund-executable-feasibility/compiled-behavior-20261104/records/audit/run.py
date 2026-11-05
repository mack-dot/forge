"""Check exact compiler-claim binding with the existing HOL kernel."""
from pathlib import Path
import hashlib,json,os,shutil,subprocess,sys,time
ROOT=Path('/Users/mackianni/forge');OUT=Path(__file__).resolve().parent
TC=ROOT/'.toolchain/experiments/refund-cakeml-20261104'
SRC=ROOT/'results/refund-arm8-compile-2026-11-04/attempt-0001/behavior-0001'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
record=json.loads((SRC/'command.json').read_text())
assert record['actual_exit']==0 and record['status']=='FINISHED'
assert record['source_sha256']=='7cb940489138a6f81eb5b169e5397df7217170a84267e9565600273f36ff40ca'
for name,digest in record['object_sha256'].items():assert sha(SRC/'objects'/name)==digest
HEAP=TC/'cakeml/misc/cakeml-heap'
assert sha(HEAP)=='36f7c254cab336ae1a331a76024c94925e03f9f6774ef545742be5cf9ebd8247'
case=sys.argv[1];assert case in ['import','import-0002','substituted-code','changed-result']
DEST=OUT/case;DEST.mkdir()
STAGED=DEST/'imported';(STAGED/'.hol/objs').mkdir(parents=True)
for name,digest in record['object_sha256'].items():
 shutil.copyfile(SRC/'objects'/name,STAGED/'.hol/objs'/name)
 assert sha(STAGED/'.hol/objs'/name)==digest
(DEST/'Holmakefile').write_text('INCLUDES = '+str(TC/'cakeml/compiler/dafny/forge_refundArm8Proof_experiment')+'\n')
(DEST/'preload.sml').write_text('load "arm8_configProofTheory";\nload "forge_refundArm8CompileTheory";\n')
expected=(OUT/'expected.sml').read_text()
if case=='substituted-code':
 assert expected.count('targetSem$installed forge_refundArm8Compile$code')==1
 expected=expected.replace('targetSem$installed forge_refundArm8Compile$code','targetSem$installed (0w::forge_refundArm8Compile$code)')
if case=='changed-result':
 assert expected.count('enabled opened candidate amount reason)))')==2
 # Change only the required output; keep the serialized input unchanged.
 needle='forge_refundCertifiedProg$refund_fields charge request original remaining\n             enabled opened candidate amount reason'
 assert expected.count(needle)==1
 expected=expected.replace(needle,needle.replace('candidate amount reason','candidate (amount+1) reason'))
body=expected+r'''
val th = forge_refundArm8ProofTheory.refund_compiled_behavior;
val _ = if aconv required_behavior (concl th) then print "EXACT_BEHAVIOR_BINDING\n"
 else raise Fail "Exact compiler behavior statement mismatch";
val (ors,axs)=Tag.dest_tag(Thm.tag th);
val _=if null(hyp th) andalso null axs andalso List.all(fn s=>s="DISK_THM") ors
 then () else raise Fail "Unexpected hypotheses or oracle tags";
val _=if length(DB.theorems "forge_refundArm8Proof")=1 then ()
 else raise Fail "Unexpected own theorem count";
val _=print("CHECKED_ORACLES "^String.concatWith "," ors^"\nCHECKED_HYPOTHESES 0\nCHECKED_TAGGED_AXIOMS 0\n");
val closure="forge_refundArm8Proof"::Theory.ancestry "forge_refundArm8Proof";
val _=List.app(fn n=>print("CLOSURE_NODE "^n^":"^String.concatWith ","(Theory.parents n)^"\n")) closure;
val _=List.app(fn n=>List.app(fn(a,_)=>print("CLOSURE_AXIOM "^n^"."^a^"\n"))(DB.axioms n)) closure;
val _=print "BEHAVIOR_AUDIT_COMPLETE\n";
val _=OS.Process.exit OS.Process.success;
'''
(DEST/'audit.sml').write_text(body)
argv=[str(TC/'HOL/bin/hol'),'run','--holstate='+str(HEAP),str(DEST/'preload.sml')]
argv += [str(STAGED/('forge_refundArm8ProofTheory'+suffix)) for suffix in ['.sig','.sml']]
argv.append(str(DEST/'audit.sml'))
env=os.environ.copy();env.update(HOLDIR=str(TC/'HOL'),CAKEMLDIR=str(TC/'cakeml'))
env['PATH']=str(TC/'poly-install/bin')+os.pathsep+env['PATH']
r={'argv':argv,'cwd':str(DEST),'source_sha256':sha(DEST/'audit.sml'),'expected_source_sha256':sha(OUT/'expected.sml'),
   'original_compiler_result_sha256':sha(SRC/'command.json'),'imported_objects':record['object_sha256'],
   'actual_exit':None,'scope':'Exact theorem binding, same-host import; not universal physical correspondence or independent full-chain replay.','end_to_end':False}
(DEST/'invocation.json').write_text(json.dumps(r,indent=2)+'\n');start=time.monotonic()
with (DEST/'stdout.log').open('wb') as stdout,(DEST/'stderr.log').open('wb') as stderr:
 child=subprocess.run(argv,cwd=DEST,env=env,stdout=stdout,stderr=stderr)
log=(DEST/'stdout.log').read_text()
r.update(actual_exit=child.returncode,wall_seconds=time.monotonic()-start,
         completion_marker='BEHAVIOR_AUDIT_COMPLETE' in log)
(DEST/'command.json').write_text(json.dumps(r,indent=2)+'\n')
print(json.dumps(r));print(log[-1800:]);print((DEST/'stderr.log').read_text()[-1400:])
raise SystemExit(child.returncode if child.returncode else (0 if r['completion_marker'] else 1))
