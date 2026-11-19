import sys
sys.path.insert(0, '/Users/USER/forge/results/night-shift-20261119/orch-A/launch')
import launcher as L
EXE = '/Users/USER/forge/results/night-shift-20261119/orch-A/ffi-c-audit/refund'
f = dict(charge=b'c', request=b'r', original=100, remaining=60, enabled=True, opened=True, candidate=True, amount=40, reason=b'returned_item')
print(L.decide(f, EXE))
print(L.decide(dict(f, amount=400), EXE))
sys.exit(0)
