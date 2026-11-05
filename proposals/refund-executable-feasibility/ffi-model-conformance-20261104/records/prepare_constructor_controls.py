"""Preserve the frozen negative cases using existing HOL term constructors."""
import hashlib
import json
import re
from pathlib import Path

OUT = Path(__file__).resolve().parent
source = OUT / 'model-positive-0003/check.sml'
base = source.read_text()
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
assert sha(source) == '7fad635b24005ac0d7dc3a9a0b5a33e91d19f634ff1c87607e95d0f7b429ac68'
live_log = (OUT / 'model-positive-0002/stdout.log').read_text()
assert 'OBSERVED_FFI_0_CHECKED' in live_log

def equations(text):
    arrays = {}
    for index, body in re.findall(r'val captured_bytes_(\d+) = byte_terms \[([0-9,]*)\];', text):
        arrays[index] = '([' + ';'.join(n+'w' for n in body.split(',')) + ']:word8 list)'
    result = []
    for line in text.splitlines():
        if line.startswith('val expected_'):
            result.append(re.sub(r'\^captured_bytes_(\d+)', lambda m: arrays[m[1]], line))
    assert len(result) == 4
    return result

records = []
for name, index, offset, old_value, new_value in [
    ('altered-read-byte', 2, 4, 40, 41),
    ('wrong-write-descriptor', 9, 7, 1, 0),
]:
    pattern = r'val captured_bytes_' + str(index) + r' = byte_terms \[([0-9,]*)\];'
    match = re.search(pattern, base)
    assert match
    values = [int(v) for v in match[1].split(',')]
    assert values[offset] == old_value
    values[offset] = new_value
    replacement = 'val captured_bytes_' + str(index) + ' = byte_terms [' + ','.join(map(str, values)) + '];'
    text = base[:match.start()] + replacement + base[match.end():]
    prior = OUT / ('model-' + name + '-0002/check.sml')
    assert equations(text) == equations(prior.read_text())
    assert sum(a != b for a,b in zip(text.splitlines(),base.splitlines())) == 1
    dest = OUT / ('model-' + name + '-0003')
    dest.mkdir(exist_ok=False)
    (dest / 'check.sml').write_text(text)
    records.append({'case': name+'-0003', 'source_sha256': sha(dest/'check.sml'),
                    'prior_frozen_source_sha256': sha(prior),
                    'all_four_equations_equal_original_negative_case': True,
                    'changed_array': index, 'changed_offset': offset,
                    'old_value': old_value, 'new_value': new_value,
                    'actual_exit': None})

runner = OUT / 'run_model_check.py'
before = runner.read_bytes()
backup = OUT / 'run_model_check-before-controls-U288.py'
assert not backup.exists()
backup.write_bytes(before)
changed = before.decode().replace("'positive-0003','constructor-diagnostic'", "'positive-0003','altered-read-byte-0003','wrong-write-descriptor-0003','constructor-diagnostic'")
assert changed != before.decode()
runner.write_text(changed)
record = {'actual_exit': 0, 'scope': 'Preparation and exact negative-input identity only',
          'cases': records, 'positive_model_check_still_owned_by_original_runner': True,
          'end_to_end': False}
(OUT/'constructor-controls-preparation.json').write_text(json.dumps(record,indent=2)+'\n')
print(json.dumps(record))
