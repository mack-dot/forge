#!/usr/bin/env python3
"""Pure-Python evaluation of subset rule 1 (e-totality) and rule 2 on all known corpora (copy of
e-totality/tools/evaluate.py, extended). Writes ../eval2_results.json; prints the tables."""
import hashlib, importlib.util, json, sys
from pathlib import Path
sys.dont_write_bytecode = True
E = Path(__file__).resolve().parent.parent
B = E.parent
R = Path('<REPO>')


def load(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


r1 = load(E / 'src-orig/subset_rule.py', 'r1')
r2 = load(E / 'subset_rule2.py', 'r2')
P1 = json.loads((B / 'e-expect/p1/part1_results.json').read_text())
HEAVY = {}
for line in (B / 'heavy/gate-subset/summary.txt').read_text().splitlines():
    parts = line.split()
    if len(parts) > 3 and parts[2] == 'exit':
        HEAVY[parts[1]] = 'ADMITTED' if parts[3] == '0' else 'REFUSED'
SCOPE_TODAY = {'C9-comment-word-include', 'C10-induction-attr', 'C11-at-in-string', 'C12-crlf-header'}
rows = []


def row(group, cls, path, **extra):
    data = path.read_bytes()
    out = {'group': group, 'class': cls, 'name': path.stem, 'file': str(path.relative_to(R)),
           'sha256': hashlib.sha256(data).hexdigest(), 'rule1': r1.rule(data) or 'pass',
           'rule2': r2.rule(data) or 'pass', 'N2': r2.bound(data)}
    out.update(extra)
    rows.append(out)


for x in P1:
    if x['set'] == 'G1':
        cls = 'correct' if x['ideal'] == 'ADMITTED' else 'wrong'
        row('G1', cls, R / x['file'], stored_all_tiers_with_expect=x['stored_after_full_gate'])
for f in sorted((B / 'e-totality/subs/correct').glob('*.dfy')):
    row('CV', 'correct', f)
for f in sorted((B / 'e-totality/subs/hostile').glob('*.dfy')):
    row('HV', 'hostile', f)
for f in sorted((B / 'e-expect/p2/subs').glob('*.dfy')):
    cls = {'H': 'halting', 'K': 'lexer', 'B': 'benign'}[f.name[0]]
    row('P2', cls, f)
for f in sorted((E / 'subs/correct').glob('*.dfy')):
    row('N', 'correct', f)
for f in sorted((E / 'subs/hostile').glob('*.dfy')):
    row('X', 'hostile', f)
for f in sorted((E / 'subs/controls').glob('*.dfy')):
    row('L', 'control', f)
HALTING = {'E06-stack-overflow-keyed', 'E07-oom-keyed', 'E08-time-keyed', 'A18-runtime-exhaustion',
           'A33-const-alloc-exhaustion', 'A37-uncompilable-such-that', 'A16-decreases-star',
           'A32-dead-main-decreases-star', 'Z24-expect-halt-amount-61', 'Z24-expect-halt-amount-1000',
           'Z24-expect-halt-amount-123456789', 'Z24-expect-halt-amount-9223372036854775805',
           'A24-expect-halt-one-input', 'A25-expect-as-assume-wrong-value', 'A38-expect-always-halt',
           'A39-expect-in-helper-method', 'E02-array-oob', 'E03-div-zero', 'S1-cr-ends-line-comment',
           'S2-cr-comment-hides-keyed-expect'}
for r in rows:
    r['halting'] = r['name'] in HALTING or r['class'] == 'halting'
    if r['group'] in ('G1', 'CV'):
        r['heavy_before'] = HEAVY.get(r['name'])
(E / 'eval2_results.json').write_text(json.dumps(rows, indent=1) + '\n')


def show(title, rs):
    print(title)
    for r in rs:
        print('   %-48s N2=%-5s r1=%-24s r2=%s' % (r['name'], r['N2'], r['rule1'][:24], r['rule2'][:80]))


correct = [r for r in rows if r['group'] in ('G1', 'CV') and r['class'] == 'correct']
print('KNOWN CORRECT (19 G1 + 17 CV = %d)' % len(correct))
print('  rule1 alone admits %d; rule2 alone admits %d' % (
    sum(r['rule1'] == 'pass' for r in correct), sum(r['rule2'] == 'pass' for r in correct)))
print('  heavy gate before (combined diff with rule1, measured): admitted %d' % sum(
    r['heavy_before'] == 'ADMITTED' for r in correct))
pred = [r for r in correct if r['rule2'] == 'pass' and (r['name'] not in SCOPE_TODAY) and
        r.get('stored_all_tiers_with_expect', 'ADMITTED') == 'ADMITTED']
pred_scope = [r for r in correct if r['rule2'] == 'pass' and
              r.get('stored_all_tiers_with_expect', 'ADMITTED') in ('ADMITTED',) or
              r['name'] in SCOPE_TODAY and r['rule2'] == 'pass']
print('  predicted gate with rule2 (other tiers from stored results; NOT RUN): %d; with scope diff: %d' % (
    len(pred), len(pred_scope)))
show('  still refused by rule2:', [r for r in correct if r['rule2'] != 'pass'])
bad = [r for r in rows if r['halting'] and r['rule2'] == 'pass']
print('HALTING/HANGING set: %d files; admitted by rule2: %s' % (
    sum(r['halting'] for r in rows), [r['name'] for r in bad]))
print('G1 wrong: rule1 pass %d, rule2 pass %d; newly passing under rule2: %s' % (
    sum(r['rule1'] == 'pass' for r in rows if r['group'] == 'G1' and r['class'] == 'wrong'),
    sum(r['rule2'] == 'pass' for r in rows if r['group'] == 'G1' and r['class'] == 'wrong'),
    [r['name'] for r in rows if r['group'] == 'G1' and r['class'] == 'wrong' and r['rule1'] != 'pass'
     and r['rule2'] == 'pass']))
print('Rule1-refused, rule2-admitted (all groups):')
for r in rows:
    if r['rule1'] != 'pass' and r['rule2'] == 'pass':
        print('   %-6s %-9s %-46s N2=%s' % (r['group'], r['class'], r['name'], r['N2']))
print('Rule1-admitted, rule2-refused (all groups):', [(r['name'], r['rule2'][:40]) for r in rows
                                                       if r['rule1'] == 'pass' and r['rule2'] != 'pass'])
for g in ('HV', 'X', 'P2', 'N', 'L'):
    show('GROUP ' + g, [r for r in rows if r['group'] == g])
