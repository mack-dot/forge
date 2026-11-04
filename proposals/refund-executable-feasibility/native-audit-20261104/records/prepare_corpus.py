"""Freeze native test cases and HOL checks of their declared model expectations.

The explicit expectations are test inputs. HOL checks each against the existing
refund result definition. This script implements no refund decision procedure.
"""
import hashlib
import json
from pathlib import Path

OUT = Path(__file__).resolve().parent
destination = OUT / 'native-corpus'
destination.mkdir(exist_ok=False)
cases = []

def case(name, ok, changes=None):
    inputs = dict(charge='charge-1', request='request-1', original='100', remaining='60',
                  enabled=True, opened=True, candidate=True, amount='40', reason='returned_item')
    inputs.update(changes or {})
    expected = dict(ok=ok, amount=inputs['amount'] if ok else '0',
                    reason=inputs['reason'] if ok else '',
                    charge=inputs['charge'] if ok else '', request=inputs['request'] if ok else '',
                    count='1' if ok else '0')
    cases.append(dict(name=name, inputs=inputs, expected=expected))

case('eligible_return', True)
case('eligible_duplicate', True, {'reason': 'duplicate_charge'})
case('eligible_service', True, {'reason': 'service_not_delivered'})
case('eligible_zero', True, {'amount': '0'})
case('eligible_maximum', True, {'original': '9223372036854775807',
     'remaining': '9223372036854775807', 'amount': '9223372036854775807'})
case('unicode_ids', True, {'charge': 'Ā', 'request': '\U0010ffff'})
case('nul_id', True, {'charge': '\x00', 'request': 'request\x00tail'})
case('escaped_ids', True, {'charge': 'a\n"\\b', 'request': '\t()\r'})
case('empty_charge', False, {'charge': ''})
case('empty_request', False, {'request': ''})
case('negative_amount', False, {'amount': '-1'})
case('over_remaining', False, {'amount': '61'})
case('original_over_money', False, {'original': '9223372036854775808'})
case('remaining_over_original', False, {'remaining': '101'})
case('disabled', False, {'enabled': False})
case('closed_request', False, {'opened': False})
case('noncandidate', False, {'candidate': False})
case('negative_remaining', False, {'remaining': '-1'})
case('unapproved_reason', False, {'reason': 'other'})
case('reason_suffix', False, {'reason': 'returned_item\x00evil'})
case('unbounded_positive', False, {'amount': str(2 ** 256)})
case('unbounded_negative', False, {'original': str(-(2 ** 256))})

def mlstring(value):
    # Use the standard Python codec only to materialize test data. No codec proof
    # is inferred from it. HOL receives the listed bytes as the exact fixture.
    return '(strlit (MAP CHR [' + ';'.join(str(n) for n in value.encode('utf-8')) + ']))'

def integer(value):
    return '(~' + value[1:] + ')' if value.startswith('-') else '(' + value + ')'

def boolean(value):
    return 'T' if value else 'F'

source = ['Theory forge_native_corpus', 'Ancestors', '  forge_refund_call mlstring',
          'Libs', '  preamble', '']
for c in cases:
    i, e = c['inputs'], c['expected']
    args = [mlstring(i['charge']), mlstring(i['request']), integer(i['original']),
            integer(i['remaining']), boolean(i['enabled']), boolean(i['opened']),
            boolean(i['candidate']), integer(i['amount']), mlstring(i['reason'])]
    expected = ('Conv NONE [Boolv ' + boolean(e['ok']) + '; Litv (IntLit ' + integer(e['amount']) +
                '); Litv (StrLit ' + mlstring(e['reason']) + '); Litv (StrLit ' + mlstring(e['charge']) +
                '); Litv (StrLit ' + mlstring(e['request']) + '); Litv (IntLit ' + integer(e['count']) + ')]')
    source.extend(['Theorem native_case_' + c['name'] + ':',
                   '  refund_expected_tuple ' + ' '.join(args) + ' =', '    ' + expected,
                   'Proof', '  EVAL_TAC', 'QED', ''])

source.extend(['val _ = List.app (fn (name,th) =>',
              '  let val (oracles,axioms) = Tag.dest_tag (Thm.tag th) in',
              '    print ("CORPUS_THEOREM " ^ name ^ "\\n");',
              '    print ("CORPUS_ORACLES " ^ String.concatWith "," oracles ^ "\\n");',
              '    print ("CORPUS_AXIOMS " ^ String.concatWith "," axioms ^ "\\n");',
              '    print ("CORPUS_HYPOTHESES " ^ Int.toString (length (hyp th)) ^ "\\n")',
              '  end) (Theory.current_theorems ());', ''])
(destination / 'cases.json').write_text(json.dumps(cases, indent=2, ensure_ascii=True) + '\n')
(destination / 'forge_native_corpusScript.sml').write_text('\n'.join(source))
manifest = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in destination.iterdir()}
(destination / 'freeze.json').write_text(json.dumps({'files': manifest, 'case_count': len(cases),
    'expected_model_check': 0, 'model_check': 'NOT_RUN', 'native_execution': 'NOT_RUN',
    'end_to_end': False}, indent=2) + '\n')
print(json.dumps({'prepared_cases': len(cases), 'model_check': 'NOT_RUN', 'native_execution': 'NOT_RUN'}))
