import sys, os
sys.dont_write_bytecode = True
which = sys.argv[1]
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', which, 'gate'))
import incremental, approval
from common import Rejected
members = sorted(incremental.OBLIGATIONS - incremental.dafny.REQUIRED_RESULTS)
snap = ''.join('Verifying %s ...\n' % m for m in members) + 'Dafny program verifier finished with %d verified, 0 errors\n' % len(members)
print(which, '| gate/backends/dafny.py ratifiable:', approval._ratifiable('gate/backends/dafny.py'),
      '| len(incremental.OBLIGATIONS) =', len(incremental.OBLIGATIONS))
try:
    incremental.trace_coverage(snap + snap)
    print(which, '| trace WITHOUT Ledger.Apply (correctness): trace_coverage ACCEPTS it')
except Rejected as e:
    print(which, '| trace WITHOUT Ledger.Apply (correctness): Rejected:', str(e))
