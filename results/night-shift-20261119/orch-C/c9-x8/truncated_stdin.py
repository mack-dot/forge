"""c9-x8: premature EOF on stdin (A-FD0-READ violated: read returns 0 before the request ends).
Exit 1 if any truncated request gives a strictly parsing frame (dangerous direction); 0 otherwise."""
import sys, subprocess
sys.path.insert(0, '<REPO>/proposals/m1b-mission-20261119/drafts/fail-closed')
import frame
EXE = '<REPO>/results/night-shift-20261119/orch-A/ffi-c-audit/refund'
ENV = {'PATH': '/usr/bin:/bin', 'LANG': 'C', 'LC_ALL': 'C', 'CML_HEAP_SIZE': '256', 'CML_STACK_SIZE': '256'}
S = frame.render_request(b'c', b'r', 100, 60, True, True, True, 40, b'returned_item')
bad = 0
for cut in [0, 1, len(S) // 2, len(S) - 2, len(S) - 1]:
    p = subprocess.run([EXE], input=S[:cut], capture_output=True, env=ENV, timeout=20)
    acc = frame.strict_accepts(p.stdout)
    print(cut, p.returncode, len(p.stdout), acc)
    bad |= acc is not None
sys.exit(1 if bad else 0)
