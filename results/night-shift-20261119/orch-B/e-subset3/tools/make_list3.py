#!/usr/bin/env python3
"""Write ../heavy/list3.txt (CLASS ABSOLUTE-PATH per line) from ../eval3_results.json for gate_subset3.sh."""
import json
from pathlib import Path
E = Path(__file__).resolve().parent.parent
rows = json.loads((E / 'eval3_results.json').read_text())
order = {'correct': 0, 'hostile': 1, 'control': 2, 'benign': 2}
lines = ['%s-%s /Users/mackianni/forge/%s' % (r['class'], r['group'], r['file'])
         for r in sorted(rows, key=lambda r: (order[r['class']], r['group'], r['name']))]
(E / 'heavy/list3.txt').write_text('\n'.join(lines) + '\n')
print(len(lines), 'lines')
