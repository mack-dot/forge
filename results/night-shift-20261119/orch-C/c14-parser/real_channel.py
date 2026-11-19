"""c14 (c)(e): the repository's full host path m1_fail_closed.decide() (private copy, pinned SHA-256, file
stdout with RLIMIT_FSIZE = bound+1, strict parse) on edge requests. Exit 1 if any verdict differs from
the oracle. Also checks that every stdout file holds exactly one frame and no byte after it."""
import sys, os, tempfile
sys.path.insert(0, '/Users/mackianni/forge/results/night-shift-20261119/orch-C/c14-parser')
from common import EXE, oracle, fc, MAX  # noqa
tempfile.tempdir = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'tmp')
os.makedirs(tempfile.tempdir, exist_ok=True)


def F(c=b'c', q=b'r', o=100, r=60, a=40, rs=b'returned_item', e=True):
    return {'charge': c, 'request': q, 'original': o, 'remaining': r, 'enabled': e, 'opened': True,
            'candidate': True, 'amount': a, 'reason': rs}


M = 1 << 20
cases = [F(), F(a=0), F(a=60), F(a=61), F(o=MAX, r=MAX, a=MAX), F(o=MAX, r=MAX, a=0), F(e=False),
         F(c=b'\x00\r\t\n"\\()' * 300, q=b'\xff' * 5000, a=0), F(c=b'c' * M, q=b'"' * M, a=60),
         F(c=b'c' * M, rs=b'bogus'), F(c=b'', q=b'r'), F(rs=b'returned_item\n'), F(o=MAX + 1, r=0, a=0),
         F(c=b' ' * 2049, q=b'\t' * 4097, a=60, rs=b'service_not_delivered')]
bad = 0
for f in cases:
    got, exp = fc.decide(f, EXE), oracle(f)
    ok = got[0] == exp[0] and (got[0] != 'AUTHORIZED' or got[1:] == exp[1:])
    bad += not ok
    print('OK ' if ok else 'BAD', got[0], str(got[1:])[:80], '| oracle', exp[0])
print('runs', len(cases), 'bad', bad)
sys.exit(1 if bad else 0)
