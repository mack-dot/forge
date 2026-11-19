#!/usr/bin/env python3
"""Pure-Python evaluation of rule 1 (e-totality), rule 2 (e-subset2) and rule 3 on all known corpora.
Writes ../eval3_results.json and prints the confusion tables and the per-file lists."""
import hashlib, importlib.util, json, sys
from pathlib import Path
sys.dont_write_bytecode = True
E = Path(__file__).resolve().parent.parent
B = E.parent
R = Path('/Users/mackianni/forge')
DR = R / 'proposals/m1b-mission-20261119/drafts'


def load(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


r1 = load(B / 'e-subset2/src-orig/subset_rule.py', 'r1')
r2 = load(B / 'e-subset2/subset_rule2.py', 'r2')
r3 = load(E / 'subset_rule3.py', 'r3')
rows, seen = [], set()
# Lexer/verifier agreement controls: benign under Dafny's own lexing (the dangerous text is comment or string
# text per controls L01-L06) or refused by Dafny itself (E04: false assertion). Not cost-hostile.
CONTROLS = {'L11-block-comment-with-slashes-cr', 'L12-string-with-comment-close', 'L13-verbatim-doubled-quote',
            'L14-char-dquote-and-escaped-quote', 'L18-include-at-line-start-in-block-comment',
            'L19-attr-induction-extra-spaces', 'K05-eof-line-comment-no-newline', 'K07-u0085-line-comment',
            'E04-assert-by', 'S3-u2028-in-line-comment', 'S4-formfeed-in-line-comment'}


def row(group, cls, path):
    path = Path(path)
    if path in seen:
        return
    seen.add(path)
    data = path.read_bytes()
    cls = 'control' if path.stem in CONTROLS else cls
    rows.append({'group': group, 'class': cls, 'name': path.stem, 'file': str(path.relative_to(R)),
                 'sha256': hashlib.sha256(data).hexdigest(), 'rule1': r1.rule(data) or 'pass',
                 'rule2': r2.rule(data) or 'pass', 'rule3': r3.rule(data) or 'pass', 'W3': r3.bound(data)})


# Correct side: 36 known correct (list2 G1-correct + new-correct), N01-N12 (list2 n2-correct), r-subset2 C01-C20.
for line in (B / 'e-subset2/heavy/list2.txt').read_text().splitlines():
    cls, path = line.split()
    group = {'G1-correct': 'K36', 'new-correct': 'K36', 'n2-correct': 'N'}.get(cls, cls)
    row(group, 'correct' if cls.endswith('correct') else 'hostile', path)
for f in sorted((B / 'r-subset2/subs').glob('C*.dfy')):
    row('C20', 'correct', f)
# Hostile and halting side.
for f in sorted((B / 'r-subset2/subs').glob('*.dfy')):
    row('REVIEW', 'hostile', f)
for f in sorted((B / 'e-totality/subs/hostile').glob('*.dfy')):
    row('x2-hostile-refused', 'hostile', f)
for f in sorted((B / 'e-subset2/subs/hostile').glob('*.dfy')):
    row('x2-hostile-refused', 'hostile', f)
for f in sorted((B / 'e-expect/p2/subs').glob('*.dfy')):
    row('P2', 'hostile' if f.name[0] in 'HK' else 'benign', f)
for f in sorted((DR / 'expect-rule/subs').glob('*.dfy')):
    row('EXPECT-DRAFT', 'hostile', f)
for f in sorted((E / 'subs/hostile').glob('*.dfy')):
    row('NEW3', 'hostile', f)
for f in sorted((E / 'subs/probe').glob('*.dfy')):   # P03 verifies but fails to LOAD (static `prototype`)
    row('PROBE', 'hostile' if f.name.startswith('P03') else 'benign', f)
for f in sorted((B / 'e-subset2/subs/controls').glob('*.dfy')):
    row('L', 'control', f)
(E / 'eval3_results.json').write_text(json.dumps(rows, indent=1) + '\n')

correct = [r for r in rows if r['class'] == 'correct']
hostile = [r for r in rows if r['class'] == 'hostile']
print('CONFUSION (correct = should admit; hostile = halting/hostile/bypass, should refuse)')
print('  %-6s %-28s %-28s' % ('rule', 'correct admitted/refused', 'hostile admitted/refused'))
for k in ('rule1', 'rule2', 'rule3'):
    print('  %-6s %3d / %-22d %3d / %-22d' % (k, sum(r[k] == 'pass' for r in correct),
                                              sum(r[k] != 'pass' for r in correct),
                                              sum(r[k] == 'pass' for r in hostile),
                                              sum(r[k] != 'pass' for r in hostile)))
for g in ('K36', 'N', 'C20'):
    rs = [r for r in correct if r['group'] == g]
    print('  correct group %-4s n=%-3d r1=%-3d r2=%-3d r3=%d admitted' % (
        g, len(rs), *(sum(r[k] == 'pass' for r in rs) for k in ('rule1', 'rule2', 'rule3'))))
for g in sorted({r['group'] for r in hostile}):
    rs = [r for r in hostile if r['group'] == g]
    print('  hostile group %-20s n=%-3d r1=%-3d r2=%-3d r3=%d admitted' % (
        g, len(rs), *(sum(r[k] == 'pass' for r in rs) for k in ('rule1', 'rule2', 'rule3'))))
print('CORRECT REFUSED BY RULE 3:')
for r in correct:
    if r['rule3'] != 'pass':
        print('   %-4s %-44s %s' % (r['group'], r['name'], r['rule3'][:100]))
print('HOSTILE ADMITTED BY RULE 3:')
for r in hostile:
    if r['rule3'] == 'pass':
        print('   %-18s %-44s W=%s %s' % (r['group'], r['name'], r['W3'], r['sha256'][:16]))
print('REVIEW FILES (rule 3):')
for r in rows:
    if r['group'] == 'REVIEW' or r['name'][:4] in ('HV15', 'HV23', 'HV24', 'HV26', 'X02-', 'X06-', 'X33-', 'X38-'):
        print('   %-44s %s' % (r['name'], r['rule3'][:90]))
print('BENIGN/CONTROL (rule 3):', [(r['name'], r['rule3'][:30]) for r in rows if r['class'] in ('benign', 'control')])
ctl = [r for r in rows if r['class'] in ('benign', 'control')]
print('CONTROLS n=%d admitted r1=%d r2=%d r3=%d' % (len(ctl), *(sum(r[k] == 'pass' for r in ctl) for k in ('rule1', 'rule2', 'rule3'))))
