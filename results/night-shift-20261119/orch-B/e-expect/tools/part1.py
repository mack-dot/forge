#!/usr/bin/env python3
"""Part 1: run the proposed rule (from the patched copy) over the G1 75 and every refund implementation in the repo."""
import hashlib, json, sys
from pathlib import Path
sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))
from rule_harness import new_rule, source_scope
REPO = Path('/Users/mackianni/forge')
E = Path(__file__).resolve().parent.parent
D = REPO / 'proposals/m1b-mission-20261119/drafts'
g1 = json.loads((D / 'expect-rule/rule_results.json').read_text())
y5 = {p.stem: p for p in (D / 'zero-review/subs').glob('*.dfy')}
z1 = {p.stem: p for p in (D / 'expect-rule/subs').glob('*.dfy')}
rows, mism = [], []
for r in g1:
    p = y5.get(r['name']) or z1.get(r['name'])
    data = p.read_bytes()
    sha = hashlib.sha256(data).hexdigest()
    nr, sc = new_rule(data), source_scope(data)
    stored_refuse = r['new_rule'] != 'pass'
    if sha != r['sha256'] or (nr is not None) != stored_refuse:
        mism.append(r['name'])
    rows.append({'set': 'G1', 'file': str(p.relative_to(REPO)), 'sha256': sha, 'ideal': r['ideal'],
                 'stored_new_rule': 'REFUSE' if stored_refuse else 'pass', 'new_rule': nr or 'pass',
                 'source_scope_after_patch': sc or 'pass', 'stored_after_full_gate': r['after']})
g1_shas = {r['sha256'] for r in rows}
repo = [l.strip() for l in open(sys.argv[1]) if l.strip()]
seen = {}
for f in repo:
    data = (REPO / f).read_bytes()
    sha = hashlib.sha256(data).hexdigest()
    seen.setdefault(sha, []).append(f)
impl_sha = hashlib.sha256((REPO / 'impl/Refund.dfy').read_bytes()).hexdigest()
for sha, files in sorted(seen.items(), key=lambda kv: kv[1][0]):
    data = (REPO / files[0]).read_bytes()
    rows.append({'set': 'REPO', 'file': files[0], 'copies': len(files), 'sha256': sha,
                 'in_G1': sha in g1_shas, 'is_impl_Refund': sha == impl_sha,
                 'new_rule': new_rule(data) or 'pass', 'source_scope_after_patch': source_scope(data) or 'pass'})
(E / 'p1/part1_results.json').write_text(json.dumps(rows, indent=1) + '\n')
g = [r for r in rows if r['set'] == 'G1']
def cnt(rs, ideal, ref):
    return sum(1 for r in rs if r['ideal'] == ideal and (r['new_rule'] != 'pass') == ref)
print('G1 rows', len(g), 'stored-vs-recomputed mismatches', mism)
print('G1 ideal REFUSED: rule refuses', cnt(g, 'REFUSED', True), 'rule passes', cnt(g, 'REFUSED', False))
print('G1 ideal ADMITTED: rule refuses', cnt(g, 'ADMITTED', True), 'rule passes', cnt(g, 'ADMITTED', False))
rp = [r for r in rows if r['set'] == 'REPO']
print('REPO unique', len(rp), 'files', len(repo), 'in G1', sum(r['in_G1'] for r in rp))
print('REPO refused by new rule:', [(r['file'], r['new_rule']) for r in rp if r['new_rule'] != 'pass'])
print('REPO refused by source scope (old+new):', sum(r['source_scope_after_patch'] != 'pass' for r in rp))
print('impl/Refund.dfy', impl_sha, [ (r['new_rule'], r['source_scope_after_patch']) for r in rp if r['is_impl_Refund']])
