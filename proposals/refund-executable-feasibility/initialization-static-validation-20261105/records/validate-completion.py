"""Check the corrected negative control and preserve the first harness failure."""
from pathlib import Path
import json
import re

OUT = Path(__file__).resolve().parent
read = lambda p: json.loads(p.read_text())
logs = lambda n: ''.join((OUT/n/f).read_text() for f in ['stdout.log', 'stderr.log'])
assert not (OUT/'validation-completion.json').exists()
assert read(OUT/'validation-sequence-failure.json')['actual_exit'] == 1
expected = {'exact-import-0002': 0, 'parent-repeat': 0, 'static-repeat': 0,
            'wrong-code': 1, 'wrong-oracle': 1, 'missing-memory': 1, 'missing-memory-0002': 1}
for name, code in expected.items():
    assert read(OUT/name/'command.json')['actual_exit'] == code
assert 'No match' in logs('missing-memory')
log = logs('missing-memory-0002')
markers = re.findall(r'^IMPORTED .*$', log, re.M)
assert len(markers) == 7 and all('HYPOTHESES 0 TAGGED_AXIOMS 0' in m for m in markers)
assert 'AFTER_POSITIVE_AUDIT' in log and 'UNEXPECTED_CONTROL_ACCEPTANCE' not in log
assert 'unsolved goals' in log and 'memory_assumption' in log
assert 'No match' not in log
record = {'actual_exit': 0, 'child_exits': expected,
          'first_missing_memory_case': 'Harness failure; not an accepted negative control.',
          'corrected_missing_memory_case': 'Positive audit passes; memory_assumption remains unproved.',
          'end_to_end': False}
(OUT/'validation-completion.json').write_text(json.dumps(record, indent=2)+'\n')
print(json.dumps(record))
