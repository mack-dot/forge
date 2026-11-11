from pathlib import Path
import hashlib
import json
import os
import subprocess
import sys

ROOT = Path('/Users/mackianni/forge')
OUT = Path(__file__).resolve().parent
TC = ROOT / '.toolchain/experiments/refund-cakeml-20261104'
AUDIT = OUT / sys.argv[1]
EXPECTED = OUT / (sys.argv[2] if len(sys.argv) > 2 else 'expected-final.sml')
AUDIT.mkdir(exist_ok=False)
whole = TC / 'cakeml/compiler/dafny/forge_refundWholeProg_experiment'
(AUDIT / 'Holmakefile').write_text('INCLUDES = ' + str(whole) + '\n')
(AUDIT / 'preload.sml').write_text('load "forge_refundWholeProgTheory";\nload "cfMainTheory";\n')
names = ['refund_stdio_extract_fs', 'refund_sem_satisfies_imp', 'refund_error_basis_semantics',
         'refund_basis_parts_ok', 'refund_basis_fs_projection', 'refund_split_from_subset',
         'refund_initial_stdio', 'refund_error_program_identity', 'refund_error_initialized_semantics']
body = EXPECTED.read_text()
body += '\nval checked = [' + ',\n'.join('("' + n + '",forge_refundRejectBasisTheory.' + n + ')' for n in names) + '];\n'
body += '''val _ = List.app (fn (name,th) =>
 let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn s => s = "DISK_THM") ors
  then () else raise Fail ("Unexpected dependency: " ^ name);
  print ("IMPORTED_THEOREM " ^ name ^ "\\n");
  if name = "refund_error_program_identity" then print "EXACT_CLOSED_PROGRAM_IDENTITY_CHECKED\\n"
  else print (Parse.thm_to_string th ^ "\\n");
  print ("IMPORTED_ORACLES " ^ String.concatWith "," ors ^ "\\n");
  print "IMPORTED_HYPOTHESES 0\\nIMPORTED_TAGGED_AXIOMS 0\\n"
 end) checked;
val closure = "forge_refundRejectBasis" :: Theory.ancestry "forge_refundRejectBasis";
val _ = List.app (fn n => print ("CLOSURE_NODE " ^ n ^ ":" ^ String.concatWith "," (Theory.parents n) ^ "\\n")) closure;
val _ = List.app (fn n => List.app (fn (a,_) => print ("CLOSURE_AXIOM " ^ n ^ "." ^ a ^ "\\n")) (DB.axioms n)) closure;
val _ = print "EXACT_EXPECTED_STATEMENT true\\nFINAL_IMPORT_COMPLETE\\n";
val _ = OS.Process.exit OS.Process.success;
'''
(AUDIT / 'audit.sml').write_text(body)
argv = [str(TC / 'HOL/bin/hol'), 'run', '--holstate=' + str(TC / 'cakeml/misc/cakeml-heap'), str(AUDIT / 'preload.sml')]
parents = [(OUT.parent / 'attempt-0006/export-0002', 'forge_refundRejectDirect'),
           (OUT.parent / 'attempt-0007/stdio-0003', 'forge_refundRejectSemantics'),
           (OUT / 'concrete-0001', 'forge_refundRejectBasis')]
for directory, theory in parents:
    argv.extend(str(directory / (theory + 'Theory' + suffix)) for suffix in ['.sig', '.sml'])
argv.append(str(AUDIT / 'audit.sml'))
env = os.environ.copy()
env.update(HOLDIR=str(TC / 'HOL'), CAKEMLDIR=str(TC / 'cakeml'))
env['PATH'] = str(TC / 'poly-install/bin') + os.pathsep + env['PATH']
record = {'argv': argv, 'cwd': str(AUDIT), 'expected_source_sha256': hashlib.sha256(EXPECTED.read_bytes()).hexdigest(),
          'audit_source_sha256': hashlib.sha256(body.encode()).hexdigest(), 'expected_theorems': names,
          'scope': 'Fresh standard-heap import of concrete initialized exception statement and exact program identity', 'end_to_end': False}
(AUDIT / 'invocation.json').write_text(json.dumps(record, indent=2) + '\n')
with (AUDIT / 'stdout.log').open('wb') as stdout, (AUDIT / 'stderr.log').open('wb') as stderr:
    child = subprocess.run(argv, cwd=AUDIT, env=env, stdout=stdout, stderr=stderr)
record['actual_exit'] = child.returncode
record['completion_marker'] = 'FINAL_IMPORT_COMPLETE' in (AUDIT / 'stdout.log').read_text()
(AUDIT / 'command.json').write_text(json.dumps(record, indent=2) + '\n')
print(json.dumps(record, indent=2))
raise SystemExit(child.returncode if child.returncode else (0 if record['completion_marker'] else 1))
