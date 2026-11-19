import importlib.util, sys
sys.path.insert(0, '<REPO>/gate')
spec = importlib.util.spec_from_file_location('ppr', sys.argv[1]); m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
def cov(paths, findings=None, affected=()):
    return {'changed': [{'path': p, 'change': 'modified'} for p in paths],
            'findings': findings if findings is not None else [{'path': p, 'reason': 'UNCOVERED_CHANGE'} for p in paths],
            'affected_obligations': ['ledger-proof'] + list(affected), 'covered': False}
cases = [
 ('exit0', 0, None, True),
 ('docs only', 3, cov(['ROADMAP.md', 'unsure.md', 'proposals/m1b/x.md', 'results/a/b.txt']), True),
 ('exit1', 1, cov(['README.md']), False),
 ('exit2', 2, None, False),
 ('code file', 3, cov(['README.md', 'impl/Refund.dfy']), False),
 ('dfy under proposals', 3, cov(['proposals/x/proof.dfy']), False),
 ('workflow md', 3, cov(['.github/workflows/x.md']), False),
 ('gate md', 3, cov(['gate/expected-audit.md']), False),
 ('upper MD', 3, cov(['NOTES.MD']), False),
 ('dotdot', 3, cov(['proposals/../gate/x.md']), False),
 ('json result', 3, cov(['results/x.json']), False),
 ('dependency finding', 3, cov(['README.md'], [{'path': 'README.md', 'reason': 'UNKNOWN_DEPENDENCY'}]), False),
 ('affected obligation', 3, cov(['proposals/refund-decision.md'], affected=['refund']), False),
 ('empty change list', 3, cov([]), False),
 ('no coverage', 3, None, False),
 ('finding on other path', 3, cov(['README.md'], [{'path': 'impl/x.dfy', 'reason': 'UNCOVERED_CHANGE'}]), False),
]
bad = 0
for name, code, c, want in cases:
    got = m.admission(code, c)[0]
    print(('ok  ' if got == want else 'FAIL'), name, got); bad += got != want
sys.exit(1 if bad else 0)
