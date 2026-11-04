"""Prepare direct HOL evaluation of frozen fixtures; no refund or codec implementation."""
import hashlib
import json
from pathlib import Path

OUT = Path(__file__).resolve().parent
PARENT = OUT.parent / 'attempt-0001/native-corpus'
cases_path = PARENT / 'cases.json'
freeze = json.loads((PARENT / 'freeze.json').read_text())
assert hashlib.sha256(cases_path.read_bytes()).hexdigest() == freeze['files']['cases.json']
cases = json.loads(cases_path.read_text())
wire = OUT / 'wire'
wire.mkdir(exist_ok=False)

def string(value):
    # The codec materializes fixture input only. The source UTF-8 proof is U262.
    return '(strlit (MAP CHR [' + ';'.join(map(str, value.encode('utf-8'))) + ']))'

def integer(value):
    return '(~' + value[1:] + ')' if value.startswith('-') else '(' + value + ')'

def boolean(value):
    return 'T' if value else 'F'

def quote(value):
    assert value.isascii()
    return json.dumps(value)

lines = [
    'load "forge_refundWireProgTheory";',
    'open HolKernel boolLib bossLib;',
    'val _ = Globals.max_print_depth := 100000;',
    'fun term s = Parse.Term [QUOTE s];',
    'fun inspect name th = let val (ors, axs) = Tag.dest_tag (Thm.tag th) in',
    '  if not (null (hyp th)) orelse not (null axs) then raise Fail "unexpected proof dependencies" else ();',
    '  print ("FIXTURE_THEOREM " ^ name ^ "\\n");',
    '  print ("FIXTURE_ORACLES " ^ String.concatWith "," ors ^ "\\n");',
    '  print ("FIXTURE_STATEMENT " ^ Parse.thm_to_string th ^ "\\n") end;',
    'fun check name source = let val th = EQT_ELIM (computeLib.EVAL_CONV (term source))',
    '  in inspect name th end;',
    'fun emit name path source = let',
    '  val th = computeLib.EVAL_CONV (term source);',
    '  val data = stringSyntax.fromHOLstring (rhs (concl th));',
    '  val _ = inspect name th;',
    '  val stream = BinIO.openOut path;',
    '  val _ = BinIO.output (stream, Byte.stringToBytes data);',
    '  val _ = BinIO.closeOut stream;',
    '  in print ("FIXTURE_BYTES " ^ name ^ " " ^ Int.toString (size data) ^ "\\n") end;',
]
for c in cases:
    i, e, name = c['inputs'], c['expected'], c['name']
    args = ' '.join([string(i['charge']), string(i['request']), integer(i['original']),
                    integer(i['remaining']), boolean(i['enabled']), boolean(i['opened']),
                    boolean(i['candidate']), integer(i['amount']), string(i['reason'])])
    fields = ','.join([boolean(e['ok']), integer(e['amount']), string(e['reason']),
                       string(e['charge']), string(e['request']), integer(e['count'])])
    req = 'sexp_to_string (refund_request ' + args + ')'
    out = 'refund_render_fields (' + fields + ')'
    lines += [
        'val _ = check ' + quote(name + ':fields') + ' ' + quote('refund_fields ' + args + ' = (' + fields + ')') + ';',
        'val _ = check ' + quote(name + ':wire') + ' ' + quote('refund_run_wire (' + req + ') = INR (' + out + ')') + ';',
        'val _ = emit ' + quote(name + ':stdin') + ' ' + quote(str(wire / (name + '.stdin'))) + ' ' + quote('explode (' + req + ')') + ';',
        'val _ = emit ' + quote(name + ':stdout') + ' ' + quote(str(wire / (name + '.stdout'))) + ' ' + quote('explode (' + out + ')') + ';',
    ]
lines += ['val _ = print "FIXTURE_BATCH_COMPLETE 22\\n";', 'OS.Process.exit OS.Process.success;', '']
(OUT / 'fixtures.sml').write_text('\n'.join(lines))
(OUT / 'preparation.json').write_text(json.dumps({
    'actual_exit': 0, 'case_count': len(cases),
    'input_cases_sha256': hashlib.sha256(cases_path.read_bytes()).hexdigest(),
    'batch_sha256': hashlib.sha256((OUT / 'fixtures.sml').read_bytes()).hexdigest(),
    'kernel_evaluation': 'NOT_RUN', 'native_execution': 'NOT_RUN', 'end_to_end': False,
    'scope': 'Existing HOL evaluator and published CakeML definitions only; no new codec or refund predicate',
}, indent=2) + '\n')
print('Prepared 22 fixed cases for direct HOL evaluation; no proof or native execution yet.')
