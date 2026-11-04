from pathlib import Path
import hashlib
import json
import os
import subprocess

ROOT = Path('/Users/mackianni/forge')
OUT = Path(__file__).resolve().parent
TC = ROOT / '.toolchain/experiments/refund-cakeml-20261104'
PARENT = OUT.parent / 'attempt-0006/export-0002'
SOURCE = OUT / 'stdio-0003'
AUDIT = OUT / 'import-audit'
AUDIT.mkdir(exist_ok=False)
whole = TC / 'cakeml/compiler/dafny/forge_refundWholeProg_experiment'
(AUDIT / 'Holmakefile').write_text('INCLUDES = ' + str(whole) + '\n')
(AUDIT / 'preload.sml').write_text('load "forge_refundWholeProgTheory";\nload "cfMainTheory";\n')
first = (OUT / 'stdio-0001/proof.sml').read_text()
final = (SOURCE / 'proof.sml').read_text()
def goal(text):
    return text.split('val refund_error_stdio_semantics = store_thm ("refund_error_stdio_semantics", ``', 1)[1].split('``,\n', 1)[0]
assert goal(first) == goal(final), 'Required final statement changed'
names = ['refund_raise_determ', 'refund_exception_determ', 'refund_evaluate_dec_list_clock_result',
         'refund_semantics_dec_list_determ_terminate_unique', 'refund_semantics_dec_list_all_terminate',
         'refund_exception_semantics', 'refund_error_stdio_semantics']
body = 'open HolKernel boolLib bossLib;\nval _ = Globals.max_print_depth := 1000;\n'
body += 'val expected = ``' + goal(first) + '``;\n'
body += '''val _ = if aconv expected (concl forge_refundRejectSemanticsTheory.refund_error_stdio_semantics)
 then () else raise Fail "Imported required statement differs";
'''
body += 'val checked = [' + ',\n'.join('("' + n + '",forge_refundRejectSemanticsTheory.' + n + ')' for n in names) + '];\n'
body += '''val _ = List.app (fn (name,th) =>
 let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn s => s = "DISK_THM") ors
  then () else raise Fail ("Unexpected dependency: " ^ name);
  print ("IMPORTED_THEOREM " ^ name ^ "\\n" ^ Parse.thm_to_string th ^ "\\n");
  print ("IMPORTED_ORACLES " ^ String.concatWith "," ors ^ "\\n");
  print "IMPORTED_HYPOTHESES 0\\nIMPORTED_TAGGED_AXIOMS 0\\n"
 end) checked;
val closure = "forge_refundRejectSemantics" :: Theory.ancestry "forge_refundRejectSemantics";
val _ = List.app (fn n => print ("CLOSURE_NODE " ^ n ^ ":" ^ String.concatWith "," (Theory.parents n) ^ "\\n")) closure;
val _ = List.app (fn n => List.app (fn (a,_) => print ("CLOSURE_AXIOM " ^ n ^ "." ^ a ^ "\\n")) (DB.axioms n)) closure;
val _ = print "EXACT_EXPECTED_STATEMENT true\\nIMPORT_AUDIT_COMPLETE\\n";
val _ = OS.Process.exit OS.Process.success;
'''
(AUDIT / 'audit.sml').write_text(body)
argv = [str(TC / 'HOL/bin/hol'), 'run', '--holstate=' + str(TC / 'cakeml/misc/cakeml-heap'), str(AUDIT / 'preload.sml')]
for directory, theory in [(PARENT, 'forge_refundRejectDirect'), (SOURCE, 'forge_refundRejectSemantics')]:
    argv.extend(str(directory / (theory + 'Theory' + suffix)) for suffix in ['.sig', '.sml'])
argv.append(str(AUDIT / 'audit.sml'))
env = os.environ.copy()
env.update(HOLDIR=str(TC / 'HOL'), CAKEMLDIR=str(TC / 'cakeml'))
env['PATH'] = str(TC / 'poly-install/bin') + os.pathsep + env['PATH']
record = {'argv': argv, 'cwd': str(AUDIT), 'required_statement_unchanged': True,
          'expected_theorems': names, 'audit_source_sha256': hashlib.sha256(body.encode()).hexdigest(),
          'scope': 'Fresh standard-heap import through HOL virtual artifact paths; no proof cache independence claim', 'end_to_end': False}
(AUDIT / 'invocation.json').write_text(json.dumps(record, indent=2) + '\n')
with (AUDIT / 'stdout.log').open('wb') as stdout, (AUDIT / 'stderr.log').open('wb') as stderr:
    child = subprocess.run(argv, cwd=AUDIT, env=env, stdout=stdout, stderr=stderr)
record['actual_exit'] = child.returncode
record['completion_marker'] = 'IMPORT_AUDIT_COMPLETE' in (AUDIT / 'stdout.log').read_text()
(AUDIT / 'command.json').write_text(json.dumps(record, indent=2) + '\n')
print(json.dumps(record, indent=2))
raise SystemExit(child.returncode if child.returncode else (0 if record['completion_marker'] else 1))
