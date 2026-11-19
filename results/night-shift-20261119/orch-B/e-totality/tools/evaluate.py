#!/usr/bin/env python3
"""Pure-Python evaluation of the subset rule on G1 (75), REPO (92 unique), e-expect p2 subs (19) and new variants."""
import hashlib, json, sys
from pathlib import Path
sys.dont_write_bytecode = True
E = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(E))
from subset_rule import rule, straight_line_subset, Rejected
R = Path('/Users/mackianni/forge')
P1 = json.loads((E.parent / 'e-expect/p1/part1_results.json').read_text())
rows = []
def bound(data):
    try:
        return straight_line_subset(data)
    except Rejected:
        return None
for x in P1:
    data = (R / x['file']).read_bytes()
    assert hashlib.sha256(data).hexdigest() == x['sha256'], x['file']
    r = rule(data)
    row = {'set': x['set'], 'file': x['file'], 'sha256': x['sha256'], 'subset': r or 'pass', 'N': bound(data),
           'scope_after_expect_patch': x['source_scope_after_patch']}
    if x['set'] == 'G1':
        before = x['stored_after_full_gate']
        row.update(ideal=x['ideal'], before_all_tiers_with_expect_rule=before,
                   after=before if before == 'REFUSED' or r is None else 'REFUSED')
    rows.append(row)
P2 = {'H': 'REFUSED', 'K': 'REFUSED', 'B': None}
for f in sorted((E.parent / 'e-expect/p2/subs').glob('*.dfy')):
    data = f.read_bytes(); r = rule(data)
    rows.append({'set': 'P2', 'file': str(f.relative_to(R)), 'sha256': hashlib.sha256(data).hexdigest(),
                 'subset': r or 'pass', 'N': bound(data)})
for kind in ('correct', 'hostile'):
    for f in sorted((E / 'subs' / kind).glob('*.dfy')):
        data = f.read_bytes(); r = rule(data)
        rows.append({'set': 'NEW-' + kind, 'file': str(f.relative_to(R)), 'sha256': hashlib.sha256(data).hexdigest(),
                     'subset': r or 'pass', 'N': bound(data)})
(E / 'eval_results.json').write_text(json.dumps(rows, indent=1) + '\n')
g1 = [r for r in rows if r['set'] == 'G1']
def cnt(rs, ideal, ok):
    return sum(1 for r in rs if r['ideal'] == ideal and (r['subset'] == 'pass') == ok)
print('G1 subset alone: correct admitted %d, correct refused %d, wrong refused %d, wrong passed %d' % (
    cnt(g1, 'ADMITTED', True), cnt(g1, 'ADMITTED', False), cnt(g1, 'REFUSED', False), cnt(g1, 'REFUSED', True)))
print('G1 correct refused by subset:', [(Path(r['file']).stem, r['subset'].split(':')[0]) for r in g1
                                         if r['ideal'] == 'ADMITTED' and r['subset'] != 'pass'])
print('G1 composed (all tiers + expect rule + subset): correct admitted %d; wrong still admitted %s; no verdict %s' % (
    sum(r['ideal'] == 'ADMITTED' and r['after'] == 'ADMITTED' for r in g1),
    [Path(r['file']).stem for r in g1 if r['ideal'] == 'REFUSED' and r['after'] == 'ADMITTED'],
    [Path(r['file']).stem for r in g1 if r['after'] == 'NO-VERDICT']))
print('G1 composed: correct admitted before subset %d after %d' % (
    sum(r['ideal'] == 'ADMITTED' and r['before_all_tiers_with_expect_rule'] == 'ADMITTED' for r in g1),
    sum(r['ideal'] == 'ADMITTED' and r['after'] == 'ADMITTED' for r in g1)))
print('G1 newly refused by subset (were admitted):', [(Path(r['file']).stem, r['ideal']) for r in g1
      if r['before_all_tiers_with_expect_rule'] != 'REFUSED' and r['after'] == 'REFUSED'])
repo = [r for r in rows if r['set'] == 'REPO']
inscope = [r for r in repo if r['scope_after_expect_patch'] == 'pass']
print('REPO unique %d: subset pass %d refuse %d; within existing scope rules %d, of which subset refuses %d:' % (
    len(repo), sum(r['subset'] == 'pass' for r in repo), sum(r['subset'] != 'pass' for r in repo), len(inscope),
    sum(r['subset'] != 'pass' for r in inscope)))
for r in inscope:
    if r['subset'] != 'pass':
        print('   ', r['file'], '|', r['subset'])
for s in ('P2', 'NEW-correct', 'NEW-hostile'):
    print(s)
    for r in rows:
        if r['set'] == s:
            print('   %-60s N=%-5s %s' % (Path(r['file']).stem, r['N'], r['subset']))
