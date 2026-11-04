"""Preserve the passing fixture bytes and prepare explicit model-control inputs."""
import hashlib
import json
from pathlib import Path
import shutil

OUT = Path(__file__).resolve().parent
source = (OUT / 'fixtures.sml').read_text()
assert json.loads((OUT / 'direct-0002/command.json').read_text())['actual_exit'] == 0
shutil.copyfile(OUT / 'fixtures.sml', OUT / 'direct-0002/fixtures.sml')
shutil.copytree(OUT / 'wire', OUT / 'direct-0002/wire')
(OUT / 'direct-0002/wire-sha256.json').write_text(json.dumps({
    p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted((OUT / 'wire').iterdir())
}, indent=2) + '\n')
header = source[:source.index('val _ = check "eligible_return:fields"')]
first = source[source.index('val _ = check "eligible_return:fields"'):].splitlines()[0]
assert first.count('= (T,(40),') == 1
(OUT / 'negative-amount.sml').write_text(header + first.replace('= (T,(40),', '= (T,(41),') + '\nOS.Process.exit OS.Process.success;\n')
old = '((strlit (MAP CHR [99;104;97;114;103;101;45;49])))'
# Use the exact expected field literals, without changing the nine input fields.
lhs, rhs = first.split(' = ', 1)
charge = '(strlit (MAP CHR [99;104;97;114;103;101;45;49]))'
request = '(strlit (MAP CHR [114;101;113;117;101;115;116;45;49]))'
assert rhs.count(charge) == rhs.count(request) == 1
swapped = rhs.replace(charge, 'SWAP_PLACEHOLDER').replace(request, charge).replace('SWAP_PLACEHOLDER', request)
(OUT / 'negative-ids.sml').write_text(header + lhs + ' = ' + swapped + '\nOS.Process.exit OS.Process.success;\n')

valid = (OUT / 'wire/eligible_return.stdin').read_bytes()
malformed = [
    ('trailing_newline', valid + b'\n', 'refund: trailing input'),
    ('second_request', valid + b' ' + valid, 'refund: trailing input'),
    ('unclosed_expression', b'(', 'refund: invalid S-expression'),
    ('empty_input', b'', 'refund: invalid S-expression'),
    ('missing_fields', b'()', 'dest9: Expected length 9, received length 0'),
    ('invalid_integer', b'(charge-1 request-1 100 60 True True True not-an-integer returned_item)', 'to_int: fromString failed'),
]
def string(data):
    return '(strlit (MAP CHR [' + ';'.join(map(str, data)) + ']))'
lines = [header]
metadata = []
for name, data, error in malformed:
    input_term, error_term = string(data), string(error.encode('ascii'))
    proposition = 'refund_run_wire ' + input_term + ' = INL ' + error_term
    lines += ['val _ = check ' + json.dumps(name + ':error') + ' ' + json.dumps(proposition) + ';',
              'val _ = emit ' + json.dumps(name + ':stdin') + ' ' + json.dumps(str(OUT / 'wire' / (name + '.stdin'))) + ' ' + json.dumps('explode ' + input_term) + ';']
    metadata.append({'name': name, 'expected_model_error': error, 'expected_stdout': '',
                     'process_exit_contract': 'NOT_ESTABLISHED', 'native_execution': 'NOT_RUN'})
lines += ['val _ = print "MALFORMED_BATCH_COMPLETE 6\\n";', 'OS.Process.exit OS.Process.success;', '']
(OUT / 'malformed.sml').write_text('\n'.join(lines))
(OUT / 'malformed-cases.json').write_text(json.dumps(metadata, indent=2) + '\n')
print('Preserved 44 positive wire artifacts; prepared two expected-proof failures and six wire-error cases.')
