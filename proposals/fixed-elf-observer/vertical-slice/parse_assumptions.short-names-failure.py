import json
from pathlib import Path
import sys
sys.path[:0] = ['/audit-tools', '/pydeps']
from oft.check import wrapper_assumptions, allowed_axioms
actual = wrapper_assumptions(Path('/slice/positive.log').read_text())
allowed = allowed_axioms('/', '/allowed-axioms.txt')
prior = set(json.loads(Path('/prior-assumptions.json').read_text()))
assert actual and not actual - allowed and actual <= prior
Path('/slice-output/assumptions.json').write_text(json.dumps(sorted(actual), indent=2) + '\n')
print(json.dumps({'count': len(actual), 'subset_of_existing_closure': True}))
