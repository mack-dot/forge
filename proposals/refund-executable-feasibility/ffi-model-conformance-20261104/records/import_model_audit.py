"""Import exact equations with the existing HOL kernel and inspect its closure."""
import hashlib
import json
import os
import re
import subprocess
import time
from pathlib import Path

ROOT = Path('/Users/mackianni/forge')
OUT = Path(__file__).resolve().parent
TC = ROOT / '.toolchain/experiments/refund-cakeml-20261104'
SOURCE = OUT / 'model-positive-0004'
AUDIT = OUT / 'model-import-audit'
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
HEAP = TC / 'cakeml/misc/cakeml-heap'
assert sha(HEAP) == '36f7c254cab336ae1a331a76024c94925e03f9f6774ef545742be5cf9ebd8247'
record = json.loads((SOURCE / 'command.json').read_text())
assert record['actual_exit'] == 0 and record['completion_marker']
assert record['objects']
for path, expected in record['objects'].items():
    assert sha(SOURCE/path) == expected
term_source = OUT / 'model-positive-0003/check.sml'
assert sha(term_source) == '7fad635b24005ac0d7dc3a9a0b5a33e91d19f634ff1c87607e95d0f7b429ac68'
identity = json.loads((OUT/'constructor-equation-readback.json').read_text())
assert identity['all_four_original_equations_reconstructed_exactly']
assert identity['original_source_sha256'] == sha(OUT/'model-positive-0002/check.sml')
assert [l for l in term_source.read_text().splitlines() if l.startswith('val expected_') or l.startswith('val captured_bytes_')] == [l for l in (SOURCE/'check.sml').read_text().splitlines() if l.startswith('val expected_') or l.startswith('val captured_bytes_')]
AUDIT.mkdir(exist_ok=False)
whole = TC/'cakeml/compiler/dafny/forge_refundWholeProg_experiment'
(AUDIT/'Holmakefile').write_text('INCLUDES = '+str(whole)+'\n')
(AUDIT/'preload.sml').write_text('load "basis_ffiTheory";\n')
body = []
for line in term_source.read_text().splitlines():
    if line.startswith('val _ = OS.FileSys.chDir'):
        break
    body.append(line)
for line in term_source.read_text().splitlines():
    if line.startswith('val captured_bytes_') or line.startswith('val expected_'):
        body.append(line)
body += ['val checked = [']
body += [f' ("observed_ffi_{i}",expected_{i},forge_refundObservedFFITheory.observed_ffi_{i})'+(',' if i<3 else '];') for i in range(4)]
body += [r'''val _ = if length(DB.theorems "forge_refundObservedFFI") = 4
 then () else raise Fail "Unexpected own theorem count";
val _ = List.app (fn (name,expected,th) =>
 let val (ors,axs) = Tag.dest_tag(Thm.tag th) in
  if aconv expected (concl th) then () else raise Fail("Statement mismatch: " ^ name);
  if null(hyp th) andalso null axs andalso List.all(fn s => s="DISK_THM") ors
  then () else raise Fail("Unexpected assumption or oracle: " ^ name);
  print("IMPORTED_THEOREM " ^ name ^ " EXACT_STATEMENT true HYPOTHESES 0 TAGGED_AXIOMS 0 ORACLES " ^ String.concatWith "," ors ^ "\n")
 end) checked;
val closure = "forge_refundObservedFFI" :: Theory.ancestry "forge_refundObservedFFI";
val _ = List.app(fn n => print("CLOSURE_NODE " ^ n ^ ":" ^ String.concatWith "," (Theory.parents n) ^ "\n")) closure;
val _ = List.app(fn n => List.app(fn (a,_) => print("CLOSURE_AXIOM " ^ n ^ "." ^ a ^ "\n")) (DB.axioms n)) closure;
val _ = print "OBSERVED_FFI_IMPORT_COMPLETE\n";
val _ = OS.Process.exit OS.Process.success;'''.replace('\\"','"')]
text = '\n'.join(body)+'\n'
(AUDIT/'audit.sml').write_text(text)
argv = [str(TC/'HOL/bin/hol'), 'run', '--holstate='+str(HEAP), str(AUDIT/'preload.sml')]
argv += [str(SOURCE/('forge_refundObservedFFITheory'+suffix)) for suffix in ['.sig','.sml']]
argv.append(str(AUDIT/'audit.sml'))
env = os.environ.copy()
env.update(HOLDIR=str(TC/'HOL'), CAKEMLDIR=str(TC/'cakeml'))
env['PATH'] = str(TC/'poly-install/bin')+os.pathsep+env['PATH']
invocation = {'argv':argv,'cwd':str(AUDIT),'audit_source_sha256':sha(AUDIT/'audit.sml'),
              'imported_objects':record['objects'],'actual_exit':None,
              'scope':'Fresh standard-heap import and exact statement comparison; not clean independent replay of all parent sources',
              'end_to_end':False}
(AUDIT/'invocation.json').write_text(json.dumps(invocation,indent=2)+'\n')
start = time.monotonic()
with (AUDIT/'stdout.log').open('wb') as stdout, (AUDIT/'stderr.log').open('wb') as stderr:
    child = subprocess.run(argv,cwd=AUDIT,env=env,stdout=stdout,stderr=stderr)
log = (AUDIT/'stdout.log').read_text()
invocation.update(actual_exit=child.returncode,wall_seconds=time.monotonic()-start,
                  completion_marker='OBSERVED_FFI_IMPORT_COMPLETE' in log)
(AUDIT/'command.json').write_text(json.dumps(invocation,indent=2)+'\n')
print(json.dumps(invocation));print(log[-3500:]);print((AUDIT/'stderr.log').read_text()[-1200:])
raise SystemExit(child.returncode if child.returncode else (0 if invocation['completion_marker'] else 1))
