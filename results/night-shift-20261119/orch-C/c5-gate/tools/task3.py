#!/usr/bin/env python3
"""Task 3: re-run rule 3 (orch-B/e-subset3/subset_rule3.py, read-only) on the seven known unsafe submissions,
the 24 halting submissions and every hostile row of eval3_results.json. Exit 1 if any of the seven or any
halting file is admitted, or if any current verdict differs from the recorded one; else 0."""
import importlib.util, json, sys, hashlib
from pathlib import Path
R = Path('<REPO>'); B = R / 'results/night-shift-20261119/orch-B'
spec = importlib.util.spec_from_file_location('r3', B / 'e-subset3/subset_rule3.py'); r3 = importlib.util.module_from_spec(spec); spec.loader.exec_module(r3)
rows = json.loads((B / 'e-subset3/eval3_results.json').read_text())
SEVEN = {'E06-stack-overflow-keyed', 'E07-oom-keyed', 'E08-time-keyed', 'H01b-such-that-modulus-hang',
         'H02-exponential-recursion-hang', 'H03-seq-comprehension-alloc', 'H04-seq-length-2pow32-throws'}
bad = 0; seen7 = set(); halt_adm = 0; halt_n = 0; host_adm = 0; host_n = 0; drift = 0; corr_adm = 0; corr_n = 0
for r in rows:
    data = (R / r['file']).read_bytes()
    if hashlib.sha256(data).hexdigest() != r['sha256']:
        print('CHANGED FILE', r['name']); drift += 1
    v = r3.rule(data) or 'pass'
    if v != r['rule3']:
        print('VERDICT DRIFT', r['name'], r['rule3'][:50], '->', v[:50]); drift += 1
    if r['name'] in SEVEN:
        seen7.add(r['name']); print('SEVEN', r['name'], '|', v[:70])
        if v == 'pass': bad += 1
    if r['group'] == 'halting':
        halt_n += 1; halt_adm += v == 'pass'
    if r['class'] == 'hostile':
        host_n += 1; host_adm += v == 'pass'
    if r['class'] == 'correct':
        corr_n += 1; corr_adm += v == 'pass'
print('seven found %d/7 admitted %d' % (len(seen7), bad))
print('halting n=%d admitted=%d' % (halt_n, halt_adm))
print('hostile rows n=%d admitted=%d (B recorded 20 admitted, all argued or run safe by B)' % (host_n, host_adm))
print('correct rows n=%d admitted=%d refused=%d' % (corr_n, corr_adm, corr_n - corr_adm))
print('drift', drift)
sys.exit(1 if bad or halt_adm or drift or len(seen7) != 7 else 0)
