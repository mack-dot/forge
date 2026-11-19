"""Bounded check: survivors M06, M07, M12 give the same decision as the original on enumerated inputs."""
import importlib.util, itertools, sys
sys.dont_write_bytecode = True
sys.path.insert(0, '<REPO>/gate')
def load(p, n):
    s = importlib.util.spec_from_file_location(n, p); m = importlib.util.module_from_spec(s); s.loader.exec_module(m); return m
orig = load(sys.argv[1], 'o')
muts = {t: load('mutants/%s.py' % t, t) for t in ('M06-case-sensitive-prefix', 'M07-allow-empty-rows', 'M12-drop-gate-prefix')}
segs = ['gate', 'GATE', 'Gate', '.github', '.GITHUB', 'proposals', 'docs', 'results', 'spec', 'clearing', 'x', '.', '..', '', 'a.md', 'b.txt', 'C.MD']
paths = ['/'.join(c) for n in (1, 2, 3) for c in itertools.product(segs, repeat=n)]
def cov(ps, fs):
    return {'changed': [{'path': p} for p in ps], 'findings': [{'path': f, 'reason': 'UNCOVERED_CHANGE'} for f in fs],
            'affected_obligations': ['ledger-proof']}
cases = [cov([p], [p]) for p in paths] + [cov([], []), cov([], ['a.md']), cov([], ['']), cov(['a.md'], [])]
diff = {t: sum(orig.admission(3, c)[0] != m.admission(3, c)[0] for c in cases) for t, m in muts.items()}
print('cases', len(cases), 'differences', diff)
sys.exit(1 if any(diff.values()) else 0)
